# Exploration: skills-mcp-setup

Change: `skills-mcp-setup` · Phase: explore (post-quest validation) · Hybrid store (OpenSpec + Engram)

## Current State

- The repo is the canonical source of the user's SDD personalization over gentle-ai. `sync-skills.sh` (825 lines) installs exclusive skills from `skills/`, appends overlay blocks (`<!-- sdd-own:<id>:start/end -->`), merges the SDD fragment `wiring/opencode.sdd.json` (keys: `$schema`, `agent`, `default_agent` — **no `mcp`**) onto the real opencode config (`OPENCODE_CONFIG` override → `opencode.jsonc` → `opencode.json`; jq `-s` merge with python3 deep_merge fallback, `.bak` backup, exit 0/1/2, `--check`/`--dry-run` never mutate).
- Runtime configs as-is on this machine:
  - OpenCode: `~/.config/opencode/opencode.jsonc` (codegraph/context7/engram, v1 shape `command/type/enabled/url`, no `environment` yet) + `opencode.json` (context7/donsetch/engram/pdf-reader). **Source-confirmed** (opencode `config.ts:272-274`): opencode loads `config.json` → `opencode.json` → `opencode.jsonc` and merges; `.jsonc` wins on conflicts. Both files are active (session MCP list is the union).
  - Claude Code: `~/.claude.json` exists with `mcpServers` (codegraph stdio) but the **`claude` CLI is NOT installed** (no binary, no npm global). `~/.claude/` is a directory of skills/commands/prompts symlinked by sync.
  - Pi: installed (0.84.4) with **`pi-mcp-adapter` 2.32.1** (npm, local to `~/.pi/npm`); real config `~/.pi/agent/mcp.json` (verified, working) uses minimal schema `mcpServers: {name: {command, args, directTools?, lifecycle?}}` with codegraph/context7/engram/pdf-reader. Adapter config source order: `~/.config/mcp/mcp.json` → `~/.agents/mcp.json` → `~/.agents/mcp/mcp.json` → `<pi agent dir>/mcp.json` (`~/.pi/agent/mcp.json`) → `.mcp.json`; `.pi/mcp.json` is the highest-precedence Pi project layer. Adapter supports `env`, `literalEnv`, `bearerTokenEnv` (env-var indirection), `headers`, `auth`/`oauth`, `httpTransport`, `disabled`; built-in catalog already includes the GitHub remote server (OAuth).
  - Codex: **NOT installed** (`~/.codex` missing, no binary). Target format known (see below).
- Skills: 15 dirs under `skills/`; **no skill named `github-automation`** (name free). GitHub-trigger overlap exists: `github-pr` (project, vendered), `branch-pr`, `chained-pr`, `issue-creation` (user-level). Registry `.atl/skill-registry.md` is regenerated via `gentle-ai skill-registry refresh --force`.
- `.gitignore` = `.atl/` + `.pi/`; `openspec/` **not** ignored (currently untracked). `.pi/` at repo root holds gentle-ai local state (gitignored).

## Affected Areas

- `skills/using-git-worktrees/`, `skills/test-fixing/`, `skills/github-automation/` — new skills (curated/reauthored), deployed by sync step 1.
- `wiring/mcp.d/` — (new) declarative per-runtime MCP definitions; `wiring/opencode.sdd.json` stays untouched (never gains `mcp` — RFC non-goal).
- `setup.sh` — (new) wrapper orchestrating `sync-skills.sh` + MCP install with flags `--check`, `--dry-run`, `--skip-gentleai-sync`, `--skip-opencode`, `--skip-mcp`, `--force-mcp-token`, `--registries`.
- Runtime configs (edited additively only): `~/.config/opencode/opencode.jsonc` `mcp` block; `~/.pi/agent/mcp.json` (Pi global); `~/.claude.json` / `~/.codex/config.toml` (declared but skipped while runtimes are absent).
- `README.md`, `.atl/skill-registry.md` — documentation + registry regeneration.

## Impact

Additive change; no existing behavior is removed. Regressive risks to manage:

- `sync-skills.sh --check` must still report zero desyncs (RFC AC 8) — setup.sh never alters sync's own artifacts.
- `opencode.jsonc` and `~/.pi/agent/mcp.json` are live configs; merges must be additive (existing servers preserved), idempotent, `.bak`-backed, and non-mutating under `--check`/`--dry-run`. Regression net: `--check` runs before any write; `.bak` restores.
- AGENTS.md golden rule "never edit `~/.config/opencode` directly" collides with setup.sh writing the opencode `mcp` block; resolved by making the MCP merge mirror sync's exact mechanics (jq/python3 additive merge, `.bak`, no key outside `mcp`), documented as the sanctioned exception.
- Skill-trigger overlap with `github-pr`/`branch-pr`/`chained-pr`/`issue-creation`: `github-automation` description must scope itself to automation/ops to avoid resolver ambiguity.

