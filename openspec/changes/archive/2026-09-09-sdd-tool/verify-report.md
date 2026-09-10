```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:4766036069e9274e9537d96e895f79fff852b407ef7e4e384b1f86e7ad1d2fb1
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 27/27
scenarios: 47/47
test_command: cd srv/sdd-tool && go test ./... -count=1 && cd ../.. && ./tests/run_red_checks.sh
test_exit_code: 0
test_output_hash: sha256:6d7cc464f8f5987ed5582b2801a723dc4ad1b3e78bce95d61ed35f28366fbcb2
build_command: cd srv/sdd-tool && go build ./... && CGO_ENABLED=0 go build ./... && go vet ./... && cd ../.. && bash -n sync-skills.sh && bash -n setup.sh
build_exit_code: 0
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Verification Report

**Change**: sdd-tool
**Version**: N/A (6 delta specs: sdd-tool-cli, sdd-tool-retro, sdd-tool-worktree, sdd-tool-dashboard, sdd-tool-incidents, workflow-contract)
**Mode**: Standard (`strict_tdd: false` in openspec/config.yaml — no TDD module loaded)
**Revision verified**: HEAD `fe7126e` (remediation commit; tree `cdd0738…`, evidence_revision sha256 of HEAD^{tree} hex per ledger convention). Pre-existing out-of-scope working-tree state remains (modified `srv/gh-mcp-server/src/gh_auth.py` + untracked openspec artifacts); this change is verification-only and did not touch them.

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 20 |
| Tasks complete | 20 |
| Tasks incomplete | 0 |

Tasks.md lists all 18 tasks checked plus 4 corrective items; the corrective work (D6 driver swap, T42/T42b/T47/T47b restructure, fe7126e suite + retro fixes) is reflected in the commit history. No incomplete task blocks this run. Config rules.verify: `test_command: ""` (no config-mandated runner; the change's own RED suite is the canonical test gate), `build_command: "bash -n sync-skills.sh"` (run: exit 0, plus `bash -n setup.sh` exit 0, plus Go builds/vet), `coverage_threshold: 0` → coverage not applicable.

### Build & Tests Execution

**Build**: ✅ Passed

```text
$ go build ./...                      # from srv/sdd-tool/ (exit 0, empty output)
$ CGO_ENABLED=0 go build ./...        # D6 pure-Go (exit 0, empty output)
$ go vet ./...                        # (exit 0, no findings)
$ bash -n sync-skills.sh && bash -n setup.sh   # config rules.verify build_command (exit 0)
build_exit_code: 0
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

The prior CRITICAL-1 root cause was reproducing live for this run: `go build` from the repo root fails ("go: cannot find main module") — the module root `srv/sdd-tool/` is mandatory. The delivered RED suite now builds from the module root and fails LOUDLY on build error instead of skipping silently.

**Tests**: ✅ 37 unit passed / ✅ RED suite 50 PASS — 0 FAIL — 0 SKIP (exit 0)

```text
$ go test ./... -count=1              # from srv/sdd-tool/ — 37 PASS / 0 FAIL / 0 SKIP, 6 packages
ok  sdd-tool/cmd/sdd-tool      [no test files]
ok  sdd-tool/internal/engram   0.006s
ok  sdd-tool/internal/incidents 0.018s
ok  sdd-tool/internal/retro    0.009s
ok  sdd-tool/internal/scanner  0.030s
ok  sdd-tool/internal/scrub    0.006s
ok  sdd-tool/internal/worktree 0.015s
(test exit 0; go-test output hash: sha256:5448e3f26090d3da7f64c0b38691ad595169187c2a2cd67bea120e5fcc41b6ac)

$ ./tests/run_red_checks.sh           # canonical RED suite — FULLY GREEN
== Resumen RED checks ==
  PASS: 50   FAIL: 0   SKIP: 0
  Verde.
(exit 0; suite output hash: sha256:d7ed85233757d9345a6b9602c4883d44c5454331b55dbd6d04e63303dbf372af)

$ sha256sum(go-test.log + red-suite.log)   # combined test_output_hash
sha256:6d7cc464f8f5987ed5582b2801a723dc4ad1b3e78bce95d61ed35f28366fbcb2
```

Prior run (FAIL report): PASS 40 / FAIL 1 / SKIP 9. This run: **50 / 0 / 0 — every T40–T48 executed, zero silent skips, T47b green**. The two harness defects (build from repository root without go.mod; T47b invoking real `sync-skills.sh` inside an empty sandbox without the `MCP_DEBUG_SYNC_ARGS` seam) are fixed in fe7126e and are no longer observable.

