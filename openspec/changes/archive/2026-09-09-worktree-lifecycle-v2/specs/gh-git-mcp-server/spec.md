# Delta for gh-git-mcp-server

> **Archive amendment (2026-09-09)**: This delta was amended at archive time to match the shipped implementation (design outran spec; see tasks.md §Spec-Delta Items and verify-report §Spec-Delta Note). Amended: (b) `git_worktree_acquire` gains an optional `store="hybrid"` parameter (lock v2 requires it); (c) denial semantics cover session mismatch, not only owner mismatch — same owner with a different session is `owned_by_other`.

## MODIFIED Requirements

### Requirement: Worktree add tool

`git_worktree_add` SHALL become a thin retrocompat wrapper delegating to `git_worktree_acquire`. It SHALL accept `repo_path` and `change`, resolve the call to `acquire(repo_path, change, owner=<caller>, session=<current>)`, and translate the acquire status to the existing `destructive_flow` two-phase envelope. It SHALL follow the safe-slug rule `^[A-Za-z0-9][A-Za-z0-9._-]*$`. The wrapper MUST NOT duplicate classifier or lock logic.
(Previously: standalone add with its own lock/classifier logic)

#### Scenario: Add delegates to acquire

- GIVEN `git_worktree_add` called with valid params
- WHEN the wrapper resolves
- THEN `acquire` is called internally
- AND the result is translated to the existing envelope format
- AND no duplicate lock or classifier logic runs

#### Scenario: Add preserves dry-run pattern

- GIVEN `git_worktree_add` with `dry_run:true`
- WHEN called
- THEN it returns planned effect with `data.dry_run:true`
- AND no worktree is created

### Requirement: Worktree remove tool

`git_worktree_remove` SHALL become a thin retrocompat wrapper delegating to `git_worktree_release` for the claim release. The existing `destructive_flow` two-phase and pre-checks (dirty, active agents, owner match) are preserved but the claim-clearing step routes through `release` internally. The server SHALL NEVER accept a raw worktree path.
(Previously: standalone remove with self-contained lock logic)

#### Scenario: Remove delegates release for claim

- GIVEN `git_worktree_remove` called with confirmed params
- WHEN the wrapper resolves
- THEN claim-clearing routes through `release` internally
- AND the worktree removal and pre-checks remain in the remove tool

### Requirement: Worktree list tool

`git_worktree_list` SHALL return enriched entries: change, path, branch, state (from 7-state classifier), owner, session, last_seen, dirty. It SHALL include the main worktree. The list remains an idempotent read.
(Previously: returned only paths and branches)

#### Scenario: Enriched list

- GIVEN a repo with worktrees
- WHEN `git_worktree_list` is called
- THEN each entry includes state, owner, session, last_seen, dirty
- AND the main worktree is included

#### Scenario: Stale worktree in list

- GIVEN a worktree with dead PID lock
- WHEN `git_worktree_list` is called
- THEN its state is `exists_stale`
- AND `last_seen` reflects the lock timestamp

### Requirement: Worktree error catalog extension

The `envelope.py` closed catalog and `spec.md` closed-set list SHALL grow by `locked_unreadable`. Existing `worktree_exists`, `active_agents`, `owned_by_other`, `dirty_worktree` are retained. The acquire tool emits `owned_by_other` and `locked_unreadable`; release is silent on non-ownership.
(Previously: catalog had `worktree_exists`, `active_agents`, `owned_by_other`, `dirty_worktree`)

#### Scenario: New error type

- GIVEN the server error catalog is inspected
- THEN `locked_unreadable` is present alongside existing worktree errors

## ADDED Requirements

### Requirement: Worktree acquire tool

`git_worktree_acquire(repo_path, change, owner, session, store="hybrid")` SHALL be exposed as a new MCP tool — `store` is an optional parameter defaulting to `"hybrid"` (lock v2 requires it; callers may override). It SHALL classify the worktree state, create/attach/claim as appropriate, write lock v2 and hint index, and return `{status, path, branch}`. Status is one of: `created`, `attached`, `claimed`, `reclaimed`, `already_mine`. Typed denials: `owned_by_other`, `locked_unreadable`. It SHALL NEVER silently take over.

#### Scenario: Acquire creates new worktree

- GIVEN state is `absent`
- WHEN `acquire` is called
- THEN status is `created`, worktree is created, lock v2 written, index updated

#### Scenario: Acquire reclaims stale

- GIVEN state is `exists_stale`
- WHEN `acquire` is called
- THEN status is `claimed`, lock v2 is updated with new session/pid/last_seen

#### Scenario: Acquire denies active other

- GIVEN state is `exists_active_other` (different owner OR different session — same owner with a different session is also a conflict)
- WHEN `acquire` is called
- THEN `ok:false` with `error.type: owned_by_other`

### Requirement: Worktree release tool

`git_worktree_release(repo_path, change, owner)` SHALL be exposed as a new MCP tool. It SHALL remove the caller's claim from the lock without destroying the worktree. Dirty worktrees are fine. Non-owner release is a silent no-op.

#### Scenario: Release clears claim

- GIVEN a worktree with lock owned by caller
- WHEN `release` is called
- THEN the claim is cleared, worktree remains, index updated
