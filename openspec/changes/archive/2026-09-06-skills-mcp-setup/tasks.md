# Tasks: skills-mcp-setup

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,600–1,900 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: size-exception
400-line budget risk: High

### Suggested Work Units (all → PR 1)

| Unit | Goal | Focused test | Harness | Rollback |
|------|------|--------------|---------|----------|
| 1 | 3 skills in `skills/` | provenance grep + `./sync-skills.sh --check` | N/A (content) | `rm -rf skills/{using-git-worktrees,test-fixing,github-automation}` |
| 2 | `wiring/mcp.d/` | `jq -e .runtime wiring/mcp.d/*.json` | N/A (declarative) | `rm -rf wiring/mcp.d/` |
| 3 | `setup.sh` | `bash -n setup.sh` + RED suite | `setup.sh --skip-mcp --check` | delete `setup.sh` |
| 4 | README + AGENTS.md | grep exception phrasing | N/A (docs) | git revert doc hunks |
| 5 | `tests/` RED suite | `bash tests/run_red_checks.sh` | fake `SDD_OWN_GH_API` | remove `tests/` |

## Phase 1: Skills

- [x] 1.1 Vendor `skills/using-git-worktrees/SKILL.md` from `obra/superpowers` (read-only; MIT Jesse Vincent): single file, suite frontmatter, minimal documented adaptation.
- [x] 1.2 Vendor+curate `skills/test-fixing/SKILL.md` from `mhattingpete/claude-skills-marketplace` (read-only; Apache-2.0): pytest/`uv run pytest` → stack-neutral (pytest as example), attribution kept.
- [x] 1.3 Reauthor `skills/github-automation/SKILL.md` fresh: automation/ops scope, official github-mcp-server only, `github_*` surface (no PR-create), disambiguates `github-pr`/`branch-pr`/`chained-pr`/`issue-creation`.
- [x] 1.4 RED: zero `Composio|rube|RUBE_|ghp_|github_pat_` in `skills/github-automation/`; no extra license files; `./sync-skills.sh --check` (read-only) exits 0.

## Phase 2: MCP Definitions (`wiring/mcp.d/`)

- [x] 2.1 `wiring/mcp.d/opencode.json`: json-key, `root_key: mcp`, wrapped remote block per design §Contracts (Bearer `{env:...}`, `oauth:false`), `alt_docker`.
- [x] 2.2 `wiring/mcp.d/pi.json`: target `~/.pi/agent/mcp.json`, `root_key: mcpServers`, `presence: command -v pi`, `bearerTokenEnv` block.
- [x] 2.3 `wiring/mcp.d/claude.json`: target `~/.claude.json`, `root_key: mcpServers`, `presence: command -v claude`, `${VAR}` header block (D11), never `-e`.
- [x] 2.4 `wiring/mcp.d/codex.json`: toml-section `[mcp_servers.github]`, bare `url` + `bearer_token_env_var`, `presence: command -v codex`.
- [x] 2.5 RED: json-key blocks wrapped, codex bare, `wiring/opencode.sdd.json` (read-only) no `mcp`, zero literal tokens.
- [x] 2.6 `wiring/mcp.d/README.md`: envelope schema, add-a-runtime, docker variant, env-file 0600 contract.

## Phase 3: setup.sh

- [x] 3.1 Executable `setup.sh`: parse flags (unknown/`--check`∧`--dry-run` → exit 1); forward sync subset only, never `--skip-mcp`/`--force-mcp-token`; `MCP_DEBUG_SYNC_ARGS` seam.
- [x] 3.2 Delegate `"$SCRIPT_DIR/sync-skills.sh" $SYNC_FLAGS`; MCP step only if sync exit ≤ 1 (D16); ≥2 → skip, propagate 2.
- [x] 3.3 D13: `curl` missing → exit 2 pre-delegation; `docker` missing only under `MCP_GITHUB_TRANSPORT=docker` → exit 2.
- [x] 3.4 5a presence (D15): `bash -c "$presence"`; opencode config detection; absent CLI → declared-skipped; installed + missing target → create `.bak`-less.
- [x] 3.5 5b gate: `[[ -t 0 ]]` guard; `read -rs` ≤3 tries; keep/replace on valid existing; `--force-mcp-token` re-prompts.
- [x] 3.6 5b validation F1: `curl -K` tmpfile (0600, `${GITHUB_PERSONAL_ACCESS_TOKEN}` header line, trap) on `$SDD_OWN_GH_API`; argv clean.
- [x] 3.7 Scopes: classic warns missing `repo`/`read:org`/`workflow` + change option; fine-grained → unverifiable; non-200 → ≤3 retries; network failure → clear fail, nothing persisted.
- [x] 3.8 5c persist: dir 0700, file 0600 tmp+mv+chmod+verify; rotation `cp -p` `.bak`, stale removed (D14/F5).
- [x] 3.9 5d json merge: jq `-s` → python3 fallback; `.bak` once; `[up-to-date]` idempotent; only `root_key`, never `wiring/opencode.sdd.json` (read-only).
- [x] 3.10 5d toml: `tomllib`+`tomli-w`; `tomli-w` absent → exit 2 before writes (D12).
- [x] 3.11 Report: sync markers + `Resumen:`; exit max(sync,mcp) 0/1/2; `--check` 0 clean/1 drift/2 structural; `--dry-run` plan-only.

## Phase 4: Documentation

- [x] 4.1 `README.md`: definitive setup (flags, env path, export line) + MCPs (mcp.d, add-a-runtime, docker), skills rows, provenance; F7 sanctioned exception.
- [x] 4.2 `AGENTS.md`: `setup.sh` sanctioned writer of `mcp` key + mcp.d convention; golden rules untouched.

## Phase 5: RED Test Suite (`tests/`)

- [x] 5.1 F1 argv: `ghp_REDTEST123` + fake API; `/proc/<pid>/cmdline` clean; config dump only `${VAR}`; tmpfile 0600, deleted.
- [x] 5.2 F2 presence: absent CLI → skip; missing target → created; re-run `[up-to-date]`.
- [x] 5.3 F3 toml: correct `[mcp_servers.github]`; re-run `[up-to-date]`; `tomli-w` absent → exit 2, target untouched.
- [x] 5.4 Idempotency: double run `[up-to-date]`, byte-identical, `mcp.github` count 1; codegraph/context7/engram preserved.
- [x] 5.5 `--check` 3-way: sync 2 → skip+2; 401 → 1; unroutable → 2; missing token → 0.
- [x] 5.6 Hygiene: grep token over output/logs/tmp → zero; env 0600; `.bak` 0600, stale removed.
- [x] 5.7 Non-mutation: `--check`/`--dry-run` tree+mtimes identical; keep → mtime unchanged; final `./sync-skills.sh --check` (read-only) exits 0.