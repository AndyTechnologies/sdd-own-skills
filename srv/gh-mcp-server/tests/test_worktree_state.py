"""RED tests for the shared worktree lifecycle layer (worktree_state.py).

Covers the 9 classifier rows, acquire/release transitions, hint index,
dirty check, repo-name derivation, and the concurrent-instances threat row.
FakeExecutor mocks git; the agent-worktrees root is monkeypatched to tmp.
"""

from __future__ import annotations

import json
import os
import subprocess
from typing import Any

import pytest

import src.worktree_state as ws
from src.executor import ProcResult


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

DEAD_PID = 999_999_999  # beyond any real PID on Linux → kill(0) → ESRCH → dead


class FakeExecutor:
    """Recorded argv → ProcResult mapping (default: fail).

    ``effects`` maps a command key to a callable run AFTER the result is
    looked up — used to emulate side effects of real commands (e.g. `git
    worktree add` creating the target directory).
    """

    def __init__(
        self,
        mapping: dict[tuple[str, ...], ProcResult] | None = None,
        effects: dict[tuple[str, ...], Any] | None = None,
    ) -> None:
        self.mapping = mapping or {}
        self.effects = effects or {}
        self.calls: list[tuple[tuple[str, ...], str | None]] = []

    def run(self, argv, *, cwd=None, text=True, timeout_s=30.0) -> ProcResult:  # noqa: ARG002
        key = tuple(argv)
        self.calls.append((key, cwd))
        if key not in self.mapping:
            return ProcResult(1, "", f"unmocked: {' '.join(argv)}")
        if key in self.effects:
            self.effects[key]()
        return self.mapping[key]


def v2_lock(**over: Any) -> dict[str, Any]:
    base = {
        "version": 2,
        "pid": os.getpid(),
        "session": "s1",
        "owner": "alice",
        "change": "c1",
        "repo_root": "/repo",
        "repo_name": "repo",
        "branch": "sdd/c1",
        "store": "hybrid",
        "created_at": "2026-01-01T00:00:00+00:00",
        "last_seen": "2026-01-01T00:00:00+00:00",
    }
    base.update(over)
    return base


def v1_lock(**over: Any) -> dict[str, Any]:
    base = {"pid": DEAD_PID, "session": "s1", "owner": "alice", "timestamp": 1788984739.8}
    base.update(over)
    return base


def porcelain_of(paths: list[str], *, branches: dict[str, str] | None = None) -> str:
    lines: list[str] = []
    branches = branches or {}
    for p in paths:
        lines.append(f"worktree {p}")
        lines.append("HEAD deadbeef")
        b = branches.get(p)
        lines.append(f"branch refs/heads/{b}" if b else "detached")
        lines.append("")
    return "\n".join(lines)


REPO = "/repo"


@pytest.fixture
def env(tmp_path, monkeypatch):
    """tmp agent-worktrees root + repo namespace fixture."""
    root = tmp_path / "agent_worktrees"
    root.mkdir()
    monkeypatch.setattr(ws, "_agent_worktrees_root", lambda: root)
    return {"root": root, "repo": "repo", "change": "c1", "target": root / "repo" / "c1"}


def make_worktree(env, *, lock: dict[str, Any] | str | None = None) -> None:
    """Create the target dir; ``lock`` may be a dict (JSON), a raw str, or None."""
    env["target"].mkdir(parents=True, exist_ok=True)
    if lock is not None:
        content = json.dumps(lock) if isinstance(lock, dict) else lock
        (env["target"] / ws.LOCK_FILENAME).write_text(content)