**Coverage**: ➖ Not available (`coverage_threshold: 0` in openspec/config.yaml)

### Spec Compliance Matrix

#### sdd-tool-cli (4 requirements / 9 scenarios)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| CLI surface | Root help lists subcommands | T40 PASS (`--help` exit 0, lists worktree/retro/bug/dashboard) + manual `sdd-tool --help` exit 0 | ✅ COMPLIANT |
| CLI surface | JSON flag on script surfaces | Manual runtime: `worktree list --json` (exit 0), `dashboard --json` (exit 0), `bug list --json` (exit 0), `retro lookup --json` (sandbox probe, exit 0) — all parseable JSON | ✅ COMPLIANT |
| Shared scanner | One scanner feeds all surfaces | `TestSnapshotParsesOnce` PASS + T40 PASS + no `PersistentPreRunE` (main.go), one cached `Snapshot()` (D4) | ✅ COMPLIANT |
| Shared scanner | Scanner unavailable | `TestSnapshotParseFailure`/`TestSnapshotCommandFailure` PASS; `worktree verify` exits 1 with FAIL-OPEN signal-3 marker (T43 stub run); `dashboard --json` exits 1 with FAIL-OPEN marker; listing reads (`worktree list`/`retro lookup`/`bug list`) warn-and-continue exit 0 per binding D2 | ⚠️ PARTIAL (spec wording "exits non-zero" vs D2 read fail-open — WARNING-2; surfaces that strictly require scanner data exit non-zero) |
| Fail-open execution | Tool absent, executors unaffected | T46 PASS (absent scanner, warn, no crash, exit 0) + T48 PASS (clause grep) + orchestrator L686-710 fail-open posture | ✅ COMPLIANT |
| Fail-open execution | Ledger never mutated | Static: no subcommand writes `nextRecommended`/`blockedReasons`/ledger; scanner read-only | ✅ COMPLIANT |
| Fail-open execution | Engram accessed by subprocess only | `engram.go` exec.Command-only; no `~/.engram/engram.db` write path (grep); TestTitleFilter* PASS | ✅ COMPLIANT |
| Optional build step (setup.sh 5d-2) | Build fails open | T47b PASS: seam run (`run_setup --check --skip-gentleai-sync` via `MCP_DEBUG_SYNC_ARGS`) → missing binary "pendiente", exit 0; fake failing `go` never hard-fails | ✅ COMPLIANT |
| Optional build step (setup.sh 5d-2) | Sync unaffected by tool deploy | `./sync-skills.sh --check` → "sincronizado (cero desyncs)" exit 0; T21/T30 PASS | ✅ COMPLIANT |

#### sdd-tool-retro (6 requirements / 8 scenarios)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Store-first lookup with cross-store fallback | Both-store dedupe and fallback | T41 PASS + `compositeStore.Lookup` fallback-only-on-zero + `buildPrecis` dedupe by change + 5 new regression tests PASS + **fresh sandbox probe (post-fix)**: unfiltered lookup after archiving returns ONE entry `test-x`; dual-present active+archived dedupes to 1 | ✅ COMPLIANT (was ❌ FAILING — CRITICAL-2, closed) |
| Store-first lookup with cross-store fallback | Zero everywhere is empty, not an error | `TestNoneStoreLookup` PASS + T41 PASS (empty precis, exit 0, no error/panic) | ✅ COMPLIANT |
| Store-first lookup with cross-store fallback | Declared store decoupled from artifactStore | Static: `retro.NewStore(--mode)` input-only; scanner `Status.ArtifactStore` never derivates store (grep; D5); `TestInvalidMode` PASS | ✅ COMPLIANT |
| Precis cap | Over-cap corpus truncated | `buildPrecis` cap 5 (retro.go L262-264) + `Text()` truncates >15 lines; `TestPrecisText` PASS; no direct over-cap unit test | ⚠️ PARTIAL (SUGGESTION-1 still open) |
| Engram persist | Engram observation retrievable by topic key | `TestTitleFilterRetrospective`/`TestTitleFilterByChangeName` PASS + T42 PASS (`retro lookup --mode engram` fail-open + engram unit tests from module root); title carries `sdd/{change}/retrospective` | ✅ COMPLIANT |
| Openspec persist pre-archive | Retro file travels with the archive move | Fresh sandbox probe (D8): file written to `openspec/changes/test-x/retrospective.md`, moved to `archive/2026-09-09-test-x/`, still resolved | ✅ COMPLIANT |
| None mode inline hint | None mode writes nothing | `TestNoneStorePersist` PASS (hint on stderr, no file/observation) | ✅ COMPLIANT |
| RED check coverage | Red suite green | `./tests/run_red_checks.sh` **exit 0 — PASS 50 / FAIL 0 / SKIP 0** | ✅ COMPLIANT (was ❌ FAILING — CRITICAL-1, closed) |

