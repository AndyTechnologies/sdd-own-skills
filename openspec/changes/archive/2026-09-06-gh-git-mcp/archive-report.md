# Archive Report: gh-git-mcp

**Change**: `gh-git-mcp`
**Archived at**: 2026-09-06
**Archive location**: `openspec/changes/archive/2026-09-06-gh-git-mcp/`
**Store**: hybrid (OpenSpec filesystem + Engram `sdd/gh-git-mcp/archive-report`)
**Cycle status**: **CLOSED — PASS** (0 CRITICAL / 0 WARNING / 0 SUGGESTION at final verify)

## Executive Summary

The repo gained a **local, token-free GitHub + Git MCP server** (`srv/gh-mcp-server/`, Python + FastMCP + uv, stdio `type:local`) exposing 23 typed tools over the `gh` CLI and local `git` so agents stop invoking bash. The `github-automation` skill became a **dual-surface** playbook (own local surface by default, official GitHub MCP only for GHEC, honest coverage tables with report-only gaps), and `wiring/mcp.d/opencode.json` gained a multi-entry envelope registering `gh-git-mcp` alongside the existing remote `github` entry. Verified: 22/22 tasks, **11/11 requirements, 25/25 scenarios, verdict pass** (0 findings). Specs promoted to `openspec/specs/` (3 FULL deltas, additive over the prior `skills-mcp-setup` cycle).

## Change Summary

What shipped (final state):

- **`srv/gh-mcp-server/`** — complete MCP server project: `pyproject.toml` (FastMCP >= 2, requires-python >= 3.12, `uv` runner), `src/server.py` composition root with transport safety net, `src/executor.py` (SubprocessRunner behind `ExecutorProto` — single subprocess caller, DI), `src/dryrun.py` (Template Method `destructive_flow` + fingerprint + mergeability classifiers), `src/envelope.py` (typed envelopes `ok|err|confirm_required|auth_required|network_error|invalid_parameter`), `src/gh_auth.py` (per-call `gh auth status` gate), `src/tool_handlers/` (14 remote_read + 3 remote_mutation + 4 local_read + 2 local_mutation).
- **Safety contract** — destructive ops are two-phase: dry-run returns computed effect, caller echoes the **exact full object** (incl. `dry_run: True` marker), server re-derives + SHA-256 fingerprints, executes only on match; fail-closed gate refuses (`not_safe`) any effect whose `data["safe"] is not True`, including confirmed echoes. Mergeability uses gh's string enums (`MERGEABLE`/`CONFLICTING`/`UNKNOWN`→None). Subprocess errors become typed `network_error` envelopes. `git_delete_branch` merged-guard uses `git merge-base --is-ancestor <branch> HEAD`.
- **`wiring/mcp.d/opencode.json`** — multi-entry block: `github` (remote, `server_key` presence primary) + `gh-git-mcp` (type:local `uv run --directory <abspath> python src/server.py`, token-free). `wiring/mcp.d/README.md` documents multi-entry contract (additive per server, presence on `server_key`, `alt_docker` only for `github`).
- **`skills/github-automation/SKILL.md`** — dual-surface: runtime selection (own local default; official only GHEC; mid-task fallback on 403), workflow equivalents table (mapped / partial→report-only), quick-reference dual columns, 403 + echo-back pitfalls, "Failed CI" official column (`github_list_workflow_runs → github_get_workflow_run → github_download_workflow_run_logs`).
- **`.gitignore`** — `.venv/` added for the server project.

## Key Decisions

### Architecture decisions D1–D8 (design rev 1 + architecture-lint integrated)

| # | Decision summary |
|---|---|
| D1 | Local stdio server over `gh` CLI instead of the remote GitHub MCP (account `plan: None` → 403 on GHEC-only endpoint); gh owns auth, server never sees the token |
| D2 | Port-and-adapter layering: `ExecutorProto` DI so handlers never call subprocess directly; composition root builds the chain |
| D3 | Typed envelope contract for every tool: `{ok, data, summary, error}` + `confirm_required` / `auth_required` / `network_error` / `invalid_parameter` |
| D4 | Two-phase destructive flow with echo-back fingerprint (SHA-256 over sorted JSON of the **full** response object incl. `dry_run`) |
| D5 | Fail-closed mergeability: gh MergeableState strings normalized — only `MERGEABLE`→safe, `CONFLICTING`→False, anything else→None |
| D6 | Transport safety net in `server.py`: `SubprocessError`→`network_error`, unexpected→`invalid_parameter` — never re-raised to the framework |
| D7 | Wiring multi-entry: registered `gh-git-mcp` additively in an existing envelope without touching the personal opencode config; `server_key` presence gate stays on `github` |
| D8 | Skill dual-surface: honest coverage (report-only where no local equivalent exists: comments, labels, review endpoints) |