def base_executor(env, *, target_in_porcelain: bool | None = None, branch_exists: bool = False) -> FakeExecutor:
    # Default porcelain membership follows real disk state — a brand-new
    # worktree (absent) is NOT yet registered by git; an existing dir is.
    if target_in_porcelain is None:
        target_in_porcelain = env["target"].is_dir()
    paths = [str(env["root"] / env["repo"] / "main")] if not target_in_porcelain else [
        str(env["root"] / env["repo"] / "main"),
        str(env["target"]),
    ]
    ref_rc = 0 if branch_exists else 1
    mapping: dict[tuple[str, ...], ProcResult] = {
        ("git", "-C", REPO, "rev-parse", "--show-toplevel"): ProcResult(0, REPO, ""),
        ("git", "-C", REPO, "worktree", "list", "--porcelain"): ProcResult(
            0, porcelain_of(paths, branches={str(env["root"] / env["repo"] / "main"): "main"}), ""
        ),
        ("git", "-C", REPO, "show-ref", "--verify", "--quiet", "refs/heads/sdd/c1"): ProcResult(ref_rc, "", ""),
        # create path (absent) — mocked success + emulated side effect
        ("git", "-C", REPO, "worktree", "add", "--no-track", "-b", "sdd/c1", str(env["target"])): ProcResult(0, "", ""),
        # attach path (absent_branch_exists) — mocked success
        ("git", "-C", REPO, "worktree", "add", "--no-track", str(env["target"]), "sdd/c1"): ProcResult(0, "", ""),
    }
    return FakeExecutor(mapping, effects={
        ("git", "-C", REPO, "worktree", "add", "--no-track", "-b", "sdd/c1", str(env["target"])): lambda: env["target"].mkdir(parents=True),
        ("git", "-C", REPO, "worktree", "add", "--no-track", str(env["target"]), "sdd/c1"): lambda: env["target"].mkdir(parents=True),
    })


# ---------------------------------------------------------------------------
# 2.2 — 9 classifier rows
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("name", "with_dir", "lock", "porcelain_includes", "branch_exists", "owner", "session", "expected"),
    [
        ("absent", False, None, False, False, "alice", "s1", "absent"),
        ("absent_branch_exists", False, None, False, True, "alice", "s1", "absent_branch_exists"),
        ("exists_inactive", True, None, True, False, "alice", "s1", "exists_inactive"),
        ("exists_stale_v1_dead", True, v1_lock(), True, False, "alice", "s1", "exists_stale"),
        ("exists_active_other_v1_alive", True, v1_lock(pid=os.getpid()), True, False, "alice", "s1", "exists_active_other"),
        ("exists_stale_v2_dead", True, v2_lock(pid=DEAD_PID), True, False, "alice", "s1", "exists_stale"),
        ("exists_active_mine", True, v2_lock(pid=os.getpid()), True, False, "alice", "s1", "exists_active_mine"),
        ("exists_active_other_v2_diff_session", True, v2_lock(pid=os.getpid()), True, False, "alice", "s9", "exists_active_other"),
        ("corrupt_dir_not_in_porcelain", True, None, False, False, "alice", "s1", "corrupt"),
        ("corrupt_ghost_in_porcelain", False, None, True, False, "alice", "s1", "corrupt"),
        ("corrupt_unparsable_lock", True, "{not-json", True, False, "alice", "s1", "corrupt"),
    ],
)
def test_classifier_rows(env, name, with_dir, lock, porcelain_includes, branch_exists, owner, session, expected):
    if with_dir:
        make_worktree(env, lock=lock)
    ex = base_executor(env, target_in_porcelain=porcelain_includes, branch_exists=branch_exists)
    state, signals = ws.classify_worktree(ex, REPO, env["change"], owner, session)
    assert state == expected, signals
    if expected == "exists_active_mine":
        assert signals["pid_alive"] is True
    if expected == "exists_stale":
        assert signals["pid_alive"] is False


def test_classifier_corrupt_lock_signals(env):
    make_worktree(env, lock="{not-json")
    ex = base_executor(env)
    state, signals = ws.classify_worktree(ex, REPO, env["change"], "alice", "s1")
    assert state == "corrupt"
    assert signals["lock_status"] == "corrupt"


def test_classifier_porcelain_failure_is_corrupt(env):
    ex = FakeExecutor({
        ("git", "-C", REPO, "rev-parse", "--show-toplevel"): ProcResult(0, REPO, ""),
        ("git", "-C", REPO, "worktree", "list", "--porcelain"): ProcResult(128, "", "fatal: git broken"),
        ("git", "-C", REPO, "show-ref", "--verify", "--quiet", "refs/heads/sdd/c1"): ProcResult(1, "", ""),
    })
    state, signals = ws.classify_worktree(ex, REPO, env["change"], "alice", "s1")
    assert state == "corrupt"
    assert "error" in signals