## Findings (verified facts)

### 1. Composio skill sources

- **`using-git-worktrees`**: NOT in ComposioHQ/awesome-claude-skills. Lives at `obra/superpowers` → `skills/using-git-worktrees/` (single `SKILL.md`, 6813 B, frontmatter name+description only). License: **MIT** (Copyright 2025 Jesse Vincent).
- **`test-fixing`**: NOT in ComposioHQ. Lives at `mhattingpete/claude-skills-marketplace` → `engineering-workflow-plugin/skills/test-fixing/` (single `SKILL.md`, 2965 B). License: **Apache-2.0** (marketplace repo). Content is pytest/`uv run pytest`-oriented → needs curation to repo conventions.
- **`github-automation`**: referenced in ComposioHQ/awesome-claude-skills README (`./github-automation/`) and `composio-skills/.claude-plugin/marketplace.json` (`source: "./github-automation"`), but the directory **is absent from master** (blobless-clone grep: zero paths; HTTP 404 for github-automation and sibling automations). The family pattern is documented from `composio-skills/ably-automation/SKILL.md` (833 service dirs): frontmatter `requires: {mcp: [rube]}`, Prerequisites (`RUBE_SEARCH_TOOLS`, `RUBE_MANAGE_CONNECTIONS`, `https://rube.app/mcp`, no API keys), setup → tool discovery → connection management → workflows → tool slugs → known pitfalls → quick-reference. **The skill must be reauthored from the README/marketplace description + this family skeleton, targeting official `github-mcp-server` tools — no upstream file to vendor.**
- Licensing: awesome-claude-skills has no root LICENSE (badge claims Apache-2.0; some root dirs carry Apache LICENSE.txt); `composio-skills/*` have no per-skill license → treat github-automation as a fresh reauthoring (structure inspiration only), attribute via README.

### 2. Official github-mcp-server

- `@modelcontextprotocol/server-github` npm package: **deprecated** (2025-04-08, "Package no longer supported"). `@github/github-mcp-server`: **does not exist** on npm (registry 404). RFC contract line (External: "npx `@modelcontextprotocol/server-github` or chosen transport") → **correction**: install via Docker image `ghcr.io/github/github-mcp-server` (recommended, official), release binary (`github-mcp-server stdio`), or `go build` (Go 1.24+). The RFC's "or chosen transport" escape hatch keeps it implementable.
- Remote hosted server: `https://api.githubcopilot.com/mcp/` (+ `/readonly`, `/insiders`, `/x/{toolset}`; `X-MCP-Toolsets`/`X-MCP-Readonly` headers); PAT via `Authorization: Bearer` header.
- Server env vars: `GITHUB_PERSONAL_ACCESS_TOKEN` (takes precedence over OAuth; RFC line 24 confirmed), `GITHUB_HOST` (GHES/ghe.com), `GITHUB_TOOLSETS`/`GITHUB_TOOLS`, `GITHUB_READ_ONLY`, `GITHUB_LOCKDOWN_MODE`, `GITHUB_INSIDERS`. Shell/`.env` examples conventionally name the var `GITHUB_PAT`.
- Minimal scopes: `repo` (required, read-write tools use `scopes.RequireAll(scopes.Repo)`), add `workflow`, `read:org`, `project`, `gist` on demand. Fine-grained tokens expose no `x-oauth-scopes` header (RFC rule confirmed).
- Tool volume is large → context-window risk; limit via toolsets or per-agent tool gating.

### 3. Per-runtime MCP config (verified)

| Runtime | Location | Shape | Secret mechanism |
|---|---|---|---|
| OpenCode | `~/.config/opencode/opencode.jsonc` `mcp` (jsonc wins over json) | `{type:local, command:[...], environment:{}}` / `{type:remote, url, headers, oauth:false}` | **no envFile**; `{env:VAR}` interpolation; official guide: `Authorization: Bearer {env:GITHUB_PERSONAL_ACCESS_TOKEN}` + `oauth:false` (OpenCode remote = PAT only, no OAuth). Key is `environment`, not `env`. |
| Claude Code | `~/.claude.json` `mcpServers` (user) | `{type:http, url, headers}` or `{command, args, env}` | `claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=...`; runtime absent → skip with notice |
| Pi | `~/.pi/agent/mcp.json` (global; `.pi/mcp.json` project override) | verified minimal `mcpServers: {name:{command,args,directTools?,lifecycle?}}`; adapter adds `env`, `bearerTokenEnv`, `headers`, `auth/oauth`, `transport`, `disabled` | `bearerTokenEnv` (env-var name) for URL servers; or stdio `docker ... --env-file` |
| Codex | `~/.codex/config.toml` `[mcp_servers.github]` | remote: `url` + `bearer_token_env_var = "GITHUB_PAT_TOKEN"` (official pattern); local: `command`/`args`/`env` | native env-var indirection; runtime absent → skip with notice |

