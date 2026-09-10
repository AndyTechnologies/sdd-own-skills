"""Worktree mutation handlers — 4 ``git_worktree_*`` tools (F6).

Lifecycle tools (primary):
- ``git_worktree_acquire``: claim a lifecycle worktree. Two-phase via
  ``destructive_flow``; typed pre-flow denials (outside the flow):
  ``owned_by_other`` (live claim by another owner/session), ``locked_unreadable``
  (corrupt lock), ``corrupt_worktree`` (disk/porcelain disagreement). An
  already-mine claim returns ``already_mine`` directly (no mutation). Safe
  states (absent / absent_branch_exists / exists_inactive / exists_stale)
  plan ``created`` / ``attached`` / ``claimed`` and delegate to
  ``worktree_state.acquire_worktree`` on confirm.
- ``git_worktree_release``: release a claim — clears lock + hint-index entry,
  NEVER removes the worktree or its files. Two-phase; pre-flow typed denials:
  ``locked_unreadable``, ``owned_by_other``, ``not_found``.

Retrocompat wrappers (harmless supersets of the v1 tools):
- ``git_worktree_add``: thin wrapper over acquire — same two-phase envelope,
  safe-slug and ``worktree_exists`` semantics for trees with no claim, but the
  create+lock+index work is delegated to ``worktree_state.acquire_worktree``
  (inline lock/classifier logic removed).
- ``git_worktree_remove``: thin wrapper over release — keeps the destructive
  two-phase flow, dirty pre-check and owner pre-check; claim clearing delegates
  to ``worktree_state.release_worktree``, then codegraph dir removal + ``git
  worktree remove``.

Server-owned artifacts (``.codegraph/``, ``.sdd-agent-lock``) are untracked by
construction, so the dirty check ignores only those two porcelain entries;
everything else stays dirty. The server NEVER accepts a raw worktree path —
only ``(repo_path, change, owner)`` (C3 cross-repo/cross-worktree boundary).
"""

from __future__ import annotations

import os
import shutil
from typing import TYPE_CHECKING, Any

from src import worktree_state as ws
from src._common import validate_worktree as _validate_worktree
from src.dryrun import DryRunResult, ECHO_PROTOCOL, destructive_flow
from src.envelope import Envelope, err, ok

if TYPE_CHECKING:
    from fastmcp import FastMCP

    from src.executor import ExecutorProto


def _classify_or_deny(
    executor: ExecutorProto,
    repo_path: str,
    change: str,
    owner: str,
    session: str | None,
) -> tuple[str | None, dict[str, Any] | None, Envelope | None]:
    """Classify the canonical worktree.

    Returns ``(state, signals, deny_envelope)`` — when the third element is
    set, callers must return it as a typed pre-flow denial (no two-phase flow).
    """
    state, signals = ws.classify_worktree(executor, repo_path, change, owner, session)
    if state == "corrupt":
        if signals.get("lock_status") == "corrupt":
            return state, signals, err(
                "locked_unreadable",
                f"Worktree lock file is corrupt — cannot verify owner",
                hint="inspect the worktree's .sdd-agent-lock manually",
            )
        return state, signals, err(
            "corrupt_worktree",
            "Worktree state disagrees with git porcelain (or the git probe failed) "
            "— refusing to act on unreadable evidence",
            hint="inspect the worktree manually",
        )
    if state == "exists_active_other":
        return state, signals, err(
            "owned_by_other",
            f"Worktree is claimed by {signals.get('owner')!r} "
            f"(session {signals.get('session')!r}, last_seen {signals.get('last_seen')})",
            hint="only the owning session may claim/release it",
        )
    return state, signals, None


