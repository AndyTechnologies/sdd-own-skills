# Proposal: skills-mcp-setup

## Intent

Definitive setup: 3 curated skills + `setup.sh` orchestrating sync-skills.sh + per-runtime GitHub MCP install (PAT in a 0600 env file).

## Scope

### In Scope
- `skills/using-git-worktrees/`, `skills/test-fixing/`: curated; sync-deployed; in registry.
- `skills/github-automation/`: reauthored (no upstream file); automation/ops scope.
- `wiring/mcp.d/`: declarative per-runtime MCP definitions (opencode, claude, pi, codex).
- `setup.sh`: flags `--check --dry-run --skip-gentleai-sync --skip-opencode --skip-mcp --force-mcp-token --registries`; sync-style merges (jq/python3, `.bak`, exit 0/1/2, non-mutating).
- `README.md` + helper scripts.

### Out of Scope
- `wiring/opencode.sdd.json` never gains `mcp`; sync internals (reuse only); existing skills; MCPs beyond GitHub; Composio; owner-match; scope blocking.

## Capabilities

### New Capabilities
- `github-mcp-setup`: token validation (GET /user, ≤3 tries, keep-vs-replace), 0600 env file, per-runtime install.
- `github-automation-skill`: official github-mcp-server tooling; no Composio/tokens.
- `git-worktrees-skill` / `test-fixing-skill`: curated content.
- `mcp-definitions`: per-runtime block contract in `wiring/mcp.d/`.

### Modified Capabilities
None — no `openspec/specs/` yet; all net-new.

## Approach

- **Transport (RFC "or chosen transport" correction)**: remote hosted `https://api.githubcopilot.com/mcp/` PRIMARY (official, zero deps, PAT Bearer everywhere): OpenCode `{type:remote,url,headers:{Authorization: Bearer {env:GITHUB_PERSONAL_ACCESS_TOKEN}},oauth:false}` (jsonc wins); Pi `bearerTokenEnv`; Codex `bearer_token_env_var`. Docker `ghcr.io/github/github-mcp-server` alternative (offline, `--env-file`).
- **Secret**: single 0600 env file (`~/.config/sdd-own/github-mcp.env`, exact path in design), `GITHUB_PERSONAL_ACCESS_TOKEN`; per-runtime indirection; never literal in config/repo.
- **Runtimes**: opencode → `opencode.jsonc` `mcp`; pi → global `~/.pi/agent/mcp.json` (repo `.pi/mcp.json` collides with gentle-ai state); claude/codex declared-but-skipped.
- **Validation precedes writes**: GET api.github.com/user → 200; existing valid → keep-vs-replace; scopes warn (`x-oauth-scopes` classic-only; fine-grained unverifiable); offline → nothing persisted.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `skills/{using-git-worktrees,test-fixing,github-automation}/` | New | 3 curated/reauthored skills |
| `wiring/mcp.d/`, `setup.sh` | New | MCP definitions + wrapper |
| `README.md` | Modified | setup docs, conventions |
| `opencode.jsonc` `mcp`; `~/.pi/agent/mcp.json` | Modified | additive blocks, `.bak` |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Dual/live opencode config merges | Med | idempotent, `.bak`, `--check` drift |
| Trigger collision with github-pr/branch-pr/chained-pr/issue-creation | Med | automation/ops scope |
| Fresh authorship, no upstream license | Med | README attribution |
| claude/codex absent | High | declared-but-skipped |
| Token leakage | Low | env-only, never argv/logs |

## Rollback Plan

`--check`/`--dry-run` precede writes; restore `.bak` or remove `mcp` blocks; delete env file + new skill dirs; SDD fragment untouched.

## Dependencies

Network to api.github.com + api.githubcopilot.com; Docker (alternative); jq/python3 (via sync).

## Success Criteria

- [ ] RFC AC 1–8 with AC3/AC7 on remote-hosted transport; deprecated npm unreferenced.
- [ ] `--check`/`--dry-run` non-mutating with correct report (skills synced, MCP configured-or-absent, token valid-or-missing).
- [ ] Invalid token → nothing persisted, ≤3 re-prompts; existing valid → keep-vs-replace.
- [ ] Token only in 0600 env; all blocks indirect. `./sync-skills.sh --check` zero desyncs.