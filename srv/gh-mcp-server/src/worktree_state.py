"""Shared worktree lifecycle layer — lock v2, 7-state classifier, hint index, acquire/release.

One contract consumed by the MCP tool handlers (``worktree_mutation.py``,
``local_read.py``). Python is authoritative for writes (locks + hint index);
sdd-tool (Go) reads locks read-only (observer, fail-open).

Safety contract:
- Never silently take over a live claim: ``exists_active_other`` always denies
  ``owned_by_other``; ``reclaimed`` is reserved (unreachable with current
  signals — PID-alive cannot prove abandonment).
- Corrupt evidence (worktree dir not in porcelain, unparsable lock) is never
  overwritten: deny ``corrupt_worktree`` / ``locked_unreadable``.
- ``last_seen`` updates on every acquire transition (created/attached/claimed);
  ``already_mine`` mutates nothing. ``created_at`` is preserved on re-claims.
- The hint index is a write-through cache only — porcelain + disk + lock are
  truth; corrupt/missing index is rebuilt empty; write failure is warn-only.
"""

from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import TYPE_CHECKING, Any

from src.envelope import Envelope, err, ok

if TYPE_CHECKING:
    from src.executor import ExecutorProto

# ---------------------------------------------------------------------------
# Constants — lock + index + safe slug (one contract)
# ---------------------------------------------------------------------------

LOCK_FILENAME = ".sdd-agent-lock"
SERVER_OWNED = {".codegraph", ".sdd-agent-lock"}
CODEGRAPH_DIRNAME = ".codegraph"
INDEX_FILENAME = ".agent-index.json"
LOCK_VERSION = 2
INDEX_VERSION = 1
LOCK_STORE_DEFAULT = "hybrid"

_SAFE_SLUG = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


# ---------------------------------------------------------------------------
# Path derivation — never a raw path from the caller, never hardcoded
# ---------------------------------------------------------------------------

def _agent_worktrees_root() -> Path:
    """Test seam: the ``~/.agent_worktrees`` root (monkeypatch in tests)."""
    return Path.home() / ".agent_worktrees"


def repo_toplevel(executor: ExecutorProto, repo_path: str) -> str:
    """``git rev-parse --show-toplevel`` output, or ``""`` on failure."""
    r = executor.run(["git", "-C", repo_path, "rev-parse", "--show-toplevel"])
    if r.returncode == 0 and r.stdout.strip():
        return r.stdout.strip()
    return ""


def derive_repo_name(executor: ExecutorProto, repo_path: str) -> str:
    """Basename of the git root — the worktree namespace (never hardcoded).

    ``/repo``, ``/repo/sub`` and ``/repo/.`` all land in the SAME namespace;
    a non-repo falls back to the passed path's basename.
    """
    root = repo_toplevel(executor, repo_path)
    if root:
        return os.path.basename(os.path.normpath(root))
    return os.path.basename(os.path.normpath(repo_path))


def worktree_path_for(repo_name: str, change: str) -> str:
    """Canonical worktree path for a repo namespace + change."""
    return str(_agent_worktrees_root() / repo_name / change)


def canonical_worktree_path(executor: ExecutorProto, repo_path: str, change: str) -> str:
    """Derive the canonical worktree path — caller input is never used raw.

    ``~/.agent_worktrees/<git-root-basename>/<change>`` resolved via
    ``Path.home()``; the git root comes from ``git rev-parse --show-toplevel``.
    """
    return worktree_path_for(derive_repo_name(executor, repo_path), change)


def validate_safe_slug(change: str) -> str | None:
    """Return an error message if *change* is not a safe slug, else ``None``.

    Safe-slug rule (design Interfaces/Contracts): ``^[A-Za-z0-9][A-Za-z0-9._-]*$``;
    rejects ``/``, ``\\``, ``..``, empty.
    """
    if not isinstance(change, str) or not change:
        return "change is empty"
    if ".." in change:
        return "change contains '..'"
    if not _SAFE_SLUG.match(change):
        return "change must match ^[A-Za-z0-9][A-Za-z0-9._-]*$ (no /, \\, spaces)"
    return None