def register(server: FastMCP, executor: ExecutorProto) -> None:
    """Wire all 4 worktree mutation tools into *server*."""

    # ------------------------------------------------------------------
    # 1. git_worktree_acquire (primary lifecycle tool)
    # ------------------------------------------------------------------
    @server.tool(
        description="Claim a lifecycle worktree at "
        "~/.agent_worktrees/<repo-name>/<change> (two-phase: dry-run → confirm). "
        + ECHO_PROTOCOL
        + " Status: created | attached | claimed | already_mine. Denies (typed, "
        "outside the two-phase flow): owned_by_other; locked_unreadable; "
        "corrupt_worktree. change must match ^[A-Za-z0-9][A-Za-z0-9._-]*$.",
    )
    async def git_worktree_acquire(
        repo_path: str,
        change: str,
        owner: str = "default",
        session: str = "default",
        store: str = "hybrid",
        dry_run: bool = True,
        confirmed: bool = False,
        confirmed_data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Claim the lifecycle worktree for *change* (two-phase)."""
        validation = _validate_worktree(executor, repo_path)
        if validation:
            return dict(validation)

        slug_err = ws.validate_safe_slug(change)
        if slug_err:
            return dict(err(
                "invalid_parameter",
                f"Invalid change: {slug_err}",
                hint="change must match ^[A-Za-z0-9][A-Za-z0-9._-]*$",
            ))

        target = ws.canonical_worktree_path(executor, repo_path, change)
        branch = f"sdd/{change}"

        state, signals, deny = _classify_or_deny(executor, repo_path, change, owner, session)
        if deny:
            return dict(deny)

        if state == "exists_active_mine":
            # No mutation needed — honest direct ok (idempotent re-acquire).
            return dict(ok(
                {
                    "status": "already_mine",
                    "change": change,
                    "path": target,
                    "branch": branch,
                    "repo_name": ws.derive_repo_name(executor, repo_path),
                    "store": signals.get("store") or store,
                },
                f"Worktree {target} already claimed by {owner}/{session} — no mutation",
            ))

        def compute_dry_run() -> DryRunResult:
            status = {
                "absent": "created",
                "absent_branch_exists": "created",
                "exists_inactive": "attached",
                "exists_stale": "claimed",
            }[state]
            data: dict[str, Any] = {
                "path": target,
                "branch": branch,
                "change": change,
                "status": status,
                "branch_exists": bool(signals.get("branch_exists")),
                "safe": True,
            }
            return DryRunResult(
                data=data,
                summary=f"Plan: {status} worktree {target} on branch {branch} "
                f"(owner={owner}, session={session})",
            )

        def execute() -> Envelope:
            return ws.acquire_worktree(
                executor, repo_path, change, owner, session, store=store
            )

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
    # 2. git_worktree_release (primary lifecycle tool)
    # ------------------------------------------------------------------
    @server.tool(
        description="Release a lifecycle worktree claim "
        "(clears lock + hint index; the worktree and its files are NEVER "
        "removed). Two-phase: dry-run → confirm. "
        + ECHO_PROTOCOL
        + " Denies (typed, outside the two-phase flow): owned_by_other; "
        "locked_unreadable; not_found.",
    )
    async def git_worktree_release(
        repo_path: str,
        change: str,
        owner: str,
        dry_run: bool = True,
        confirmed: bool = False,
        confirmed_data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Release the claim on *change*'s worktree (two-phase)."""
        validation = _validate_worktree(executor, repo_path)
        if validation:
            return dict(validation)

        slug_err = ws.validate_safe_slug(change)
        if slug_err:
            return dict(err(
                "invalid_parameter",
                f"Invalid change: {slug_err}",
                hint="change must match ^[A-Za-z0-9][A-Za-z0-9._-]*$",
            ))

        target = ws.canonical_worktree_path(executor, repo_path, change)

        state, signals, deny = _classify_or_deny(executor, repo_path, change, owner, None)
        if deny:
            return dict(deny)

        if state == "absent":
            return dict(err(
                "not_found",
                f"No worktree at derived path {target}",
                hint="check the change name / repo path",
            ))

        def compute_dry_run() -> DryRunResult:
            data: dict[str, Any] = {
                "path": target,
                "change": change,
                "lock_owner": signals.get("owner"),
                "workspace_kept": True,
                "safe": True,
            }
            return DryRunResult(
                data=data,
                summary=f"Plan: release claim on {target} (lock + index entry cleared, "
                f"worktree kept)",
            )

        def execute() -> Envelope:
            return ws.release_worktree(executor, repo_path, change, owner)

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
    # 3. git_worktree_add (retrocompat wrapper over acquire)
    # ------------------------------------------------------------------
    @server.tool(
        description="Create a git worktree at "
        "~/.agent_worktrees/<repo-name>/<change> (two-phase: dry-run → confirm). "
        + ECHO_PROTOCOL
        + " change must match ^[A-Za-z0-9][A-Za-z0-9._-]*$ (rejects / \\ .. empty). "
        "For claiming an existing worktree use git_worktree_acquire.",
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

        slug_err = ws.validate_safe_slug(change)
        if slug_err:
            return dict(err(
                "invalid_parameter",
                f"Invalid change: {slug_err}",
                hint="change must match ^[A-Za-z0-9][A-Za-z0-9._-]*$",
            ))

        target = ws.canonical_worktree_path(executor, repo_path, change)
        branch = f"sdd/{change}"

        state, signals, deny = _classify_or_deny(executor, repo_path, change, owner, session)
        if deny:
            return dict(deny)

        if state == "exists_active_mine":
            return dict(ok(
                {
                    "status": "already_mine",
                    "change": change,
                    "path": target,
                    "branch": branch,
                },
                f"Worktree {target} already claimed by {owner}/{session} — no mutation",
            ))

        if state in ("exists_inactive", "exists_stale"):
            # Legacy add semantics: a tree already exists — never duplicate it.
            return dict(err(
                "worktree_exists",
                f"Worktree already exists at {target} (state {state}, "
                f"claimed by {signals.get('owner')!r})",
                hint="use git_worktree_acquire to claim it, or git_worktree_release/remove to retire it",
            ))

        def compute_dry_run() -> DryRunResult:
            data: dict[str, Any] = {
                "path": target,
                "branch": branch,
                "change": change,
                "safe": True,
                "branch_exists": bool(signals.get("branch_exists")),
            }
            return DryRunResult(
                data=data,
                summary=f"Plan: create worktree {target} on branch {branch}",
            )

        def execute() -> Envelope:
            return ws.acquire_worktree(
                executor, repo_path, change, owner, session, store="hybrid"
            )

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
    # 4. git_worktree_remove (retrocompat wrapper over release)
    # ------------------------------------------------------------------
    @server.tool(
        description="Remove a git worktree at "
        "~/.agent_worktrees/<repo-name>/<change> (two-phase: dry-run → confirm). "
        + ECHO_PROTOCOL
        + " Denies (typed, outside the two-phase flow): dirty worktree → "
        "dirty_worktree; lock owner != owner arg → "
        "owned_by_other; corrupt lock → locked_unreadable; absent → not_found. "
        "Never accepts a raw worktree path — (repo_path, change, owner) only.",
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

        slug_err = ws.validate_safe_slug(change)
        if slug_err:
            return dict(err(
                "invalid_parameter",
                f"Invalid change: {slug_err}",
                hint="change must match ^[A-Za-z0-9][A-Za-z0-9._-]*$ — raw paths are never accepted",
            ))

        target = ws.canonical_worktree_path(executor, repo_path, change)

        state, signals, deny = _classify_or_deny(executor, repo_path, change, owner, None)
        if deny:
            return dict(deny)

        if state == "absent":
            return dict(err(
                "not_found",
                f"No worktree at derived path {target}",
                hint="check the change name / repo path",
            ))

        # Pre-check 1 — dirty worktree (server-owned artifacts excluded)
        dirty, status_err = ws.status_dirty(executor, target)
        if status_err:
            return dict(status_err)
        if dirty:
            return dict(err(
                "dirty_worktree",
                f"Worktree {target} has uncommitted changes — refusing to remove",
                hint="commit or stash first",
            ))

        def compute_dry_run() -> DryRunResult:
            # Recompute the same facts inside the flow so the confirm-time
            # recomputation stays fail-closed if state drifted since the pre-checks.
            dirty, status_err = ws.status_dirty(executor, target)
            if status_err:
                dirty = True  # fail-closed: cannot verify cleanliness
            lock_now, lock_status_now = ws.read_lock_v2(target)
            # missing lock → no owner claim (does not block); corrupt → cannot
            # verify owner → fail-closed; ok → owner must match.
            if lock_status_now == "corrupt":
                owner_match = False
            else:
                owner_match = True if lock_status_now == "missing" else ws.lock_owner(lock_now) == owner
            data: dict[str, Any] = {
                "path": target,
                "change": change,
                "dirty": dirty,
                "lock_owner": ws.lock_owner(lock_now),
                "safe": (not dirty) and owner_match,
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
            # 1) Clear the claim (lock + hint index entry) via the shared layer.
            release = ws.release_worktree(executor, repo_path, change, owner)
            if not release["ok"]:
                return release
            # 2) Drop server-owned artifacts so git's own clean check passes;
            #    any user-untracked/modified files then still block removal.
            shutil.rmtree(os.path.join(target, ws.CODEGRAPH_DIRNAME), ignore_errors=True)
            r = executor.run(["git", "-C", repo_path, "worktree", "remove", target])
            if r.returncode != 0:
                return err("invalid_parameter", r.stderr.strip())
            return ok(None, f"Worktree {target} removed (claim released)")

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