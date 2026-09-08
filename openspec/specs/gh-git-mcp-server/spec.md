# gh-git-mcp-server Specification

## Purpose

Local FastMCP server (`srv/gh-mcp-server/`, uv + fastmcp>=2, stdio) exposing 23 typed `gh_*`/`git_*` tools over the `gh` and `git` CLIs, so agents operate GitHub without bash (auth prompts, parse failures). Auth is delegated entirely to `gh`; the server never sees the token. Destructive ops are two-phase with computed dry-runs. Explicit per-call repo.

## Requirements

### Requirement: Typed output envelope

Every tool SHALL return the RFC envelope `{"ok": bool, "data": <struct>|null, "summary": str, "error": null|{"type": <typed>, "message": str}}`. Read tools SHALL populate `data` and a non-empty `summary`; the server SHALL NOT return raw CLI text passthrough as `data`. Exceptions SHALL be caught per tool and wrapped in the typed envelope with `ok:false`, never raised mid-payload.

#### Scenario: Happy read

- GIVEN `gh` authenticated and an explicit `owner/repo`
- WHEN a remote read tool returns
- THEN `ok:true`, structured `data`, non-empty `summary`, `error:null`

#### Scenario: Failure envelope

- GIVEN any tool raises
- WHEN it returns
- THEN `ok:false` and `error.type` is one of `auth_required`, `repo_not_found`, `network_error`, `not_found`, `not_a_repo`, `dirty_worktree`, `confirm_required`, `invalid_parameter`
- AND no partial mutation is returned

### Requirement: Explicit repo and subprocess hygiene

Every tool SHALL take an explicit repo target (`owner`+`repo`, or `path` for local git); the server SHALL NOT infer a repo from cwd. Every subprocess SHALL run with `GH_PROMPT_DISABLED=1` and `GIT_TERMINAL_PROMPT=0`, an inherited-unmodified env (the server never sets/reads `GH_TOKEN`/`GITHUB_TOKEN`), and a hard ~30 s timeout.

#### Scenario: Explicit target

- GIVEN a valid local or remote target
- WHEN any tool runs
- THEN it targets that explicit repo, independent of cwd
- AND no token value appears in tool input, argv, logs, or payload

### Requirement: Fail-closed authentication

Every remote tool SHALL first check `gh auth status --exit-code`; if it fails, the tool SHALL return `ok:false` with `error.type: auth_required` and a fix hint (`gh auth login`). No remote tool SHALL mutate when auth is missing.

#### Scenario: Auth failure blocks all

- GIVEN `gh` not authenticated
- WHEN any remote tool runs
- THEN every remote tool returns `auth_required`
- AND nothing mutates

### Requirement: Two-phase destructive operations with computed dry-runs

Destructive tools (merge PR, delete branch, re-run workflow, destructive local git) SHALL default to `dry_run:true`, returning the computed effect with `ok:true` and `data.dry_run:true`, mutating nothing. Execution SHALL require `confirmed:true`; a confirmed call with no prior dry-run SHALL re-run the dry-run internally and still require a follow-up confirm. Dry-runs SHALL be computed, not delegated — `gh pr merge` has no `--dry-run` and `gh branch` does not exist. Merge dry-run SHALL roll up PR state + mergeable + check rollup + method suggestion; branch-delete dry-run SHALL verify merge via `compare` commits; fail closed on unknown state.

#### Scenario: Dry-run mutates nothing

- GIVEN a mergeable PR and `dry_run` default
- WHEN the destructive tool is called once
- THEN it returns the would-be effect with `data.dry_run:true`
- AND no mutation occurs

#### Scenario: Confirm without dry-run refused

- GIVEN `confirmed:true` with no prior dry-run
- WHEN the destructive tool runs
- THEN it re-computes the dry-run and requires a follow-up confirm
- AND no mutation occurs

#### Scenario: Confirm executes once

- GIVEN a computed dry-run and `confirmed:true`
- WHEN the destructive tool runs
- THEN exactly one mutation happens
- AND no silent retries occur

#### Scenario: Unknown state fail-closed

- GIVEN the dry-run cannot determine mergeability or merged state
- WHEN the destructive tool runs
- THEN it fails closed with a typed error and mutates nothing

### Requirement: Explicit PR method and repo target

`gh_merge_pull_request` SHALL accept a merge method; `gh_delete_branch` SHALL delete via `gh api -X DELETE .../git/refs/heads/<branch>` and protect unmerged work.

#### Scenario: Delete non-merged branch refused

- GIVEN the target branch is unmerged (`compare` default..branch non-empty)
- WHEN `gh_delete_branch` runs with confirm
- THEN it refuses with a typed error and deletes nothing

### Requirement: Mutation single-shot semantics

Read tools SHALL be idempotent; mutations SHALL be explicit, single-shot, with no silent retries.

#### Scenario: Repeated read stable

- GIVEN the same explicit repo
- WHEN a read tool runs twice
- THEN both results are consistent and no state changes

### Requirement: Tool surface completeness

The server SHALL expose 26 tools in 5 families: remote read (14), remote mutation (3), local read (5: 4 existing + `git_worktree_list`), local mutation (4: 2 existing + `git_worktree_add`, `git_worktree_remove`).

#### Scenario: Full surface advertised (AC7)

- GIVEN the server starts
- WHEN an MCP `tools/list` probe runs
- THEN it lists 26 tools including 3 worktree tools
- AND `error.type` covers: `auth_required`, `repo_not_found`, `network_error`, `not_found`, `not_a_repo`, `dirty_worktree`, `not_safe`, `commit_failed`, `invalid_parameter`, `worktree_exists`, `active_agents`, `owned_by_other`
- AND `confirm_required` is a summary marker on `ok()` envelopes, never an `error.type`

#### Scenario: Git commit dry-run

- GIVEN `git_commit` with dry-run
- THEN it returns a staged summary with `data.dry_run:true`
- AND no commit is written until confirm

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
