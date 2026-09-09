"""Shared helpers — thin pure utilities used across handler families."""

from __future__ import annotations

from typing import TYPE_CHECKING

from src.envelope import Envelope, err

if TYPE_CHECKING:
    from src.executor import ExecutorProto


def validate_worktree(executor: ExecutorProto, path: str) -> Envelope | None:
    """Return an error envelope if *path* is not a git worktree."""
    r = executor.run(["git", "-C", path, "rev-parse", "--is-inside-work-tree"])
    if r.returncode != 0 or "true" not in r.stdout.strip().lower():
        return err("not_a_repo", f"Path {path} is not a git worktree", hint="point path at a repo")
    return None
