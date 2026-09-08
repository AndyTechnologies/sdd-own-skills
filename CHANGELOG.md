# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2026-09-08

### Changed
- `sdd-tasks` now emits Suggested Work Units (SWUs) with four closed-domain tokens (`start`, `finish`, `verification`, `rollback`), each a command or explicit `N/A` with reason, making commands machine-checkable and never free-form prose.
- `sdd-apply` shape-validates every suggested command before execution; malformed commands are rejected fail-closed with a finding and blocked work unit, never executed or paraphrased.
- `sdd-apply` and `sdd-verify` may only edit files inside authorized edit roots; out-of-root edits produce `blocked(edit_authority_missing)` with two exits (fix into authorized roots or grant authority).

### Added
- `sdd-verify` now shape-validates evidence claims; malformed evidence is discarded, the unit marked `not-verifiable`, and verify blocks until apply corrects it — no degraded trust from untrusted claims.
- Post-verify Review-Driven Development (RDD) hook in the orchestrator: on RDD ON, a selectorless preflight runs and relays consent as a Lossless Blocking Prompt in both interactive and auto modes, never skipping human authorization; declined consent continues the pipeline to archive.
- Four new test groups (T28–T31) in `tests/run_red_checks.sh` covering contract pins, synthetic SWU probes, sync idempotency, and F4 hook validation.
