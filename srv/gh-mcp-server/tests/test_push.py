"""RED tests for the git_push dry-run path (classify_push + _push_state).

Covers the fail-closed classifier rows (detached HEAD, no upstream, nothing to
push, safe push with ahead/behind/dirty detail) and the state-collection wiring
(symbolic-ref, rev-parse @{u}, rev-list left-right count, status porcelain).
FakeExecutor mocks git; no network is ever touched — the dry-run is local-only.
"""

from __future__ import annotations

from typing import Any

import pytest

from src.dryrun import classify_push
from src.executor import ProcResult
from src.tool_handlers.local_mutation import _push_state

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


class FakeExecutor:
    """Recorded argv -> ProcResult mapping (default: fail)."""

    def __init__(
        self,
        mapping: dict[tuple[str, ...], ProcResult] | None = None,
    ) -> None:
        self.mapping = mapping or {}
        self.calls: list[tuple[tuple[str, ...], str | None]] = []

    def run(self, argv, *, cwd=None, text=True, timeout_s=30.0) -> ProcResult:  # noqa: ARG002
        key = tuple(argv)
        self.calls.append((key, cwd))
        if key not in self.mapping:
            return ProcResult(1, "", f"unmocked: {' '.join(argv)}")
        return self.mapping[key]


def ok_out(stdout: str) -> ProcResult:
    return ProcResult(0, stdout, "")


def err_out(stderr: str = "boom") -> ProcResult:
    return ProcResult(1, "", stderr)


BASE = {
    "branch": "main",
    "upstream": "origin/main",
    "ahead": 3,
    "behind": 0,
    "dirty_count": 0,
}


# ---------------------------------------------------------------------------
# classify_push — pure classifier rows
# ---------------------------------------------------------------------------


def test_push_detached_head_fails_closed() -> None:
    effect = classify_push(
        branch=None, upstream=None, ahead=0, behind=0, dirty_count=0
    )
    assert effect.data["safe"] is False
    assert effect.data["branch"] is None
    assert "Detached HEAD" in effect.summary


def test_push_no_upstream_fails_closed() -> None:
    effect = classify_push(
        branch="feature/x", upstream=None, ahead=2, behind=0, dirty_count=0
    )
    assert effect.data["safe"] is False
    assert "no upstream" in effect.summary


def test_push_nothing_ahead_fails_closed() -> None:
    effect = classify_push(branch="main", upstream="origin/main", ahead=0, behind=0, dirty_count=0)
    assert effect.data["safe"] is False
    assert "Nothing to push" in effect.summary


def test_push_safe_with_detail() -> None:
    effect = classify_push(branch="main", upstream="origin/main", ahead=3, behind=1, dirty_count=2)
    assert effect.data["safe"] is True
    assert effect.data == {**BASE, "ahead": 3, "behind": 1, "dirty_count": 2, "safe": True}
    assert "3 commit(s)" in effect.summary
    assert "1 behind" in effect.summary
    assert "2 dirty" in effect.summary


def test_push_safe_in_sync_detail() -> None:
    effect = classify_push(**BASE)
    assert effect.data["safe"] is True
    assert "in sync" in effect.summary
    assert "dirty" not in effect.summary


# ---------------------------------------------------------------------------
# _push_state — executor wiring (no-network dry-run)
# ---------------------------------------------------------------------------


def read_only_mapping() -> dict[tuple[str, ...], ProcResult]:
    """The 4 read commands every push dry-run issues, all passing."""
    return {
        ("git", "-C", "/repo", "symbolic-ref", "-q", "--short", "HEAD"): ok_out("main\n"),
        ("git", "-C", "/repo", "rev-parse", "--abbrev-ref", "@{u}"): ok_out("origin/main\n"),
        (
            "git",
            "-C",
            "/repo",
            "rev-list",
            "--left-right",
            "--count",
            "HEAD...@{u}",
        ): ok_out("3\t0\n"),  # left=HEAD-side (ahead), right=@{u}-side (behind)
        ("git", "-C", "/repo", "status", "--porcelain"): ok_out(" M file.txt\n?? untracked\n"),
    }


def test_push_state_happy_path() -> None:
    executor = FakeExecutor(read_only_mapping())
    effect = _push_state(executor, "/repo")

    assert effect.data["safe"] is True
    assert effect.data["branch"] == "main"
    assert effect.data["upstream"] == "origin/main"
    assert effect.data["ahead"] == 3
    assert effect.data["behind"] == 0
    assert effect.data["dirty_count"] == 2
    # dry-run must only ever issue local git reads (no push, no network tool)
    assert all("push" not in c[0] for c in executor.calls)


def test_push_state_detached() -> None:
    mapping = read_only_mapping()
    mapping[("git", "-C", "/repo", "symbolic-ref", "-q", "--short", "HEAD")] = err_out("detached")
    executor = FakeExecutor(mapping)
    effect = _push_state(executor, "/repo")

    assert effect.data["safe"] is False
    assert "Detached HEAD" in effect.summary


def test_push_state_no_upstream() -> None:
    mapping = read_only_mapping()
    mapping[("git", "-C", "/repo", "rev-parse", "--abbrev-ref", "@{u}")] = err_out(
        "no upstream configured"
    )
    executor = FakeExecutor(mapping)
    effect = _push_state(executor, "/repo")

    assert effect.data["safe"] is False
    assert effect.data["branch"] == "main"
    assert effect.data["upstream"] is None
    assert "no upstream" in effect.summary


def test_push_state_ahead_parse_from_left_right_count() -> None:
    """rev-list --left-right --count prints AHEAD<TAB>BEHIND; the wiring parses both."""
    mapping = read_only_mapping()
    mapping[
        ("git", "-C", "/repo", "rev-list", "--left-right", "--count", "HEAD...@{u}")
    ] = ok_out("5\t2\n")
    executor = FakeExecutor(mapping)
    effect = _push_state(executor, "/repo")

    assert effect.data["safe"] is True
    assert effect.data["ahead"] == 5
    assert effect.data["behind"] == 2


def test_push_state_ahead_zero_nothing_to_push() -> None:
    mapping = read_only_mapping()
    mapping[
        ("git", "-C", "/repo", "rev-list", "--left-right", "--count", "HEAD...@{u}")
    ] = ok_out("0\t0\n")
    executor = FakeExecutor(mapping)
    effect = _push_state(executor, "/repo")

    assert effect.data["safe"] is False
    assert effect.data["ahead"] == 0
    assert "Nothing to push" in effect.summary