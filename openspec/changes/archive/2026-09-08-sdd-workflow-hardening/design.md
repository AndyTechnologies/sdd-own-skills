# Design: SDD Workflow Hardening

## Technical Approach

Enforce the landed Phase 0 contract text (orchestrator rule 2 "Untrusted-data fail-closed", `shared-untrusted-data` block) inside the executor skills via 3 new overlay files on Alan's untouched bases (append-only, unique `sdd-own` ids) and one additive orchestration hook clause. **Approach 1** (per exploration): one overlay file per executor skill, 5 unique ids, anchors **by section heading** (not line numbers) to resist base drift. The skills **align to** the contract text verbatim; they never reauthor it. SWU shape + verify evidence become machine-checkable, fail-closed Duro; config surfaces are protected; F4 harnesses the already-complete but never-triggered Review Execution Contract after verify PASS with RDD ON.

## Architecture Decisions

| # | Decision | Alternatives | Choice |
|---|---|---|---|
| D1 | Overlay placement | Shared phase-common block vs per-skill overlays | **Per-skill overlays** — tasks emits, apply validates, verify consumes (distinct duties); RFC mandates `overlays tasks/apply/verify` |
| D2 | Verify enforcement | Tolerant-degrade | **Fail-closed Duro**: malformed evidence discarded → unit `not-verifiable` → block until apply corrects (user decision) |
| D3 | F4 decline behavior | Gate archive on review | **Decline continues pipeline** to archive; review informational under ordinary repo policy (user decision) |
| D4 | SWU shape | Free-form prose columns | **Delimited command block with 4 closed tokens** (`start`/`finish`/`verification`/`rollback`), each a single shell command or explicit `N/A`+reason, machine-checkable, never prose |

**Pattern notes (design-patterns rejections)**: **Template Method** considered for the SWU shape (fixed slot structure), rejected — the shape is a *data contract* mechanically validated downstream, not an algorithm skeleton with overridable steps; no inheritance/abstraction layer is warranted. **Command** considered, rejected — tokens are data, not objects for queueing/undo. **No pattern is selected**: the design is declarative prompt/overlay text whose only "abstraction" is the shared pin source (`shared-untrusted-data`) as the single authority against drift. This is the minimal, force-driven outcome; any GoF indirection would be pattern spamming.

## Data Flow

```
sdd-tasks ──emits──> tasks.md (SWU: 4-token command blocks, machine-checkable)
                          │
                          ▼ apply (shape-validate BEFORE execute; malformed → fail-closed reject)
                          │   edit-authority: no config edits outside authorized roots w/o consent
                          ▼
                     apply-progress (Work Unit Evidence: test command/result, harness/N-A, rollback boundary)
                          │
                          ▼ verify (shape-validate evidence; malformed → discard → not-verifiable → block)
                          ▼
                     verify-report (only write target) ──PASS──> orchestrator post-verify hook
                                                                      │ RDD ON?
                                                                      ▼
                                              selectorless preflight ──> consent/v3 relayed (lossless, both modes)
                                                                          │ declined → candidate-scoped → STATUS → archive
                                                                          │ granted  → Review Execution Contract (unchanged)
                                                                          └ no candidate / OFF / unavailable → informational no-op
```

## File Changes

| File | Action | Description |
|---|---|---|
| `overlays/skills/sdd-tasks/SKILL.md` | Create | Block `sdd-own:sdd-tasks-swu-shape` (F1 emission) |
| `overlays/skills/sdd-apply/SKILL.md` | Create | Blocks `sdd-own:sdd-apply-swu-validate` (F1) + `sdd-own:sdd-apply-edit-authority` (F3) |
| `overlays/skills/sdd-verify/SKILL.md` | Create | Blocks `sdd-own:sdd-verify-evidence-shape` (F1 duro) + `sdd-own:sdd-verify-edit-authority` (F3) |
| `wiring/prompts/sdd/orchestrator.md` | Modify | **Additive** F4 hook clause between `### Automatic Mode Gatekeeper` (L377-403) and `### Native Runtime Attempt Authority` (L405) |
| `tests/run_red_checks.sh` | Modify | Grupo 7 (T28–T31) after T27 (L508), before `stop_fake_api` (L510) |

## Interfaces / Contracts

