# Crash Recovery Specification

## Purpose

Defines organic post-power-loss continuation: discovering existing worktrees, cross-referencing apply-progress, presenting work by volume, and resuming after acquire.

## Requirements

### Requirement: Organic continuation entry

When a user issues a natural entry like "continúa con el cambio", the system SHALL discover existing worktrees via `git_worktree_list` and cross-reference each with `apply-progress` per change. No explicit change name is required.

#### Scenario: Natural entry discovers work

- GIVEN the user says "continúa con el cambio"
- WHEN the system runs `git_worktree_list` + applies-progress cross-ref
- THEN it finds all changes with active or stale worktrees
- AND presents them with their current phase and state

### Requirement: Presentation by volume

The system SHALL present work by count: 1 worktree → direct continuation with informational notice; 2–5 → selection Quest (question tool, one focused question, options = changes with phase + dirty); >5 → table (index, change, branch, state, last_seen, dirty, phase) + validated textual input; 0 → informative nothing-to-continue + propose `/sdd-new`.

#### Scenario: Single worktree

- GIVEN exactly 1 worktree with apply-progress
- WHEN continuation triggers
- THEN the system presents a direct informational notice and resumes
- AND no selection is required

#### Scenario: Two to five worktrees

- GIVEN 3 worktrees with apply-progress
- WHEN continuation triggers
- THEN the system presents a Quest with one question and options showing change + phase + dirty status

#### Scenario: More than five worktrees

- GIVEN 7 worktrees with apply-progress
- WHEN continuation triggers
- THEN the system presents a table with columns: index, change, branch, state, last_seen, dirty, phase
- AND accepts validated textual input (number, name, or alias)
- AND unambiguous single match is required; ambiguity re-presents the table

#### Scenario: Zero worktrees

- GIVEN no worktrees
- WHEN continuation triggers
- THEN the system presents "nothing to continue" and proposes `/sdd-new` or exploration

### Requirement: Resume after selection

After selection, the system SHALL `acquire(change)` → verify binding signals → resume apply from apply-progress. If acquire denies (`owned_by_other`), the denial is surfaced to the user.

#### Scenario: Resume happy path

- GIVEN user selects a change from continuation
- WHEN `acquire` returns `claimed` or `already_mine`
- THEN binding signals are verified (worktree exists, branch matches)
- AND apply resumes from the persisted apply-progress

#### Scenario: Resume denied

- GIVEN user selects a change
- WHEN `acquire` returns `owned_by_other`
- THEN the denial is presented to the user
- AND no resume occurs

### Requirement: Orchestrator acquire gate

Every phase that needs a worktree SHALL call `acquire` BEFORE `sdd-tool worktree verify`. Auto re-claim SHALL happen without prompt on objective stale evidence (dead PID). Lossless blocking prompt SHALL only occur on real conflicts (`exists_active_other`, `corrupt`).

#### Scenario: Auto re-claim on stale

- GIVEN a worktree is `exists_stale` (dead PID)
- WHEN a phase starts needing a worktree
- THEN `acquire` re-claims automatically without user prompt
- AND the phase proceeds

#### Scenario: Blocking prompt on conflict

- GIVEN a worktree is `exists_active_other`
- WHEN a phase starts needing a worktree
- THEN the system presents a blocking prompt explaining the conflict
- AND waits for user decision before proceeding

#### Scenario: Verify follows acquire

- GIVEN `acquire` succeeds
- WHEN `sdd-tool worktree verify` runs
- THEN it confirms the binding signals match the acquire result

### Requirement: Nothing-to-continue proposal

When zero worktrees are found, the system SHALL NOT silently do nothing. It SHALL present an informative message and propose starting new work via `/sdd-new` or exploration.

#### Scenario: Zero worktrees proposal

- GIVEN no worktrees exist
- WHEN continuation is attempted
- THEN the user sees "nothing to continue"
- AND is offered `/sdd-new` or exploration as next steps