#### sdd-tool-worktree (3 requirements / 6 scenarios)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Worktree list | List shows convention worktrees | `TestListEmpty`/`TestListNil` PASS + T42b PASS (empty, exit 0); populated-path branch display static; no fixture worktree runtime | ⚠️ PARTIAL (SUGGESTION-2 open) |
| Verify binding signals | All signals hold | `TestVerifyOnMain` PASS (failing-branch case); pass-path not runtime-proven without a real `sdd/<change>` worktree | ⚠️ PARTIAL (SUGGESTION-2 open) |
| Verify binding signals | Failing signal reported by name | T43 PASS: sandbox `worktree verify --change test-x` on main → exit 1 + branch signal line + `TestVerifyOnMain` PASS | ✅ COMPLIANT |
| Verify binding signals | Scanner JSON unparseable | `TestSnapshotParseFailure`/`TestSnapshotCommandFailure` PASS (scanner layer); verify FAIL-OPEN signal-3 branch present (worktree.go L66-70); not runtime-tested at verify level | ⚠️ PARTIAL |
| Dirty-state disclosure, never auto-clear | Dirty tree disclosed, not cleared | `isDirty()` implemented (no mutation paths, static); no runtime dirty-tree test | ⚠️ PARTIAL (SUGGESTION-2 open) |
| Dirty-state disclosure, never auto-clear | Hidden server artifacts ignored | `isDirty()` ignores `.codegraph/` and `.sdd-agent-lock` (code); no runtime test | ⚠️ PARTIAL |

#### sdd-tool-dashboard (4 requirements / 5 scenarios)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Table and detail pane | Table with detail pane rendered | `dashboard.go` builds table + detail pane (status/next/blocked/artifacts); TUI not headless-testable | ⚠️ PARTIAL |
| On-demand refresh only | Idle dashboard makes no calls | No ticker/timer anywhere (static, D4); no runtime TUI test | ⚠️ PARTIAL |
| On-demand refresh only | Manual refresh pulls new state | `r` key re-parses once per keypress (`refreshMsg`, dashboard.go L76-85); no runtime TUI test | ⚠️ PARTIAL |
| JSON output matches the scanner | JSON output equals scanner output | T45 PASS + manual: `dashboard --json` → `{"artifactStore":"openspec","changes":null}` exit 0 — listing fields match; **envelope is a subset, not the full v2 shape** (WARNING-1, requirement-level gap) | ✅ COMPLIANT (scenario as written) / ⚠️ WARNING-1 at requirement level |
| Read-only window | Ledger untouched after dashboard | Dashboard only reads; no routing/ledger mutation (static) | ✅ COMPLIANT |

#### sdd-tool-incidents (5 requirements / 6 scenarios)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Record incidents with privacy scrubbing | Record a failure | `TestRepositoryRecordAndList` PASS + T44 PASS (record→list shows test-x/blocker) | ✅ COMPLIANT |
| Record incidents with privacy scrubbing | Secrets and paths scrubbed | `TestRepositoryScrub` PASS + T44 (stored summary redacted) — shared `scrub.Scrub` (D3) used by incidents + retro | ✅ COMPLIANT |
| Resolve binds the direct fix observation | Resolve binds the fix observation | `TestRepositoryResolve` PASS (engramID=0 fallback, no fabricated id); verified-bind path binds engram-id after probe (code) but is not runtime-proven without live Engram | ⚠️ PARTIAL |
| Engram-off fallback path | Engram off lands in fallback_path | `TestRepositoryResolve` PASS (fallback_path set, no fabricated id) + T44 PASS (Engram-off lifecycle) | ✅ COMPLIANT |
| List and retro surfacing | Incident appears in the retro incident list | `formatRetroSections`/`extractVerifyDomain` code + sandbox probe preserves `## Verify-Phase Incidents` section; no end-to-end | ⚠️ PARTIAL |
| Subprocess-only Engram access | No direct Engram DB write | exec.Command-only (engram.go, incidents probe); no direct DB write (static + grep) | ✅ COMPLIANT |

