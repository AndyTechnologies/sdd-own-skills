# Archive Report — SDD Workflow Hardening

**Change**: sdd-workflow-hardening
**Archived to**: `openspec/changes/archive/2026-09-08-sdd-workflow-hardening/`
**Archive date**: 2026-09-08
**Artifact store**: openspec (repo-local at `openspec/`)
**Schema**: gentle-ai.verify-result/v1 evidence revision `sha256:0ba8d03dd15da15be38595bb5336a8d1c199a7a754c2af6fbda94e3084b394c0` (final verify-report, re-verification PASS)

## Final State (at close — authoritative)

Per the orchestrator's final-state facts (most recent account) and the persisted tasks artifact (13/13 checked, `taskProgress.allComplete: true`):

- **Implementation**: 13/13 tasks complete; work units WU1→WU4 executed in dependency order (WU1 overlays → WU2 F4 hook → WU3 Grupo 7 tests → WU4 sync verification).
- **One remediation occurred after the first verify**: T30 in `tests/run_red_checks.sh` was rewritten from the stale pre-sync invariant (exactly 4 desyncs, exit 1) to the post-sync invariant (exit 0, zero `[DESYNC]` lines, `Errores 0`, duplicate-id 0). This was a **test-defect fix, not an implementation change** — the implementation (3 overlays, F4 hook, Grupo 7) was already correct; the test asserted the pre-sync shape and was unreachable post-sync.
- **Final verification PASS**: suite **31/31 PASS / 0 FAIL / 0 SKIP**; T05/T21 green post-sync; T28/T29/T30/T31 green; `gentle-ai sdd-verify-validate` valid:true verdict pass, exit 0; sync check zero desyncs. The single prior CRITICAL (T30 stale pre-sync invariant) is remediated; the prior FAIL verdict is superseded by this PASS (per `verify-report.md` re-verification section).
- **No commits, no pushes, no PRs were made during any phase** — the change exists as uncommitted files only. None were made as part of archive.
- **Sync state at close**: `./sync-skills.sh --check --skip-gentleai-sync` → exit 0, zero desyncs, `Errores 0`, `Estado: sincronizado (cero desyncs)` — full sync applied, 3 overlays deployed, F4 hook deployed.

### Artifact snapshot provenance

The milestone artifacts record the state at their write time; the final state above outranks them where they differ:

| Artifact | Written at | Role at close |
|---|---|---|
| `tasks.md` | sdd-tasks, updated by apply | Source of truth for completion: 13/13 `[x]`, zero unchecked |
| `apply-progress.md` | during apply (intermediate snapshot) | Records WU evidence (WU4 `--check` reported 4 pre-sync desyncs — valid for pre-sync time only) |
| `verify-report.md` | re-verification (final evidence revision `0ba8…394c0`) | PASS verdict, full green matrix, T30 post-sync assertion |

Per the Final-State Authority hierarchy, `apply-progress.md`'s pre-sync WU4 claim ("exactly 4 file desyncs, exit 1") is a snapshot of the pre-sync state; the final state is zero desyncs post-sync, machine-verified by T30 and the sync check at close.

## Spec Delta Sync

Composition ran through the native `gentle-ai sdd-archive-compose` (Mandatory Native Composition — no model-driven Read/Edit merge):

```bash
gentle-ai sdd-archive-compose \
  --canonical "openspec/specs/workflow-contract/spec.md" \
  --delta "openspec/changes/sdd-workflow-hardening/specs/workflow-contract/spec.md" \
  --output "openspec/specs/workflow-contract/spec.md.compose-tmp" \
&& mv "openspec/specs/workflow-contract/spec.md.compose-tmp" "openspec/specs/workflow-contract/spec.md"
```

Exit 0. The composed main spec `openspec/specs/workflow-contract/spec.md` (209 lines) now contains **9 requirements / 25 scenarios**:

| Action | Requirement | Details |
|---|---|---|
| MODIFIED | Untrusted-data fail-closed | Replaced with the hardened version: 4-token delimited SWU shape, apply fail-closed rejection, verify fail-closed Duro (`not-verifiable`, block until apply corrects); 4 scenarios |
| ADDED | Config-protection (apply/verify edit authority) | `blocked(edit_authority_missing)` two exits, verify writes only its report; 2 scenarios |
| ADDED | Post-verify RDD hook | Selectorless preflight on RDD ON, lossless consent relay, decline continues to archive, no-op when OFF/unavailable; 4 scenarios |

