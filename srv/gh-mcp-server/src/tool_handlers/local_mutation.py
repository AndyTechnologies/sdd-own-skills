"""Local mutation handlers — 2 ``git_*`` tools.

- ``git_commit``: two-phase (dry-run = staged summary; confirm = two sequential
  executor calls: ``add <paths>`` when ``paths`` is given, else ``add -A``, then
  ``commit``). Documents staged-index-on-failed-commit.
- ``git_delete_branch``: two-phase via ``destructive_flow``, ``--merged`` guard.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

from src._common import validate_worktree as _validate_worktree
from src.dryrun import DryRunResult, ECHO_PROTOCOL, destructive_flow
from src.envelope import Envelope, err, ok

if TYPE_CHECKING:
    from fastmcp import FastMCP

    from src.executor import ExecutorProto


def _matches_any_path(porcelain_line: str, paths: list[str]) -> bool:
    """True if a ``git status --porcelain`` line refers to one of the given paths.

    The line has the form ``XY <path>`` (``??`` for untracked); git quotes paths
    containing special characters. A directory path matches every file under it.
    """
    line = porcelain_line.strip()
    if line.startswith("??"):
        candidate = line[2:].strip()
    elif len(line) >= 3 and line[0] != "?":
        candidate = line[2:].strip()
    else:
        candidate = line
    candidate = candidate.strip('"')
    for p in paths:
        p = p.rstrip("/")
        if candidate == p or candidate.startswith(p + "/"):
            return True
    return False


def register(server: FastMCP, executor: ExecutorProto) -> None:
    """Wire all 2 local mutation tools into *server*."""

    # ------------------------------------------------------------------
    # 1. git_commit
    # ------------------------------------------------------------------
    @server.tool(
        description="Stage and commit changes (two-phase: dry-run → confirm). "
        + ECHO_PROTOCOL
        + " With `paths` provided, stages ONLY those paths and the dry-run "
        "summarizes them; without `paths`, stages all changes (`git add -A`). "
        "confirm runs git add then git commit -m <message>. On failed commit "
        "the index remains staged (partial state is visible, not a mutation).",
    )
    async def git_commit(
        path: str,
        message: str,
        paths: list[str] | None = None,
        dry_run: bool = True,
        confirmed: bool = False,
        confirmed_data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Stage and commit changes (two-phase: dry-run → confirm)."""
        validation = _validate_worktree(executor, path)
        if validation:
            return dict(validation)

        def compute_dry_run() -> DryRunResult:
            # Scoped mode: only paths that exist under the given list participate.
            r = executor.run(["git", "-C", path, "status", "--porcelain"])
            if r.returncode != 0:
                return DryRunResult(
                    data={"error": "status_failed"},
                    summary="Could not read git status",
                )
            files = [line.strip() for line in r.stdout.strip().splitlines() if line.strip()]
            if paths:
                files = [f for f in files if _matches_any_path(f, paths)]
            staged = [f for f in files if f and f[0] in ("M", "A", "D", "R", "C")]
            unstaged = [f for f in files if f and f[0] == "?" or (f and len(f) > 1 and f[1] in ("M", "D"))]
            data: dict[str, Any] = {
                "staged_count": len(staged),
                "unstaged_count": len(unstaged),
                "files": staged[:20],  # cap for readability
                "paths": paths,
                "message": message,
                "safe": len(staged) > 0,
            }
            if not staged:
                return DryRunResult(
                    data=data,
                    summary="Nothing staged — add files first (no changes to commit)",
                )
            scope = f" under {', '.join(paths)}" if paths else ""
            return DryRunResult(
                data=data,
                summary=f"{len(staged)} file(s) staged for commit{scope}: {message}",
            )

        def execute() -> Envelope:
            # Step 1: add — scoped to paths when given, else all changes
            if paths:
                add_r = executor.run(["git", "-C", path, "add", "-A", "--", *paths])
            else:
                add_r = executor.run(["git", "-C", path, "add", "-A"])
            if add_r.returncode != 0:
                return err("invalid_parameter", f"git add failed: {add_r.stderr.strip()}")

            # Step 2: commit — path-limited when scoped so pre-staged files
            # outside ``paths`` survive untouched in the index
            commit_argv = ["git", "-C", path, "commit", "-m", message]
            if paths:
                commit_argv += ["--", *paths]
            commit_r = executor.run(commit_argv)
            if commit_r.returncode != 0:
                # staged-index-on-failed-commit: index is staged, no committed state changed
                return err(
                    "commit_failed",
                    f"git add succeeded but commit failed: {commit_r.stderr.strip()}",
                    hint="index remains staged — run git status to inspect",
                )

            return ok(None, f"Committed: {message}")

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
    # 2. git_delete_branch (local)
    # ------------------------------------------------------------------
    @server.tool(
        description="Delete a local branch (two-phase: dry-run → confirm). "
        + ECHO_PROTOCOL
        + " Verifies branch is merged before allowing deletion. "
        "force=true uses -D (deletes even if unmerged).",
    )
    async def git_delete_branch(
        path: str,
        branch: str,
        force: bool = False,
        dry_run: bool = True,
        confirmed: bool = False,
        confirmed_data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Delete a local branch (two-phase: dry-run → confirm)."""
        validation = _validate_worktree(executor, path)
        if validation:
            return dict(validation)

        def compute_dry_run() -> DryRunResult:
            # Is the target branch an ancestor of HEAD? (exit 0 = merged).
            # NOTE: `git branch --merged <b>` lists branches reachable FROM b,
            # which always includes b itself — the correct antecedent check is
            # `merge-base --is-ancestor`.
            r = executor.run(["git", "-C", path, "merge-base", "--is-ancestor", branch, "HEAD"])
            if r.returncode not in (0, 1):
                return DryRunResult(
                    data={"error": "check_failed"},
                    summary=f"Could not check merge status for {branch}",
                )
            is_merged = r.returncode == 0
            data: dict[str, Any] = {
                "branch": branch,
                "is_merged": is_merged,
                "force": force,
                "safe": is_merged or force,
            }
            if not is_merged and not force:
                return DryRunResult(
                    data=data,
                    summary=f"Branch {branch} is not merged — refusing to delete (use force=true to override)",
                )
            return DryRunResult(
                data=data,
                summary=f"Branch {branch} is merged — safe to delete",
            )

        def execute() -> Envelope:
            flag = "-D" if force else "-d"
            r = executor.run(["git", "-C", path, "branch", flag, "--", branch])
            if r.returncode != 0:
                return err("invalid_parameter", r.stderr.strip())
            return ok(None, f"Branch {branch} deleted")

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