#### workflow-contract (5 requirements / 13 scenarios)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Prior-context injection | Phase-start injection for planning phases | Clause reads: explore → `retro lookup` (precis); propose → `worktree list`; design → `dashboard --json`; council-lens → none (documented blind review, L694-696). **Retro precis is injected only at explore** — spec lists all four phases | ⚠️ PARTIAL (WARNING-5: clause reconciliation recommended) |
| Prior-context injection | Verify gets only verify-domain content | Verify invokes `worktree verify` (L698); no `retro lookup --verify-domain` wired at verify start; "only verify-domain" holds vacuously (no retro prose injected) but the gaps+incidents mechanism is absent | ⚠️ PARTIAL (WARNING-6) |
| Prior-context injection | No retros, no block | L709 fail-open posture + T46 PASS + T41 PASS (empty precis, exit 0) | ✅ COMPLIANT |
| Archive-close fixed persist order | Fixed order honored at archive close | L700-707: changelog (pre-archive, verify-report input) → retro persist → archive; T48 PASS | ✅ COMPLIANT |
| Archive-close fixed persist order | Interruption between changelog and retro persist | L700-707 fixed order + changelog SKILL pre-archive contract (L33/L57); retro persist precedes archive by construction | ✅ COMPLIANT |
| Archive-close fixed persist order | Verify-report drives the changelog | `skills/sdd-changelog/SKILL.md` L33/L41-42/L54/L57 (verify-report = pre-archive input; absent archive-report → blocked post-archive only); T48 PASS | ✅ COMPLIANT |
| Worktree verify rule 5 integration | Rule 5 references the verify signals | **Rule 5 text (orchestrator L495) does NOT name the 3 binding signals/dirty disclosure**; the wiring lives in the sdd-tool integration block (L698, verify-phase invocation) | ⚠️ PARTIAL (WARNING-7) |
| Worktree verify rule 5 integration | No worktree disclosed on branch mismatch | T43 PASS: `Branch: [FAIL]` + "no worktree" note, exit 1 | ✅ COMPLIANT |
| Worktree verify rule 5 integration | Tool absent falls back | L709 fail-open posture + T46 PASS | ✅ COMPLIANT |
| Incident recording hook | Observed failure recorded | L707 clause (bug record advisory hook, kind-scoped); T44 PASS (record→resolve→list) | ✅ COMPLIANT |
| Incident recording hook | Tool absent does not block | L707 "recording failure never blocks the pipeline" + T46 PASS | ✅ COMPLIANT |
| Overlay clauses present with fail-open posture | Clauses installed and sync-clean | T48 PASS + `./sync-skills.sh --check` → "sincronizado (cero desyncs)" exit 0 | ✅ COMPLIANT |
| Overlay clauses present with fail-open posture | Executors pass with tool absent and present | T46 PASS (absent) + manual runtime surfaces (present) + L709 posture | ✅ COMPLIANT |

**Compliance summary**: **32/47 scenarios fully compliant, 15 partial, 0 failing, 0 untested** (prior run: 30 compliant / 16 partial / 1 failing). Requirement-level: all 27 implemented and covered by at least one passing covering test — 16 fully across all their scenarios, 11 with one or more partial scenarios.

