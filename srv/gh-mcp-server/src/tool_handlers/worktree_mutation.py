"""Worktree mutation handlers — 2 ``git_worktree_*`` tools (F6).

- ``git_worktree_add``: two-phase via ``destructive_flow``. The canonical
  target is derived, never taken raw: ``~/.agent_worktrees/<basename(repo_path)>/<change>``
  resolved with ``Path.home()``; ``change`` must match the safe-slug rule
  ``^[A-Za-z0-9][A-Za-z0-9._-]*$`` (rejects ``/``, ``\\``, ``..``, empty).
  ``.sdd-agent-lock`` is written IMMEDIATELY after worktree creation (before
  deps/``.codegraph``); ``codegraph init`` is best-effort.
- ``git_worktree_remove``: two-phase via ``destructive_flow`` with three typed
  pre-checks OUTSIDE the flow (same pattern as ``_validate_worktree`` in
  ``local_mutation.py``): dirty worktree → ``dirty_worktree``; live lock PID
  (``kill -0``) → ``active_agents``; lock owner != caller owner →
  ``owned_by_other``. The server NEVER accepts a raw worktree path — only
  ``(repo_path, change, owner)`` (C3 cross-repo/cross-worktree boundary).
- Server-owned artifacts (``.codegraph/``, ``.sdd-agent-lock``) are untracked
  by construction, so the dirty check ignores only those two porcelain entries;
  everything else (user untracked/modified) stays dirty. ``execute`` pre-removes
  the server-owned artifacts before ``git worktree remove`` so git's own clean
  check is the fail-closed backstop against drift.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import time
from pathlib import Path
from typing import TYPE_CHECKING, Any

from src.dryrun import DryRunResult, ECHO_PROTOCOL, destructive_flow
from src.envelope import Envelope, err, ok

if TYPE_CHECKING:
    from fastmcp import FastMCP

    from src.executor import ExecutorProto


# ---------------------------------------------------------------------------
# Pure helpers — safe-slug + canonical derivation (never a raw path from caller)
# ---------------------------------------------------------------------------

_SAFE_SLUG = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
_LOCK_FILENAME = ".sdd-agent-lock"
_SERVER_OWNED = {".codegraph", ".sdd-agent-lock"}
_CODEGRAPH_DIRNAME = ".codegraph"


def _is_server_owned(line: str) -> bool:
    """True for porcelain entries that are server-owned artifacts.

    Both are untracked by construction: ``?? .codegraph/`` and
    ``?? .sdd-agent-lock``. Renames carry the destination after `` -> ``.
    """
    path = line.split(" -> ")[-1].rsplit(" ", 1)[-1].rstrip("/")
    return path in _SERVER_OWNED


def _status_dirty(executor: ExecutorProto, target: str) -> tuple[bool, Envelope | None]:
    """Return (dirty, error). Dirty = any porcelain entry that is not a
    server-owned artifact. ``error`` is set when git status itself fails."""
    r = executor.run(["git", "-C", target, "status", "--porcelain"])
    if r.returncode != 0:
        return True, err("invalid_parameter", r.stderr.strip())
    remaining = [line for line in r.stdout.splitlines() if not _is_server_owned(line)]
    return bool(remaining), None


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


def canonical_worktree_path(repo_path: str, change: str) -> str:
    """Derive the canonical worktree path — caller input is never used raw.

    ``~/.agent_worktrees/<basename(repo_path)>/<change>`` resolved via
    ``Path.home()``; the repo basename is ``normpath``'d so trailing
    separators and traversal tricks collapse into the namespace root.
    """
    base = os.path.basename(os.path.normpath(repo_path))
    return str(Path.home() / ".agent_worktrees" / base / change)


def _validate_worktree(executor: ExecutorProto, path: str) -> Envelope | None:
    """Return an error envelope if *path* is not a git worktree."""
    r = executor.run(["git", "-C", path, "rev-parse", "--is-inside-work-tree"])
    if r.returncode != 0 or "true" not in r.stdout.strip().lower():
        return err("not_a_repo", f"Path {path} is not a git worktree", hint="point path at a repo")
    return None


# ---------------------------------------------------------------------------
# .sdd-agent-lock helpers
# ---------------------------------------------------------------------------

def lock_path(worktree: str) -> str:
    """Path of the agent lock inside a worktree root."""
    return os.path.join(worktree, _LOCK_FILENAME)


def read_lock(worktree: str) -> dict[str, Any] | None:
    """Read and parse ``.sdd-agent-lock``. ``None`` if absent or corrupt."""
    try:
        with open(lock_path(worktree), encoding="utf-8") as fh:
            data = json.load(fh)
        return data if isinstance(data, dict) else None
    except (OSError, json.JSONDecodeError):
        return None


def lock_owner(lock: dict[str, Any] | None) -> str | None:
    """Caller-asserted lock owner (advisory — real gates are derivation + liveness)."""
    if not lock:
        return None
    owner = lock.get("owner")
    return str(owner) if owner is not None else None


def lock_has_live_pid(lock: dict[str, Any] | None) -> bool:
    """``kill -0`` liveness probe for the lock PID. Stale/absent → ``False``."""
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


def write_lock(worktree: str, *, owner: str, session: str) -> None:
    """Write ``.sdd-agent-lock`` — called immediately after worktree creation."""
    lock = {
        "pid": os.getpid(),
        "session": session,
        "owner": owner,
        "timestamp": time.time(),
    }
    with open(lock_path(worktree), "w", encoding="utf-8") as fh:
        json.dump(lock, fh)


def remove_lock(worktree: str) -> None:
    """Best-effort lock cleanup after confirmed removal."""
    try:
        os.remove(lock_path(worktree))
    except OSError:
        pass


def register(server: FastMCP, executor: ExecutorProto) -> None:
    """Wire all 2 worktree mutation tools into *server*."""

    # ------------------------------------------------------------------
    # 1. git_worktree_add
    # ------------------------------------------------------------------
    @server.tool(
        description="Create a git worktree at "
        "~/.agent_worktrees/<repo-name>/<change> (two-phase: dry-run → confirm). "
        + ECHO_PROTOCOL
        + " change must match ^[A-Za-z0-9][A-Za-z0-9._-]*$ (rejects / \\ .. empty).",
    )
    async def git_worktree_add(
        repo_path: str,
        change: str,
        owner: str = "default",
        session: str = "default",
        dry_run: bool = True,
        confirmed: bool = False,
        confirmed_data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Create a git worktree (two-phase: dry-run → confirm)."""
        validation = _validate_worktree(executor, repo_path)
        if validation:
            return dict(validation)

        slug_err = validate_safe_slug(change)
        if slug_err:
            return dict(err(
                "invalid_parameter",
                f"Invalid change: {slug_err}",
                hint="change must match ^[A-Za-z0-9][A-Za-z0-9._-]*$",
            ))

        target = canonical_worktree_path(repo_path, change)
        if os.path.isdir(target):
            return dict(err(
                "worktree_exists",
                f"Worktree already exists at {target}",
                hint="pick a different change name (stale worktrees require git_worktree_remove)",
            ))

        def compute_dry_run() -> DryRunResult:
            branch = f"sdd/{change}"
            data: dict[str, Any] = {
                "path": target,
                "branch": branch,
                "change": change,
                "safe": not os.path.isdir(target),
            }
            return DryRunResult(
                data=data,
                summary=f"Plan: create worktree {target} on branch {branch}",
            )

        def execute() -> Envelope:
            # Default branch = the repo's current HEAD (start-point omitted → HEAD).
            branch = f"sdd/{change}"
            r = executor.run(
                ["git", "-C", repo_path, "worktree", "add", "--no-track",
                 "-b", branch, target]
            )
            if r.returncode != 0:
                return err("invalid_parameter", r.stderr.strip())

            # Lock IMMEDIATELY after creation, BEFORE deps/codegraph init.
            try:
                write_lock(target, owner=owner, session=session)
            except OSError as exc:
                return err(
                    "invalid_parameter",
                    f"Worktree created but lock write failed: {exc}",
                    hint="worktree exists; remove it before retrying",
                )

            # Best-effort .codegraph init — never fails the op.
            codegraph_ok = True
            from src.executor import SubprocessError
            try:
                cg = executor.run(["codegraph", "init"], cwd=target, timeout_s=60)
                codegraph_ok = cg.returncode == 0
            except (SubprocessError, OSError):
                codegraph_ok = False

            summary = f"Worktree created at {target} on branch {branch} (lock written)"
            if not codegraph_ok:
                summary += "; codegraph init skipped (binary missing or failed)"
            return ok(None, summary)

        result = destructive_flow(
            remote=False,
            executor=executor,
            compute_dry_run=compute_dry_run,
            execute=execute,
            dry_run=dry_run,
            confirmed=confirmed,
            confirmed_data=confirmed_data,
        )
        return dict(result)

    # ------------------------------------------------------------------
    # 2. git_worktree_remove
    # ------------------------------------------------------------------
    @server.tool(
        description="Remove a git worktree at "
        "~/.agent_worktrees/<repo-name>/<change> (two-phase: dry-run → confirm). "
        + ECHO_PROTOCOL
        + " Denies (typed, outside the two-phase flow): dirty worktree → "
        "dirty_worktree; live lock PID → active_agents; lock owner != owner arg → "
        "owned_by_other. Never accepts a raw worktree path — (repo_path, change, owner) only.",
    )
    async def git_worktree_remove(
        repo_path: str,
        change: str,
        owner: str,
        dry_run: bool = True,
        confirmed: bool = False,
        confirmed_data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Remove a git worktree (two-phase: dry-run → confirm)."""
        validation = _validate_worktree(executor, repo_path)
        if validation:
            return dict(validation)

        slug_err = validate_safe_slug(change)
        if slug_err:
            return dict(err(
                "invalid_parameter",
                f"Invalid change: {slug_err}",
                hint="change must match ^[A-Za-z0-9][A-Za-z0-9._-]*$ — raw paths are never accepted",
            ))

        target = canonical_worktree_path(repo_path, change)
        if not os.path.isdir(target):
            return dict(err(
                "not_found",
                f"No worktree at derived path {target}",
                hint="check the change name / repo path",
            ))

        # Pre-check 1 — dirty worktree (server-owned artifacts excluded)
        dirty, status_err = _status_dirty(executor, target)
        if status_err:
            return dict(status_err)
        if dirty:
            return dict(err(
                "dirty_worktree",
                f"Worktree {target} has uncommitted changes — refusing to remove",
                hint="commit or stash first",
            ))

        # Pre-check 2 — live agent (kill -0 on the lock PID)
        lock = read_lock(target)
        if lock_has_live_pid(lock):
            return dict(err(
                "active_agents",
                f"Worktree {target} has a live agent (lock pid {lock.get('pid')})",
                hint="wait for the agent session to finish",
            ))

        # Pre-check 3 — lock owner must match the caller (caller-asserted, advisory)
        if lock_owner(lock) != owner:
            return dict(err(
                "owned_by_other",
                f"Worktree {target} lock owner {lock_owner(lock) or '(none)'} != {owner}",
                hint="only the owning session may remove it (or an explicit two-phase recovery)",
            ))

        def compute_dry_run() -> DryRunResult:
            # Recompute the same facts inside the flow so the confirm-time
            # recomputation stays fail-closed if state drifted since the pre-checks.
            dirty, status_err = _status_dirty(executor, target)
            if status_err:
                dirty = True  # fail-closed: cannot verify cleanliness
            lock_now = read_lock(target)
            live = lock_has_live_pid(lock_now)
            owner_match = lock_owner(lock_now) == owner
            data: dict[str, Any] = {
                "path": target,
                "change": change,
                "dirty": dirty,
                "live_agents": live,
                "lock_owner": lock_owner(lock_now),
                "safe": (not dirty) and (not live) and owner_match,
            }
            if not data["safe"]:
                return DryRunResult(
                    data=data,
                    summary=f"Refusing to remove {target}: state is not clean",
                )
            return DryRunResult(
                data=data,
                summary=f"Plan: remove worktree {target}",
            )

        def execute() -> Envelope:
            # Drop server-owned artifacts first so git's own clean check passes;
            # any user-untracked/modified files then still block removal (drift
            # between dry-run and confirm fails closed below).
            shutil.rmtree(os.path.join(target, _CODEGRAPH_DIRNAME), ignore_errors=True)
            remove_lock(target)
            r = executor.run(["git", "-C", repo_path, "worktree", "remove", target])
            if r.returncode != 0:
                return err("invalid_parameter", r.stderr.strip())
            return ok(None, f"Worktree {target} removed")

        result = destructive_flow(
            remote=False,
            executor=executor,
            compute_dry_run=compute_dry_run,
            execute=execute,
            dry_run=dry_run,
            confirmed=confirmed,
            confirmed_data=confirmed_data,
        )
        return dict(result)