# ---------------------------------------------------------------------------
# Lock v2 — read/parse/write/remove + PID liveness
# ---------------------------------------------------------------------------

def lock_path(worktree: str) -> str:
    """Path of the agent lock inside a worktree root."""
    return os.path.join(worktree, LOCK_FILENAME)


def read_lock_v2(worktree: str) -> tuple[dict[str, Any] | None, str]:
    """Read and parse ``.sdd-agent-lock``.

    Returns ``(lock, status)`` where status is:
    - ``"ok"`` — valid JSON dict (any version; classification applies liveness)
    - ``"missing"`` — no lock file (no owner)
    - ``"corrupt"`` — file exists but is not a valid JSON dict (fail-closed:
      the caller cannot trust owner/liveness from it)
    """
    try:
        with open(lock_path(worktree), encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict):
            return data, "ok"
        return None, "corrupt"
    except FileNotFoundError:
        return None, "missing"
    except (OSError, json.JSONDecodeError):
        return None, "corrupt"


def _now_iso() -> str:
    """UTC ISO-8601 timestamp (seconds) for ``created_at`` / ``last_seen``."""
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def write_lock_v2(
    worktree: str,
    *,
    owner: str,
    session: str,
    change: str,
    repo_root: str,
    repo_name: str,
    branch: str,
    store: str,
) -> None:
    """Write ``.sdd-agent-lock`` (v2 schema).

    PID is the server's PID at acquire time (server death == dead PID ==
    stale == auto re-claim). ``created_at`` is preserved from a readable prior
    lock on re-claims; ``last_seen`` is refreshed on every write.
    """
    existing, st = read_lock_v2(worktree)
    prev_created = existing.get("created_at") if st == "ok" else None
    created_at = prev_created if isinstance(prev_created, str) and prev_created else _now_iso()
    lock = {
        "version": LOCK_VERSION,
        "pid": os.getpid(),
        "session": session,
        "owner": owner,
        "change": change,
        "repo_root": repo_root,
        "repo_name": repo_name,
        "branch": branch,
        "store": store,
        "created_at": created_at,
        "last_seen": _now_iso(),
    }
    with open(lock_path(worktree), "w", encoding="utf-8") as fh:
        json.dump(lock, fh, indent=2, sort_keys=True)


def remove_lock(worktree: str) -> None:
    """Best-effort lock cleanup."""
    try:
        os.remove(lock_path(worktree))
    except OSError:
        pass


def lock_owner(lock: dict[str, Any] | None) -> str | None:
    """Caller-asserted lock owner (advisory — real gates are derivation + liveness)."""
    if not lock:
        return None
    owner = lock.get("owner")
    return str(owner) if owner is not None else None


def lock_has_live_pid(lock: dict[str, Any] | None) -> bool:
    """``kill -0`` liveness probe for the lock PID. Stale/absent → ``False``.

    ESRCH → dead (stale); EPERM → alive (exists, owned by another user);
    unparsable/non-positive PID → dead (stale).
    """
    if not lock:
        return False
    try:
        pid = int(lock.get("pid"))
    except (TypeError, ValueError):
        return False
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True  # process exists but owned by another user — alive
    return True


# ---------------------------------------------------------------------------
# Dirty check — porcelain minus server-owned artifacts, fail-closed
# ---------------------------------------------------------------------------

def _is_server_owned(line: str) -> bool:
    """True for porcelain entries that are server-owned artifacts.

    Both are untracked by construction: ``?? .codegraph/`` and
    ``?? .sdd-agent-lock``. Renames carry the destination after `` -> ``.
    """
    path = line.split(" -> ")[-1].rsplit(" ", 1)[-1].rstrip("/")
    return path in SERVER_OWNED


