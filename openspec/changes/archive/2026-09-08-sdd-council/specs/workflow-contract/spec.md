# Delta for Workflow Contract

## MODIFIED Requirements

### Requirement: Council-chain target flow

Post-design, the default chain MUST be: design → council (ALWAYS, multi-voice + user decision on forks) → arch-lint (ALWAYS, acta mandatory input) → gate (advance/retry). The council SHALL be executed by a dedicated `sdd-council` skill and 4 agents (`sdd-council` + 3 lens agents), registered in `wiring/opencode.sdd.json` with no `__managed_by`. Council MUST persist an acta at `openspec/changes/{change-name}/council.md` and MUST NOT relaunch design; the orchestrator relaunches design when arch-lint fails. Auto mode allows max 1 retry of the full council → arch-lint chain; a second failure MUST STOP with a report (no loop-until-clean). The boundary-free/`N/A`-skip on arch-lint SHALL be removed; `N/A` remains valid only for an empty/trivial design.
(Previously: prose-only rule 4 with no council machinery, no agents, no acta, no wiring; arch-lint was opt-in and boundary-conditional)

#### Scenario: Happy-path chain

- GIVEN a completed design with forks
- WHEN the chain runs
- THEN council fires always after design, before tasks, via `sdd-council` orchestrating 3 lens agents in parallel
- AND the user decides forks (model never decides alone)
- AND arch-lint always fires after council, verifying requirements/scope (axis 1) + acta decisions title-by-title (axis 2)
- AND the gate advances; council never relaunches design

#### Scenario: Arch-lint failure retried once then STOP

- GIVEN arch-lint fails on the design
- WHEN the orchestrator (not council) relaunches design with findings + acta
- THEN the chain retries at most once in auto mode
- AND a second failure stops the chain with a report (no loop-until-clean)

#### Scenario: No-forks fast-path (convergence)

- GIVEN all 3 lens agents converge on a single viable option
- WHEN the chain runs
- THEN the acta records convergence and the chain continues with NO user interruption
- AND arch-lint still always fires with the acta as mandatory input

#### Scenario: Acta missing at arch-lint

- GIVEN arch-lint runs without a council acta
- WHEN axis 2 is evaluated
- THEN arch-lint fails-closed (reports acta missing) and the chain halts
- AND a missing acta is never silently skipped

#### Scenario: Empty/trivial design N/A

- GIVEN `design.md` is empty or trivial (no decisions to review)
- WHEN the chain runs
- THEN council returns N/A and arch-lint skips axis 2
- AND the chain continues (N/A preserved only for this case)

## ADDED Requirements

### Requirement: Orchestrator rule 4 and organic hooks rewrite

`wiring/prompts/sdd/orchestrator.md` SHALL rewrite rule 4 (~line 493) and extend `Organic Support Phase Hooks` item 3 (~line 371-375) to describe the enforceable council → arch-lint(acta) → gate chain: council ALWAYS after design and before tasks; arch-lint ALWAYS after council with acta mandatory; auto mode max 1 retry; convergence = no interruption; forks → user decides; max 2 rounds then STOP. The F4 post-verify text (lines 405-414) and consent strings MUST remain byte-stable (T31 passes unchanged).

#### Scenario: Rule 4 rewritten, F4 text stable

- GIVEN orchestrator.md rule 4 is rewritten
- WHEN the F4 post-verify hook and consent block are grepped
- THEN T31 pins (`gentle-ai review status`, `review-integration/v2`, `consent/v3`, etc.) still match unchanged

#### Scenario: Organic hooks item 3 extended

- GIVEN `Organic Support Phase Hooks` item 3 in orchestrator.md
- WHEN inspected
- THEN it describes council ALWAYS after design, arch-lint ALWAYS after council with mandatory acta, gate

### Requirement: Arch-lint axis 2 (acta verification)

`skills/sdd-architecture-lint/SKILL.md` SHALL add axis 2: verify each council acta decision title-by-title against the design. The acta SHALL be a mandatory input—fail-closed if missing. `N/A` skip SHALL apply only to empty/trivial design. Axis 1 (requirements/scope) SHALL remain unchanged.

#### Scenario: Acta decisions verified title-by-title

- GIVEN an acta with titled decisions and a design
- WHEN arch-lint axis 2 runs
- THEN each acta decision is verified against the design title-by-title

#### Scenario: Missing acta fails closed

- GIVEN arch-lint runs without an acta
- WHEN axis 2 executes
- THEN axis 2 fails-closed reporting the missing acta

### Requirement: Command overlay council chain

Command overlays SHALL wire the ALWAYS council → arch-lint(acta) chain: `sdd-continue.md` SUPPORT-CONDITIONAL and `sdd-ff.md` item 6 SHALL replace the boundary-conditional arch-lint skip with the ALWAYS council → arch-lint(acta) chain.

#### Scenario: sdd-continue SUPPORT-CONDITIONAL wired

- GIVEN an installed `sdd-continue.md`
- WHEN its SUPPORT-CONDITIONAL block is inspected
- THEN council runs always then arch-lint(acta) always; no boundary-conditional skip

#### Scenario: sdd-ff item 6 wired

- GIVEN an installed `sdd-ff.md`
- WHEN item 6 is inspected
- THEN arch-lint(acta) fires ALWAYS after council; no boundary-conditional skip

### Requirement: RED checks T32+

`tests/run_red_checks.sh` SHALL append RED checks T32+ following the T28/T29/T31 pattern covering: orchestrator task allow-list includes `sdd-council`; `sdd-council` task allow-list includes the 3 lens agents; `OWN_PROMPTS` includes `sdd-council.md`; no `mcp` key in `wiring/opencode.sdd.json` (protect T02); hook pins (council always fires after design); acta-as-lint-input (mandatory); convergence fast-path (no interruption); forks → user decides; 2-rounds STOP.

#### Scenario: Full red suite green

- GIVEN all changes are applied and synced
- WHEN `./tests/run_red_checks.sh` runs
- THEN it reports green with >= 31 original + new checks
- AND `./sync-skills.sh --check` reports 0 desyncs (T30)
