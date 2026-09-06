# Exploration: gh-git-mcp

Validates the approved RFC (`openspec/changes/gh-git-mcp/quest.md`, Approval: approved) against the real repo and environment. Read-only pass — no code written, no repo files modified beyond this artifact.

## Current State

- This is a config/infra repo: `sync-skills.sh` (skills/overlays/wiring pipeline), `setup.sh` (skills sync + MCP registration + GitHub token), `wiring/opencode.sdd.json` (SDD agent fragment, agent-only), `wiring/mcp.d/` (declarative per-runtime MCP blocks).
- The official remote GitHub MCP (`https://api.githubcopilot.com/mcp/`) is registered in `~/.config/opencode/opencode.jsonc` via `wiring/mcp.d/opencode.json` and **fails with 403** (account `plan: None` — no GHEC/Copilot eligibility). Verified live: `opencode mcp list` shows `github failed — SSE error: Non-200 status code (403)`.
- **opencode loads BOTH global config files**: verified with `opencode mcp list` — 6 servers total, merged from `opencode.jsonc` (codegraph, context7, engram, github) and `opencode.json` (context7, donsetch, engram, pdf-reader). `setup.sh`'s `resolve_opencode_config` targets `opencode.jsonc` (via `OPENCODE_CONFIG` → jsonc → json), so pipeline-registered servers land in jsonc, which loads and merges for the runtime. `opencode.json` is not touched by the pipeline (pdf-reader there was registered manually — unchanged by this change).
- Deployment precedent: `mcp_pdf_reader` (home of `pdf-reader`: `type: local`, `command: ["/usr/sbin/uv", "run", "--directory", "/home/andy/Proyectos/mcp_pdf_reader", "python", "src/server.py"]`; fastmcp **2.8.1** locked in `uv.lock`, `requires-python >=3.12`; environment has Python 3.14.7 + uv 0.12.7; pdf-reader currently connected, proving fastmcp works on this Python).
- `gh` CLI 2.98.0 authed as `AndyTechnologies` (token lives in `~/.config/gh/hosts.yml` — the server never reads it). `git` 2.55.0 available.
- `github-automation` skill is **our exclusive skill** (canonical `skills/github-automation/SKILL.md`, author AndyTechnologies; no overlay — `overlays/skills/` only holds sdd-* phases). Direct edit of the canonical file, no block markers needed.

## Affected Areas

- `srv/gh-mcp-server/` (NEW uv project) — the FastMCP server; mirrors mcp_pdf_reader layout (`pyproject.toml`, `src/server.py`, README, `uv.lock`).
- `wiring/mcp.d/opencode.json` — the envelope whose `block` gains the `gh-git-mcp` local server entry (or a new envelope file, see Approaches).
- `~/.config/opencode/opencode.jsonc` (runtime, via `setup.sh` real mode) — receives the merged `gh-git-mcp` entry in its `mcp` block.
- `skills/github-automation/SKILL.md` — adapted to dual-surface (own `gh_*`/`git_*` tools + official `github_*` for eligible accounts).
- `openspec/specs/mcp-definitions/spec.md` — delta for the new local-server block contract.
- `wiring/mcp.d/README.md` — document multi-server block rule (if extending the opencode envelope).
- `.gitignore` — add `.venv/` (and any uv artifacts) for the nested uv project.
- `README.md`, `docs/` (optional) — document the new server + adaptation.

## Impact

Regressive impact of this change:

- **`wiring/mcp.d/opencode.json`**: additive (new server key inside `block`; the `github` remote entry is untouched byte-for-byte). The merge is a deep additive merge (`target[mcp] * block` via jq `-s` or python3 fallback) — verified in `setup.sh` `merge_json_key`. No regression to the github remote, codegraph, context7, engram.
- **`~/.config/opencode/opencode.jsonc`**: `setup.sh` real mode adds the `gh-git-mcp` entry; existing servers preserved (verified merge semantics + current `git`-tracked state of the file being a merge output with `.bak`). No regression risk.
- **`skills/github-automation/SKILL.md`**: MODIFIED. The existing automation workflows (issue triage order list→read→act; PR status/checks-before-merge; branch deletion merged-guards; actions log-evidence) and the `github_*` names for eligible accounts MUST be preserved -- the skill is the behavioral contract for a path that must keep working. Regression risk: LOW if the adaptation only adds a dual-surface mapping table + runtime selection rule and does not rewrite the workflows.
- **`srv/` subproject**: greenfield. Verified `sync-skills.sh` only iterates `skills/`, `overlays/`, `wiring/prompts/sdd`, `wiring/opencode.sdd.json` — a new top-level `srv/` dir cannot collide with the sync pipeline. `.gitignore` additions are additive.
- **Regression net**: `./setup.sh --check` / `./sync-skills.sh --check` must stay zero-desync (AC 8); `tests/run_red_checks.sh` (RED regression suite for setup.sh) must keep passing. Note: before a real-mode apply, `--check` legitimately reports the new entry as `[pendiente]`/`[aviso]` (expected, not a desync); after apply it reports `[up-to-date]`.
- `openspec` main specs: `mcp-definitions` delta is additive (new local-server requirement).

