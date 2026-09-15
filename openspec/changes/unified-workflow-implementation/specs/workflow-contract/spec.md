# Delta for workflow-contract

## MODIFIED Requirements

### Requirement: Council-chain target flow

Post-design, the chain MUST be: design → arch-lint (ALWAYS, axis 1) → council (OPTIONAL, threshold-driven) → arch-lint axis 2 (only if a council ran) → gate (advance/retry). Council SHALL trigger when the task forecast (fallback: design — binding) exceeds >10 files, >400 lines, or touches critical paths (`wiring/`, `skills/`, `prompts/`); when triggered it SHALL run the FULL machinery (`sdd-council` + 3 lens agents, acta at `openspec/changes/{change-name}/council.md`, no `__managed_by`). Council MUST NOT relaunch design; the orchestrator relaunches design when arch-lint fails. Auto mode max 1 retry of the chain; a second failure MUST STOP with a report (no loop-until-clean). Convergence = no interruption; forks → user decides.
(Previously: council ALWAYS after design; arch-lint acta mandatory input)

#### Scenario: Thresholds met, full council runs

- GIVEN a completed design whose forecast exceeds a threshold
- WHEN the post-design chain runs
- THEN arch-lint axis 1 runs always, then the full council (3 lenses + acta), then axis 2 verifies the acta title-by-title
- AND tasks proceed from the forecast

#### Scenario: No threshold, council skipped

- GIVEN a completed design whose forecast is under all thresholds
- WHEN the post-design chain runs
- THEN arch-lint axis 1 gates alone; council does not run and axis 2 is skipped
- AND the gate advances without user interruption

#### Scenario: Convergence fast-path

- GIVEN all 3 lens agents converge on one option
- WHEN the council runs
- THEN the acta records convergence and the chain continues with NO user interruption
- AND axis 2 still verifies the acta

#### Scenario: Council ran, acta missing

- GIVEN a council ran but the acta is missing or unreadable
- WHEN axis 2 executes
- THEN arch-lint fails-closed reporting the missing acta; the chain halts (never silently skipped)

#### Scenario: Arch-lint failure retried once then STOP

- GIVEN arch-lint fails on the design
- WHEN the orchestrator (not council) relaunches design with findings + acta
- THEN the chain retries at most once in auto mode
- AND a second failure stops the chain with a report

### Requirement: Arch-lint axis 2 (acta verification)

`skills/sdd-architecture-lint/SKILL.md` SHALL implement axis 2: verify each council acta decision title-by-title against the design. Axis 2 SHALL be conditional — it runs only when a council ran; when no council ran it is skipped and axis 1 gates alone. When a council ran but the acta is missing or unreadable, arch-lint MUST fail-closed. Axis 1 (requirements/scope) SHALL remain unchanged and ALWAYS run.
(Previously: axis 2 always, acta mandatory input, N/A only for empty/trivial design)

#### Scenario: Acta decisions verified title-by-title

- GIVEN a council ran and an acta with titled decisions exists
- WHEN arch-lint axis 2 runs
- THEN each acta decision is verified against the design title-by-title

#### Scenario: No council, axis 2 skipped

- GIVEN arch-lint runs post-design with no council triggered
- WHEN arch-lint executes
- THEN axis 1 gates alone and axis 2 is skipped; no acta required

#### Scenario: Council ran, acta missing fails closed

- GIVEN a council ran but the acta is missing or unreadable
- WHEN axis 2 is due
- THEN arch-lint fails-closed reporting the missing acta

### Requirement: Command overlay council chain

Command overlays SHALL wire the threshold-driven chain: `sdd-continue.md` SUPPORT-CONDITIONAL and `sdd-ff.md` item 6 SHALL name arch-lint ALWAYS (axis 1) → council OPTIONAL (thresholds) → axis 2 conditional on the acta; no boundary-conditional skip and no always-council language.
(Previously: always council → arch-lint(acta) chain)

#### Scenario: sdd-continue SUPPORT-CONDITIONAL wired