All 7 pre-existing unrelated requirements preserved byte-for-byte (No-raw-git delegation, External-knowledge-gap, Council-chain, Worktree lifecycle, Bounded parallelism, Result-contract strictness). The delta contained no REMOVED/RENAMED sections; the merge was non-destructive (no `rules.archive` warn required).

## Archive Contents

```
openspec/changes/archive/2026-09-08-sdd-workflow-hardening/
├── proposal.md          ✅ (from sdd-propose)
├── quest.md             ✅ (RFC pre-pass, binding mandate)
├── exploration.md       ✅ (from sdd-explore)
├── specs/workflow-contract/spec.md  ✅ (delta spec, unchanged bytes)
├── design.md            ✅ (from sdd-design)
├── tasks.md             ✅ 13/13 tasks complete, zero unchecked
├── apply-progress.md    ✅ (intermediate snapshot)
└── verify-report.md     ✅ (final evidence revision, PASS)
```

Mechanical move evidence: `git mv` refused the untracked directory (`fatal: source directory is empty`); the skill's fallback guard verified the source byte-identical to the pre-move recursive snapshot (`diff -r` empty), then plain `mv` succeeded; the post-move `diff -r snapshot vs destination` was **empty** (passing readback). `archive-report.md` is additive and excluded from the comparison.

## Implemented Artifacts (as shipped)

- `overlays/skills/sdd-tasks/SKILL.md` — block `sdd-own:sdd-tasks-swu-shape` (F1 emission: 4 closed tokens, machine-checkable, never prose)
- `overlays/skills/sdd-apply/SKILL.md` — blocks `sdd-own:sdd-apply-swu-validate` (F1: validate-before-execute, fail-closed atomic) + `sdd-own:sdd-apply-edit-authority` (F3: `blocked(edit_authority_missing)` two exits)
- `overlays/skills/sdd-verify/SKILL.md` — blocks `sdd-own:sdd-verify-evidence-shape` (F1 Duro: discard → `not-verifiable` → block) + `sdd-own:sdd-verify-edit-authority` (F3: only write target is verify-report)
- `wiring/prompts/sdd/orchestrator.md` — additive F4 clause `### Post-Verify Review Hook (F4)` at line 405, between `### Automatic Mode Gatekeeper` (L377) and `### Native Runtime Attempt Authority` (L416); Review Execution Contract and RDD switch untouched
- `tests/run_red_checks.sh` — Grupo 7 (T28–T31) after T27, header coverage map updated; T30 asserts the post-sync invariant

Deployed state (machine-verified in final verify-report): `sdd-own` blocks present in installed `~/.agents/skills/sdd-{tasks,apply,verify}/SKILL.md`; installed orchestrator prompt symlinks to `~/.config/sdd-own/prompts/sdd/orchestrator.md` with F4 hook present (`next-transition` count 2, `never skips human authorization` count 1).

## Verification of Archive

- [x] Main specs updated correctly (9 requirements / 25 scenarios; unrelated requirements preserved)
- [x] Change folder moved to archive
- [x] Archive contains all artifacts (proposal, quest, exploration, specs, design, tasks, apply-progress, verify-report)
- [x] Archived `tasks.md` has no unchecked implementation tasks
- [x] Active changes directory no longer contains this change
- [x] Verbatim `diff -r` readback output included in this phase's result and empty (no differences)

## Residuals / Risks

- **T29 path pin post-archive**: T29 in `tests/run_red_checks.sh` probes `openspec/changes/sdd-workflow-hardening/tasks.md` — a path that no longer exists after archive. A future full-suite run would fail T29 until the probe path is updated (the suite is a per-change living artifact; the next change touching it should repoint the probe, e.g. to the archived folder or a synthetic fixture). Not fixed during archive per the no-alter contract on source artifacts.
- **WU1 verification pin behavior**: apply added the literal `fail-closed` token to the sdd-apply overlay text to satisfy T28/WU1's exact pin (recorded in `apply-progress.md` deviations) — already resolved, noted for audit.
- **Pre-existing harness flakiness**: the monolithic red-check run hangs in non-TTY contexts (PTY/fake_api); the suite was executed per-block with its own harness during verify. Pre-existing, independent of this change.

## Intentional-With-Warnings Markers

None — archive was clean: all artifacts present, 13/13 tasks complete, zero CRITICAL findings in the final verify-report, zero unchecked tasks, no stale-checkbox reconciliation needed.