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

### Requirement: Worktree remove tool

`git_worktree_remove` SHALL become a thin retrocompat wrapper delegating to `git_worktree_release` for the claim release. The existing `destructive_flow` two-phase and pre-checks (dirty, active agents, owner match) are preserved but the claim-clearing step routes through `release` internally. The server SHALL NEVER accept a raw worktree path.
(Previously: standalone remove with self-contained lock logic)

#### Scenario: Remove delegates release for claim

- GIVEN `git_worktree_remove` called with confirmed params
- WHEN the wrapper resolves
- THEN claim-clearing routes through `release` internally
- AND the worktree removal and pre-checks remain in the remove tool

### Requirement: Worktree error catalog extension

The `envelope.py` closed catalog and `spec.md` closed-set list SHALL grow by `locked_unreadable`. Existing `worktree_exists`, `active_agents`, `owned_by_other`, `dirty_worktree` are retained. The acquire tool emits `owned_by_other` and `locked_unreadable`; release is silent on non-ownership.
(Previously: catalog had `worktree_exists`, `active_agents`, `owned_by_other`, `dirty_worktree`)

#### Scenario: New error type

- GIVEN the server error catalog is inspected
- THEN `locked_unreadable` is present alongside existing worktree errors

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
