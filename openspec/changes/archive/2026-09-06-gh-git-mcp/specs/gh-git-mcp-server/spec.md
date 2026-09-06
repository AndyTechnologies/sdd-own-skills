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

The server SHALL expose the 23-tool surface in 4 families: remote read (`gh_get_me`, `gh_get_repo`, `gh_list_repositories`, `gh_list_issues`, `gh_get_issue`, `gh_list_pull_requests`, `gh_get_pull_request`, `gh_get_pr_checks`, `gh_get_pr_diff`, `gh_list_commits`, `gh_list_workflow_runs`, `gh_get_workflow_run`, `gh_get_run_logs`, `gh_search_code`), remote mutation (`gh_merge_pull_request`, `gh_delete_branch`, `gh_rerun_workflow`), local read (`git_status`, `git_diff`, `git_log`, `git_branch`), local mutation (`git_commit`, `git_delete_branch`).

#### Scenario: Full surface advertised

- GIVEN the server starts
- WHEN an MCP `tools/list` probe runs
- THEN it lists 23 `gh_*`/`git_*` tools with no token env

#### Scenario: Git commit dry-run

- GIVEN `git_commit` with dry-run
- THEN it returns a staged summary with `data.dry_run:true`
- AND no commit is written until confirm
