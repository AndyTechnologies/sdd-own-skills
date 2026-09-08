# SDD Council Specification

## Purpose

Multi-voice post-design review skill with 3 independent lens agents (arch/product/risk), parallel execution, convergence/fork logic, acta persistence, 2-round hard cap, and arch-lint integration.

## Requirements

### Requirement: Skill existence and structure

`skills/sdd-council/SKILL.md` SHALL exist as an exclusive full-install skill containing: 3 lens definitions (architecture, product/UX, risk/resilience), parallel `task()` orchestration of the 3 lens agents, convergence/fork/re-frame rules, 2-round hard cap, acta format (titled decisions + convergence status + round count), and the invariant that council NEVER decides forks alone and NEVER relaunches design.

#### Scenario: Skill deployed via sync

- GIVEN `skills/sdd-council/SKILL.md` in the repo
- WHEN `sync-skills.sh --check` runs
- THEN zero desyncs reported (T30-compatible)

#### Scenario: Skill contains required sections

- GIVEN the skill is loaded
- WHEN its content is inspected
- THEN it contains lens definitions for arch/product/risk, convergence/fork rules, 2-round cap, and acta format

### Requirement: Lens agent registration

`wiring/opencode.sdd.json` SHALL register 4 agents: `sdd-council` (file-based prompt `wiring/prompts/sdd/sdd-council.md` with its own `task` allow-list for the 3 lens agents), `sdd-council-arch`, `sdd-council-product`, `sdd-council-risk` (inline prompts, `mode: subagent`, `hidden: true`, `permission: {}`). All 4 SHALL have `__managed_by` absent. `gentle-orchestrator` task allow-list SHALL include `sdd-council`.

#### Scenario: Orchestrator can task council

- GIVEN `gentle-orchestrator` task allow-list
- WHEN inspected in `wiring/opencode.sdd.json`
- THEN `sdd-council` is present

#### Scenario: Council can task lens agents

- GIVEN `sdd-council` agent definition
- WHEN its `task` allow-list is inspected
- THEN `sdd-council-arch`, `sdd-council-product`, `sdd-council-risk` are present

#### Scenario: No __managed_by on any council agent

- GIVEN the 4 council agents in `wiring/opencode.sdd.json`
- WHEN inspected
- THEN none has a `__managed_by` field

#### Scenario: No mcp key added

- GIVEN `wiring/opencode.sdd.json` after changes
- WHEN inspected
- THEN no `mcp` key exists (protects T02)

### Requirement: File-based prompt and OWN_PROMPTS

`wiring/prompts/sdd/sdd-council.md` SHALL exist as the file-based prompt for the council agent. It SHALL be added to `OWN_PROMPTS` in `sync-skills.sh` (line 105) so sync deploys it to `~/.config/sdd-own/prompts/sdd/` and symlinks it.

#### Scenario: Prompt file exists

- GIVEN the change is applied
- WHEN `wiring/prompts/sdd/sdd-council.md` is inspected
- THEN the file exists with the council orchestration contract

#### Scenario: OWN_PROMPTS includes council

- GIVEN `sync-skills.sh` OWN_PROMPTS list
- WHEN grepped
- THEN `sdd-council.md` is present

### Requirement: Convergence fast-path (no-fork)

When all 3 lens agents agree on a single viable option, the council SHALL record the acta with the converged decision and SHALL NOT interrupt the user. The acta records convergence status and the chain continues without prompting.

#### Scenario: 3 voices converge

- GIVEN 3 lens agents return the same verdict
- WHEN council consolidates
- THEN acta records convergence, no user interruption, chain continues to arch-lint

### Requirement: Fork resolution by human

When 2+ divergent options exist, the orchestrator SHALL present framed options to the user and wait for explicit decision. The model NEVER decides forks alone. User rejection of all options SHALL STOP with a report.

#### Scenario: Real fork presented to user

- GIVEN lens agents return divergent options
- WHEN council detects a fork
- THEN orchestrator presents options to user and waits for decision

#### Scenario: User rejects all options

- GIVEN the user rejects all framed options
- WHEN the rejection is processed
- THEN STOP with report; tasks blocked until design/proposal revised

### Requirement: Two-round hard cap

Council SHALL run at most 2 rounds (initial + 1 re-frame with fresh voices). If round 2 is still unresolved, the orchestrator SHALL STOP with a report and block tasks. Council is stateless across invocations.

#### Scenario: Second round unresolved

- GIVEN round 2 produces no convergence or fork decision
- WHEN the orchestrator evaluates
- THEN STOP with report, tasks blocked

#### Scenario: Fresh voices per round

- GIVEN a re-frame round is needed
- WHEN the council runs round 2
- THEN 3 fresh lens agent invocations run (not cached results)

### Requirement: Acta persistence

The council SHALL persist an acta at `openspec/changes/{change-name}/council.md` AND Engram mirror topic `sdd/{change-name}/council`. The acta SHALL contain titled decisions, convergence/fork status, round count, and (if fork) which option was selected.

#### Scenario: Acta written to both stores

- GIVEN council completes a round
- WHEN acta is persisted
- THEN file exists at `openspec/changes/{change-name}/council.md` AND Engram topic `sdd/{change-name}/council` has the same content

### Requirement: Council never relaunches design

Council SHALL be read-only with respect to `design.md`. Only the orchestrator MAY trigger a design re-launch (specifically when arch-lint fails and the acta shows decisions were not applied).

#### Scenario: Council is read-only

- GIVEN council runs and produces an acta
- WHEN design.md is inspected afterward
- THEN design.md is unchanged by the council

### Requirement: Organic support phase hook

Council SHALL be wired as an organic support phase in 3 homes: (a) orchestrator contract `Organic Support Phase Hooks`, (b) command overlay `SUPPORT-CONDITIONAL` in `sdd-continue.md`, (c) the skill itself. Council SHALL NOT alter `nextRecommended`.

#### Scenario: Council not in nextRecommended

- GIVEN council has run
- WHEN `nextRecommended` is inspected
- THEN no council token exists; council is a support phase only