def status_dirty(executor: ExecutorProto, target: str) -> tuple[bool, Envelope | None]:
    """Return ``(dirty, error)`` for a worktree.

    Dirty = any porcelain entry that is not a server-owned artifact; git
    failure is fail-closed (dirty + error envelope).
    """
    r = executor.run(["git", "-C", target, "status", "--porcelain"])
    if r.returncode != 0:
        return True, err("invalid_parameter", r.stderr.strip())
    remaining = [line for line in r.stdout.splitlines() if not _is_server_owned(line)]
    return bool(remaining), None


# ---------------------------------------------------------------------------
# 7-state classifier (ordered 9-row table, design Interfaces/Contracts)
# ---------------------------------------------------------------------------

def _parse_porcelain(stdout: str) -> list[dict[str, str]]:
    """Parse ``git worktree list --porcelain`` blocks into dicts."""
    entries: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for line in stdout.splitlines():
        if not line.strip():
            if current:
                entries.append(current)
                current = {}
            continue
        key, _, value = line.partition(" ")
        current[key] = value
    if current:
        entries.append(current)
    return entries


def _pretty_branch(raw: str | None) -> str:
    if not raw:
        return "(detached)"
    if raw.startswith("refs/heads/"):
        return raw[len("refs/heads/"):]
    return raw


def _classify(
    *,
    dir_exists: bool,
    in_porcelain: bool,
    lock_status: str,
    lock: dict[str, Any] | None,
    branch_exists: bool,
    owner: str | None,
    session: str | None,
) -> tuple[str, dict[str, Any]]:
    """Ordered classifier — returns ``(state, signals)``.

    Rows (first match, design table):
      corrupt (disk/porcelain disagreement or unparsable lock) → absent →
      absent_branch_exists → exists_inactive → v1/≠2+dead → v1/≠2+alive →
      v2+dead → v2+owner+session → v2+other.

    ``owner``/``session`` identify the caller; when ``None`` (enriched list,
    caller-neutral) a live v2 lock can never be "mine".
    """
    pid_alive = lock_has_live_pid(lock) if lock_status == "ok" else False
    version = 0
    lock_owner_ = None
    lock_session: str | None = None
    if lock_status == "ok" and lock is not None:
        try:
            version = int(lock.get("version", 0))
        except (TypeError, ValueError):
            version = 0
        lock_owner_ = lock_owner(lock)
        raw_session = lock.get("session")
        lock_session = str(raw_session) if raw_session is not None else None

    signals: dict[str, Any] = {
        "dir_exists": dir_exists,
        "in_porcelain": in_porcelain,
        "lock_status": lock_status,
        "lock_version": version if lock_status == "ok" else None,
        "pid_alive": pid_alive,
        "branch_exists": branch_exists,
        "owner": lock_owner_,
        "session": lock_session,
        "created_at": lock.get("created_at") if lock else None,
        "last_seen": lock.get("last_seen") if lock else None,
        "store": lock.get("store") if lock else None,
        "repo_name": lock.get("repo_name") if lock else None,
        "repo_root": lock.get("repo_root") if lock else None,
    }

    # Row 1 — corrupt: disk/porcelain disagreement (either direction), or
    # unparsable lock. A dir on disk with no porcelain entry, or a porcelain
    # entry whose tree vanished, is broken evidence → fail closed.
    if (dir_exists != in_porcelain) or lock_status == "corrupt":
        return "corrupt", signals
    # Rows 2-3 — absent (branch exists → attach existing branch, no -b)
    if not dir_exists:
        return ("absent_branch_exists" if branch_exists else "absent"), signals
    # Row 4 — exists_inactive: worktree on disk, no lock
    if lock_status == "missing":
        return "exists_inactive", signals
    # Rows 5-6 — v1/≠2 split on PID liveness
    if version != LOCK_VERSION:
        return ("exists_stale" if not pid_alive else "exists_active_other"), signals
    # Rows 7-9 — v2 split on PID liveness + owner AND session match
    if not pid_alive:
        return "exists_stale", signals
    owner_match = owner is not None and lock_owner_ == owner
    session_match = session is not None and lock_session == session
    return ("exists_active_mine" if (owner_match and session_match) else "exists_active_other"), signals


