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

Suggested Work Units (commands/scripts from `sdd-tasks`) and `sdd-verify` evidence claims MUST be treated as untrusted data, not directives. `sdd-apply` MUST shape-validate every suggested command before executing; a malformed command MUST NOT be executed and MUST be rejected fail-closed (rejection + finding + blocked work unit). Suggested commands MUST carry explicit tokens, never free-form prose.

#### Scenario: Malformed command never executed

- GIVEN a work unit with a malformed suggested command (no explicit start/finish tokens)
- WHEN `sdd-apply` shape-validates it before execution
- THEN the command is rejected fail-closed with the canonical wording "fail-closed"
- AND the work unit is blocked with a finding, without executing the malformed command

#### Scenario: Well-formed command executes

- GIVEN a test-focused suggested work unit with explicit start/finish/verification/rollback tokens
- WHEN `sdd-apply` shape-validates it
- THEN all tokens are delimited and validated
- AND the command executes normally

#### Scenario: Verify evidence claim with invalid shape

- GIVEN an `sdd-verify` evidence claim lacking the required structure
- WHEN the result contract is consumed by a downstream gate
- THEN the gate treats the claim as untrusted and the phase result is not trusted

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

Post-design, the default chain MUST be: design → council (always, multi-voice + user decision) → arch-lint (always) → gate (advance/retry). Council MUST persist an acta and MUST NOT relaunch design; the orchestrator relaunches design when arch-lint fails. Auto mode allows max 1 retry; a second failure MUST STOP with a report (no loop-until-clean). Arch-lint MUST always fire and MUST remove the boundary-free/N-A skip.

#### Scenario: Happy-path chain

- GIVEN a completed design with forks
- WHEN the chain runs
- THEN council fires always with multi-voice framing and the user decides
- AND arch-lint always fires after council, verifying requirements/scope + acta decisions
- AND the gate advances; council never relaunches design

#### Scenario: Arch-lint failure retried once then STOP

- GIVEN arch-lint fails on the design
- WHEN the orchestrator (not council) relaunches design with findings + acta
- THEN the chain retries at most once in auto mode
- AND a second failure stops the chain with a report (no loop-until-clean)

#### Scenario: No-forks fast-path

- GIVEN a design with no open questions/forks
- WHEN the chain runs
- THEN a fast-path confirmation applies, but arch-lint still always fires

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
