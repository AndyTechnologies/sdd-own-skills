# MCP Definitions Specification

## Purpose

Spec for the declarative per-runtime MCP block definitions in `wiring/mcp.d/` (RFC goal 5; non-goal: the SDD fragment never gains `mcp`; invariant: blocks reference the env file, never literal values).

## Requirements

### Requirement: Declarative definitions directory

Per-runtime MCP definitions SHALL live in `wiring/mcp.d/`, one declarative file per supported runtime (opencode, claude, pi, codex). The SDD fragment `wiring/opencode.sdd.json` MUST NOT gain `mcp` keys.

#### Scenario: Fragment untouched

- GIVEN `wiring/opencode.sdd.json`
- WHEN the change is applied
- THEN it contains no `mcp` key

#### Scenario: Definitions present

- GIVEN the change applied
- THEN `wiring/mcp.d/` holds one definition file per runtime
- AND each file renders into that runtime's native config shape

### Requirement: Block contract

Each definition file SHALL render into its runtime's native config shape. A definition SHALL declare one or more server entries; when multiple entries share one file, the `server_key` SHALL name the primary presence entry used for check-mode presence detection, and the additional entries SHALL be additive (rendered into the runtime `mcp`/`mcpServers` block without altering the primary entry). Per-runtime secret indirection SHALL be: OpenCode remote with `enabled:true`, headers, and `oauth:false`; Pi `bearerTokenEnv`; Codex `bearer_token_env_var`; Claude `-e`. Blocks MUST NOT embed literal token values; a declared local server entry SHALL be launched with a command array whose working-directory argument uses the `{{SDD_OWN_DIR}}` placeholder (e.g. `command: ["uv","run","--directory","{{SDD_OWN_DIR}}/srv/gh-mcp-server",...]`), resolved to `$HOME/.config/sdd-own` at render time by setup.sh, and the server SHALL be deployed to `~/.config/sdd-own/srv/<server>` by setup.sh; the entry SHALL reference no token. (Previously: each definition declared a single remote GitHub MCP transport; the opencode block held only `github` remote.)

#### Scenario: OpenCode block

- GIVEN the opencode definition
- WHEN rendered into the `mcp` block of `opencode.jsonc`
- THEN it declares the `github` remote entry unchanged
- AND the `gh-git-mcp` local entry appended additively under the same block

#### Scenario: Primary presence entry

- GIVEN a multi-entry opencode block
- WHEN setup.sh runs presence checks
- THEN `server_key: "github"` still gates presence
- AND the local entry's absence is reported non-blocking (pending/notice), not a desync

#### Scenario: Pi and Codex indirection

- GIVEN the pi and codex definitions
- WHEN rendered into `~/.pi/agent/mcp.json` and `~/.codex/config.toml`
- THEN they reference env-var names (`bearerTokenEnv` / `bearer_token_env_var`), never literal values

#### Scenario: Local entry token-free

- GIVEN the `gh-git-mcp` local entry
- WHEN inspected
- THEN it declares `type:local` with a `command` array
- AND contains no token, header, or env interpolation for a secret

### Requirement: Extensibility

Adding a runtime SHALL require only a new definition file under `wiring/mcp.d/`, with no structural change to setup logic beyond rendering the new shape. Adding a server entry within an already-supported runtime SHALL require only an additive entry in the existing definition block, with `server_key` naming the primary presence entry. (Previously: extensibility covered only new runtimes, each a single-server definition file.)

#### Scenario: New runtime

- GIVEN a fifth runtime is to be supported
- WHEN its definition file is added
- THEN setup renders it without pipeline restructuring

#### Scenario: Added local server entry

- GIVEN the opencode definition already supports `github`
- WHEN `gh-git-mcp` is added to the same block
- THEN setup merges both entries into the runtime `mcp` block idempotently
- AND re-running setup leaves no duplicate or orphaned keys