- GIVEN an installed `sdd-continue.md`
- WHEN its SUPPORT-CONDITIONAL block is inspected
- THEN arch-lint axis 1 always; council fires only on forecast thresholds; axis 2 only when council ran

#### Scenario: sdd-ff item 6 wired

- GIVEN an installed `sdd-ff.md`
- WHEN item 6 is inspected
- THEN it names the conditional chain and never "council ALWAYS"

### Requirement: Archive-close fixed persist order

At archive close the orchestrator MUST run, in fixed order: `archive` → `changelog` (automatic, POST-archive) → `retro persist` (via `sdd-tool`, as today) → `PR ready`; merge ALWAYS human. The changelog SHALL run post-archive consuming the archive-report (replacing the pre-archive verify-report hook); changelog and retro SHALL complete before the PR is marked ready. Delta composition at archive SHALL use the native deterministic command `gentle-ai sdd-archive-compose --canonical <canonical spec path> --delta <delta spec path>` (fails clean naming the section/requirement when a delta does not apply), never manual merging.
(Previously: verify → changelog PRE-archive consuming the verify-report → retro → archive)

#### Scenario: Fixed order honored at archive close

- GIVEN verify and the hard gate pass
- WHEN the archive-close sequence runs
- THEN archive launches first, then the automatic changelog reads the archive-report, then retro persists via `sdd-tool`, then the PR is marked ready
- AND the merge remains human-only

#### Scenario: Interruption between archive and changelog

- GIVEN the sequence is interrupted after archive, before changelog
- WHEN it resumes
- THEN changelog completes from the archive-report before retro and PR-ready
- AND changelog never precedes archive

#### Scenario: Archive-report drives the changelog

- GIVEN a completed archive-report
- WHEN the post-archive changelog hook runs
- THEN `sdd-changelog` accepts the archive-report input and emits its entry before the close completes

### Requirement: Orchestrator rule 4 and organic hooks rewrite

`wiring/prompts/sdd/orchestrator.md` SHALL rewrite rule 4 and extend `Organic Support Phase Hooks` item 3 to the unified flow contract: arch-lint ALWAYS post-design (axis 1); council OPTIONAL on forecast thresholds (fallback design); axis 2 only when council ran; auto max 1 retry then STOP; convergence = no interruption; forks → user decides. F4 post-verify text and consent strings MUST remain byte-stable (T31 passes); the hard gate SHALL be ADDED around F4, never replacing it.
(Previously: rule 4 described council ALWAYS → arch-lint(acta) → gate)

#### Scenario: Rule 4 rewritten, F4 text stable

- GIVEN orchestrator.md rule 4 is rewritten
- WHEN the F4 post-verify hook and consent block are grepped
- THEN T31 pins (`gentle-ai review status`, `review-integration/v2`, `consent/v3`, etc.) match unchanged

#### Scenario: Organic hooks item 3 extended

- GIVEN `Organic Support Phase Hooks` item 3 in orchestrator.md
- WHEN inspected
- THEN it describes arch-lint ALWAYS axis 1, council OPTIONAL thresholds, axis 2 conditional

### Requirement: RED checks T32+

`tests/run_red_checks.sh` SHALL rewrite T32/T35/T48 to the new pins and append T49+: orchestrator allow-list includes `sdd-council`; lens allow-lists intact; `OWN_PROMPTS` includes `sdd-council.md` and any hard-gate prompt; no `mcp` key in `wiring/opencode.sdd.json` (protect T02); council-OFF fast path; axis 1 always + axis 2 conditional; changelog POST-archive (T48 rewrite); bootstrap pre-resolve; quest 3-section schema; PR-draft-from-start; hard gate always; preflight canonical 3 groups only (runtime block, separate worktree confirm); threshold triggers.
(Previously: T32+ pinned council ALWAYS, acta mandatory, hook "council always fires")

#### Scenario: Full red suite green

- GIVEN all changes are applied and synced
- WHEN `./tests/run_red_checks.sh` runs
- THEN it reports green with rewritten T32/T35/T48 and new T49+
- AND `./sync-skills.sh --check` reports 0 desyncs (T30)