## Approaches

### 1. Server placement

1. **In-repo subproject `srv/gh-mcp-server/`** (recommended)
   - Pros: single repo; the change (skill adaptation + wiring + registration + server) lands coherently under one SDD change; sync pipeline provably ignores `srv/`; versioned together with the skill that drives it.
   - Cons: mixed-content repo (config/infra + Python app); needs `.gitignore` additions (`.venv/`).
   - Effort: Low.

2. **Sibling standalone repo** (mirror mcp_pdf_reader at `/home/andy/Proyectos/gh-git-mcp`)
   - Pros: exactly mirrors mcp_pdf_reader; independent uv project lifecycle.
   - Cons: SDD change forks across two repos (skill + wiring here, server elsewhere); absolute-path registration still machine-specific any way; harder to archive/verify atomically.
   - Effort: Medium.

**Recommendation: option 1** — the RFC's "mirror mcp_pdf_reader pattern" refers to the *deployment* pattern (`uv run --directory <path> python src/server.py`), which in-repo satisfies identically. Register with the absolute repo path (precedent: pdf-reader's absolute path in `opencode.json`).

### 2. Registration in `wiring/mcp.d/`

1. **Extend `wiring/mcp.d/opencode.json` block to hold both `github` (remote) and `gh-git-mcp` (local)** (recommended)
   - Pros: one envelope per config target (matches `mcp-definitions` "one declarative file per supported runtime"); the existing `server_key: "github"` keeps acting as the presence gate; no new file; setup.sh needs zero changes (glob discovery + `merge_json_key` handle multi-entry blocks natively -- `target[mcp] * block` is a whole-object merge).
   - Cons: the documented F6 wrapping rule ("block envuelto bajo `server_key`") is 1:1; a multi-entry block stretches it. Fix: update `wiring/mcp.d/README.md` contract table (+ spec delta) to permit multi-entry blocks where `server_key` names the primary entry used for presence checks. Check-mode pending semantics key off `github`, so a pre-apply `--check` reports pendiente for the new entry (expected, not a desync).
   - Effort: Low.

2. **New envelope file `wiring/mcp.d/opencode-local.json`** (runtime id `opencode-local`, `server_key: "gh-git-mcp"`)
   - Pros: keeps the 1:1 envelope contract and clean per-server presence checks.
   - Cons: two envelopes resolving the same config target (contract says runtime id matches filename; "one file per runtime" stretched in the other direction); both process in 5d; more moving parts.
   - Effort: Low.

**Recommendation: option 1** (documented multi-entry block, primary `server_key`). Design phase must update the mcp.d README contract table + mcp-definitions spec accordingly.

### 3. Tool surface (see Surface Design below)

Single recommended surface: 22 tools in 4 families (remote read / remote mutation / local read / local mutation), mapping 1:1 to `gh`/`git` subcommands with `--json` where supported. No real alternatives — the scope is fixed by the RFC; the only open micro-decisions are per-tool (e.g. whether `git_commit` is single-shot vs confirmed; whether to add `gh_get_pr_diff`/`git_log` as scope-adjacent reads that materially help agents — recommended: yes, additive reads are non-destructive).

### 4. Skill adaptation

Single approach: direct edit of the canonical `skills/github-automation/SKILL.md` (exclusive skill, full-install — no overlay, no block markers). Add: (a) a runtime-selection rule (own server when the official remote is 403/unavailable; official `github_*` unchanged for eligible accounts); (b) a dual-surface mapping table (`github_*` family → `gh_*`/`git_*` equivalents); (c) a note in the tool-surface section that the own server's tool list is stable (unlike the official server's constantly-renamed surface) but still verify via `tools/list`. Preserve every workflow section verbatim.