# ---------------------------------------------------------------------------
# 2.3 — acquire transitions
# ---------------------------------------------------------------------------

def _acquire_ex(env, *, target_in_porcelain: bool | None = None, branch_exists=False) -> FakeExecutor:
    ex = base_executor(env, target_in_porcelain=target_in_porcelain, branch_exists=branch_exists)
    ex.mapping[("codegraph", "init")] = ProcResult(0, "", "")
    return ex


def test_acquire_created(env):
    ex = _acquire_ex(env)
    result = ws.acquire_worktree(ex, REPO, env["change"], "alice", "s1")
    assert result["ok"] is True
    assert result["data"]["status"] == "created"
    assert env["target"].is_dir()
    lock, st = ws.read_lock_v2(str(env["target"]))
    assert st == "ok"
    assert lock["version"] == 2 and lock["pid"] == os.getpid()
    assert lock["owner"] == "alice" and lock["session"] == "s1"
    assert lock["store"] == "hybrid" and lock["repo_name"] == "repo"
    # index write-through
    index = ws.read_index(env["repo"])
    assert [e["change"] for e in index["worktrees"]] == [env["change"]]
    # codegraph init best-effort ran
    assert ("codegraph", "init") in [c[0] for c in ex.calls]


def test_acquire_attached(env):
    make_worktree(env)  # exists_inactive: tree, no lock
    ex = _acquire_ex(env)
    result = ws.acquire_worktree(ex, REPO, env["change"], "alice", "s1")
    assert result["data"]["status"] == "attached"
    lock, st = ws.read_lock_v2(str(env["target"]))
    assert st == "ok" and lock["version"] == 2
    assert ("codegraph", "init") not in [c[0] for c in ex.calls]  # only on created


def test_acquire_claimed_preserves_created_at(env):
    make_worktree(env, lock=v2_lock(pid=DEAD_PID, created_at="2020-05-05T05:05:05+00:00"))
    ex = _acquire_ex(env)
    result = ws.acquire_worktree(ex, REPO, env["change"], "bob", "s2")
    assert result["data"]["status"] == "claimed"
    lock, st = ws.read_lock_v2(str(env["target"]))
    assert st == "ok"
    assert lock["owner"] == "bob" and lock["session"] == "s2"
    assert lock["created_at"] == "2020-05-05T05:05:05+00:00"  # preserved


def test_acquire_v1_claimed(env):
    make_worktree(env, lock=v1_lock())  # legacy v1, dead PID
    ex = _acquire_ex(env)
    result = ws.acquire_worktree(ex, REPO, env["change"], "bob", "s2")
    assert result["data"]["status"] == "claimed"
    lock, st = ws.read_lock_v2(str(env["target"]))
    assert st == "ok" and lock["version"] == 2


def test_acquire_already_mine_no_mutation(env):
    make_worktree(env, lock=v2_lock(pid=os.getpid()))
    ex = _acquire_ex(env)
    before = (env["target"] / ws.LOCK_FILENAME).read_text()
    result = ws.acquire_worktree(ex, REPO, env["change"], "alice", "s1")
    assert result["data"]["status"] == "already_mine"
    after = (env["target"] / ws.LOCK_FILENAME).read_text()
    assert before == after  # no mutation
    assert ("codegraph", "init") not in [c[0] for c in ex.calls]
    assert ws.read_index(env["repo"])["worktrees"] == []  # index untouched


def test_acquire_deny_owned_by_other(env):
    make_worktree(env, lock=v2_lock(pid=os.getpid(), owner="mallory"))
    ex = _acquire_ex(env)
    result = ws.acquire_worktree(ex, REPO, env["change"], "alice", "s1")
    assert result["ok"] is False
    assert result["error"]["type"] == "owned_by_other"
    lock, _ = ws.read_lock_v2(str(env["target"]))
    assert lock["owner"] == "mallory"  # untouched


