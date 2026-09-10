# Archive Report: sdd-tool

**Change**: sdd-tool — Go CLI (4 GAPs + incident overlay)
**Archived**: 2026-09-09 → `openspec/changes/archive/2026-09-09-sdd-tool/`
**Archive mode**: openspec (filesystem)
**Verdict at close**: PASS WITH WARNINGS — no CRITICAL findings; change complete, specs synced, cycle closed.

## Readback Traceability (observations actually read)

Openspec store — these file paths were read during the archive phase (equivalent of Engram observation IDs for openspec mode):

- `openspec/changes/sdd-tool/proposal.md`
- `openspec/changes/sdd-tool/design.md`
- `openspec/changes/sdd-tool/tasks.md`
- `openspec/changes/sdd-tool/verify-report.md`
- `openspec/changes/sdd-tool/specs/sdd-tool-cli/spec.md`
- `openspec/changes/sdd-tool/specs/sdd-tool-retro/spec.md`
- `openspec/changes/sdd-tool/specs/sdd-tool-worktree/spec.md`
- `openspec/changes/sdd-tool/specs/sdd-tool-dashboard/spec.md`
- `openspec/changes/sdd-tool/specs/sdd-tool-incidents/spec.md`
- `openspec/changes/sdd-tool/specs/workflow-contract/spec.md`
- `openspec/specs/workflow-contract/spec.md` (existing main spec, composition input)
- `skills/_shared/openspec-convention.md`, `skills/_shared/sdd-phase-common.md`, `openspec/config.yaml`

Also confirmed in the archived folder: `quest.md`, `exploration.md`, `council.md`, `arch-lint.md`, `apply-progress.md`, `retrospective.md`.

## Final State (terminal record, per Final-State Authority)

### Task Completion Gate

The persisted tasks artifact (`tasks.md`) reflects the final state: **20/20 implementation tasks checked** (`- [x]`), **0 unchecked** (`- [ ]`). No stale checkboxes; no archive-time reconciliation was needed. All seven phases (Foundation, Retro+scrub, Worktree, Dashboard, Incidents, Wiring, RED suite T40+) and the corrective run are complete.

### Verification

`verify-report` (intermediate snapshot, verification time): verdict `pass_with_warnings`, **blockers 0, critical_findings 0**, requirements 27/27, scenarios 47/47; go build/vet exit 0; 37 unit tests PASS / RED suite 50 PASS — 0 FAIL — 0 SKIP (exit 0). Both prior CRITICALs (CRITICAL-1 RED suite not green as shipped; CRITICAL-2 archived retro dedupe broken) are closed with runtime evidence in that report.

**Work completed after verify-report was persisted** (final-state facts from the orchestrator launch prompt, higher rank than the snapshot):

1. **Archive-close retro contract implemented** — commit `7597757` "fix(sdd-tool): retro persist --verify-domain implements archive-close contract": `ResolvePersistBody` derives Verification Gaps + Verify-Phase Incidents from the verify-report when `--verify-domain` is passed; `ExtractVerifyDomain` fixed (shared lookup bug — retains section content, not just headings); `extractH2Sections` strict whole-heading extraction; **11 new unit tests** in `internal/retro/retro_test.go`; go build/vet/test all green. This closes the verify-report's WARNING-6 gap (S36 "Verify gets only verify-domain content" — the gaps+incidents mechanism now exists).
2. **RED suite hang fixed** — commit `d5affd5` "fix(tests): red-check hang from orphaned fake_api processes + per-test timing traces": `sandbox.sh` tracks ALL fake_api PIDs (array) and redirects child stderr away from runner FDs; `run_red_checks.sh` helpers print per-test elapsed time and a total-duration summary.
3. **Retrospective persisted pre-archive** — `retro persist --change sdd-tool --verify-domain` ran with exit 0 (mode `both`): `openspec/changes/sdd-tool/retrospective.md` written AND engram mirror saved (topic `sdd/sdd-tool/retrospective`, obs #570). The retro file is present in the archived folder (traveled via the folder move; archive readback clean). This satisfies the archive-close retro hook before the folder move.
4. **Runtime ledger settled** — the persist remediation attempt passed, then a maintainer-authorized reset cleared the changed-line budget so archive could open. No further runtime ledger action pending from the orchestrator's side.

### Known pre-existing, out-of-scope state (explicitly NOT part of this change)

Per the launch prompt: the working tree carries unrelated modifications (`srv/gh-mcp-server/dryrun.py`, `gh_auth.py`, `README.md`, untracked `.codegraph/`, `docs/diagrams/`, `skills/archify/`, `squashfs-root/`, tests) that were not touched by this archive. The RED suite currently shows **8–9 FAILs caused by worktree-lifecycle-v2 commit `76f248a` not yet synced** (desyncs in `orchestrator.md` + `using-git-worktrees` skill; MCP ECHO_PROTOCOL count 7→9). This is attributable to that unrelated commit, NOT to the sdd-tool change, and was deliberately NOT fixed here. At verification time the sdd-tool RED checks were 50/0/0; the current suite FAILs are the unrelated desync, not a regression of this change.

## Specs Synced (delta → main)

| Domain | Action | Details |
|--------|--------|---------|
| sdd-tool-cli | Created (mechanical copy, `diff -r` clean) | 4 requirements / 9 scenarios |
| sdd-tool-retro | Created (mechanical copy, `diff -r` clean) | 6 requirements / 8 scenarios |
| sdd-tool-worktree | Created (mechanical copy, `diff -r` clean) | 3 requirements / 6 scenarios |
| sdd-tool-dashboard | Created (mechanical copy, `diff -r` clean) | 4 requirements / 5 scenarios |
| sdd-tool-incidents | Created (mechanical copy, `diff -r` clean) | 5 requirements / 6 scenarios |
| workflow-contract | Updated (native `gentle-ai sdd-archive-compose`, exit 0) | +5 ADDED requirements (Prior-context injection, Archive-close fixed persist order, Worktree verify rule 5 integration, Incident recording hook, Overlay clauses present with fail-open posture); all 13 pre-existing requirements preserved byte-for-byte (18 total) |

Main spec count: 27 requirements / 47 scenarios across the 6 domains.

## Archive Move

Source `openspec/changes/sdd-tool/` → `openspec/changes/archive/2026-09-09-sdd-tool/` via `git mv` (no fallback needed). Pre-move recursive snapshot compared with the archived tree: **`diff -r` readback EMPTY** (verbatim output captured in the phase result). All 11 artifacts (proposal, specs/ 6 domains, design, tasks, verify-report, apply-progress, retrospective, quest, exploration, council, arch-lint) present in the archive. Active changes directory no longer contains this change. No archive-suffix/overwrite/merge decisions were needed (destination did not exist).

## Intentional Archive Notes

- Archive is **complete**, not partial — no missing proposal/spec/design artifacts (all present).
- No archive-time stale-checkbox reconciliation was performed (tasks artifact was already complete).
- No CRITICAL verification issues — none blocked close.
- `rules.archive` from `openspec/config.yaml` ("Warn before merging destructive overlay deltas") — not triggered: workflow-contract delta was purely ADDED; no destructive merge.

## Cycle State

The SDD cycle for `sdd-tool` is COMPLETE: planned (quest → explore → propose → spec → design → council → arch-lint), implemented (20/20 tasks), verified (pass with warnings, 0 CRITICAL), and archived (specs synced, folder moved, retro hook satisfied). Ready for the next change.