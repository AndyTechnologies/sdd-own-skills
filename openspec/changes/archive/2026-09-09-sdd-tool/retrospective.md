---
change: sdd-tool
phase: verify
store-mode: openspec
---

## What Worked

(none)

## What Didn't

(none)

## Verification Gaps

- **WARNING**:
- 1. (`dashboard --json` envelope subset — prior WARNING-1, open) `dashboard --json` emits `{artifactStore, changes}` — a re-encoded subset, not the full `gentle-ai.sdd-status` v2 envelope (schemaName[redacted] absent). Scenario S27 ("listing fields match") is compliant and T45 green; the requirement wording "identical fields" is broader. Non-blocking; script consumers needing the full envelope should call `gentle-ai sdd-status --json` directly.
- 2. (cli spec "Scanner unavailable → non-zero" vs D2 read fail-open — prior WARNING-2, open) Design D2 (binding, council acta) sanctions warn-and-continue for reads; `worktree verify` and `dashboard --json` (surfaces that strictly require scanner data) exit non-zero loudly, while `worktree list`/`retro lookup`/`bug list` warn+null+exit 0. Reconciliation still needed (narrow the scenario or change behavior). Also folded in: the dashboard TUI shows "Loading..." indefinitely on parse failure rather than a loud exit (acta D5 partial).
- 3. (T05[redacted] "pre-existing baseline failures" disclosure — prior WARNING-3, resolved-in-practice) All four PASSED in this fresh run (and PASSED in the prior verify run). The apply-progress disclosure was environment-sensitive and is not reproducible on the current tree; no regression exists. Annotated for apply-progress correction.
- 4. (Task "Suite green" non-reproducible disclosure — prior WARNING-4, resolved) Superseded by CRITICAL-1's closure: the suite is green as shipped and the harness defects are recorded above.
- 5. (workflow-contract S35 — NEW) Retro precis injection at phase start is wired only for `sdd-explore` (L692); `sdd-propose`/`sdd-design` receive alternative read-only surfaces (worktree list, dashboard) and `sdd-council-lens` receives none (documented: "council lenses are blind review", L694-696). Spec lists all four phases receiving the retro precis. Recommend narrowing the scenario or adding `retro lookup` to propose[redacted]
- 6. (workflow-contract S36 — NEW) "Verify gets only verify-domain content": verify invokes `worktree verify` (L698) but no `retro lookup --verify-domain` mechanism is wired at verify start — the verification_gaps[redacted] injection from prior changes is absent (outcome holds vacuously). Recommend wiring the verify-domain lookup or narrowing the scenario.
- 7. (workflow-contract S41 — NEW) Orchestrator rule 5 (L495) does NOT name the 3 binding signals or dirty-state disclosure; the `worktree verify` integration lives only in the sdd-tool integration block (L698). Spec says rule 5 SHALL integrate the signals as the re-entry check. Recommend adding the signal references to rule 5 text itself.
- **SUGGESTION**:
- 1. Add a unit test for `buildPrecis` over-cap truncation (7 retros → newest 5, ≤15 lines) — still open.
- 2. Add a runtime test for `worktree verify` pass-path and dirty classification using a fixture worktree — still open.
- 3. Fixed (fe7126e): `scanDir` archive skip + archived-name normalization — 5 regression tests added. [CLOSED]
- 4. Consider emitting the full v2 envelope keys (or at least schemaName[redacted]) in `dashboard --json` for script parity — still open.
- 5. New: `worktree list --json` and `bug list --json` emit `null` on empty results (nil slice) — valid JSON but `[]` would be cleaner for script consumers.


## Verify-Phase Incidents

- **CRITICAL**: None — both prior CRITICALs are closed with runtime evidence:
- 1. **CRITICAL-1 (RED suite not green as shipped) → CLOSED.** `.[redacted]` now exits 0: **PASS 50 / FAIL 0 / SKIP 0** (prior: 40[redacted]). All T40–T48 executed with zero silent skips; T47b PASS. Root causes fixed in fe7126e: (a) suite builds from `srv[redacted]` module root with loud error output on build failure (no more silent skip); (b) T47b routes through the `run_setup` sandbox seam (`MCP_DEBUG_SYNC_ARGS`), so the real `sync-skills.sh` never runs inside the empty sandbox (gate F9 no longer fires). The original defect was independently reproduced this run (`go build` from repo root fails — no go.mod), confirming the fix is real, not masked.
- 2. **CRITICAL-2 (archived retro dedupe broken) → CLOSED.** Fresh sandbox probe (independent of unit tests): retro filed at `openspec[redacted]`, archived by moving to `openspec[redacted]`, then (a) `retro lookup --change test-x` → `{"count":1}` with change name `test-x` (normalized, prior: `{"count":0}`), (b) unfiltered lookup → ONE entry (prior: TWO mangled entries `09-09-test-x` + `2026-09-09-test-x`), (c) active+archived dual presence still dedupes to ONE entry. Fix verified in code: `scanDir` skips the `archive` subdir in the active scan (retro.go L196), `stripDatePrefix` + `extractChangeFromPath` normalize archive names; 5 regression tests cover it (TestStripDatePrefix, TestExtractChangeFromPathActive, TestExtractChangeFromPathArchiveSinglePart, TestExtractChangeFromPathArchiveTwoPart, TestScanDirSkipsArchiveSubdirAndDedupes).
