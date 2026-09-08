# Delta for gh-git-mcp-server

RFC traceability: AC3-6 (worktree tools), AC7 (error catalog). Proposal D2 (active_agents), D4 (tool pattern).

## ADDED Requirements

### Requirement: Worktree add tool

`git_worktree_add` SHALL accept `repo_path` and `change`, create a worktree at `~/.agent_worktrees/<basename(repo_path)>/<change>` from the default branch with branch `sdd/<change>`, initialize `.codegraph/`, and write `.sdd-agent-lock`. It SHALL follow `destructive_flow` two-phase: default `dry_run:true`; confirmed requires prior dry-run. The `change` parameter SHALL match the safe-slug rule `^[A-Za-z0-9][A-Za-z0-9._-]*$` (reject `/`, `\`, `..`, empty). Returns `error.type: worktree_exists` if the target already exists.

#### Scenario: Happy path add (AC3/AC4)

- GIVEN a valid `repo_path` and a new `change_name`
- WHEN `git_worktree_add` is called with `dry_run:true`
- THEN it returns the planned worktree path and branch with `data.dry_run:true`
- AND no worktree is created

#### Scenario: Confirm add creates worktree (AC4)

- GIVEN a prior dry-run for `git_worktree_add`
- WHEN `confirmed:true` is provided
- THEN the worktree is created at the correct path from default branch
- AND `.codegraph/` is initialized and `.sdd-agent-lock` is written

#### Scenario: Add when worktree exists

- GIVEN a worktree already exists at the target path
- WHEN `git_worktree_add` is called
- THEN it returns `ok:false` with `error.type: worktree_exists`

### Requirement: Worktree list tool

`git_worktree_list` SHALL accept `repo_path` and return all worktrees (including main) as an idempotent read sibling in `local_read.py`.

#### Scenario: List worktrees (AC5)

- GIVEN a repo with one or more worktrees
- WHEN `git_worktree_list` is called
- THEN it returns `ok:true` with worktree paths and branches including the main worktree

### Requirement: Worktree remove tool

`git_worktree_remove` SHALL accept `repo_path`, `change`, and `owner`, follow `destructive_flow` two-phase, and enforce three pre-checks (typed denies, outside the two-phase destructive_flow path — same pattern as `_validate_worktree` in local_mutation.py): (1) `dirty_worktree` — refuse on uncommitted changes (`git status --porcelain`); (2) `active_agents` — refuse if `.sdd-agent-lock` has a live PID (`kill -0`); stale PID allows removal; (3) `owned_by_other` — refuse if `.sdd-agent-lock.owner` does not match the caller's `owner`. The server SHALL NEVER accept a raw worktree path; it derives canonical `~/.agent_worktrees/<basename(repo_path)>/<change>` and validates `change` against the safe-slug rule. A raw path or traversal attempt returns `error.type: invalid_parameter`. On confirmed removal the lock is cleared.

#### Scenario: Remove happy path (AC4)

- GIVEN a clean worktree with no active agents
- WHEN `git_worktree_remove` is called with `dry_run:true`
- THEN it returns the planned removal with `data.dry_run:true`

#### Scenario: Remove dirty worktree denied (AC4)

- GIVEN a worktree with uncommitted changes
- WHEN `git_worktree_remove` is called
- THEN it returns `ok:false` with `error.type: dirty_worktree`

#### Scenario: Remove active agent denied (AC4)

- GIVEN a worktree with `.sdd-agent-lock` containing a live PID
- WHEN `git_worktree_remove` is called
- THEN it returns `ok:false` with `error.type: active_agents`

#### Scenario: Remove owned by other denied (AC4)

- GIVEN a worktree with `.sdd-agent-lock` where `.owner` does not match the caller
- WHEN `git_worktree_remove` is called
- THEN it returns `ok:false` with `error.type: owned_by_other`

#### Scenario: Remove stale lock allowed (AC4)

- GIVEN a worktree with `.sdd-agent-lock` containing a stale PID
- WHEN `git_worktree_remove` is called with `confirmed:true`
- THEN the worktree is removed and `.sdd-agent-lock` is cleared

### Requirement: Worktree error catalog extension

The `envelope.py` closed catalog and `spec.md` closed-set list SHALL grow by `worktree_exists`, `active_agents`, and `owned_by_other`. The existing `dirty_worktree` (previously unemitted) SHALL be emitted by `git_worktree_remove`. This maintains the A12 typed-envelope contract in lockstep.

#### Scenario: New error types (AC7)

- GIVEN the server error catalog is inspected
- THEN `worktree_exists`, `active_agents`, `owned_by_other`, and `dirty_worktree` are present

## MODIFIED Requirements

### Requirement: Tool surface completeness

The server SHALL expose 26 tools in 5 families: remote read (14), remote mutation (3), local read (5: 4 existing + `git_worktree_list`), local mutation (4: 2 existing + `git_worktree_add`, `git_worktree_remove`).
(Previously: 23 tools in 4 families; no worktree tools.)

#### Scenario: Full surface advertised (AC7)

- GIVEN the server starts
- WHEN an MCP `tools/list` probe runs
- THEN it lists 26 tools including 3 worktree tools
- AND `error.type` covers: `auth_required`, `repo_not_found`, `network_error`, `not_found`, `not_a_repo`, `dirty_worktree`, `not_safe`, `commit_failed`, `invalid_parameter`, `worktree_exists`, `active_agents`, `owned_by_other`
- AND `confirm_required` is a summary marker on `ok()` envelopes, never an `error.type`
