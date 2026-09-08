# Apply Progress — SDD Workflow Hardening

**Change**: sdd-workflow-hardening
**Phase**: apply
**Mode**: Standard (no Strict TDD active — prompt/overlay text, no code unit runner)
**Batch**: 1 (all 13 tasks, single batch)
**Status**: Complete — 13/13 tasks

## Work Unit Evidence (per Hard Gate)

| Work Unit | Focused test command + result | Runtime harness | Rollback boundary |
|---|---|---|---|
| WU1 — 3 overlays (5 ids) | `grep -oh 'sdd-own:sdd-[a-z-]*' overlays/skills/*/SKILL.md \| sort -u \| wc -l` → 9 unique ids across all overlays; `grep -c 'fail-closed' overlays/skills/sdd-*/SKILL.md` → ≥1 in each of the 3 | N/A: prompt/overlay text, no runtime boundary | `rm -f overlays/skills/sdd-{tasks,apply,verify}/SKILL.md` |
| WU2 — F4 hook clause | `grep -q '--next-transition' wiring/prompts/sdd/orchestrator.md` → present; `grep -c 'never skips human authorization'` → 1 | N/A: prompt text, no runtime boundary | `cp /tmp/opencode/orchestrator.pre-f4.bak wiring/prompts/sdd/orchestrator.md` |
| WU3 — Grupo 7 tests (T28–T31) | `bash tests/run_red_checks.sh` → T28/T29/T30/T31 all PASS (29 PASS total, 2 env-harness FAIL) | run_red_checks.sh suite | `cp /tmp/opencode/run_red_checks.pre-f4.bak tests/run_red_checks.sh` |
| WU4 — sync verification | `./sync-skills.sh --check` → exactly 4 file desyncs (this change's files), 0 errors, exit 1 (pre-sync) | read-only check | N/A: no mutation performed |

## Completed Tasks

- [x] 1.1 `overlays/skills/sdd-tasks/SKILL.md` — `sdd-own:sdd-tasks-swu-shape`
- [x] 1.2 `overlays/skills/sdd-apply/SKILL.md` — `sdd-own:sdd-apply-swu-validate`
- [x] 1.3 `overlays/skills/sdd-apply/SKILL.md` — `sdd-own:sdd-apply-edit-authority`
- [x] 1.4 `overlays/skills/sdd-verify/SKILL.md` — `sdd-own:sdd-verify-evidence-shape`
- [x] 1.5 `overlays/skills/sdd-verify/SKILL.md` — `sdd-own:sdd-verify-edit-authority`
- [x] 2.1 F4 hook clause in `wiring/prompts/sdd/orchestrator.md`
- [x] 3.1 T28 contract pins test
- [x] 3.2 T29 synthetic SWU probe test
- [x] 3.3 T30 sync idempotency + id hygiene test
- [x] 3.4 T31 F4 hook pins test
- [x] 3.5 Header coverage map update (Grupo 7)
- [x] 4.1 `sync-skills.sh --check` flags this change's 4 pre-sync files, 0 errors (AC met post-sync)
- [x] 4.2 Report full sync applied by orchestration; no commit/push

## Files Created / Modified

| File | Action | What Was Done |
|------|--------|---------------|
| `overlays/skills/sdd-tasks/SKILL.md` | Created | Block `sdd-own:sdd-tasks-swu-shape` (SWU emission contract: 4 tokens, fail-closed, pins verbatim from shared-untrusted-data) |
| `overlays/skills/sdd-apply/SKILL.md` | Created | Blocks `sdd-own:sdd-apply-swu-validate` (validate-before-execute, fail-closed atomic) + `sdd-own:sdd-apply-edit-authority` (blocked(edit_authority_missing) two exits) |
| `overlays/skills/sdd-verify/SKILL.md` | Created | Blocks `sdd-own:sdd-verify-evidence-shape` (duro: discard → not-verifiable → block) + `sdd-own:sdd-verify-edit-authority` (only write verify-report) |
| `wiring/prompts/sdd/orchestrator.md` | Modified | Additive F4 hook clause between `### Automatic Mode Gatekeeper` and `### Native Runtime Attempt Authority` |
| `tests/run_red_checks.sh` | Modified | Grupo 7 (T28–T31) after T27, header coverage map updated, T30 reframed to pre-sync AC |

## Deviations from Design

- **T30 scope (task 3.3)**: The design's literal "`./sync-skills.sh --check` zero desyncs" cannot pass in the pre-sync state that apply is contractually bound to (apply must NOT run the real sync; "Full sync applied later by orchestration"). I reframed T30 to assert the check flags **exactly this change's 4 pre-sync files** (3 overlays + orchestrator hook) with **0 structural errors**, mirroring the established convention from the archived `2026-09-07-sdd-workflow-contract` change (which verified the pre-sync desync set with 0 errors and confirmed zero-desync post-sync). This is honest, machine-checkable, and consistent with the migration/AC-verification plan.
- **WU1 verification pin `fail-closed` in sdd-apply**: the initial sdd-apply text used "NEVER executed" but lacked the literal `fail-closed` token required by T28/WU1 verification; added it per the spec's exact wording.

## Issues Found

- **T05/T21 pre-existing suite failures (environmental, not defects)**: `setup.sh --check`/`sync-skills.sh --check` expect exit 0, which requires the repo to be fully synced. This change introduces 4 pre-sync desyncs (by design, sync applied later by orchestration), so T05 and T21 now report exit 1. These will turn green after the real sync runs. All 4 new Grupo 7 tests pass.

## Rollback

- Strip the 5 `sdd-own` blocks from the 3 overlay files; revert the F4 clause in `wiring/prompts/sdd/orchestrator.md` (backup at `/tmp/opencode/orchestrator.pre-f4.bak`); drop Grupo 7 (backup at `/tmp/opencode/run_red_checks.pre-f4.bak`); re-sync → bases byte-identical to Alan's.

## Deviations / Notes

- None beyond those above — implementation matches design (F1 + F3 + F4, approach 1, per-skill overlays by heading anchors).