def classify_worktree(
    executor: ExecutorProto,
    repo_path: str,
    change: str,
    owner: str,
    session: str,
) -> tuple[str, dict[str, Any]]:
    """Classify the canonical worktree for *change* (acquire/release path)."""
    repo_name = derive_repo_name(executor, repo_path)
    target = worktree_path_for(repo_name, change)
    lock, lock_status = read_lock_v2(target)
    branch_exists = False
    branch = f"sdd/{change}"
    ref = executor.run(
        ["git", "-C", repo_path, "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"]
    )
    if ref.returncode == 0:
        branch_exists = True

    porcelain = executor.run(["git", "-C", repo_path, "worktree", "list", "--porcelain"])
    if porcelain.returncode != 0:
        # Fail-closed: git cannot enumerate the worktrees — treat as corrupt evidence
        # (the caller already validated the repo; an exotic git failure must not
        # be read as "absent" and silently create a second worktree).
        signals = {
            "error": porcelain.stderr.strip(),
            "path": target,
            "branch": branch,
            "branch_exists": branch_exists,
            "lock_status": lock_status,
        }
        return "corrupt", signals

    porcelain_paths = {e.get("worktree") for e in _parse_porcelain(porcelain.stdout)}
    return _classify(
        dir_exists=os.path.isdir(target),
        in_porcelain=target in porcelain_paths,
        lock_status=lock_status,
        lock=lock,
        branch_exists=branch_exists,
        owner=owner,
        session=session,
    )


# ---------------------------------------------------------------------------
# Hint index — write-through cache, never truth
# ---------------------------------------------------------------------------

def _index_path(repo_name: str) -> str:
    return str(_agent_worktrees_root() / repo_name / INDEX_FILENAME)


def _empty_index(repo_name: str) -> dict[str, Any]:
    return {"version": INDEX_VERSION, "repo_name": repo_name, "updated_at": None, "worktrees": []}


def read_index(repo_name: str) -> dict[str, Any]:
    """Read the hint index; missing/corrupt/foreign-version → empty (rebuilt)."""
    try:
        with open(_index_path(repo_name), encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict) and data.get("version") == INDEX_VERSION:
            return data
    except (OSError, json.JSONDecodeError):
        pass
    return _empty_index(repo_name)


def write_index(repo_name: str, worktrees: list[dict[str, Any]]) -> None:
    """Write-through (atomic tmp+replace). Failure is warn-only — never truth."""
    try:
        path = _index_path(repo_name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        data = _empty_index(repo_name)
        data["worktrees"] = worktrees
        data["updated_at"] = _now_iso()
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, sort_keys=True)
        os.replace(tmp, path)
    except OSError:
        pass


def append_index(repo_name: str, entry: dict[str, Any]) -> None:
    """Add/replace *entry* (keyed by ``change``) in the hint index."""
    data = read_index(repo_name)
    worktrees = [w for w in data.get("worktrees", []) if w.get("change") != entry.get("change")]
    worktrees.append(entry)
    write_index(repo_name, worktrees)


def remove_index_entry(repo_name: str, change: str) -> None:
    """Drop the *change* entry from the hint index."""
    data = read_index(repo_name)
    write_index(repo_name, [w for w in data.get("worktrees", []) if w.get("change") != change])


# ---------------------------------------------------------------------------
# Acquire / release — the lifecycle transitions
# ---------------------------------------------------------------------------

def _codegraph_init(executor: ExecutorProto, target: str) -> bool:
    """Best-effort ``codegraph init`` on a fresh worktree — never fails the op."""
    from src.executor import SubprocessError

    try:
        cg = executor.run(["codegraph", "init"], cwd=target, timeout_s=60)
        return cg.returncode == 0
    except (SubprocessError, OSError):
        return False