## Surface Design (enumerated, validated against gh 2.98)

All tools take explicit repo: `owner`+`repo` (−R owner/repo) or `path` (git −C). Read tools: single-phase, idempotent. Mutations: two-phase (dry-run default → `confirmed: true` required; confirmed-without-dry-run re-runs the dry-run internally and still requires the follow-up confirm — RFC invariant).

Remote reads (`gh_*`, single-phase):

| Tool | Command mapping |
|---|---|
| `gh_get_me` | `gh api user` (auth + identity probe) |
| `gh_get_repo` | `gh repo view owner/repo --json ...` |
| `gh_list_repositories` | `gh repo list owner --json --limit N` |
| `gh_list_issues` | `gh issue list -R owner/repo --json ...` |
| `gh_get_issue` | `gh issue view -R owner/repo N --json ...` |
| `gh_list_pull_requests` | `gh pr list -R owner/repo --json ...` |
| `gh_get_pull_request` | `gh pr view -R owner/repo N --json ...` |
| `gh_get_pr_checks` | `gh pr view -R owner/repo N --json statusCheckRollup,mergeStateStatus (...)` |
| `gh_get_pr_diff` | `gh pr diff -R owner/repo N` (wrapped text, not raw passthrough) |
| `gh_list_commits` | `gh api repos/owner/repo/commits?per_page=N` |
| `gh_list_workflow_runs` | `gh run list -R owner/repo --json ... --limit N` |
| `gh_get_workflow_run` | `gh run view -R owner/repo RUN_ID --json ...` |
| `gh_get_run_logs` | `gh run view -R owner/repo RUN_ID --log{,-failed}` |
| `gh_search_code` | `gh api search/code?q=...` (documented rate-limit cost) |

Remote mutations (`gh_*`, two-phase): **verified constraint: `gh pr merge` has NO `--dry-run` flag in 2.98, and there is NO `gh branch` command in 2.98** — dry-runs must be computed, not delegated.

| Tool | Command mapping | Dry-run computation |
|---|---|---|
| `gh_merge_pull_request` | `gh pr merge -R owner/repo N --squash\|--merge\|--rebase [--delete-branch] [--auto]` | PR state + mergeable + check rollup + merge method suggestion (returns the would-be effect, mutates nothing) |
| `gh_delete_branch` | `gh api -X DELETE repos/owner/repo/git/refs/heads/{branch}` | merged-check via compare commits (default..branch), protects unmerged work |
| `gh_rerun_workflow` | `gh run rerun -R owner/repo RUN_ID [--failed]` | run status/result report (failed jobs list for `--failed`) |

Local reads (`git_*`, single-phase, explicit `path`):

| Tool | Command mapping |
|---|---|
| `git_status` | `git -C path status --porcelain=v1 -b` (branch + porcelain summary) |
| `git_diff` | `git -C path diff [--staged] [--stat\|full]` |
| `git_log` | `git -C path log --oneline -n N` (commit context for `git_commit`) |
| `git_branch` | `git -C path branch -vv` (list); create/switch via `git switch -c` (non-destructive) |

Local mutations (`git_*`):

| Tool | Command mapping | Phase |
|---|---|---|
| `git_commit` | `git -C path add -A && git commit -m msg` | single-shot (non-destructive per RFC classification: plain commit, not reset/force; dry-run shows staged summary) |
| `git_delete_branch` | `git -C path branch -d name` (merged-guard; `-D` only after explicit confirm) | two-phase (dry-run = `git branch --merged` check) |

Process/env hygiene for every subprocess (fail-closed core): `GH_PROMPT_DISABLED=1` + `--nocolor` (gh never blocks on an interactive prompt over stdio), `GIT_TERMINAL_PROMPT=0` (git never prompts for credentials), hard subprocess timeout (~30 s), subprocess env is inherited-unmodified (the server never sets/reads `GH_TOKEN`/`GITHUB_TOKEN` — auth is `gh`'s own `hosts.yml`). Every remote tool starts with `gh auth status --exit-code` (fail-closed `auth_required` with `gh auth login` fix hint; per-call check is ~20–50 ms and satisfies the RFC's "every remote tool" wording).

