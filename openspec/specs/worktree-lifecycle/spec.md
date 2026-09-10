# Worktree Lifecycle Specification

## Purpose

Defines the 7-state worktree classifier, acquire/release semantics, lock v2 schema, hint index, repo-name derivation, and error catalog for the SDD worktree lifecycle.

> **Archive amendment (2026-09-09)**: This delta was amended at archive time to match the shipped implementation — the design deliberately outran the spec (recorded in tasks.md §Spec-Delta Items and verify-report §Spec-Delta Note; verified by the 44-test Python suite and 11-test Go observer suite). Amended points: (a) v1-lock classification is PID-liveness-aware, replacing the unconditional "Legacy v1 lock treated as stale" scenario; (b) `git_worktree_acquire` gains an optional `store="hybrid"` parameter; (c) `already_mine` requires owner AND session match (session is load-bearing); (4) the `exists_inactive` gloss is corrected to "worktree, no lock" (design decision table; inactive → `attached`, stale → `claimed`). Amended content is marked inline.

## Requirements

### Requirement: 7-state classifier

The system SHALL classify every worktree into exactly one of: `absent`, `absent_branch_exists`, `exists_inactive`, `exists_stale`, `exists_active_mine`, `exists_active_other`, `corrupt`. Classification is derived from: `git worktree list --porcelain` (existence), `.sdd-agent-lock` presence (v2 schema), PID liveness (`kill -0`), owner match, and tree health.

#### Scenario: Absent worktree

- GIVEN no worktree at `~/.agent_worktrees/<repo>/<change>` and no branch `sdd/<change>`
- WHEN the classifier runs
- THEN state is `absent`

#### Scenario: Absent branch exists

- GIVEN no worktree but branch `sdd/<change>` exists
- WHEN the classifier runs
- THEN state is `absent_branch_exists`

#### Scenario: Exists stale

- GIVEN a worktree exists with `.sdd-agent-lock` v2 and the PID is dead
- WHEN the classifier runs
- THEN state is `exists_stale`

#### Scenario: Exists active mine

- GIVEN a worktree exists with `.sdd-agent-lock` v2, PID alive, owner AND session match the caller
- WHEN the classifier runs
- THEN state is `exists_active_mine`

#### Scenario: Exists active other

- GIVEN a worktree exists with `.sdd-agent-lock` v2, PID alive, owner OR session does NOT match the caller (same owner with a different session is also a conflict)
- WHEN the classifier runs
- THEN state is `exists_active_other`

#### Scenario: Corrupt

- GIVEN a worktree path exists on disk but `git worktree list --porcelain` does not list it
- WHEN the classifier runs
- THEN state is `corrupt`

#### Scenario: Legacy v1 lock with dead PID treated as stale

- GIVEN a worktree exists with a v1 `.sdd-agent-lock` (missing `version` field) and the lock PID is dead
- WHEN the classifier runs
- THEN state is `exists_stale` (claimable)

#### Scenario: Legacy v1 lock with live PID classified as active other

- GIVEN a worktree exists with a v1 `.sdd-agent-lock` (missing `version` field) and the lock PID is alive
- WHEN the classifier runs
- THEN state is `exists_active_other` (deny `owned_by_other` — never silently take over a live pre-v2 session mid-rollout)

### Requirement: Acquire tool

`git_worktree_acquire(repo_path, change, owner, session, store="hybrid")` SHALL return `{status, path, branch}`. `store` is an optional parameter defaulting to `"hybrid"` (lock v2 requires it; callers may override). Status is one of: `created` (new worktree), `attached` (existing, first lock), `claimed` (stale reclaimed), `reclaimed` (active_other reclaim on lock expiry), `already_mine`. Denials are typed: `owned_by_other`, `locked_unreadable`. The tool SHALL NEVER silently take over another owner's active worktree.

#### Scenario: Acquire absent

- GIVEN state is `absent`
- WHEN `acquire` is called
- THEN status is `created`, worktree and lock v2 are created, index is written
- AND `.codegraph/` is initialized

#### Scenario: Acquire exists inactive

- GIVEN state is `exists_inactive` (worktree present, no `.sdd-agent-lock`; the design-corrected gloss — a lock v2 with a dead PID classifies as `exists_stale`, not `exists_inactive`)
- WHEN `acquire` is called by the original owner or any caller
- THEN status is `attached`, lock v2 is created with the caller's pid/session/last_seen

