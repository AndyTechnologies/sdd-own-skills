---
name: github-automation
description: "Trigger: GitHub automation and operations - repositories, issues, branches, commits, pull request review/merge/status, Actions workflows, and code search. Dual surface: official GitHub MCP (preferred, any account with a PAT) or own local gh_*/git_* MCP (fallback). Does NOT cover PR or issue creation (github-pr, branch-pr, chained-pr, and issue-creation own those), and never embeds tokens."
license: MIT
metadata:
  author: AndyTechnologies (sdd-own-skills)
  version: "1.0"
---

# GitHub Automation

## Runtime selection (dual surface)

This skill supports **two GitHub tool surfaces**. Selection is per session, decided once by account eligibility, then kept:

| Surface | Tools | When to use |
|---------|-------|-------------|
| **Official `github_*`** | `github/github-mcp-server` (remote `https://api.githubcopilot.com/mcp/` with `enabled: true`, provisioned by `./setup.sh`) | **Default and preferred.** Works on any account plan with a valid PAT — the remote endpoint serves any GitHub account via the PAT; a `403` means invalid/expired PAT or missing `enabled: true`, not missing GHEC. |
| **Own local `gh_*` / `git_*`** | `gh-git-mcp` (local FastMCP over the `gh` + `git` CLIs) — `gh_get_me`, `gh_get_repo`, `gh_list_pull_requests`, `gh_merge_pull_request`, `gh_delete_branch`, `gh_search_code`, `gh_rerun_workflow`, `git_status`, `git_diff`, `git_commit`, … | **Fallback.** Token-free (auth delegated to `gh`), zero remote dependency; use when the official server is not configured, cannot connect, or a call fails. |

How to decide: run the identity call — official `github_get_me` first. If the official surface is configured and returns a healthy identity, stay on it for the session. If the official server is missing, fails to connect, or returns `401`/`403`/network errors (token problem or server down), **switch to the own local surface** (`gh_get_me`) for the session and do not retry the official one blindly — check the token via `./setup.sh`. If a call fails mid-task, re-evaluate: switch that remaining task to the working surface and continue it there. Do not mix surfaces per call without cause — the switch is the fallback, not the default.

Coverage is not 1:1. The own local surface implements the workflows below with the `gh_*`/`git_*` equivalents, but some official `github_*` tools have **no local equivalent** and degrade to **report-only** (see Workflow equivalents).

## Prerequisites

### Own local surface (`gh_*` / `git_*`)

The `gh-git-mcp` server is a local FastMCP over the `gh` and `git` CLIs, wired to the runtime by `setup.sh` (multi-entry MCP block). Prerequisites:

- `gh` CLI ≥ 2.x installed and authenticated (`gh auth login`) — the server **delegates all auth to `gh`**; it never sees or embeds a token.
- `git` available on PATH.
- `uv` available (the server runs via `uv run --directory srv/gh-mcp-server python -m src.server`).

The server exposes typed envelopes `{ok, data, summary, error}`. **Destructive operations are two-phase**: call the tool once to get the computed effect (dry-run), then confirm by echoing that **exact** `data` object back — all fields, verbatim, including the `dry_run` marker. The server re-derives the effect, fingerprints it (SHA-256), and executes only on a match. Never call a destructive tool with `confirmed=true` without a preceding dry-run echo-back.

### Official surface (`github_*`)

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

## Workflow equivalents (own local surface)

When running on the own local `gh_*`/`git_*` surface, the families map as follows. **Read-only workflows are fully covered.** Write/action workflows are covered where a local equivalent exists; unmappable actions degrade to **report-only** (tell the user what to do, never fake the action).