## FastMCP pattern (validated)

- SDK: **fastmcp** — correct choice; mcp_pdf_reader locks **2.8.1** and the env runs it on Python 3.14.7 (pdf-reader shows `connected`). Pin `fastmcp>=2` in the new pyproject (2.8.x line).
- Entry: `from fastmcp import FastMCP; mcp = FastMCP("gh-git-mcp"); @mcp.tool(); ...; mcp.run()` — default stdio transport; `type: local` command `uv run --directory <repo>/srv/gh-mcp-server python src/server.py` reproduces the pdf-reader shape exactly.
- Error pattern (fail-closed): every tool returns the RFC envelope `{"ok": bool, "data": <json>|null, "summary": str, "error": null | {"type": "<typed>", "message": str}}` — never raises mid-mutation, never returns partial state; typed errors: `auth_required`, `repo_not_found`, `network_error`, `not_found`, `not_a_repo`, `dirty_worktree`, `confirm_required`, `invalid_parameter`. Exception→typed-envelope wrapper around each tool body.
- Dry-run/confirm state: in-memory per process (dry-run result token or re-computation; no cross-session persistence needed — server is stateless otherwise).

## Recommendation

Build the server **in-repo at `srv/gh-mcp-server/`** (uv + fastmcp 2.x, final `src/server.py`, exact mcp_pdf_reader shape), register it by **extending the `wiring/mcp.d/opencode.json` block** (github remote untouched, new `gh-git-mcp` local entry; update mcp.d README + mcp-definitions spec for the multi-entry block rule), adapt **`skills/github-automation/SKILL.md`** by direct edit (dual-surface mapping table + runtime-selection rule, workflows preserved verbatim), add `.venv/` to `.gitignore`, and land the whole change (server + wiring + skill + docs + spec delta) in one SDD change. The RFC is fully implementable as-is; zero blocking unknowns.

## Risks

- **Envelope contract stretch (low)**: multi-entry block in `wiring/mcp.d/opencode.json` deviates from the documented 1:1 `server_key` wrap (F6). Mitigation: consent-based doc+spec update in the same change. Fallback: separate envelope file (Approach 2.2).
- **Config dual-file loading (low, verified)**: new entry lands in `opencode.jsonc` (setup.sh target) while pdf-reader lives in `opencode.json` — both load and merge (verified `opencode mcp list` = 6 servers). If a future opencode version stops merging both files, the local entry would still load (jsonc is the primary file). No action needed now.
- **Computed dry-runs (low)**: `gh pr merge` lacks `--dry-run`; `gh branch` doesn't exist in 2.98. Dry-run for merge/delete must be computed (PR mergeability/checks; compare-commits merged-check). Slightly more code, same safety contract. Verified against the installed 2.98.0 binary.
- **Subprocess hangs (medium)**: an interactive `gh`/`git` prompt over stdio would hang the server. Mandatory `GH_PROMPT_DISABLED=1` / `GIT_TERMINAL_PROMPT=0` + hard timeout; covered by design, must be tested in verify.
- **Verify coverage (medium)**: repo has no test runner (`build_command: bash -n sync-skills.sh`); the server's own behavior (dry-run/confirm, typed errors, auth fail-closed) needs a runtime smoke test in verify (e.g. `uv run python src/server.py` + MCP tools/list probe; `opencode mcp list` shows the new server connected). No `pytest` suite is mandated by the ACs, but a small dev-extra test suite is a cheap addition if the change wants it (optional).
- **`gh` version drift (low)**: tool mapping was validated against 2.98.0; future `gh` changes (e.g. `gh branch` arriving) are additive, not breaking — server wraps subprocesses, not the CLI surface.

## Ready for Proposal

**Yes** — the approved RFC is fully implementable in this repo with no blocking unknowns. Tell the user: the server lands in-repo (`srv/gh-mcp-server/`, uv+fastmcp, mirroring mcp_pdf_reader), registration goes through the sanctioned `wiring/mcp.d` + `setup.sh` pipeline into `opencode.jsonc`, and the `github-automation` skill is adapted by direct edit (exclusive skill). The only design decision to confirm at propose/design: multi-entry block in the opencode envelope vs. a separate envelope file (recommended: multi-entry).