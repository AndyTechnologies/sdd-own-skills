# sdd-tool-retro Specification

## Purpose

Store-aware retrospective persistence and lookup: store-first on the declared store, cross-store fallback only on zero domain results, dedupe by change name, precis capped at 3–5 retros of ≤15 lines each. Persist writes the openspec file pre-archive (so it travels via the folder move) and/or an Engram observation (topic `sdd/{change}/retrospective`, type `learning`, title carrying the topic key); `none` mode emits an inline hint only.

## Requirements

### Requirement: Store-first lookup with cross-store fallback

Retro lookup SHALL read the declared store first (declared mode `both`, `openspec`, `engram`, or `none` is an input — never derived from `sdd-status.artifactStore`). Fallback to the other store SHALL happen ONLY when the first returns zero domain results. Results SHALL be deduped by change name. Zero results in both stores SHALL yield an empty precis, not a failure.

#### Scenario: Both-store dedupe and fallback

- GIVEN declared mode `both` and zero openspec retros but N engram retros for the change
- WHEN `retro lookup` runs
- THEN the lookup falls back to engram, dedupes by change name, and returns the precis

#### Scenario: Zero everywhere is empty, not an error

- GIVEN no retros in either store
- WHEN `retro lookup` runs
- THEN an empty precis is returned with success exit

#### Scenario: Declared store decoupled from artifactStore

- GIVEN `sdd-status.artifactStore` reports `openspec` and declared retro mode is `both`
- WHEN `retro lookup` runs
- THEN lookup uses `both`, never the reported `artifactStore` value

### Requirement: Precis cap

The retro precis SHALL contain 3–5 retrospectives, each ≤15 lines, deduped by change name. An over-cap corpus SHALL be truncated to the newest 5.

#### Scenario: Over-cap corpus truncated

- GIVEN 7 retros for distinct changes
- WHEN the precis is built
- THEN exactly the newest 5 are included, none exceeding 15 lines

### Requirement: Engram persist

`retro persist` SHALL save to Engram via the `engram` subprocess: title carrying the topic key, topic `sdd/{change}/retrospective`, type `learning`, project scoped. CLI saves are prompt-context-free by construction (no `capture_prompt` flag), satisfying `capture_prompt: false` by design.

#### Scenario: Engram observation retrievable by topic key

- GIVEN `retro persist` ran with declared mode `both` or `engram`
- WHEN `engram search "sdd/{change}/retrospective" --project <repo>` runs
- THEN the observation resolves (title carries the key) with type `learning`

### Requirement: Openspec persist pre-archive

With declared mode `both` or `openspec`, `retro persist` SHALL write the retro file into `openspec/changes/{change}/` BEFORE the `sdd-archive` launch, so the archive folder move carries it into `archive/{date}-{change}/`. The archive snapshot readback SHALL stay clean (file present in the source snapshot).

#### Scenario: Retro file travels with the archive move

- GIVEN the retro file exists in `openspec/changes/{change}/` before archive launches
- WHEN `sdd-archive` runs the folder move
- THEN the file is present in `archive/{date}-{change}/` and the `diff -r` readback is empty

### Requirement: None mode inline hint

With declared mode `none`, `retro persist` SHALL emit an inline hint only — no file, no observation.

#### Scenario: None mode writes nothing

- GIVEN declared mode `none`
- WHEN `retro persist` runs
- THEN an inline hint is emitted and neither file nor observation is created

### Requirement: RED check coverage

`tests/run_red_checks.sh` SHALL add T40+ RED checks covering both-store dedupe, cross-store fallback on zero results, and retrievability of the persisted retro on both sides.

#### Scenario: Red suite green

- GIVEN all tool code and wiring applied
- WHEN `./tests/run_red_checks.sh` runs
- THEN the new checks pass, covering dedupe, fallback, and both-store retrievability