| Workflow | Own local equivalent | Coverage |
|----------|---------------------|----------|
| Identity / profile | `gh_get_me` | Mapped |
| Repo metadata | `gh_get_repo` / `gh_list_repositories` | Mapped |
| Discovery (search) | `gh_search_code` / `gh_list_issues` | Mapped |
| Issue triage (list/detail/comment) | `gh_list_issues` / `gh_get_issue` | Mapped |
| Issue comment write | — (no local tool) | **Partial → report-only** (suggest `gh issue comment <n> -b "…"` or switch to official surface) |
| Labels/assignees write | — (no local tool) | **Partial → report-only** |
| Branch list/detail/create | `git_branch` / `git_commit` (local) | Mapped (local git) |
| Branch delete (merged) | `gh_delete_branch` / `git_delete_branch` | Mapped (two-phase dry-run+confirm) |
| Commit history read | `git_log` / `git_diff` / `git_status` | Mapped |
| PR list/get/diff | `gh_list_pull_requests` / `gh_get_pull_request` / `gh_get_pr_diff` | Mapped |
| PR checks/status | `gh_get_pr_checks` / `gh_get_pr_diff` | Mapped |
| PR review (inline comments/approve) | — (no local tool) | **Partial → report-only** (PR review belongs to the review skills; own surface cannot write reviews) |
| PR merge | `gh_merge_pull_request` | Mapped (dry-run → confirm echo-back; mergeability + checks + base-up-to-date enforced) |
| Actions workflows (list/detail) | `gh_list_workflow_runs` / `gh_get_workflow_run` | Mapped |
| Workflow run logs | `gh_get_run_logs` | Mapped |
| Re-run workflow | `gh_rerun_workflow` | Mapped (dry-run first; refuses green runs) |
| File/content read | `git_diff` / `git_log` / local file tools | Mapped (use local file tools for content, `git_*` for history/text diffs) |
| File write / create PR | — (out of scope: `github-pr`/`branch-pr`/`chained-pr`/`issue-creation` own it) | Out of scope |

Rule: **never fake an unmappable action.** If a workflow needs a write the own surface cannot do (comment, labels, review), produce the exact `gh` CLI command or switch to the official surface for that single step, and say so.

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

- **Hardcoded tool names go stale.** GitHub MCP renames/extends `github_*` tools; verify the live surface before every automation batch. On the own local surface the surface is fixed (`gh_*`/`git_*`) but still verify availability of a tool before assuming it exists.
- **403/401 from the official server is a token/config issue, not an account-plan issue.** The official remote endpoint `api.githubcopilot.com/mcp/` serves any GitHub account via a valid PAT; a `403 forbidden: access denied` means an invalid or expired token, or the server entry missing `"enabled": true` in the runtime config. Fix the token via `./setup.sh` (it asks, validates, and stores the PAT; never ask for the secret in chat) — do not switch surfaces on a clean auth failure. If the server is down/unreachable, fall back to the own local surface.
- **Rate limits.** Search and Actions calls burn budget fast. Read-heavy batches (reviewing many PRs) should run in the smallest number of calls that answer the question.
- **Token in the wrong place.** The token belongs ONLY in the runtime env (`$GITHUB_PERSONAL_ACCESS_TOKEN`, env file, or the runtime's own mechanism). Never inline it in tool input, logs, chat output, commits, or config files. The own local surface never sees a token at all.
- **Reviewing without checks.** Status/checks first, always. Approving a PR with a red check ships broken intent.
- **Deleting on a guess.** Branch deletion without a merged-check is how useful work gets lost.
- **Skipping the echo-back.** On the own local surface, a destructive confirmation must echo the exact dry-run `data`; guessing or hand-writing the confirmation data never executes safely.

## Quick Reference

| Need | Own local surface | Official surface |
|------|-------------------|------------------|
| Who am I / scopes | `gh_get_me` | `github_get_me` |
| Repo facts | `gh_get_repo` | `github_get_repo` → `github_list_repositories` |
| Find code | `gh_search_code` | `github_search_code` → `github_get_file` |
| Triage issues | `gh_list_issues` | `github_list_issues` → `github_get_issue` → comment/link |
| Review a PR | `gh_get_pull_request` + `gh_get_pr_diff` + checks | `github_get_pull_request` → status/checks → review |
| Merge a PR | `gh_merge_pull_request` (dry-run → confirm echo-back) | `github_get_pull_request_status` + checks → `github_merge_pull_request` |
| Create a PR | **PR skills** (`github-pr`/`branch-pr`/`chained-pr`) | — |
| Failed CI | `gh_list_workflow_runs` → `gh_get_workflow_run` → `gh_get_run_logs` | `github_list_workflow_runs` → `github_get_workflow_run` → `github_download_workflow_run_logs` |
| Delete a branch | `gh_delete_branch` / `git_delete_branch` (merged check) | `github_compare_commits` (merged?) → `github_delete_branch` |
| Trace a regression | `git_log` | `github_list_commits` → `github_get_commit` |

## Own-surface pitfalls (additional)

- **Do not mix surfaces.** Decide once per session (identity call → what works), then stay consistent.
- **Destructive echo-back is mandatory.** `confirmed=true` without the exact dry-run `data` echo-back never executes — and neither should you attempt to bypass it.
- **Unmappable writes are report-only.** No local tool can post a comment, write labels, or submit a review; never pretend an action happened that did not.