def test_acquire_deny_locked_unreadable(env):
    make_worktree(env, lock="{not-json")
    ex = _acquire_ex(env)
    result = ws.acquire_worktree(ex, REPO, env["change"], "alice", "s1")
    assert result["ok"] is False
    assert result["error"]["type"] == "locked_unreadable"


def test_acquire_deny_corrupt_worktree(env):
    make_worktree(env)  # on disk, NOT in porcelain
    ex = _acquire_ex(env, target_in_porcelain=False)
    result = ws.acquire_worktree(ex, REPO, env["change"], "alice", "s1")
    assert result["ok"] is False
    assert result["error"]["type"] == "corrupt_worktree"


def test_acquire_absent_branch_exists_attaches(env):
    ex = _acquire_ex(env, branch_exists=True)
    result = ws.acquire_worktree(ex, REPO, env["change"], "alice", "s1")
    assert result["data"]["status"] == "created"
    # no -b in the add call (branch reuse)
    add_calls = [c for c in ex.calls if c[0][:4] == ("git", "-C", REPO, "worktree")]
    assert add_calls and "-b" not in add_calls[0][0]


# ---------------------------------------------------------------------------
# 2.4 — release
# ---------------------------------------------------------------------------

def test_release_happy_path(env):
    make_worktree(env, lock=v2_lock(pid=os.getpid()))
    ws.append_index(env["repo"], {"change": env["change"], "path": str(env["target"]), "branch": "sdd/c1"})
    ex = _acquire_ex(env)
    result = ws.release_worktree(ex, REPO, env["change"], "alice")
    assert result["ok"] is True
    assert not (env["target"] / ws.LOCK_FILENAME).exists()  # lock cleared
    assert env["target"].is_dir()  # worktree NOT removed
    assert ws.read_index(env["repo"])["worktrees"] == []  # index entry removed


def test_release_non_owner_noop(env):
    make_worktree(env, lock=v2_lock(pid=os.getpid(), owner="alice"))
    ex = _acquire_ex(env)
    result = ws.release_worktree(ex, REPO, env["change"], "bob")
    assert result["ok"] is True
    assert (env["target"] / ws.LOCK_FILENAME).exists()  # untouched


def test_release_no_lock_noop(env):
    make_worktree(env)
    ex = _acquire_ex(env)
    result = ws.release_worktree(ex, REPO, env["change"], "alice")
    assert result["ok"] is True


def test_release_missing_worktree_noop(env):
    ex = _acquire_ex(env)
    result = ws.release_worktree(ex, REPO, env["change"], "alice")
    assert result["ok"] is True
    assert result["data"]["path"] == str(env["target"])


def test_release_corrupt_lock_denied(env):
    make_worktree(env, lock="{not-json")
    ex = _acquire_ex(env)
    result = ws.release_worktree(ex, REPO, env["change"], "alice")
    assert result["ok"] is False
    assert result["error"]["type"] == "locked_unreadable"


def test_release_dirty_ok(env):
    """Release never checks cleanliness — dirty worktrees release fine."""
    make_worktree(env, lock=v2_lock(pid=os.getpid()))
    (env["target"] / "user-file.txt").write_text("user work")
    ex = _acquire_ex(env)
    result = ws.release_worktree(ex, REPO, env["change"], "alice")
    assert result["ok"] is True
    assert (env["target"] / "user-file.txt").exists()
    assert not any("status" in c[0] for c in ex.calls)  # release runs no git status


# ---------------------------------------------------------------------------
# 2.5 — index
# ---------------------------------------------------------------------------

def test_index_write_through_on_acquire_and_release(env):
    ex = _acquire_ex(env)
    ws.acquire_worktree(ex, REPO, env["change"], "alice", "s1")
    index = ws.read_index(env["repo"])
    assert index["version"] == 1
    assert index["worktrees"][0]["change"] == env["change"]
    ws.release_worktree(ex, REPO, env["change"], "alice")
    assert ws.read_index(env["repo"])["worktrees"] == []