def acquire_worktree(
    executor: ExecutorProto,
    repo_path: str,
    change: str,
    owner: str,
    session: str,
    store: str = LOCK_STORE_DEFAULT,
) -> Envelope:
    """Classify + create/attach/claim the lifecycle worktree.

    Status is one of ``created``, ``attached``, ``claimed``, ``already_mine``
    (``reclaimed`` is reserved). Typed denials: ``owned_by_other``,
    ``locked_unreadable``, ``corrupt_worktree``. Never silently takes over.
    """
    repo_name = derive_repo_name(executor, repo_path)
    target = worktree_path_for(repo_name, change)
    branch = f"sdd/{change}"
    state, signals = classify_worktree(executor, repo_path, change, owner, session)

    if state == "exists_active_mine":
        return ok(
            {
                "status": "already_mine",
                "change": change,
                "path": target,
                "branch": branch,
                "repo_name": repo_name,
                "store": signals.get("store") or store,
            },
            f"Worktree {target} already claimed by {owner}/{session} — no mutation",
        )

    if state == "exists_active_other":
        return err(
            "owned_by_other",
            f"Worktree {target} is claimed by {signals.get('owner')!r} "
            f"(session {signals.get('session')!r}, last_seen {signals.get('last_seen')})",
            hint="only the owning session may reclaim it; wait for release or resolve explicitly",
        )

    if state == "corrupt":
        if signals.get("lock_status") == "corrupt":
            return err(
                "locked_unreadable",
                f"Worktree {target} lock file is corrupt — cannot verify owner",
                hint=f"inspect {target}/.sdd-agent-lock manually",
            )
        return err(
            "corrupt_worktree",
            f"Worktree {target} is on disk but not listed by git porcelain "
            "(or the git probe failed) — refusing to overwrite unreadable evidence",
            hint="inspect the tree manually",
        )

    # create / attach / claim
    if state == "absent":
        r = executor.run(["git", "-C", repo_path, "worktree", "add", "--no-track", "-b", branch, target])
        if r.returncode != 0:
            return err("invalid_parameter", r.stderr.strip())
        status = "created"
    elif state == "absent_branch_exists":
        r = executor.run(["git", "-C", repo_path, "worktree", "add", "--no-track", target, branch])
        if r.returncode != 0:
            return err("invalid_parameter", r.stderr.strip())
        status = "created"
    elif state == "exists_inactive":
        status = "attached"
    elif state == "exists_stale":
        status = "claimed"
    else:  # pragma: no cover — classifier closed set
        return err("corrupt_worktree", f"Unclassified state {state!r} for {target}")

    repo_root = signals.get("repo_root") or repo_toplevel(executor, repo_path)
    try:
        write_lock_v2(
            target,
            owner=owner,
            session=session,
            change=change,
            repo_root=repo_root,
            repo_name=repo_name,
            branch=branch,
            store=store,
        )
    except OSError as exc:
        return err(
            "invalid_parameter",
            f"Worktree {status} but lock write failed: {exc}",
            hint="inspect permissions; the worktree may exist without a claim",
        )

    lock, _st = read_lock_v2(target)
    append_index(
        repo_name,
        {
            "change": change,
            "path": target,
            "branch": branch,
            "owner": owner,
            "session": session,
            "last_seen": (lock or {}).get("last_seen"),
            "state": "exists_active_mine",
        },
    )

    if status == "created":
        codegraph_ok = _codegraph_init(executor, target)
        summary = f"Worktree created at {target} on branch {branch} (lock v2 + index written)"
        if not codegraph_ok:
            summary += "; codegraph init skipped (binary missing or failed)"
    elif status == "attached":
        summary = f"Worktree attached at {target} (lock v2 written for {owner}/{session})"
    else:
        summary = (
            f"Stale claim reclaimed at {target} "
            f"(lock v2 rewritten for {owner}/{session}, created_at preserved)"
        )
    return ok(
        {"status": status, "change": change, "path": target, "branch": branch, "repo_name": repo_name, "store": store},
        summary,
    )