### 4. Repo/sync mechanics

- `sync-skills.sh` target detection: `OPENCODE_CONFIG` → `.jsonc` → `.json`; merge touches only `agent`/`default_agent`/`$schema`; `--check` exits 1 on desyncs, `--dry-run` no-mutation; no `--skip-mcp` flag, no MCP handling — setup.sh adds that.
- `wiring/` currently holds only `opencode.sdd.json` → natural home for declarative MCP definitions: **`wiring/mcp.d/`** (per-runtime JSON/TOML blocks), which keeps the SDD fragment clean per AGENTS.md.
- Runtimes present on this machine: opencode, pi (with adapter). Absent: claude CLI, codex → skip-with-notice paths (RFC edge case).

## Approaches

1. **MCP definitions location** — `wiring/mcp.d/` per-runtime declarative files vs `.setup/mcp.d/` hidden dir vs inline in setup.sh.
   - Pros (wiring/mcp.d/): visible next to the wiring contract, versioned, renderable per runtime, keeps fragment untouched, matches "Declarative definitions in the repo" (RFC goal).
   - Cons: new convention must be documented in README.
   - Effort: Low. **Recommended.**
2. **GitHub server install transport** — Remote hosted (`api.githubcopilot.com/mcp`, official "recommended" for OpenCode) vs local Docker (ghcr.io image) vs release binary.
   - Pros (remote): zero local deps, official, PAT via header/bearer on every runtime; consistent across all 4 targets.
   - Cons: requires network at runtime; OAuth unavailable where noted (OpenCode/Claude/Pi remote = PAT only — fine, RFC is PAT-only).
   - Pros (local docker): offline-capable after pull, OAuth-in-memory option, `--env-file` fits the "blocks reference env file" invariant.
   - Effort: Low (remote) / Med (docker). **Recommended: remote as primary, local docker documented as alternative transport.**
3. **Secret referencing** — token stored once in a 0600 env file (home-private, never in repo/config), each runtime block references it indirectly: OpenCode `{env:GITHUB_PERSONAL_ACCESS_TOKEN}` (exported by setup.sh for its process env), Pi `bearerTokenEnv`, Codex `bearer_token_env_var`, Claude `-e`; docker variant uses `--env-file`.
   - Satisfies RFC invariant "MCP blocks reference the env file, never literal values" per-runtime without a single cross-runtime envFile feature.
   - Effort: Low. **Recommended.** Canonical var name in the env file: `GITHUB_PERSONAL_ACCESS_TOKEN` (server-native; `GITHUB_PAT` reserved as the shell alias).

## Recommendation

Proceed to `sdd-propose`. The RFC is implementable as-is with one contract correction: replace the deprecated npm transport reference with Docker/binary/remote-hosted (the "or chosen transport" alternative in the RFC). Design defaults: `wiring/mcp.d/` declarative definitions; remote hosted server as primary transport; single 0600 env file with per-runtime env-var indirection; opencode targets `opencode.jsonc` (wins on merge); Pi targets global `~/.pi/agent/mcp.json` (avoid repo `.pi/mcp.json` collision with gentle-ai state); claude/codex blocks declared but skipped while runtimes are absent; MCP merge reuses sync's additive jq/python3 + `.bak` + `--check`/`--dry-run` mechanics.

## Risks

- RFC text names a deprecated npm package (contracts/External) — propose must pick docker/binary/remote (allowed by "or chosen transport").
- `github-automation` has no upstream source → reauthoring required; composio-skills carry no license files → fresh authorship, no vendoring.
- Trigger overlap with `github-pr`/`branch-pr`/`chained-pr`/`issue-creation` → careful description scope.
- Dual opencode configs: `.jsonc` is authoritative-but-merged; idempotency required so re-runs never duplicate the `mcp` block.
- claude/codex absent → graceful skip; definitions must be ready for later installation.
- Pi project config path collides with gitignored repo `.pi/` (gentle-ai state) → use global config.
- Token validation requires network to `api.github.com`; no network → nothing persisted (RFC edge case).

## Ready for Proposal

**Yes.** Implementable as-is; one transport correction (npm → Docker/binary/remote) must be folded into the proposal.