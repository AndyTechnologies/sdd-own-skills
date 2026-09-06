---
name: github-automation
description: "Trigger: GitHub automation and operations - repositories, issues, branches, commits, pull request review/merge/status, Actions workflows, and code search through the official GitHub MCP. Does NOT cover PR or issue creation (github-pr, branch-pr, chained-pr, and issue-creation own those), and never embeds tokens."
license: MIT
metadata:
  author: AndyTechnologies (sdd-own-skills)
  version: "1.0"
---

# GitHub Automation

## Prerequisites

This skill assumes the GitHub MCP server is configured for your runtime — normally via `./setup.sh` (see the repository README, "GitHub MCP"). It uses the **official GitHub MCP server** (`github/github-mcp-server`).

**This skill never handles credentials.** Tokens live in `$GITHUB_PERSONAL_ACCESS_TOKEN` (for the runtime's process environment) or in the per-runtime 0600 env file `~/.config/sdd-own/github-mcp.env`, provisioned by `setup.sh`. You never read, print, or write a token yourself. If a tool call needs the token and it is missing, tell the user to run `./setup.sh` — do not ask for the secret in chat.

## Tool Surface

The official server exposes idiomatic `github_*` tools. The constantly updated names matter here: **always check the live tool list before automating** (`mcp__github__<server>__list_tools` style discovery, or the server's tools listing) instead of hardcoding names from memory.

Families you operate:

| Family | What it covers | Notes |
|--------|---------------|-------|
| `github_get_me` / `github_get_user` | Identity, profile | First call in any session: confirms auth, scopes, and rate-limit headroom |
| `github_get_repo` / `github_list_repositories` | Repo metadata | Repo existence and defaults before automation |
| `github_search_repositories` / `github_search_code` / `github_search_issues` | Discovery | Code search is rate-limited harder than repo search — budget it |
| `github_list_issues` / `github_get_issue` / `github_add_issue_comment` | Issue triage ops | See Issue Triage below |
| `github_list_branches` / `github_get_branch` / `github_create_branch` / `github_delete_branch` | Branch ops | Guard deletions with existence + merged checks |
| `github_list_commits` / `github_get_commit` / `github_compare_commits` | Commit/PR context | The compare tools are the cheapest diff-intent check for review |
| `github_list_pull_requests` / `github_get_pull_request` / `github_review_pull_request` / `github_merge_pull_request` / `github_get_pull_request_status` / `github_get_pull_request_checks` | PR review/merge/status ops | **Review and merge only — creation belongs to the PR skills** |
| `github_list_workflow_runs` / `github_get_workflow_run` / `github_re_run_workflow` / `github_download_workflow_run_logs` | Actions ops | Log downloads are your best evidence source for failed runs |
| `github_list_files` / `github_get_file` / `github_get_file_contents` | Content ops | Read-only; prefer blob API for large binaries |

Scope discipline: for pure read/analysis work prefer the **readonly toolset** if your runtime lets the MCP server run with it; for automation (create/add/review/merge/re-run) you need the full toolset. If a call fails with a permissions error, report whether the server is running in readonly mode — do not "work around" it with a second server.

Gating: **issue triage and PR review act on what the queue shows, not on what you imagine.** Always list → read → act, in that order.

## Automation Workflows

### Repository ops

- Confirm repo exists and its defaults (`default_branch`, visibility, topics) before scripting anything against it. `github_get_repo` first, always.
- Batch discovery uses `github_list_repositories` and `github_search_repositories` (lookahead on org/owner before assuming the repo lives where you think).

### Issue triage ops

Order: `github_list_issues` (queue) → `github_get_issue` (detail: labels, assignees, linked PR) → `github_add_issue_comment` (follow-up, repro questions, labels) or signal to the human.

- Triage by root class, never one-by-one: if the same failure mode shows up across issues, name the class and let the fix shrink the system, not spawn per-issue patches.
- Linking an issue to a fixing PR (via commit message keywords like "Fixes #NN") is the standard chain — prefer it over manual close.

### PR review/merge/status ops

- Status before review: `github_get_pull_request` + `github_get_pull_request_status` + `github_get_pull_request_checks`. A PR with red checks is a review-with-evidence, not a merge candidate.
- Review: read the actual diff intent via compare/list-files, then `github_review_pull_request` with comments tied to concrete lines. Approve only when the diff + checks + context line up; `REQUEST_CHANGES` needs the same evidence standard.
- Merge: only when checks are green AND the base branch is up to date. Prefer the merge method the repo's history uses (squash vs merge vs rebase) — check recent merged PRs before choosing.
- Chained/stacked PR review belongs to the `branch-pr`/`chained-pr` skills; here you operate status, checks, and merge.

### Branch/commit ops

- Create branches only from the current default branch unless explicitly told otherwise. Name them scoped (`<scope>/<slug>`) to match repo convention.
- Delete branches only after confirming the work is merged (`github_compare_commits` default..branch) — never delete an unmerged branch on a guess.
- Commit history reads (`github_list_commits`/`github_get_commit`) serve review context: find what introduced a regression, then the fix lives in the code, not the history.

### Actions ops

- Failed run evidence: `github_list_workflow_runs` → `github_get_workflow_run` → `github_download_workflow_run_logs`. The logs are the truth; never infer a failure from the run name.
- Re-running a failed, flaky run is legitimate (timing/transient), but two consecutive re-runs of the same job without a code fix is a signal: read the logs and diagnose instead.

### Code-search ops

- `github_search_code` is the fastest "where is X" for public code; scope it with `q=repo:owner/name` when the target is a known repo.
- It is rate-limited harder than repo search — batch queries, and prefer `github_get_file` once you know the path.

## Pitfalls

- **Hardcoded tool names go stale.** GitHub MCP renames/extends `github_*` tools; verify the live surface before every automation batch.
- **Rate limits.** Search and Actions calls burn budget fast. Read-heavy batches (reviewing many PRs) should run in the smallest number of calls that answer the question.
- **Token in the wrong place.** The token belongs ONLY in the runtime env (`$GITHUB_PERSONAL_ACCESS_TOKEN`, env file, or the runtime's own mechanism). Never inline it in tool input, logs, chat output, commits, or config files.
- **Reviewing without checks.** Status/checks first, always. Approving a PR with a red check ships broken intent.
- **Deleting on a guess.** Branch deletion without a merged-check is how useful work gets lost.

## Quick Reference

| Need | First tool | Then |
|------|-----------|------|
| Who am I / scopes | `github_get_me` | — |
| Repo facts | `github_get_repo` | `github_list_repositories` |
| Find code | `github_search_code` | `github_get_file` |
| Triage issues | `github_list_issues` | `github_get_issue` → comment/link |
| Review a PR | `github_get_pull_request` | status/checks → `github_review_pull_request` |
| Merge a PR | `github_get_pull_request_status` + checks | `github_merge_pull_request` |
| Create a PR | **PR skills** (`github-pr`/`branch-pr`/`chained-pr`) | — |
| Failed CI | `github_list_workflow_runs` | `github_get_workflow_run` → download logs |
| Delete a branch | `github_compare_commits` (merged?) | `github_delete_branch` |
| Trace a regression | `github_list_commits` | `github_get_commit` |