def test_index_corrupt_rebuilds_empty(env):
    index_path = env["root"] / env["repo"] / ws.INDEX_FILENAME
    index_path.parent.mkdir(parents=True)
    index_path.write_text("{garbage")
    data = ws.read_index(env["repo"])
    assert data["version"] == 1 and data["worktrees"] == []
    # append after corruption works (rebuild)
    ws.append_index(env["repo"], {"change": "x", "path": "/p"})
    assert ws.read_index(env["repo"])["worktrees"][0]["change"] == "x"


def test_index_missing_returns_empty(env):
    assert ws.read_index(env["repo"])["worktrees"] == []


def test_index_write_failure_warn_only(env, monkeypatch):
    blocker = env["root"] / "blocker"
    blocker.write_text("file")
    monkeypatch.setattr(ws, "_agent_worktrees_root", lambda: blocker)  # root is a FILE
    ws.append_index(env["repo"], {"change": "x"})  # must not raise


def test_index_entry_replaced_not_duplicated(env):
    entry = {"change": "c1", "path": "/p", "branch": "sdd/c1"}
    ws.append_index(env["repo"], entry)
    ws.append_index(env["repo"], {**entry, "path": "/p2"})
    worktrees = ws.read_index(env["repo"])["worktrees"]
    assert len(worktrees) == 1 and worktrees[0]["path"] == "/p2"


# ---------------------------------------------------------------------------
# 2.6 — dirty check
# ---------------------------------------------------------------------------

def _status_ex(env, stdout="", rc=0) -> FakeExecutor:
    return FakeExecutor({
        ("git", "-C", str(env["target"]), "status", "--porcelain"): ProcResult(rc, stdout, ""),
    })


def test_dirty_staged_only(env):
    ex = _status_ex(env, "A  file.txt\n")
    dirty, err_ = ws.status_dirty(ex, str(env["target"]))
    assert dirty is True and err_ is None


def test_dirty_server_owned_only_clean(env):
    ex = _status_ex(env, "?? .codegraph/\n?? .sdd-agent-lock\n")
    dirty, err_ = ws.status_dirty(ex, str(env["target"]))
    assert dirty is False and err_ is None


def test_dirty_mixed(env):
    ex = _status_ex(env, "?? .codegraph/\n M src/x.py\n")
    dirty, err_ = ws.status_dirty(ex, str(env["target"]))
    assert dirty is True and err_ is None


def test_dirty_git_failure_fail_closed(env):
    ex = _status_ex(env, rc=128)
    dirty, err_ = ws.status_dirty(ex, str(env["target"]))
    assert dirty is True and err_ is not None and err_["ok"] is False


# ---------------------------------------------------------------------------
# 2.7 — repo-name derivation (real git repos)
# ---------------------------------------------------------------------------

@pytest.fixture
def real_repo(tmp_path):
    repo = tmp_path / "proj"
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    subprocess.run(
        ["git", "-C", str(repo), "-c", "user.email=t@t", "-c", "user.name=t",
         "commit", "--allow-empty", "-q", "-m", "init"],
        check=True,
    )
    (repo / "sub").mkdir()
    return repo


def test_derive_repo_name_toplevel(real_repo):
    import src.executor as executor_mod
    ex = executor_mod.SubprocessRunner()
    assert ws.derive_repo_name(ex, str(real_repo)) == "proj"
    assert ws.derive_repo_name(ex, str(real_repo / "sub" / ".")) == "proj"
    assert ws.derive_repo_name(ex, str(real_repo) + "/./") == "proj"


def test_derive_repo_name_non_repo_fallback(tmp_path):
    import src.executor as executor_mod
    ex = executor_mod.SubprocessRunner()
    notgit = tmp_path / "notgit"
    notgit.mkdir()
    assert ws.derive_repo_name(ex, str(notgit)) == "notgit"


def test_canonical_path_uses_derived_name(env, real_repo, monkeypatch):
    root = env["root"]
    monkeypatch.setattr(ws, "_agent_worktrees_root", lambda: root)
    import src.executor as executor_mod
    ex = executor_mod.SubprocessRunner()
    assert ws.canonical_worktree_path(ex, str(real_repo), "c1") == str(root / "proj" / "c1")


