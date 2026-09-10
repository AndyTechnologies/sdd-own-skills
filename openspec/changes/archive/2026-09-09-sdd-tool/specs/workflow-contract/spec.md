# Delta for Workflow Contract

## ADDED Requirements

### Requirement: Prior-context injection

The orchestrator SHALL inject retrospective context (retro precis from `sdd-tool retro lookup`) at phase start for `explore`, `propose`, `design`, and council lenses. `verify` SHALL receive ONLY verify-domain content: `verification_gaps` plus verify-phase incidents from prior changes — never general retro prose. Zero retros SHALL result in no injection and no block (fail-open).

#### Scenario: Phase-start injection for planning phases

- GIVEN an approved RFC and available retros
- WHEN explore, propose, design, or council lenses start
- THEN the retro precis is injected as prior context

#### Scenario: Verify gets only verify-domain content

- GIVEN prior retros plus recorded verify-phase incidents and `verification_gaps`
- WHEN verify starts
- THEN only `verification_gaps` and verify-phase incidents are injected

#### Scenario: No retros, no block

- GIVEN zero retros for the change
- WHEN any injection phase starts
- THEN no context is injected and the phase proceeds

### Requirement: Archive-close fixed persist order

At archive close the orchestrator MUST run, in fixed order: `verify` → `changelog` → `retro persist` → `archive`. The changelog hook SHALL run PRE-archive consuming the verify-report as its input (replacing the post-archive hook), so the order guarantees changelog and retro persistence complete before the archive folder move.

#### Scenario: Fixed order honored at archive close

- GIVEN verify passes
- WHEN the archive-close sequence runs
- THEN changelog is delegated pre-archive with the verify-report as input, then retro persist runs, then `sdd-archive` launches

#### Scenario: Interruption between changelog and retro persist

- GIVEN the sequence is interrupted after changelog, before retro persist
- WHEN the orchestrator resumes
- THEN retro persist completes before archive runs; archive never precedes changelog and retro

#### Scenario: Verify-report drives the changelog

- GIVEN a completed verify-report
- WHEN the changelog hook runs pre-archive
- THEN `sdd-changelog` accepts the verify-report input and emits its entry before archive

### Requirement: Worktree verify rule 5 integration

Orchestrator rule 5 (Worktree lifecycle) SHALL integrate `sdd-tool worktree verify` as the re-entry check: the three binding signals (`git rev-parse --show-toplevel` = expected root; `git branch --show-current` = `sdd/<change>`; `gentle-ai sdd-status --json` parses), plus dirty-state disclosure; the rule SHALL NOT auto-clear dirty worktrees — the human decides. A failing branch signal SHALL disclose "no worktree". Tool absent SHALL fall back to current behavior (fail-open).

#### Scenario: Rule 5 references the verify signals

- GIVEN the installed orchestrator.md
- WHEN rule 5 is inspected
- THEN it names the 3 binding signals and dirty-state disclosure with no auto-clear

#### Scenario: No worktree disclosed on branch mismatch

- GIVEN verification on `main` (branch signal ≠ `sdd/<change>`)
- WHEN the re-entry check runs
- THEN "no worktree" is disclosed and the human decides

#### Scenario: Tool absent falls back

- GIVEN `sdd-tool` is absent
- WHEN the re-entry check would run
- THEN the rule degrades to current workflow behavior; nothing blocks

### Requirement: Incident recording hook

An organic support hook SHALL record orchestrator-observed failures (blocker, failing test run, transport failure) via `sdd-tool bug record`. Resolution SHALL bind the fix's direct Engram observation id (`bug resolve --engram-id <obs-id>`); Engram off SHALL use the incident's `fallback_path`. Summaries SHALL be privacy-scrubbed. The hook SHALL fail open: tool absent → no recording, flow continues.

#### Scenario: Observed failure recorded

- GIVEN the orchestrator observes a blocker
- WHEN the incident hook fires
- THEN `bug record` runs and the incident surfaces in the retro incident list upon resolution

#### Scenario: Tool absent does not block

- GIVEN `sdd-tool` is absent and a failure occurs
- WHEN the incident hook would fire
- THEN no recording happens and the pipeline continues unchanged

### Requirement: Overlay clauses present with fail-open posture

All four overlay clauses (injection, archive-close retro persist, worktree verify, incident recording) SHALL be present in the installed `orchestrator.md`; each SHALL visibly fail open: any tool absence or error degrades executors to exactly the pre-tool behavior. Wiring SHALL leave `./sync-skills.sh --check` reporting zero desyncs.

#### Scenario: Clauses installed and sync-clean

- GIVEN the change is applied and synced
- WHEN `./sync-skills.sh --check` runs and the orchestrator contract is grepped
- THEN zero desyncs are reported and the four clauses are present

#### Scenario: Executors pass with tool absent and present

- GIVEN the tool binary absent OR present
- WHEN an executor runs any SDD phase
- THEN the phase completes with identical behavior to the pre-tool flow