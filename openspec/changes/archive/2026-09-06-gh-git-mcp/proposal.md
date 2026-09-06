# Proposal: gh-git-mcp

## Intent

Agents running `gh`/`git` via bash trigger auth prompts and parse failures. Ship a local FastMCP server with typed `gh_*`/`git_*` tools, adapt `github-automation` to drive it, and register via `wiring/mcp.d` + `setup.sh`.

## Scope

### In Scope
- `srv/gh-mcp-server/` — uv+fastmcp: 22 tools/4 families, typed envelope, computed dry-runs, fail-closed auth.
- `wiring/mcp.d/opencode.json` gains `gh-git-mcp` local entry (`github` remote untouched); lands in `opencode.jsonc` via setup.sh (zero changes).
- `skills/github-automation/SKILL.md` dual-surface adaptation (direct edit; workflows preserved).
- `.gitignore`, `wiring/mcp.d/README.md` multi-entry contract, spec deltas.

### Out of Scope
Official remote MCP replacement for eligible accounts; token handling in server; `mcp` keys in `wiring/opencode.sdd.json`; git-worktree/PR/issue/chained-PR skill rewrites.

## Capabilities

### New
- `gh-git-mcp-server`: server, 22-tool surface, safety contract, local registration.

### Modified
- `mcp-definitions`: multi-entry block rule (`server_key` = primary presence entry).
- `github-automation-skill`: dual-surface mapping + runtime-selection rule.

## Approach

In-repo FastMCP over stdio, explicit per-call repo. Reads single-phase; mutations two-phase with **computed** dry-runs (mergeability/check rollup; `compare/commits` merged-check). Subprocesses: prompt-disable env, 30 s timeout, inherited env, per-call `gh auth status`, typed fail-closed.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `srv/gh-mcp-server/` | New | FastMCP server (uv project) |
| `wiring/mcp.d/opencode.json` | Modified | + `gh-git-mcp` local entry |
| `opencode.jsonc` (runtime) | Modified | merged entry via setup.sh |
| `skills/github-automation/SKILL.md` | Modified | dual-surface mapping + runtime rule |
| `wiring/mcp.d/README.md`, `.gitignore` | Modified | multi-entry contract; `.venv/` |
| `openspec/specs/{mcp-definitions,github-automation-skill}/` | Modified | deltas at archive |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Multi-entry envelope stretches 1:1 contract | Low | Doc+spec delta in this change; fallback separate file |
| Computed dry-runs drift from gh | Low | Validated vs 2.98; fail closed on unknown state |
| Subprocess hang over stdio | Med | Prompt-disable env + hard timeout; smoke test in verify |
| `gh` version drift | Low | Additive only; server wraps subprocesses |

## Rollback Plan

1. `git checkout` skill, envelope, README, `.gitignore`, spec deltas. Re-run `setup.sh` real mode to remove `gh-git-mcp` from `opencode.jsonc` (`.bak` exists). Delete `srv/gh-mcp-server/`.
2. Fallback: strip key from `opencode.jsonc` by hand; `./sync-skills.sh --check` confirms baseline.

## Dependencies

gh 2.98 authed; git 2.55; Python 3.14 + uv + fastmcp>=2 (proven via pdf-reader). setup.sh + `tests/run_red_checks.sh` unchanged.

## Success Criteria

- [ ] `tools/list` with 22 tools, no token env.
- [ ] Reads return typed envelope + summary (explicit repo).
- [ ] Mutations: dry-run default → confirm required → one mutation on confirm.
- [ ] Unauth → typed `auth_required`; nothing mutates.
- [ ] Skill dual-surface documented; official path works for eligible accounts.
- [ ] `./setup.sh --check` / `./sync-skills.sh --check` zero desyncs.