# Tasks: SDD Workflow Hardening

## Review Workload Forecast

Estimated changed lines: ~200–280 (3 overlays ~90, hook ~20, tests ~90, this file)

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low
Delivery strategy: exception-ok

## Dependency Graph

WU1 → WU3 (T28–T30 grep overlays); WU2 → WU3 (T31 greps hook); WU1 → WU4 (landing gate). WU1/WU2 independent; WU3 needs both. Order: WU1 → WU2 → WU3 → WU4.

## Work Units (SWU shape)

### WU1 — Create 3 overlays (5 ids)

`sdd-tasks` (`sdd-own:sdd-tasks-swu-shape`); `sdd-apply` (`sdd-own:sdd-apply-swu-validate`, `sdd-own:sdd-apply-edit-authority`); `sdd-verify` (`sdd-own:sdd-verify-evidence-shape`, `sdd-own:sdd-verify-edit-authority`). Content per design; pins verbatim from `shared-untrusted-data`; anchors by heading.

```sh
start: mkdir -p overlays/skills/sdd-tasks overlays/skills/sdd-apply overlays/skills/sdd-verify
finish: grep -oh 'sdd-own:sdd-[a-z-]*' overlays/skills/*/SKILL.md | sort -u | wc -l
verification: grep -c 'fail-closed' overlays/skills/sdd-*/SKILL.md
rollback: rm -f overlays/skills/sdd-tasks/SKILL.md overlays/skills/sdd-apply/SKILL.md overlays/skills/sdd-verify/SKILL.md
```

### WU2 — F4 hook clause

Additive in `wiring/prompts/sdd/orchestrator.md`, between `### Automatic Mode Gatekeeper` and `### Native Runtime Attempt Authority`; Review Execution Contract / RDD switch untouched.

```sh
start: cp wiring/prompts/sdd/orchestrator.md /tmp/opencode/orchestrator.pre-f4.bak
finish: grep -q '--next-transition' wiring/prompts/sdd/orchestrator.md
verification: grep -c 'never skips human authorization' wiring/prompts/sdd/orchestrator.md
rollback: cp /tmp/opencode/orchestrator.pre-f4.bak wiring/prompts/sdd/orchestrator.md
```

### WU3 — Grupo 7 tests (T28–T31)

Extend `tests/run_red_checks.sh` after T27, before `stop_fake_api`; update header map.

```sh
start: cp tests/run_red_checks.sh /tmp/opencode/run_red_checks.pre-f4.bak
finish: grep -q 'T31 F4 hook pins' tests/run_red_checks.sh
verification: bash tests/run_red_checks.sh
rollback: cp /tmp/opencode/run_red_checks.pre-f4.bak tests/run_red_checks.sh
```

### WU4 — Sync verification

`./sync-skills.sh --check`, zero desyncs. Full sync applied later by orchestration; no commit/push.

```sh
start: ./sync-skills.sh --check
finish: N/A: read-only unit; --check exit 0 is the pass condition
verification: ./sync-skills.sh --check
rollback: N/A: no mutation performed
```

## Phase 1: Overlay Creation

- [x] 1.1 `overlays/skills/sdd-tasks/SKILL.md` — `sdd-own:sdd-tasks-swu-shape`: per SWU fenced block, 4 closed tokens `start`/`finish`/`verification`/`rollback`, one command or `N/A`+reason each; machine-checkable; never prose; pins verbatim; anchors `### Suggested Work Units` + `### Task Writing Rules`.
- [x] 1.2 `overlays/skills/sdd-apply/SKILL.md` — `sdd-own:sdd-apply-swu-validate`: validate BEFORE execute; malformed → fail-closed (finding + blocked unit), never approximated/paraphrased/grouped; anchors `#### Hard Gate (All Modes): Work Unit Evidence`.
- [x] 1.3 Same — `sdd-own:sdd-apply-edit-authority`: no config edits outside roots without consent; `blocked(edit_authority_missing)` two exits; anchors `## Status and Workspace Guard`.
- [x] 1.4 `overlays/skills/sdd-verify/SKILL.md` — `sdd-own:sdd-verify-evidence-shape`: delimited evidence; malformed discarded → `not-verifiable` → block until apply corrects (duro); anchors `## Hard Rules` + `## Execution Steps`.
- [x] 1.5 Same — `sdd-own:sdd-verify-edit-authority`: only write target verify-report; anchors `## Output Contract`.

## Phase 2: Orchestrator Hook

- [x] 2.1 Insert F4 clause: post-verify + RDD ON → selectorless preflight; consent/v3 relayed losslessly interactive AND auto; never skips human authorization; declined → candidate-scoped, re-enter STATUS, continue to archive; no candidate / OFF / unavailable → no-op.

## Phase 3: Tests

- [x] 3.1 T28: pins greps in `wiring/prompts/sdd/orchestrator.md` (read-only), `overlays/shared/sdd-phase-common.md` (read-only), 3 overlays: `fail-closed`, untrusted DATA, 4 tokens, delimited evidence, `not-verifiable`, `blocked(edit_authority_missing)`.
- [x] 3.2 T29: synthetic SWU probe — assert `start`/`finish`/`verification`/`rollback` present; apply text has fail-closed chain.
- [x] 3.3 T30: `./sync-skills.sh --check` flags exactly this change's 4 pre-sync files, 0 errors; ids unique (dup-check mirror).
- [x] 3.4 T31: F4 pins on `wiring/prompts/sdd/orchestrator.md` (read-only) — preflight shape, lossless consent, never skips human authorization, decline continues.
- [x] 3.5 Update header coverage map with Grupo 7.

## Phase 4: Verification

- [x] 4.1 `./sync-skills.sh --check` → flags this change's 4 pre-sync files, 0 errors (zero-desync AC met post-sync by orchestration); re-run idempotent.
- [x] 4.2 Report full sync applied by orchestration; no commit/push.

## Test Strategy Mapping (spec scenarios)

| Spec scenario | Tests |
|---|---|
| Malformed never executed / Atomic rejection | T28, T29 |
| Well-formed executes | T29 |
| Invalid evidence (duro) | T28, T29 |
| Config blocked / Verify only report | T28 |
| Preflight fires / Decline continues / OFF no-op / Granted unchanged | T31 |
| AC: sync zero desyncs | T30, WU4 |