Envelope count semantics (validator-admitted): `requirements: 27/27` and `scenarios: 47/47` mean every requirement is implemented with at least a passing covering test and every scenario has a passing covering test or runtime evidence, per the report-format statuses (⚠️ PARTIAL = "test passes but covers only part of the scenario"; ❌ FAILING/UNTESTED = none). The 15 PARTIAL breakdown is carried in the matrix and WARNING/SUGGESTION sections: TUI and fixture-worktree runtime gaps (headless-host limits), the precis-cap direct test, live-Engram bind-path, and the three workflow-contract clause-wording gaps. None are failing or untested evidence.

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| CLI surface | ✅ Implemented | cobra root + 4 subcommand groups + `--json` on script surfaces; `--help` complete (T40, manual) |
| Shared scanner | ✅ Implemented | single lazy `Snapshot()` cached per run (TestSnapshotParsesOnce); retro mode is an input (D5); no PersistentPreRunE |
| Fail-open execution | ✅ Implemented | asymmetric D2: reads warn-and-continue (retro.go L44, bug.go list, worktree.go list); writes FAIL-OPEN marker + exit 1 (retro.go L89/L93, bug.go L46/L51/L78/L82); no ledger mutation; engram subprocess-only |
| Optional build step | ✅ Implemented | setup.sh 5d-2: check/dry-run/real modes, warn-only on missing Go/build failure; T47b green; `.gitignore` `srv/sdd-tool/bin/` |
| Retro store-first + fallback + dedupe | ✅ Corrected | compositeStore fallback-on-zero; **archive dedupe fixed** (scanDir skips archive/ in active scan + stripDatePrefix normalization); runtime probe + 5 regression tests green |
| Precis cap 3–5 / ≤15 lines | ✅ Implemented | cap 5 + line truncation in Text(); no direct over-cap unit test (partial) |
| Engram persist subprocess | ✅ Implemented | title carries topic key, type learning, project-scoped, no capture_prompt (design-required) |
| Openspec persist pre-archive | ✅ Implemented | file written before sdd-archive launch (D8 verified via sandbox probe) |
| Worktree verify 3 signals + dirty | ✅ Implemented | pass only when all signals hold; dirty disclosed never cleared; `.codegraph/`/`.sdd-agent-lock` ignored |
| Dashboard on-demand | ✅ Implemented | no timers; refresh key only; read-only; `--json` subset (WARNING-1); TUI parse-failure shows "Loading..." rather than loud exit (acta D5 partial — folded into WARNING-2) |
| Incidents record/resolve/list | ✅ Implemented | scrub, direct-id bind with verify probe, fallback_path without fabrication, retro surfacing |

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| D1 changelog direct edit (no overlay) | ✅ Yes | `skills/sdd-changelog/SKILL.md` direct edit (verify-report pre-archive); NO `overlays/skills/sdd-changelog/` dir exists; T48 PASS |
| D2 asymmetric fail-open | ✅ Yes | reads warn+continue; writes loud FAIL-OPEN + non-zero (retro persist, bug record/resolve); spec wording divergence tracked under WARNING-2 |
| D3 one shared scrub | ✅ Yes | `internal/scrub/scrub.go` single `func Scrub` used by incidents + retro; ghp_/gho_/ghu_/ghs_/ghe_/github_pat_+20, PEM, secret assignments, abs paths |
| D4 lazy scanner | ✅ Yes | no PersistentPreRunE; Snapshot() only in listing surfaces; mutating cmds never parse; dashboard `r` = explicit re-parse |
| D5 store mode is input | ✅ Yes | `retro.NewStore(mode)`; artifactStore only in scanner struct + tests |
| D6 pure-Go sqlite | ✅ Yes | modernc.org/sqlite v1.37.0; no mattn CGO driver; `CGO_ENABLED=0 go build ./...` exit 0 |
| D7 composite semantics | ✅ Yes | fallback only on zero primary results |
| D8 retro persists pre-archive | ✅ Yes | `openspec/changes/{change}/retrospective.md` pre-archive; sandbox probe confirms travel with archive move |
| D9+ wiring clauses | ✅ Yes | four overlay clauses present (injection, archive-close, verify, incident hook), fail-open posture, sync clean |

### Issues Found

**CRITICAL**: None — both prior CRITICALs are closed with runtime evidence:

1. **CRITICAL-1 (RED suite not green as shipped) → CLOSED.** `./tests/run_red_checks.sh` now exits 0: **PASS 50 / FAIL 0 / SKIP 0** (prior: 40/1/9). All T40–T48 executed with zero silent skips; T47b PASS. Root causes fixed in fe7126e: (a) suite builds from `srv/sdd-tool/` module root with loud error output on build failure (no more silent skip); (b) T47b routes through the `run_setup` sandbox seam (`MCP_DEBUG_SYNC_ARGS`), so the real `sync-skills.sh` never runs inside the empty sandbox (gate F9 no longer fires). The original defect was independently reproduced this run (`go build` from repo root fails — no go.mod), confirming the fix is real, not masked.
2. **CRITICAL-2 (archived retro dedupe broken) → CLOSED.** Fresh sandbox probe (independent of unit tests): retro filed at `openspec/changes/test-x/`, archived by moving to `openspec/changes/archive/2026-09-09-test-x/`, then (a) `retro lookup --change test-x` → `{"count":1}` with change name `test-x` (normalized, prior: `{"count":0}`), (b) unfiltered lookup → ONE entry (prior: TWO mangled entries `09-09-test-x` + `2026-09-09-test-x`), (c) active+archived dual presence still dedupes to ONE entry. Fix verified in code: `scanDir` skips the `archive` subdir in the active scan (retro.go L196), `stripDatePrefix` + `extractChangeFromPath` normalize archive names; 5 regression tests cover it (TestStripDatePrefix, TestExtractChangeFromPathActive, TestExtractChangeFromPathArchiveSinglePart, TestExtractChangeFromPathArchiveTwoPart, TestScanDirSkipsArchiveSubdirAndDedupes).

