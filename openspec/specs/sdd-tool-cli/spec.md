# sdd-tool-cli Specification

## Purpose

Cobra CLI root (`sdd-tool`) for the four GAPs plus the incident overlay: worktree `list|verify`, retro lookup/persist, on-demand dashboard, `bug record|resolve|list`. One shared scanner (`gentle-ai sdd-status --json`) drives every listing surface; `--json` on all script surfaces; hard fail-open rules; deployed by `setup.sh` step 5d-2 as an optional build that never blocks.

## Requirements

### Requirement: CLI surface

`sdd-tool` SHALL expose subcommands `worktree list|verify`, `retro lookup|persist`, `dashboard`, and `bug record|resolve|list` via a cobra root. Script surfaces SHALL accept a `--json` flag. `sdd-tool --help` SHALL list all subcommands.

#### Scenario: Root help lists subcommands

- GIVEN the `sdd-tool` binary installed
- WHEN `sdd-tool --help` runs
- THEN all subcommands are listed with usage

#### Scenario: JSON flag on script surfaces

- GIVEN a script surface (e.g. `worktree list`)
- WHEN invoked with `--json`
- THEN structured JSON is emitted, parseable without human output

### Requirement: Shared scanner

All listing surfaces SHALL read ONE cached parse of `gentle-ai sdd-status --json` (schema v2) as their single data source. The scanner MUST NOT be re-invoked per surface within one command run. The retro store mode SHALL be an input, never derived from `sdd-status.artifactStore`.

#### Scenario: One scanner feeds all surfaces

- GIVEN a command touching listing surfaces
- WHEN it runs
- THEN `gentle-ai sdd-status --json` is invoked once and its cached parse feeds every surface

#### Scenario: Scanner unavailable

- GIVEN `gentle-ai sdd-status --json` fails or is absent
- WHEN a surface needs it
- THEN the command exits non-zero with a clear message and mutates nothing

### Requirement: Fail-open execution

Any tool absence or subcommand error SHALL exit non-zero without blocking the SDD flow; executors behave exactly as before the tool existed. The tool MUST NOT mutate `nextRecommended`, `blockedReasons`, or the attempt ledger. The tool MUST NOT write `~/.engram/engram.db`; Engram access SHALL use the `engram` subprocess (`search`/`save`) only.

#### Scenario: Tool absent, executors unaffected

- GIVEN the `sdd-tool` binary is absent
- WHEN an orchestrator overlay clause references it
- THEN the clause fails open and the phase proceeds exactly as before (fail-open)

#### Scenario: Ledger never mutated

- GIVEN any `sdd-tool` subcommand runs
- WHEN `gentle-ai sdd-status --json` is read afterward
- THEN `nextRecommended` and `blockedReasons` are unchanged

#### Scenario: Engram accessed by subprocess only

- GIVEN a retro or bug operation touching Engram
- WHEN it executes
- THEN only `engram search`/`save` subprocess calls run; `~/.engram/engram.db` is never written directly

### Requirement: Optional build step (setup.sh 5d-2)

`setup.sh` SHALL add step 5d-2: an optional `go build` of `srv/sdd-tool` honoring check/dry-run/real modes. Missing Go or a build failure SHALL emit a warning only — never block, never touch token configuration. The built binary SHALL have a `.gitignore` entry.

#### Scenario: Build fails open

- GIVEN Go missing or `go build` fails
- WHEN setup runs step 5d-2
- THEN a fail-open warning is emitted and setup continues

#### Scenario: Sync unaffected by tool deploy

- GIVEN wiring and `srv/sdd-tool/` in place
- WHEN `./sync-skills.sh --check` runs
- THEN it reports zero desyncs (sync ignores `srv/`)