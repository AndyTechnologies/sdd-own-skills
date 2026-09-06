# GitHub MCP Setup Specification

## Purpose

Spec for the `setup.sh` wrapper (RFC goal 2, AC 1/2/3/8): orchestrates `sync-skills.sh` steps 0-4 plus one MCP step, with sync-identical merge mechanics, flags, reports, and non-mutating check/dry-run modes.

## Requirements

### Requirement: Orchestration and flags

`setup.sh` SHALL run `sync-skills.sh` steps 0-4 (gentle-ai sync, skill install, overlays, opencode merge, registries) followed by the MCP step. It SHALL support `--check`, `--dry-run`, `--skip-gentleai-sync`, `--skip-opencode`, `--skip-mcp`, `--force-mcp-token`, and `--registries <proyecto...>`. `--check` and `--dry-run` MUST be mutually exclusive and MUST NOT mutate state.

#### Scenario: Clean run

- GIVEN a machine with opencode and pi installed
- WHEN `setup.sh` runs and a valid token is provided at the prompt
- THEN steps 0-4 run, the MCP step configures opencode and pi, and the report prints install/update/skip per runtime

#### Scenario: Flag passthrough

- GIVEN `setup.sh --skip-gentleai-sync --skip-opencode --skip-mcp`
- WHEN run
- THEN the corresponding sync steps are skipped and no MCP writes occur

### Requirement: Documentation

`README.md` SHALL document setup usage, the `wiring/mcp.d/` convention, the env file location, and the sanctioned exception: the MCP merge is the one allowed writer to `~/.config/opencode` outside the sync pipeline (AC 8).

#### Scenario: README updated

- GIVEN the change applied
- WHEN the README is reviewed
- THEN it documents setup flags, mcp.d convention, and env file path

### Requirement: Merge mechanics mirror sync

MCP config merges SHALL reuse sync's additive mechanics: jq/python3 merge, `.bak` backup, exit codes 0/1/2, and sync-style reports. Merges SHALL be idempotent (re-runs never duplicate blocks) and SHALL touch only the `mcp` block of OpenCode (target `opencode.jsonc`, which wins over `.json`) and `mcpServers` of the Pi global config `~/.pi/agent/mcp.json`, never the repo `.pi/mcp.json` (collides with gentle-ai state) and never the SDD fragment or personal keys.

#### Scenario: Idempotent merge

- GIVEN an existing `mcp` block in `opencode.jsonc`
- WHEN `setup.sh` re-runs
- THEN no duplicate blocks appear and a `.bak` exists from the first merge

#### Scenario: Config collision

- GIVEN `opencode.jsonc` with personal servers (codegraph, context7, engram)
- WHEN the merge runs
- THEN personal servers are preserved and only the GitHub block is added

#### Scenario: Exit codes

- GIVEN a failure or desync
- WHEN `setup.sh` runs
- THEN it exits 0 on success, 1 on usage/config errors or check desyncs, 2 on apply failures, mirroring `sync-skills.sh`

### Requirement: Absent runtimes

Runtimes not installed (claude, codex) SHALL be declared-but-skipped with a notice; unsupported runtimes SHALL be skipped with a notice and MUST NOT fail the run.

#### Scenario: Declared but skipped

- GIVEN no `claude` CLI and no `~/.codex`
- WHEN the MCP step runs
- THEN claude and codex are reported "declared, skipped"
- AND opencode/pi still proceed

### Requirement: Check and dry-run reports

`setup.sh --check` SHALL report skills synced, GitHub MCP configured-or-absent, and token valid-or-missing without mutating (AC 1). `setup.sh --dry-run` SHALL show the plan and write nothing (AC 2).

#### Scenario: Check state

- GIVEN clean state
- WHEN `--check` runs
- THEN it reports skills synced, MCP absent, token missing
- AND mutates nothing

#### Scenario: Dry-run plan

- GIVEN no token
- WHEN `--dry-run` runs
- THEN it prints the plan including the would-be token prompt
- AND writes nothing