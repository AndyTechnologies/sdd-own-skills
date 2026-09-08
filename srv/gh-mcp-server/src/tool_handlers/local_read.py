"""Local read handlers — 5 ``git_*`` tools.

All tools:
- Validate ``path`` is a git worktree
- Use ``executor.run()`` with ``git -C path ...``
- Return ``ok(data, summary)``
- Idempotent, no state change
"""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any

from src.envelope import Envelope, err, ok

if TYPE_CHECKING:
    from fastmcp import FastMCP

    from src.executor import ExecutorProto


def _validate_worktree(executor: ExecutorProto, path: str) -> Envelope | None:
    """Return an error envelope if *path* is not a git worktree."""
    r = executor.run(["git", "-C", path, "rev-parse", "--is-inside-work-tree"])
    if r.returncode != 0 or "true" not in r.stdout.strip().lower():
        return err("not_a_repo", f"Path {path} is not a git worktree", hint="point path at a repo")
    return None


def register(server: FastMCP, executor: ExecutorProto) -> None:
    """Wire all 5 local read tools into *server*."""

    # ------------------------------------------------------------------
    # 1. git_status
    # ------------------------------------------------------------------
    @server.tool()
    async def git_status(path: str) -> dict[str, Any]:
        """Get git status (branch + porcelain summary)."""
        validation = _validate_worktree(executor, path)
        if validation:
            return dict(validation)
        r = executor.run(["git", "-C", path, "status", "--porcelain=v1", "-b"])
        if r.returncode != 0:
            return dict(err("invalid_parameter", r.stderr.strip()))
        return dict(ok({"status": r.stdout}, f"Status for {path}"))

    # ------------------------------------------------------------------
    # 2. git_diff
    # ------------------------------------------------------------------
    @server.tool()
    async def git_diff(path: str, staged: bool = False, stat_only: bool = False) -> dict[str, Any]:
        """Get git diff. staged=true for staged changes, stat_only=true for summary."""
        validation = _validate_worktree(executor, path)
        if validation:
            return dict(validation)
        cmd = ["git", "-C", path, "diff"]
        if staged:
            cmd.append("--cached")
        if stat_only:
            cmd.append("--stat")
        r = executor.run(cmd)
        if r.returncode != 0:
            return dict(err("invalid_parameter", r.stderr.strip()))
        return dict(ok({"diff": r.stdout}, f"Diff for {path} ({len(r.stdout)} chars)"))

    # ------------------------------------------------------------------
    # 3. git_log
    # ------------------------------------------------------------------
    @server.tool()
    async def git_log(path: str, limit: int = 20) -> dict[str, Any]:
        """Get recent git log (oneline)."""
        validation = _validate_worktree(executor, path)
        if validation:
            return dict(validation)
        r = executor.run(["git", "-C", path, "log", "--oneline", f"-n{limit}"])
        if r.returncode != 0:
            return dict(err("invalid_parameter", r.stderr.strip()))
        return dict(ok({"log": r.stdout}, f"Last {limit} commits for {path}"))

    # ------------------------------------------------------------------
    # 4. git_branch
    # ------------------------------------------------------------------
    @server.tool()
    async def git_branch(path: str) -> dict[str, Any]:
        """List local branches with tracking info."""
        validation = _validate_worktree(executor, path)
        if validation:
            return dict(validation)
        r = executor.run(["git", "-C", path, "branch", "-vv"])
        if r.returncode != 0:
            return dict(err("invalid_parameter", r.stderr.strip()))
        return dict(ok({"branches": r.stdout}, f"Branches for {path}"))

    # ------------------------------------------------------------------
    # 5. git_worktree_list
    # ------------------------------------------------------------------
    @server.tool()
    async def git_worktree_list(path: str) -> dict[str, Any]:
        """List all git worktrees (including main) for a repo. Idempotent read."""
        validation = _validate_worktree(executor, path)
        if validation:
            return dict(validation)
        r = executor.run(["git", "-C", path, "worktree", "list", "--porcelain"])
        if r.returncode != 0:
            return dict(err("invalid_parameter", r.stderr.strip()))
        # Porcelain format: blocks of "key value" lines separated by blank lines.
        worktrees: list[dict[str, str]] = []
        current: dict[str, str] = {}
        for line in r.stdout.splitlines():
            if not line.strip():
                if current:
                    worktrees.append(current)
                    current = {}
                continue
            key, _, value = line.partition(" ")
            current[key] = value
        if current:
            worktrees.append(current)
        summary = "; ".join(
            f"{w.get('branch', 'detached')} @ {w.get('worktree', '?')}"
            for w in worktrees
        )
        return dict(ok({"worktrees": worktrees}, f"{len(worktrees)} worktree(s): {summary}"))
