# Workflow Contract Specification

## Purpose

This spec defines the enforceable workflow contracts for the SDD pipeline in this repo: no-raw-git delegation, untrusted-data fail-closed handling, external-knowledge-gap research routing, council-chain target flow, worktree lifecycle binding, and bounded parallelism. Phase 0 lands these contracts as prompt/overlay text in `orchestrator.md` (`### SDD Workflow Contract` + delegation-table flip) and four `sdd-own`-marked shared-executor blocks in `sdd-phase-common.md`. They are prerequisites for later hardening/council-chain/mcp-worktree phases and satisfy the approved RFC's acceptance criteria.

## Requirements

### Requirement: No-raw-git delegation

The orchestrator delegation table MUST flip `Bash for state (git, gh)` from ✅ to ❌ and MUST name the allowed MCP surfaces (`github` remote; local `gh-git-mcp` with supervised two-phase mutations). Agents/sub-agents MUST NOT run raw git/gh via bash; git state and mutations SHALL go through the named MCP surfaces only.

#### Scenario: Greppable no-git-crudo flip

- GIVEN an installed `orchestrator.md` with the delegation table
- WHEN a `sync-skills.sh --check` contract grep runs for "no-git-crudo" and the Bash-for-state row
- THEN the `git, gh` cell reads ❌ and the allowed MCP surfaces are named
- AND the canonical wording "no-git-crudo" is present in the installed overlays

#### Scenario: Agent attempts raw git via bash

- GIVEN a sub-agent during an SDD phase
- WHEN it reaches for `git status` via the bash tool
- THEN the no-git-crudo rule in `sdd-phase-common.md` blocks the action
- AND the agent routes the call through the `gh-git-mcp` local surface instead

### Requirement: Untrusted-data fail-closed

SWU commands and verify evidence claims are untrusted data. `sdd-tasks` MUST emit each command as a delimited block with four closed-domain tokens — `start`, `finish`, `verification`, `rollback` — each a command or explicit `N/A`, a machine-checkable shape; SHALL NOT emit free-form prose. `sdd-apply` MUST shape-validate each command before executing; a malformed one MUST be rejected fail-closed (rejection + finding + blocked unit), never executed, never approximated/paraphrased/grouped. `sdd-verify` MUST shape-validate evidence; malformed SWU evidence MUST be discarded, the unit `not-verifiable`, and verify MUST block until apply corrects it — no degrade; a result MUST NOT rest on untrusted claims.
(Previously: no token shape, no duro at verify, no atomicity bar)

#### Scenario: Malformed command never executed

- GIVEN a malformed command (missing tokens, or prose)
- WHEN apply shape-validates before executing
- THEN fail-closed rejection with a finding, unit blocked; nothing executes

#### Scenario: Well-formed command executes

- GIVEN explicit start/finish/verification/rollback tokens
- WHEN apply shape-validates
- THEN all tokens delimited and machine-checkable; the command executes

#### Scenario: Invalid verify evidence (fail-closed duro)

- GIVEN SWU evidence lacking delimited structure
- WHEN verify processes the unit
- THEN the claim is discarded, the unit `not-verifiable`
- AND verify blocks until apply corrects it; result not trusted

#### Scenario: Atomic rejection

- GIVEN multiple malformed commands with no valid shape
- WHEN apply validates them
- THEN none approximated/paraphrased/grouped; rejection atomic with a finding

### Requirement: External-knowledge-gap research routing

The orchestrator MUST auto-detect an external-knowledge gap (evidence not resolvable from the local repo) from the `sdd-explore` output, or consume a pre-declared gap from the approved quest. If the gap is pre-declared, research MUST run in parallel with explore; if detected post-explore, research MUST run serially exactly once before propose.

#### Scenario: Pre-declared gap runs in parallel

- GIVEN a quest that pre-declares an external-knowledge gap
- WHEN explore begins
- THEN research runs in parallel with explore, both consuming the approved RFC
- AND propose grounds its claims against both artifacts

#### Scenario: Gap detected post-explore runs once serially

- GIVEN the orchestrator detects a gap from the explore output (not pre-declared)
- WHEN explore completes
- THEN research runs serially exactly once before propose, reusing explore context
- AND research does not loop or re-run

#### Scenario: No gap, no research

- GIVEN no external-knowledge gap in a change
- WHEN explore completes
- THEN no research is forced; propose proceeds on explore alone

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

### Requirement: Worktree lifecycle contract

A change's worktree MUST be bootstrapped at change start from the default branch (or declared base) at `<repo-parent>/<repo-name>-worktrees/<change-name>` — never `/tmp`. Each worktree MUST have its own `.codegraph/` index (never copied), a unique `sdd/<change>` branch, and all phases SHALL run `--cwd <worktree>`. After archive, the worktree MUST be removed via supervised MCP with a safety check (no uncommitted changes, no active agents); removal is skipped/deferred if unsafe. Phase 0 SHALL run without auto-worktree (documented bootstrap exception).