## ADDED Requirements

### Requirement: Hard gate pre-archive

Before archive, the orchestrator MUST run the hard gate ALWAYS: a native attempt ledger (`sdd-attempt`) SHALL record each attempt, and an adversarial verifier with fresh eyes SHALL compare specs vs code. Failure SHALL return to the origin phase (max 2 rounds) then STOP with a human report. The hard gate SHALL be additive around the F4/RDD hook, which stays byte-stable (T31).

#### Scenario: Hard gate always runs pre-archive

- GIVEN verify passes and the change is ready to archive
- WHEN the pre-archive point is reached
- THEN the native ledger records the attempt and the adversarial verifier compares specs vs code
- AND archive does not start until the hard gate passes

#### Scenario: Hard gate failure returns to origin

- GIVEN the adversarial verifier finds spec-vs-code mismatches
- WHEN the hard gate fails
- THEN control returns to verify/apply via the return edge, max 2 rounds
- AND a 3rd failure stops with a report to the human

### Requirement: Bootstrap canonical paths (Q40)

At session start the orchestrator MUST pre-resolve canonical paths: `sdd-tool` → `$HOME/.config/sdd-own/bin/sdd-tool` (or PATH), `sdd-rfc-author` prompt → `wiring/prompts/sdd/sdd-rfc-author.md` (installed `~/.config/sdd-own/prompts/sdd/sdd-rfc-author.md`), and skills. The flow SHALL NEVER look them up mid-phase; a mid-phase `command not found` for `sdd-tool` is a contract violation, not an error case. `sdd-rfc-author` is a prompt-defined sub-agent, not a `~/.agents/skills` skill; the orchestrator MUST NOT search skills for it.

#### Scenario: Paths resolved before any phase

- GIVEN a session starts
- WHEN the bootstrap runs
- THEN `sdd-tool`, the `sdd-rfc-author` prompt, and skills paths resolve BEFORE any phase runs
- AND zero mid-phase lookups occur across the flow

#### Scenario: command not found is a contract violation

- GIVEN a mid-phase `sdd-tool` invocation
- WHEN the canonical path is missing
- THEN it is reported as a bootstrap contract violation, not retried as a transient error

### Requirement: PR lifecycle (draft from start)

On change start the orchestrator MUST create a DRAFT PR on branch `sdd/{change-name}` via MCP surfaces only (`gh-git-mcp`/`github`, no-git-crudo), with incremental commits per work unit. At close (after archive → changelog → retro) the PR SHALL be marked ready; the merge MUST remain human-only, never automatic. An oversized PR (>400 changed lines) SHALL fire the ask-on-risk human gate before apply.

#### Scenario: Draft PR exists from the start

- GIVEN a change starts in the confirmed worktree
- WHEN the worktree + PR-draft step runs
- THEN a draft PR exists on `sdd/{change}` via the MCP surfaces with incremental commits per work unit

#### Scenario: Close marks ready, merge stays human

- GIVEN archive, changelog, and retro complete
- WHEN the close sequence finishes
- THEN the PR is marked ready
- AND the merge is never automatic; the human merges

#### Scenario: Oversized PR asks on risk

- GIVEN the forecast exceeds 400 changed lines
- WHEN the PR lifecycle evaluates delivery
- THEN the ask-on-risk human gate fires before apply proceeds
- AND no oversized work starts unless delivery resolves to chained/sliced PRs or `size:exception`

### Requirement: Preflight canonical groups and separate worktree confirmation

The session preflight SHALL use the runtime-managed canonical group set recognized by the native OpenCode plugin: exactly 3 fixed groups (Pace, Artifact store, Delivery strategy) with canonical labels and the fixed 400-line review policy, and the `SDD Session Preflight` block is injected by the runtime only — never authored, extended, or relabeled by the model. The worktree confirmation and the `gh-git-mcp` availability check SHALL be asked as a SEPARATE orchestrator step, never as extra canonical groups (the runtime rejects 4+ canonical groups). The worktree SHALL be reused for the same change; on conflict the human is asked. Once confirmed, work NEVER runs in the main repository. Init stays silent: `sdd-init` runs only if context is missing.