### Round-1 verify corrections (all resolved, re-proven in round 2)

1. CRITICAL A9 — fail-closed gate present: `safe is not True` → `err("not_safe")` before any execute, even with matching echo (smoke: 0 executions on unsafe effect).
2. Mergeability string enums fail-closed (`UNKNOWN`→None).
3. Echo-back fingerprint over the full response object — verbatim echo executes exactly once.
4. `SubprocessError`→typed `network_error` (proven against the real composition root).
5. `git_delete_branch` guard direction fixed (`merge-base --is-ancestor`), proven in scratch repo: unmerged→safe:False, merged→safe:True.
6. `git_commit` failure → typed `err("commit_failed", hint=…)`, no `ok:true`.
7. Skill: echo-back verbatim contract incl. `dry_run` marker; "Failed CI" official column corrected; mid-task re-evaluation on 403 documented.
8. `gh_search_code` cross-repo — accepted doc note, no code change.

## Verification (final)

| Metric | Value |
|--------|-------|
| Requirements | 11/11 |
| Scenarios | 25/25 |
| Smoke checks | 19/19 (runtime-smoke-r2.py) |
| Verdict | **pass** — 0 blockers, 0 findings |
| Evidence revision | sha256:705c40d85204b0640b0438db9f23d4bff66b1172d76f54f774999536bd123b88 |
| Build | `bash -n sync-skills.sh` exit 0 |

Evidence detail in `verify-report.md` (round-2 regenerated version, supersedes the round-1 FAIL header).

## Spec Promotion

Delta specs promoted additively to `openspec/specs/`:

- `openspec/specs/gh-git-mcp-server/spec.md`
- `openspec/specs/mcp-definitions/spec.md`
- `openspec/specs/github-automation-skill/spec.md`

No prior main-spec conflicts; existing specs from the `skills-mcp-setup` cycle untouched.

## Traceability

Engram observations read (all required topics, full content via `mem_get_observation`):

| Topic | Observation ID |
|---|---|
| `sdd/gh-git-mcp/quest` | (topic read) |
| `sdd/gh-git-mcp/apply-progress` | #381 |
| `sdd/gh-git-mcp/verify-report` | (round-1 #383, round-2 regenerated) |
| `sdd/gh-git-mcp/verify-fixes` | #385 |

Filesystem artifacts: `openspec/changes/archive/2026-09-06-gh-git-mcp/{quest,exploration,proposal,design,architecture-lint,tasks,apply-progress,verify-report}.md` + `specs/*/spec.md`.

## Risks / Open Items

- **Delivery pending (user-owned)**: nothing committed, nothing deployed. Real `./sync-skills.sh` + `./setup.sh` require explicit user authorization — only `--check` modes ran during the cycle (expected deltas only: 1 skill update + 1 MCP entry pending, 0 errors).
- **Ephemeral verify harness**: round-2 smoke lives at `/tmp/opencode/gh-git-mcp-verify-r2/runtime-smoke-r2.py` — evidence referenced in `verify-report.md`; do not depend on the path persisting.
- **Scratch-repo harness gotcha**: is-ancestor guard tests must checkout the base branch first (HEAD-on-target self-reports merged) — a test-harness note, not a code issue.

## Rules Applied

- Mechanical Copy Contract honored for spec promotion and the archive move (shell-only `cp`/`mv`, readback diff); no byte passed through model Read/Write where avoidable.
- No CRITICAL issues in verify → archive permitted.
- Archive is an audit trail: no archived artifact modified; `archive-report.md` is additive-only.
- `openspec/` convention respected: no git commits, no deploy, no sync.