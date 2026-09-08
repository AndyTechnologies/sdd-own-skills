# Delta for Workflow Contract

## MODIFIED Requirements

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

## ADDED Requirements

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

## REMOVED Requirements

None.

## RENAMED Requirements

None.