def release_worktree(executor: ExecutorProto, repo_path: str, change: str, owner: str) -> Envelope:
    """Clear the caller's claim (lock + index entry) — never destroys, dirty OK.

    No worktree, no lock, or lock from another owner → ok no-op.
    Corrupt lock → ``locked_unreadable`` (cannot verify ownership).
    """
    repo_name = derive_repo_name(executor, repo_path)
    target = worktree_path_for(repo_name, change)
    if not os.path.isdir(target):
        return ok(
            {"status": "released", "change": change, "path": target, "repo_name": repo_name},
            f"Nothing to release at {target} (no worktree)",
        )
    lock, lock_status = read_lock_v2(target)
    if lock_status == "corrupt":
        return err(
            "locked_unreadable",
            f"Worktree {target} lock file is corrupt — cannot verify owner",
            hint=f"inspect {target}/.sdd-agent-lock manually",
        )
    if lock_status == "missing" or lock_owner(lock) != owner:
        return ok(
            {"status": "released", "change": change, "path": target, "repo_name": repo_name},
            f"No claim to release at {target} (no lock or not owned by {owner}) — no-op",
        )
    remove_lock(target)
    remove_index_entry(repo_name, change)
    return ok(
        {"status": "released", "change": change, "path": target, "repo_name": repo_name},
        f"Claim released at {target} (lock + index entry removed; worktree kept)",
    )


# ---------------------------------------------------------------------------
# Enriched list — porcelain truth + classifier + index hints
# ---------------------------------------------------------------------------

def enriched_worktree_list(executor: ExecutorProto, repo_path: str) -> Envelope:
    """Idempotent read: every worktree (main included) enriched with lifecycle state.

    Caller-neutral classification: a live lock is reported as
    ``exists_active_other`` unless the caller identity is known (it is not from
    the list alone); ``git_worktree_acquire`` is the authoritative mine/other gate.
    """
    porcelain = executor.run(["git", "-C", repo_path, "worktree", "list", "--porcelain"])
    if porcelain.returncode != 0:
        return err("invalid_parameter", porcelain.stderr.strip())
    entries = _parse_porcelain(porcelain.stdout)
    repo_name = derive_repo_name(executor, repo_path)
    toplevel = repo_toplevel(executor, repo_path)
    porcelain_paths = {e.get("worktree") for e in entries}
    index = read_index(repo_name)
    index_by_change: dict[str, Any] = {e.get("change"): e for e in index.get("worktrees", []) if e.get("change")}
    agent_root = str(_agent_worktrees_root()) + os.sep

    worktrees: list[dict[str, Any]] = []
    for e in entries:
        path = e.get("worktree") or ""
        if not path:
            continue
        is_main = bool(toplevel) and os.path.normpath(path) == os.path.normpath(toplevel)
        change = os.path.basename(os.path.normpath(path)) if path.startswith(agent_root) else None
        lock, lock_status = read_lock_v2(path)
        state, sig = _classify(
            dir_exists=True,
            in_porcelain=path in porcelain_paths,
            lock_status=lock_status,
            lock=lock,
            branch_exists=True,
            owner=None,
            session=None,
        )
        dirty, _derr = status_dirty(executor, path)
        idx = index_by_change.get(change) if change else None
        entry: dict[str, Any] = {
            "change": change,
            "path": path,
            "branch": _pretty_branch(e.get("branch")),
            "state": state,
            "owner": sig.get("owner"),
            "session": sig.get("session"),
            "last_seen": sig.get("last_seen"),
            "dirty": dirty,
            "is_main": is_main,
        }
        # Index fills only what the lock cannot say (hint, never truth)
        if entry["owner"] is None and idx:
            entry["owner"] = idx.get("owner")
        if entry["session"] is None and idx:
            entry["session"] = idx.get("session")
        if entry["last_seen"] is None and idx:
            entry["last_seen"] = idx.get("last_seen")
        worktrees.append(entry)

    return ok(
        {"repo_name": repo_name, "worktrees": worktrees},
        f"{len(worktrees)} worktree(s)",
    )