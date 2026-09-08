# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2026-09-08

### Changed
- `sdd-tasks` now emits Suggested Work Units (SWUs) with four closed-domain tokens (`start`, `finish`, `verification`, `rollback`), each a command or explicit `N/A` with reason, making commands machine-checkable and never free-form prose.
- `sdd-apply` shape-validates every suggested command before execution; malformed commands are rejected fail-closed with a finding and blocked work unit, never executed or paraphrased.
- `sdd-apply` and `sdd-verify` may only edit files inside authorized edit roots; out-of-root edits produce `blocked(edit_authority_missing)` with two exits (fix into authorized roots or grant authority).
- The post-design chain is now enforceable machinery, not prose: after every `design`, `sdd-council` runs ALWAYS, then `sdd-architecture-lint` runs ALWAYS with the council acta as a mandatory input; auto mode allows at most one retry of the full council → arch-lint chain, then STOP (no loop-until-clean).
- `sdd-architecture-lint` is no longer opt-in or boundary-conditional: it gains axis 2, which verifies each acta decision title-by-title and fails closed when the acta is missing; `N/A` remains valid only for empty/trivial designs.

### Added
- `sdd-verify` now shape-validates evidence claims; malformed evidence is discarded, the unit marked `not-verifiable`, and verify blocks until apply corrects it — no degraded trust from untrusted claims.
- Post-verify Review-Driven Development (RDD) hook in the orchestrator: on RDD ON, a selectorless preflight runs and relays consent as a Lossless Blocking Prompt in both interactive and auto modes, never skipping human authorization; declined consent continues the pipeline to archive.
- Four new test groups (T28–T31) in `tests/run_red_checks.sh` covering contract pins, synthetic SWU probes, sync idempotency, and F4 hook validation.
- New `sdd-council` support phase: 3 lens agents (`sdd-council-arch`, `sdd-council-product`, `sdd-council-risk`) review design+proposal in parallel; convergence proceeds without interrupting the user, real forks are framed for the user to decide (the model never decides forks alone), rounds are capped at 2 then STOP, and the council never relaunches design.
- The council persists an acta (`openspec/changes/{change}/council.md` + Engram mirror `sdd/{change}/council`) with titled decisions, convergence status, and round count.
- The runtime sync merge now propagates root `subagent_depth: 2` (fragment-wins, idempotent, both jq and python merge engines), enabling the orchestrator → council → lens-agent task chain.
- Command overlays (`sdd-continue` SUPPORT-CONDITIONAL, `sdd-ff` item 6) wire the ALWAYS council → arch-lint(acta) chain, and new RED checks T32–T39 pin the council allow-lists, `OWN_PROMPTS` entry, no-`mcp` rule, and `subagent_depth`.