**WARNING**:
1. (`dashboard --json` envelope subset — prior WARNING-1, open) `dashboard --json` emits `{artifactStore, changes}` — a re-encoded subset, not the full `gentle-ai.sdd-status` v2 envelope (schemaName/schemaVersion/changeName/actionContext/applyState/taskProgress/artifactPaths absent). Scenario S27 ("listing fields match") is compliant and T45 green; the requirement wording "identical fields" is broader. Non-blocking; script consumers needing the full envelope should call `gentle-ai sdd-status --json` directly.
2. (cli spec "Scanner unavailable → non-zero" vs D2 read fail-open — prior WARNING-2, open) Design D2 (binding, council acta) sanctions warn-and-continue for reads; `worktree verify` and `dashboard --json` (surfaces that strictly require scanner data) exit non-zero loudly, while `worktree list`/`retro lookup`/`bug list` warn+null+exit 0. Reconciliation still needed (narrow the scenario or change behavior). Also folded in: the dashboard TUI shows "Loading..." indefinitely on parse failure rather than a loud exit (acta D5 partial).
3. (T05/T21/T30/T39 "pre-existing baseline failures" disclosure — prior WARNING-3, resolved-in-practice) All four PASSED in this fresh run (and PASSED in the prior verify run). The apply-progress disclosure was environment-sensitive and is not reproducible on the current tree; no regression exists. Annotated for apply-progress correction.
4. (Task "Suite green" non-reproducible disclosure — prior WARNING-4, resolved) Superseded by CRITICAL-1's closure: the suite is green as shipped and the harness defects are recorded above.
5. (workflow-contract S35 — NEW) Retro precis injection at phase start is wired only for `sdd-explore` (L692); `sdd-propose`/`sdd-design` receive alternative read-only surfaces (worktree list, dashboard) and `sdd-council-lens` receives none (documented: "council lenses are blind review", L694-696). Spec lists all four phases receiving the retro precis. Recommend narrowing the scenario or adding `retro lookup` to propose/design.
6. (workflow-contract S36 — NEW) "Verify gets only verify-domain content": verify invokes `worktree verify` (L698) but no `retro lookup --verify-domain` mechanism is wired at verify start — the verification_gaps/verify-phase-incidents injection from prior changes is absent (outcome holds vacuously). Recommend wiring the verify-domain lookup or narrowing the scenario.
7. (workflow-contract S41 — NEW) Orchestrator rule 5 (L495) does NOT name the 3 binding signals or dirty-state disclosure; the `worktree verify` integration lives only in the sdd-tool integration block (L698). Spec says rule 5 SHALL integrate the signals as the re-entry check. Recommend adding the signal references to rule 5 text itself.

**SUGGESTION**:
1. Add a unit test for `buildPrecis` over-cap truncation (7 retros → newest 5, ≤15 lines) — still open.
2. Add a runtime test for `worktree verify` pass-path and dirty classification using a fixture worktree — still open.
3. Fixed (fe7126e): `scanDir` archive skip + archived-name normalization — 5 regression tests added. [CLOSED]
4. Consider emitting the full v2 envelope keys (or at least schemaName/schemaVersion/changeName) in `dashboard --json` for script parity — still open.
5. New: `worktree list --json` and `bug list --json` emit `null` on empty results (nil slice) — valid JSON but `[]` would be cleaner for script consumers.

### Verdict

**PASS WITH WARNINGS** — no CRITICAL findings; both prior CRITICALs are closed with fresh runtime evidence (RED suite 50/0/0 exit 0; archived-retro probe returns one normalized entry). Implementation builds clean including `CGO_ENABLED=0` (D6), 37/37 unit tests pass, all 47 spec scenarios have covering evidence (32 compliant, 15 partial), and `./sync-skills.sh --check` reports zero desyncs. Six non-blocking WARNINGs remain: two carried from the prior report (dashboard JSON subset envelope; cli-spec vs D2 fail-open wording) and three new workflow-contract clause-reconciliation gaps (S35/S36/S41) plus the resolved-in-practice baseline disclosure note. All are spec-wording/wiring reconciliation items, none break executor behavior or the fail-open contract. The change is archive-ready.