#### Scenario: Acquire already mine

- GIVEN state is `exists_active_mine`
- WHEN `acquire` is called by the same owner AND the same session
- THEN status is `already_mine`, path and branch are returned, no mutation

#### Scenario: Acquire same owner different session

- GIVEN a worktree with lock v2, PID alive, owner matches the caller but session does NOT
- WHEN `acquire` is called
- THEN the tool returns `ok:false` with `error.type: owned_by_other`
- AND no mutation occurs

#### Scenario: Acquire owned by other

- GIVEN state is `exists_active_other`
- WHEN `acquire` is called by a different owner
- THEN the tool returns `ok:false` with `error.type: owned_by_other`
- AND no mutation occurs

#### Scenario: Acquire locked unreadable

- GIVEN a worktree with a `.sdd-agent-lock` file that cannot be parsed (corrupt JSON)
- WHEN `acquire` is called
- THEN the tool returns `ok:false` with `error.type: locked_unreadable`

#### Scenario: Acquire corrupt worktree

- GIVEN state is `corrupt`
- WHEN `acquire` is called
- THEN the tool returns `ok:false` with a typed error describing the corruption

### Requirement: Release tool

`git_worktree_release(repo_path, change, owner)` SHALL remove the caller's claim from `.sdd-agent-lock`. It SHALL NEVER destroy the worktree. Dirty worktrees are fine. If no lock exists or the caller does not own the claim, release is a no-op (success, no mutation).

#### Scenario: Release happy path

- GIVEN a worktree with `.sdd-agent-lock` owned by the caller
- WHEN `release` is called
- THEN the lock claim is cleared
- AND the worktree is NOT removed
- AND dirty state is preserved

#### Scenario: Release no-op when not owner

- GIVEN a worktree with `.sdd-agent-lock` owned by another
- WHEN `release` is called by the non-owner
- THEN it returns success with no mutation

### Requirement: Lock v2 schema

The `.sdd-agent-lock` file SHALL be JSON with schema: `{version: 2, pid: int, session: str, owner: str, change: str, repo_root: str, repo_name: str, branch: str, store: str, created_at: str, last_seen: str}`. The `repo_name` field SHALL ALWAYS be derived from `git rev-parse --show-toplevel` basename, never hardcoded.

#### Scenario: Lock written on acquire

- GIVEN `acquire` succeeds
- WHEN the lock is written
- THEN it contains all v2 fields
- AND `repo_name` matches the basename of the `git rev-parse --show-toplevel` output

#### Scenario: Stale detection via PID

- GIVEN a lock with a PID that no longer exists (`kill -0` fails)
- WHEN the classifier evaluates
- THEN the worktree is classified as `exists_stale`

### Requirement: Hint index

The hint index at `~/.agent_worktrees/<repo>/.agent-index.json` SHALL be a persistent write-through cache. It is NEVER the source of truth. Truth is always rebuilt from `git worktree list --porcelain` + disk lock + tree state. The index is written on acquire and release.

#### Scenario: Index written on acquire

- GIVEN `acquire` succeeds
- WHEN the index is updated
- THEN it records change, path, branch, owner, session, last_seen

#### Scenario: Index is advisory

- GIVEN the index exists
- WHEN truth differs from the index (e.g., external git operation)
- THEN the system uses git porcelain as truth, not the index

### Requirement: Repo-name derivation

The repo name for worktree paths and lock fields SHALL be derived from `git rev-parse --show-toplevel` basename, never hardcoded. This fixes the current hardcode of `"sdd-own-skills"` in `srv/sdd-tool/internal/worktree/worktree.go` ~L77.

#### Scenario: Different repo gets correct name

- GIVEN `acquire` is called in repo `/home/user/my-project`
- WHEN the worktree path is derived
- THEN it is `~/.agent_worktrees/my-project/<change>`
- AND lock `repo_name` is `my-project`

### Requirement: Enriched worktree list

`git_worktree_list(repo_path)` SHALL return for each worktree: change, path, branch, state (from classifier), owner, session, last_seen, dirty. The list SHALL include the main worktree.

#### Scenario: Enriched list output

- GIVEN a repo with two worktrees (one active, one stale)
- WHEN `git_worktree_list` is called
- THEN each entry includes state, owner, session, last_seen, dirty
- AND the main worktree is included with state reflecting its lock status
