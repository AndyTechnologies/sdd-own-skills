"""Local read handlers — 5 ``git_*`` tools.

All tools:
- Validate ``path`` is a git worktree
- Use ``executor.run()`` with ``git -C path ...``
- Return ``ok(data, summary)``
- Idempotent, no state change
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

from src import worktree_state as ws
from src._common import validate_worktree as _validate_worktree
from src.envelope import err, ok

if TYPE_CHECKING:
    from fastmcp import FastMCP

    from src.executor import ExecutorProto


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
        """List all git worktrees (including main) for a repo, enriched with
        lifecycle state (state, owner, session, last_seen, dirty, is_main)."""
        validation = _validate_worktree(executor, path)
        if validation:
            return dict(validation)
        result = ws.enriched_worktree_list(executor, path)
        return dict(result)