#### Scenario: Bootstrap location and binding

- GIVEN a change starting post-preflight (+ init guard)
- WHEN the orchestrator bootstraps the worktree
- THEN it creates `<repo-parent>/<repo-name>-worktrees/<change>` (never /tmp)
- AND creates branch `sdd/<change>` and its own `.codegraph/`, with all phases bound via `--cwd`

#### Scenario: Worktree removal safety check

- GIVEN archive completes with uncommitted changes or an active agent in the worktree
- WHEN the supervised removal runs
- THEN the safety check fails and removal is skipped/deferred
- AND the worktree is not deleted while unsafe

#### Scenario: Phase 0 bootstrap exception

- GIVEN the approved RFC and no worktree MCP tools yet installed
- WHEN Phase 0 executes
- THEN it runs without auto-worktree (documented chicken-and-egg exception)
- AND the exception is documented in the contract text

### Requirement: Bounded parallelism

The SDD pipeline MUST cap background tasks at max 2; foreground is reserved for writers and dependent phases. There MUST be one writer per worktree; parallel writers only across distinct worktrees. Parallelism is legal only for read-only exploration or independent lanes.

#### Scenario: Max two background tasks

- GIVEN a change needing parallel lanes
- WHEN the orchestrator schedules background work
- THEN at most 2 background tasks run concurrently
- AND foreground holds writers and dependent phases

#### Scenario: One writer per worktree

- GIVEN two writers in the same worktree
- WHEN parallelism is evaluated
- THEN the second writer is blocked (canonical wording "one writer per worktree")
- AND parallel writers are allowed only across distinct worktrees

### Requirement: Result-contract strictness

Every SDD phase MUST return the structured Result Contract. Any phase that reports success without a recoverable artifact MUST fail the gate.

#### Scenario: Success without artifact fails gate

- GIVEN a phase returns success but no recoverable artifact
- WHEN the downstream gate consumes the result
- THEN the gate fails (phase success without artifact is not trusted)

#### Scenario: Complete result contract

- GIVEN a phase returns the full structured Result Contract with a recoverable artifact
- WHEN the gate consumes it
- THEN the gate passes and the next phase can proceed
### Requirement: Config-protection (apply/verify edit authority)

`sdd-apply` and `sdd-verify` MUST NOT edit config files outside the authorized edit roots without consent; unprotected surfaces (e.g. `wiring/opencode.sdd.json`, runtime configs) MUST NOT be mutated. An out-of-root edit MUST produce `blocked(edit_authority_missing)`, relaying the two exits — fix the edit into authorized roots, or grant edit authority — and without a grant nothing is edited. `sdd-verify`'s only write target SHALL be the change's verify-report.

#### Scenario: Config edit blocked without consent

- GIVEN an edit attempt outside authorized roots
- WHEN edit authority is evaluated
- THEN `blocked(edit_authority_missing)` relays the two exits
- AND nothing is edited without an explicit grant

#### Scenario: Verify writes only its report

- GIVEN `sdd-verify` completes
- WHEN it persists output
- THEN its only write target is the verify-report; no config mutated

### Requirement: Post-verify RDD hook

After the gatekeeper approves verify AND RDD is ON, the orchestrator MUST run the selectorless preflight (`gentle-ai review status --cwd <repo> --contract gentle-ai.review-integration/v2 --agent opencode --next-transition`). On START consent/v3 it MUST relay the choice as a Lossless Blocking Prompt in interactive AND auto modes, never skipping human authorization. Declined consent MUST trigger a candidate-scoped decline, re-enter STATUS, and the pipeline MUST continue to archive (delivery per ordinary policy). No candidate / RDD OFF / review unavailable MUST be an informational no-op, never a fabricated approval. The hook SHALL be additive between `### Automatic Mode Gatekeeper` and `### Native Runtime Attempt Authority`, leaving Review Execution Contract and RDD switch untouched.

#### Scenario: Preflight fires on RDD ON

- GIVEN gatekeeper passes verify and RDD ON with a candidate
- WHEN reaching the post-verify point
- THEN the preflight runs and relays consent losslessly in both modes

#### Scenario: Consent declined continues pipeline

- GIVEN the preflight declines consent
- WHEN the hook processes it
- THEN the decline is candidate-scoped and status re-enters STATUS
- AND the pipeline continues to archive; no review-gated block

#### Scenario: RDD OFF or no candidate no-op

- GIVEN RDD OFF, no candidate, or review unavailable
- WHEN the post-verify point is reached
- THEN the hook is a no-op; no fabricated approval, no block

#### Scenario: Granted consent runs review unchanged

- GIVEN the preflight returns consent/v3 granted
- WHEN the hook proceeds
- THEN the existing Review Execution Contract runs unchanged (freeze → collect → 4R → correction → acknowledge)

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