#### Scenario: Canonical groups exactly three, runtime-injected block

- GIVEN a session preflight
- WHEN the orchestrator asks the decision groups
- THEN exactly the 3 canonical groups are asked with fixed labels and order
- AND a separate step confirms the worktree (path + branch `sdd/{change}`) and the `gh-git-mcp` availability

#### Scenario: Same change reuses; conflict asks

- GIVEN a previous session confirmed the same change's worktree
- WHEN preflight runs again
- THEN the worktree is reused without re-asking
- AND a conflicting worktree state asks the human, never silently resolves

### Requirement: gh-git-mcp availability check

Before the change progresses past phase 0, the orchestrator MUST verify the `gh-git-mcp` MCP surface (provisioned by setup.sh 5d) is available as part of the separate worktree-confirmation step; unavailability SHALL be reported in that step and the PR/worktree lifecycle SHALL NOT start past phase 0.

#### Scenario: MCP available, flow proceeds

- GIVEN `gh-git-mcp` is provisioned and reachable
- WHEN preflight checks availability
- THEN the change proceeds past phase 0 with worktree + PR-draft capability

#### Scenario: MCP unavailable blocks past phase 0

- GIVEN `gh-git-mcp` is not provisioned
- WHEN preflight checks availability
- THEN unavailability is reported and the PR lifecycle does not start past phase 0

### Requirement: Quest 3-section schema and single gate

`quest.md` MUST contain exactly 3 RFC sections — product, architecture, general — each with the full 9-slot quest schema, authored by `sdd-rfc-author` (one author, one pass) and approved through a SINGLE human gate (`## Approval: approved`; ✅ all, ❌ re-opens only the affected section). An engram mirror SHALL be saved (topic `sdd/{change}/quest`, `capture_prompt: false`). needs-changes SHALL re-interview only the affected branch (≤50 budget) and relaunch the author with the new Q&A plus the existing `quest.md` path.

#### Scenario: Three sections, single gate

- GIVEN the quest phase produces `quest.md`
- WHEN the gate is presented
- THEN the 3 RFC sections (3 × 9 slots) are approved together with one ✅
- AND one ❌ re-opens only the affected section, never three gates

#### Scenario: Needs-changes relaunch on affected branch

- GIVEN the gate returns needs-changes
- WHEN the author is relaunched
- THEN only the affected RFC branch is re-interviewed (≤50 budget)
- AND the author receives the new Q&A plus the existing `quest.md` path

### Requirement: Return edge (bounded correction)

On phase failure, control MUST return to the origin phase; max 2 correction rounds; a 3rd failure SHALL produce a report to the human — never a loop. Applies to gate rejection, arch-lint/council failure, hard-gate failure, and apply/verify corrections alike.

#### Scenario: Failure returns to origin, max 2

- GIVEN a phase fails
- WHEN the return edge triggers
- THEN control returns to the origin phase for correction
- AND a 3rd failure reports to the human (no loop-until-clean)

### Requirement: Handoff by path (locations, never contents)

All phase handoffs MUST pass locations, never artifact contents: explore receives the `quest.md` path; propose receives quest + explore paths and returns its own location; spec receives the proposal path; design receives proposal + spec paths. The sole exception is the inline Q&A handed to the RFC author. The orchestrator SHALL NOT carry RFC format contracts — the format lives inside the author's prompt.

#### Scenario: Path-based handoffs across phases

- GIVEN a phase completes with an artifact
- WHEN the orchestrator hands off to the next phase
- THEN it passes only the artifact path
- AND the receiving sub-agent reads the artifact from the backend itself

#### Scenario: Sole exception is the RFC Q&A

- GIVEN the quest phase
- WHEN the orchestrator hands the Q&A to `sdd-rfc-author`
- THEN the inline Q&A plus destination path is the only content-carrying handoff in the flow