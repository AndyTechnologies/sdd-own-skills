# Pre-Experience Retrospective — arch-principles-quest-linter

## Failure Log

### F1: Verify false-negative on T52 runtime leg

- **WHAT**: T52 (runtime-leg greps `architecture-principles\.md` in `--check` output) produced a false-negative. The installed-state check prints `[up-to-date]` without naming the file, so the grep pattern never matches.
- **WHERE**: `tests/run_red_checks.sh`, T52 assertion block.
- **CORRECTION**: Added a 3-signal OR acceptance block + `$REAL_HOME` pin to `tests/run_red_checks.sh` (U7 remediation). The test now accepts any of three signals to confirm the file is present, eliminating the false-negative on installed-state output.

### F2: Dispatcher format blocker — non-canonical headings in specs

- **WHAT**: `sdd-spec` produced spec files with `#### Requirement:` (h4) + bullet-pointed scenarios, but the native dispatcher counts `### Requirement:` (h3) + `#### Scenario:` (h4). This caused 3 rounds of heading reformatting.
- **WHERE**: 5 spec files under `openspec/changes/arch-principles-quest-linter/specs/`.
- **ROOT CAUSE**: Sub-agent `sdd-spec` used non-canonical heading levels from an older convention.
- **CORRECTION**: 22 heading level conversions (h4→h3 for requirements) + 37 scenario reformatting passes (bullets→h4 scenario blocks) across all 5 specs.

### F3: Preflight gate loss after compaction

- **WHAT**: The `sdd-task-result-artifacts` plugin stores preflight authority in an in-memory Map keyed by sessionID; compaction clears it. The heading literal in the prompt then causes rejection.
- **WHERE**: Plugin `sdd-task-result-artifacts.ts`, in-memory state.
- **ROOT CAUSE**: Session-scoped memory not surviving compaction.
- **CORRECTION**: Empirically erratic — resolved by re-questioning canonical preflight each session. No persistent fix; workaround is session-aware re-initialization.

## Skill Candidates

### potential: sdd-spec-format

- **Origin lesson**: sdd-spec produced non-canonical heading levels (h4 requirements, bullet scenarios) causing 3 rounds of reformatting before the dispatcher accepted them.
- **Trigger**: `sdd-spec`, spec writing, OpenSpec heading conventions, `#### Scenario:`, `### Requirement:`.
- **Proposal**: Teach sdd-spec to emit `### Requirement:` (h3) + `#### Scenario:` (h4) natively, eliminating the format mismatch with the dispatcher's counting logic.

### potential: preflight-recovery

- **Origin lesson**: Plugin preflight authority lives in an in-memory session-scoped Map; compaction destroys it, causing spurious rejections.
- **Trigger**: `sdd-task-result-artifacts`, compaction recovery, preflight authority, session-scoped state.
- **Proposal**: Provide a recovery path for re-establishing preflight authority after compaction, so sub-agents don't need to re-question it each session.
