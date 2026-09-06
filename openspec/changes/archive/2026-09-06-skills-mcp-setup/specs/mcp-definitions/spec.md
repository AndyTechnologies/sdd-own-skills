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

Each definition SHALL declare the remote primary transport `https://api.githubcopilot.com/mcp/` with header `Authorization: Bearer {env:GITHUB_PERSONAL_ACCESS_TOKEN}`, plus the Docker alternative `ghcr.io/github/github-mcp-server` with `--env-file`. Per-runtime secret indirection SHALL be: OpenCode remote with headers and `oauth:false`; Pi `bearerTokenEnv`; Codex `bearer_token_env_var`; Claude `-e`. Blocks MUST NOT embed literal token values.

#### Scenario: OpenCode block

- GIVEN the opencode definition
- WHEN rendered into the `mcp` block of `opencode.jsonc`
- THEN it declares remote, the Bearer env interpolation, and `oauth:false`
- AND contains no literal token

#### Scenario: Pi and Codex indirection

- GIVEN the pi and codex definitions
- WHEN rendered into `~/.pi/agent/mcp.json` and `~/.codex/config.toml`
- THEN they reference env-var names (`bearerTokenEnv` / `bearer_token_env_var`), never literal values

### Requirement: Extensibility

Adding a runtime SHALL require only a new definition file under `wiring/mcp.d/`, with no structural change to setup logic beyond rendering the new shape.

#### Scenario: New runtime

- GIVEN a fifth runtime is to be supported
- WHEN its definition file is added
- THEN setup renders it without pipeline restructuring