# ---------------------------------------------------------------------------
# 2.8 — concurrent instances (threat-matrix row 4)
# ---------------------------------------------------------------------------

def test_concurrent_same_owner_diff_session_denies(env):
    make_worktree(env, lock=v2_lock(pid=os.getpid(), owner="alice", session="s1"))
    ex = _acquire_ex(env)
    result = ws.acquire_worktree(ex, REPO, env["change"], "alice", "s2")
    assert result["ok"] is False
    assert result["error"]["type"] == "owned_by_other"


def test_concurrent_different_owner_denies(env):
    make_worktree(env, lock=v2_lock(pid=os.getpid(), owner="alice"))
    ex = _acquire_ex(env)
    result = ws.acquire_worktree(ex, REPO, env["change"], "bob", "s1")
    assert result["ok"] is False
    assert result["error"]["type"] == "owned_by_other"


# ---------------------------------------------------------------------------
# Enriched list (spec: worktree-lifecycle + gh-git-mcp-server)
# ---------------------------------------------------------------------------

def test_enriched_list(env, tmp_path):
    main = tmp_path / "repo-checkout"  # the real checkout — OUTSIDE the agent root
    main.mkdir()
    other = env["root"] / env["repo"] / "c2"
    env["target"].mkdir(parents=True)  # c1: stale v2 lock
    other.mkdir(parents=True)
    (env["target"] / ws.LOCK_FILENAME).write_text(json.dumps(v2_lock(pid=DEAD_PID)))
    paths = [str(main), str(env["target"]), str(other)]
    ex = FakeExecutor({
        ("git", "-C", REPO, "rev-parse", "--show-toplevel"): ProcResult(0, str(main), ""),
        ("git", "-C", REPO, "worktree", "list", "--porcelain"): ProcResult(
            0,
            porcelain_of(paths, branches={str(main): "main", str(env["target"]): "sdd/c1", str(other): "sdd/c2"}),
            "",
        ),
        ("git", "-C", str(env["target"]), "status", "--porcelain"): ProcResult(0, "?? .sdd-agent-lock\n", ""),
        ("git", "-C", str(main), "status", "--porcelain"): ProcResult(0, "", ""),
        ("git", "-C", str(other), "status", "--porcelain"): ProcResult(0, "?? .sdd-agent-lock\n", ""),
    })
    result = ws.enriched_worktree_list(ex, REPO)
    assert result["ok"] is True
    entries = {e["change"]: e for e in result["data"]["worktrees"]}
    assert len(entries) == 3
    # main included + is_main
    main_entry = entries[None]
    assert main_entry["is_main"] is True
    assert main_entry["state"] == "exists_inactive"  # no lock on main
    assert main_entry["dirty"] is False
    # stale entry carries lock facts
    c1 = entries["c1"]
    assert c1["state"] == "exists_stale"
    assert c1["owner"] == "alice" and c1["last_seen"] == "2026-01-01T00:00:00+00:00"
    assert c1["branch"] == "sdd/c1" and c1["dirty"] is False
    # inert worktree
    c2 = entries["c2"]
    assert c2["state"] == "exists_inactive" and c2["is_main"] is False


def test_enriched_list_ignores_orphan_index_entries(env, tmp_path):
    main = tmp_path / "repo-checkout"
    main.mkdir()
    ex = FakeExecutor({
        ("git", "-C", REPO, "rev-parse", "--show-toplevel"): ProcResult(0, str(main), ""),
        ("git", "-C", REPO, "worktree", "list", "--porcelain"): ProcResult(
            0, porcelain_of([str(main)], branches={str(main): "main"}), ""
        ),
        ("git", "-C", str(main), "status", "--porcelain"): ProcResult(0, "", ""),
    })
    ws.append_index(env["repo"], {"change": "ghost", "path": str(env["root"] / env["repo"] / "ghost"), "owner": "zed"})
    result = ws.enriched_worktree_list(ex, REPO)
    assert result["ok"] is True
    # porcelain is truth — the orphan index entry is NOT listed
    assert [w["change"] for w in result["data"]["worktrees"]] == [None]