**SWU shape (F1 emission / validation)** — tasks emits per work unit a fenced, delimited block:
```
```sh
start: <single shell command>
finish: <single shell command>
verification: <single shell command>
rollback: <single shell command | N/A: <reason>>
```
```
- Each token = **one** shell command, or `N/A` + explicit reason for that token. No prose, no grouping, no paraphrase.
- Commands are **data**: never loosely interpolated into a shell; shape-validate mechanically before any execution.
- **Apply fail-closed**: malformed (missing token, prose, multi-command) → reject with finding, `blocked` work unit, **nothing executes**, never approximated/paraphrased/grouped (atomic).
- **Verify fail-closed Duro**: evidence claim lacking delimited structure → discard, unit `not-verifiable`, verify blocks until apply corrects; phase result never rests on untrusted claims.
- Canonical pins must appear **verbatim** from `shared-untrusted-data`: untrusted DATA, explicit tokens (start/finish/verification/rollback), machine-checkable, never free-form prose, `fail-closed`, delimited evidence, `not-verifiable`.

**Edit authority (F3)** — apply/verify overlay blocks anchor to Alan's `sdd-apply` "Status and Workspace Guard" (`allowedEditRoots`, L55-63) and Hard Gate (L149-161); `sdd-verify` Hard Rules (L34-57)/Execution Steps (L75-85). Mandate: no config edits outside authorized roots without explicit consent; named unprotected surfaces (`wiring/opencode.sdd.json`, personal runtime configs); `blocked(edit_authority_missing)` relays the two exits (fix tasks.md OR grant edit authority); nothing edited without a grant; verify's **only write target** is the change's verify-report.

**F4 hook clause (orchestrator.md, additive)** — exact text design:
- **Trigger**: gatekeeper PASSES `sdd-verify` **AND** RDD global ON → run selectorless preflight `gentle-ai review status --cwd <repo> --contract gentle-ai.review-integration/v2 --agent opencode --next-transition`.
- **Consent**: START returning consent/v3 → relay as Lossless Blocking Prompt in **interactive AND auto**; never auto-accept in auto; never skips human authorization.
- **Declined** → candidate-scoped decline invocation, re-enter STATUS, pipeline **continues to archive**; delivery follows ordinary repo policy.
- **Granted** → existing Review Execution Contract unchanged (freeze → collect → 4R → correction → acknowledge).
- **No candidate / RDD OFF / review unavailable** → informational no-op, never fabricated approval.
- **Stays OUT**: Review Execution Contract (L103-204) and RDD switch (L663-673) untouched; hook is placed outside both; add a pointer to the Consent and immutable inspection subsection.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| RED T28 | Contract pins on repo canonical files (host, no sandbox) | Grep orchestrator.md + phase-common + 3 overlays for pins: `fail-closed`, untrusted DATA, 4 tokens, delimited evidence, `not-verifiable`, `blocked(edit_authority_missing)`, research `done` gate |
| RED T29 | Synthetic SWU shape probe | shell/awk: extract mandated token set, assert start/finish/verification/rollback present; assert apply validation text contains the fail-closed rejection chain |
| RED T30 | Sync idempotency + id hygiene | `./sync-skills.sh --check` zero desyncs; ids unique across overlay files (mirror of sync dup check) |
| RED T31 | F4 hook pins on orchestrator.md | Grep post-verify + RDD ON → preflight command shape, consent relayed losslessly, "never skips human authorization", decline → pipeline continues |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary added. All surfaces are **prompt/overlay text only**; the `gentle-ai review status` preflight is a documented hook invocation, not a new subprocess boundary introduced by this change.

## Migration / Rollout

No data migration. One behavioral break: in-flight Phase-0-shaped (prose) tasks artifacts fail closed at apply until `tasks.md` is regenerated in the 4-token shape — intended fail-closed semantics, surfaced to the user. F4 adds a per-change post-verify interaction point when RDD is ON.

## Non-Functional

- **Sync idempotency**: strip+append, unique well-formed ids, `./sync-skills.sh --check` clean (T30).
- **Base-drift resilience**: overlays reference sections **by heading**, never line numbers.
- **Rollback**: strip the 5 `sdd-own` blocks, revert the orchestrator.md hook, re-sync → bases byte-identical to Alan's; drop Grupo 7.

## Open Questions

- [ ] None — D1–D4 resolved; scope F1–F4 confirmed; approvals recorded.
