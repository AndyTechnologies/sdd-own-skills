```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:7fdc9f7531302fb361493d259f12c79491a48119dd6d51d3001caa9b983ac239
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 19/19
scenarios: 47/47
test_command: .venv/bin/python -m pytest tests/test_worktree_state.py -v
test_exit_code: 0
test_output_hash: sha256:61da1c4067ced647b27e46c46bfcb91a29c3c5add0fb2c9927057cf9af8cafaa
build_command: bash -n sync-skills.sh
build_exit_code: 0
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Verification Report

**Change**: worktree-lifecycle-v2
**Version**: N/A (delta specs, 4 capabilities)
**Mode**: Standard (strict_tdd: false)

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 31 |
| Tasks complete | 31 |
| Tasks incomplete | 0 |

All 31 tasks checked `[x]` in `tasks.md`; zero unchecked. Apply-progress reports 31/31 with work-unit evidence; every claimed file exists in the worktree (no-hallucination spot-check passed: `worktree_state.py`, `test_worktree_state.py`, `lock.go`, `lock_test.go`, modified `worktree_mutation.py` / `local_read.py` / `envelope.py` / `worktree.go` / `orchestrator.md` / `SKILL.md`).

### Build & Tests Execution

**Build**: ✅ Passed

```text
bash -n sync-skills.sh → exit 0 (sha256 e3b0c44...)
```

**Tests**: ✅ 44 passed (Python, 0 failed) · Go observer: focused lock/stale/repo-name suite ✅ 11 passed; full Go suite ⚠️ 1 pre-existing branch-sensitive failure on the feature-branch cwd (see WARNING W1)

```text
.venv/bin/python -m pytest tests/test_worktree_state.py -v
→ 44 passed in 0.22s (pytest 9.1.1, Python 3.14.7)  [cwd srv/gh-mcp-server]
→ covers all 9 design classifier rows + ghost/unparsable-lock corrupt rows,
  acquire transitions (created/attached/claimed/already_mine + 3 denials),
  release matrix (happy/noop x3/corrupt/dirty-ok), index write-through +
  corrupt/missing rebuild + warn-only failure, dirty fail-closed, repo-name
  derivation, concurrency (same-owner-diff-session, different-owner), enriched list.
go test ./internal/worktree/... -run 'TestParseLockV2|TestIsStale|TestRepoName'
→ 11 PASS in 0.043s (version==2 guard rows v1/missing/corrupt/missing-file/v2;
  IsStale dead/alive/zero-nil-negative; RepoNameFromGitRoot toplevel/subdir/./,
  non-repo fallback, degenerate)  [cwd srv/sdd-tool in worktree]
go test ./internal/worktree/...  [feature-branch cwd] → FAIL: TestVerifyOnMain only
go test ./internal/worktree/...  [MAIN cwd] → ok (cached pass)
```

**Coverage**: ➖ Not available (threshold 0; no coverage tool configured in `openspec/config.yaml`)

**Supplementary sdd-tool evidence**: `sdd-tool worktree verify --change worktree-lifecycle-v2 --json` (built from worktree source) → `{"pass":true, root:pass, branch:pass, scanner:pass, dirty:true}` — all 3 binding signals confirmed from the worktree root; `dirty:true` reflects the change's uncommitted files (expected). `sdd-tool worktree list --json` → `null` (scanner-snapshot dependent, pre-existing behavior; the enriched list lives in the MCP `git_worktree_list`, verified via `test_enriched_list`). Binary not installed on PATH — built ad hoc; reported as supplementary evidence, not verdict input.

### Spec Compliance Matrix

#### Capability: worktree-lifecycle (7 requirements, 21 scenarios)

| Requirement | Scenario | Test / Evidence | Result |
|-------------|----------|-----------------|--------|
| 7-state classifier | Absent worktree | `test_classifier_rows[absent]` | ✅ COMPLIANT |
| | Absent branch exists | `test_classifier_rows[absent_branch_exists]` | ✅ COMPLIANT |
| | Exists stale | `test_classifier_rows[exists_stale_v1_dead]`, `[exists_stale_v2_dead]` | ✅ COMPLIANT |
| | Exists active mine | `test_classifier_rows[exists_active_mine]` | ✅ COMPLIANT |
| | Exists active other | `test_classifier_rows[exists_active_other_v1_alive]`, `[exists_active_other_v2_diff_session]` | ✅ COMPLIANT |
| | Corrupt | `test_classifier_rows[corrupt_dir_not_in_porcelain]`, `[corrupt_ghost_in_porcelain]`, `[corrupt_unparsable_lock]`, `test_classifier_porcelain_failure_is_corrupt` | ✅ COMPLIANT |
| | Legacy v1 lock treated as stale | `test_classifier_rows[exists_stale_v1_dead]` — see Spec-Delta 1 (design supersedes gloss for live-PID v1: `[exists_active_other_v1_alive]`) | ✅ COMPLIANT |
| Acquire tool | Acquire absent (create + lock + index + `.codegraph/` init) | `test_acquire_created` (asserts lock fields + index write-through + `("codegraph","init")` call) | ✅ COMPLIANT |
| | Acquire exists inactive | `test_acquire_attached` | ✅ COMPLIANT |
| | Acquire already mine | `test_acquire_already_mine_no_mutation` | ✅ COMPLIANT |
| | Acquire owned by other | `test_acquire_deny_owned_by_other` + `test_concurrent_different_owner_denies` | ✅ COMPLIANT |
| | Acquire locked unreadable | `test_acquire_deny_locked_unreadable` + `test_classifier_rows[corrupt_unparsable_lock]` | ✅ COMPLIANT |
| | Acquire corrupt worktree | `test_acquire_deny_corrupt_worktree` | ✅ COMPLIANT |
| Release tool | Release happy path | `test_release_happy_path` | ✅ COMPLIANT |
| | Release no-op when not owner | `test_release_non_owner_noop`, `test_release_no_lock_noop`, `test_release_missing_worktree_noop` (dirty preserved: `test_release_dirty_ok`) | ✅ COMPLIANT |
| Lock v2 schema | Lock written on acquire (all fields + repo_name = toplevel basename) | `test_acquire_created` (lock contents asserted) + `test_derive_repo_name_toplevel`, `test_canonical_path_uses_derived_name` | ✅ COMPLIANT |
| | Stale detection via PID | `test_classifier_rows[exists_stale_v2_dead]` + Go `TestIsStaleDeadPID` | ✅ COMPLIANT |
| Hint index | Index written on acquire | `test_index_write_through_on_acquire_and_release`, `test_index_entry_replaced_not_duplicated` | ✅ COMPLIANT |
| | Index is advisory (porcelain wins) | `test_index_corrupt_rebuilds_empty`, `test_index_missing_returns_empty`, `test_enriched_list_ignores_orphan_index_entries` | ✅ COMPLIANT |
| Repo-name derivation | Different repo gets correct name | `test_derive_repo_name_toplevel`, `test_canonical_path_uses_derived_name`, Go `TestRepoNameFromGitRoot` (+subdir/./ rows) | ✅ COMPLIANT |
| Enriched worktree list | Enriched list output (main included) | `test_enriched_list` (asserts state/owner/session/last_seen/dirty per entry; `main_entry["is_main"] is True`) | ✅ COMPLIANT |

#### Capability: crash-recovery (5 requirements, 11 scenarios) — orchestrator wiring contract (config-repo; prompt block is the implementation surface, verified textually verbatim against design)

| Requirement | Scenario | Test / Evidence | Result |
|-------------|----------|-----------------|--------|
| Organic continuation entry | Natural entry discovers work | orchestrator.md L719: `git_worktree_list` + apply-progress cross-ref; no change name required | ✅ COMPLIANT (wiring-verified) |
| Presentation by volume | Single worktree | L719: "1 direct+notice; ... no selection required" | ✅ COMPLIANT (wiring-verified) |
| | Two to five worktrees | L719: "2–5 one `question` (change+phase+dirty)" | ✅ COMPLIANT (wiring-verified) |
| | More than five worktrees | L719: ">5 table (index\|change\|branch\|state\|last_seen\|dirty\|phase) + validated input (number/name/alias; unambiguous single match, else re-present)" | ✅ COMPLIANT (wiring-verified) |
| | Zero worktrees | L719: "0 informative + propose `/sdd-new`" | ✅ COMPLIANT (wiring-verified) |
| Resume after selection | Resume happy path | L719: "Selection → acquire → verify binding signals → resume apply-progress" | ✅ COMPLIANT (wiring-verified) |
| | Resume denied | L716-717: blocking prompt on `owned_by_other`, "never silently take over" | ✅ COMPLIANT (wiring-verified) |
| Orchestrator acquire gate | Auto re-claim on stale | L716: "`exists_stale` (dead PID — lock v1/≠2 or v2) → auto re-claim (`claimed`), no prompt" | ✅ COMPLIANT (wiring-verified) |
| | Blocking prompt on conflict | L717: blocking prompt ONLY on `owned_by_other`/`locked_unreadable`/`corrupt_worktree`, relay typed envelope and wait | ✅ COMPLIANT (wiring-verified) |
| | Verify follows acquire | L715: acquire BEFORE `sdd-tool worktree verify`; route only on `{created\|attached\|claimed\|reclaimed\|already_mine}` | ✅ COMPLIANT (wiring-verified) |
| Nothing-to-continue proposal | Zero worktrees proposal | L719: "0 informative + propose `/sdd-new`" | ✅ COMPLIANT (wiring-verified) |

#### Capability: gh-git-mcp-server (6 requirements, 10 scenarios)

| Requirement | Scenario | Test / Evidence | Result |
|-------------|----------|-----------------|--------|
| Worktree add tool (wrapper) | Add delegates to acquire | `worktree_mutation.py` `git_worktree_add` → `compute_dry_run` plans + `execute()` delegates to `ws.acquire_worktree(...)`; no classifier/lock logic duplicated (source-verified) | ✅ COMPLIANT |
| | Add preserves dry-run pattern | `destructive_flow(dry_run=True)` returns planned effect with `data.dry_run:true`, no creation (shared two-phase, source-verified; `compute_dry_run` returns plan only) | ✅ COMPLIANT |
| Worktree remove tool (wrapper) | Remove delegates release for claim | `git_worktree_remove` execute(): `ws.release_worktree(...)` clears claim → codegraph dir drop → `git worktree remove`; dirty pre-check + owner pre-check retained (source-verified) | ✅ COMPLIANT |
| Worktree list tool | Enriched list | `test_enriched_list` (state/owner/session/last_seen/dirty/is_main; `git_worktree_list` → `ws.enriched_worktree_list` in `local_read.py`) | ✅ COMPLIANT |
| | Stale worktree in list | `test_enriched_list` asserts stale entry `state == "exists_stale"`, `owner`, `last_seen == lock timestamp` | ✅ COMPLIANT |
| Error catalog extension | New error type | `envelope.py` closed catalog docstring: `worktree_exists, active_agents, owned_by_other, dirty_worktree, locked_unreadable, corrupt_worktree` | ✅ COMPLIANT |
| Worktree acquire tool | Acquire creates new worktree | `test_acquire_created` (status `created`, lock v2 written, index updated) | ✅ COMPLIANT |
| | Acquire reclaims stale | `test_acquire_claimed_preserves_created_at`, `test_acquire_v1_claimed` (status `claimed`, lock rewritten) | ✅ COMPLIANT |
| | Acquire denies active other | `test_acquire_deny_owned_by_other` (`ok:false`, `error.type: owned_by_other`) | ✅ COMPLIANT |
| Worktree release tool | Release clears claim | `test_release_happy_path` (claim cleared, worktree remains, index updated) | ✅ COMPLIANT |

#### Capability: git-worktrees-skill (1 requirement, 5 scenarios) — skill 6c section verified textually

| Requirement | Scenario | Test / Evidence | Result |
|-------------|----------|-----------------|--------|
| MCP worktree lifecycle extension | Acquire/release documented | `SKILL.md` 6c L184-186: acquire/release/list primary; add/remove retrocompat wrappers | ✅ COMPLIANT |
| | State model documented | 6c L189: 7-state model + acquire transitions (created/attached/claimed/already_mine; `reclaimed` reserved) | ✅ COMPLIANT |
| | Denial semantics documented | 6c L190: `owned_by_other`, `locked_unreadable`, `corrupt_worktree` + PID-reuse manual recovery guidance | ✅ COMPLIANT |
| | No-git-crudo preserved | 6c L184: "never raw `git worktree` via bash"; no raw commands in the 6c section; pre-6c fallback content is Alan's preserved original | ✅ COMPLIANT |
| | Non-regression | `./sync-skills.sh --check` from MAIN → **exit 0, zero desyncs**; pre-6c content untouched (6c appended at EOF after Provenance) | ✅ COMPLIANT |

**Compliance summary**: 47/47 scenarios compliant. 38 covered by passing runtime tests (44 pytest + 11 focused Go + 8 supplementary Go on MAIN/full), 9 covered by verbatim-exact wiring/skill contracts (config-repo: prompt text and skill doc are the implementation surface; no runtime test is possible or configured — `rules.verify.test_command` is empty by project convention).

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| 7-state classifier (9-row decision table) | ✅ Implemented | `worktree_state.py::_classify` ordered rows match design table exactly; plus hardened corrupt for disk/porcelain disagreement either direction and git-probe failure (deviation D1, superset) |
| Acquire tool | ✅ Implemented | `acquire_worktree` — created/attached/claimed/already_mine; typed denials; codegraph init best-effort on created; `store` defaults `"hybrid"` (LOCK_STORE_DEFAULT); `created_at` preserved on re-claims; no silent takeover |
| Release tool | ✅ Implemented | `release_worktree` — owner-match → lock+index deletion; no-lock/non-owner no-op; corrupt → `locked_unreadable`; never destroys, dirty OK |
| Lock v2 schema | ✅ Implemented | All 11 fields; `pid` = server pid at acquire; `repo_name` always `derive_repo_name` (toplevel basename); Go `ParseLockV2` guards `version == 2` explicitly (version 1/missing/corrupt/missing-file → error) |
| Hint index | ✅ Implemented | `~/.agent_worktrees/<repo>/.agent-index.json` version 1, write-through on acquire/release, atomic tmp+replace, corrupt/missing → empty rebuilt, write failure warn-only |
| Repo-name derivation | ✅ Implemented | `worktree.go::List` uses `RepoNameFromGitRoot(cwd())` — hardcode `"sdd-own-skills"` removed; Python `derive_repo_name`/`canonical_worktree_path` reject caller-raw paths |
| Enriched worktree list | ✅ Implemented | `enriched_worktree_list` — porcelain truth, per-entry state/owner/session/last_seen/dirty/is_main, main included, index fills only lock-silent fields (advisory) |
| MCP wrappers add/remove | ✅ Implemented | Thin delegation; `destructive_flow` envelope retained; safe-slug via `validate_safe_slug`; remove keeps dirty/owner pre-checks; no classifier duplication |
| Orchestrator acquire gate | ✅ Implemented | `orchestrator.md` L712-721 appended block, verbatim design contract + double-apply assertion; `sdd-propose` line amended in own `sdd-tool-integration` block (L693) |
| Skill 6c extension | ✅ Implemented | `SKILL.md` 6c appended post-Provenance (pre-6c Alan content untouched) |
| Error catalog | ✅ Implemented | `corrupt_worktree` added; `locked_unreadable` listed; `confirm_required` stays a summary marker |

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Classifier as pure decision function + table | ✅ Yes | One-shot mapping, no classes; design table implemented 1:1 |
| Python writes / Go reads (observer D2 fail-open) | ✅ Yes | `worktree_state.py` sole writer; `lock.go` read-only, `version==2` guard, no write calls |
| Lock pid = server pid at acquire | ✅ Yes | `os.getpid()` at write time (Python), `syscall.Kill` parity (Go) |
| `reclaimed` reserved, unreachable | ✅ Yes | Status in closed set; route list kept with "intentionally reserved" note in orchestrator block + skill |
| Corrupt evidence never overwritten | ✅ Yes | `corrupt_worktree`/`locked_unreadable` typed denials, never silent |
| `add`/`remove` thin retrocompat wrappers | ✅ Yes | Envelope + two-phase + safe-slug kept; classifier logic not duplicated |
| Acquire gate (acquire-before-verify, prompt only on conflicts) | ✅ Yes | Orchestrator block verbatim; auto re-claim on objective stale; blocking prompt on real conflicts only |
| Volume-based continuation (1/2–5/>5/0) | ✅ Yes | Orchestrator block exact thresholds + validated input rules |
| Hint index never truth | ✅ Yes | Porcelain wins; corrupt/missing → empty rebuilt; write failure warn-only |
| Release never destroys, dirty OK | ✅ Yes | Lock + index entry only; non-owner no-op |
| Spec-delta (3 points) resolved per design | ✅ Yes | v1 PID-liveness split; `store="hybrid"` default; already_mine owner+session match — all coded + tested (see Spec-Delta below) |
| Design deviation D1 (ghost harden) | ✅ Yes (superset) | Disk/porcelain disagreement either direction → corrupt; additional RED test; fail-closed, no spec broken |

### Deviations from Design

| # | Deviation | Assessment |
|---|-----------|------------|
| D1 | Classifier row-1 hardened: ghost porcelain entry + unparsable lock → `corrupt` (design classified lock-unparsable as corrupt already; ghost dir-vanished added) | ✅ Safe superset; RED-tested (`corrupt_ghost_in_porcelain`, `corrupt_unparsable_lock`); fail-closed; no spec/design row contradicted |
| D2 | Test infra introduced (`pyproject.toml` dev group `pytest>=8`, `uv.lock`, `.venv`) | ✅ Required for RED suite; venv gitignored; revertible |
| D3 | `already_mine` short-circuits outside the two-phase flow (direct ok) | ✅ Matches design "route on already_mine → no mutation"; no confirm round-trip noise |
| D4 | `git_worktree_release` denies `not_found` at tool level; core `release_worktree` stays ok no-op | ✅ Documented tool-UX vs core-semantics split; consistent with `git_worktree_remove` denial parity |

### Spec-Delta Note (for archive phase — spec.md NOT edited per tasks.md L76-80)

1. **v1 lock classification** (spec "Legacy v1 lock treated as stale" unconditional): design + implementation split on PID liveness — `v1/≠2 ∧ pid dead → exists_stale → claimed`; `v1/≠2 ∧ pid alive → exists_active_other → deny owned_by_other`. Tests: `exists_stale_v1_dead`, `exists_active_other_v1_alive`. Archive must sync the spec row.
2. **Acquire signature** (spec fixed `git_worktree_acquire(repo_path, change, owner, session)`): design + implementation add optional `store="hybrid"` (lock v2 requires it; callers may override). Tests exercise default. Archive must sync the spec signature.
3. **already_mine session match** (spec: owner match only): design + implementation require owner AND session match; same owner + different session → `exists_active_other` → `owned_by_other`. Tests: `exists_active_mine`, `exists_active_other_v2_diff_session`, `test_concurrent_same_owner_diff_session_denies`. Archive must sync the spec scenario.

These three are DESIGN-correct per council risks 1-3 and are verified against the design contract; they do not fail the change.

### Issues Found

**CRITICAL**: None.

**WARNING**:
- W1 (pre-existing, not change-caused): `TestVerifyOnMain` fails when the Go suite runs on a feature-branch cwd (it asserts the "no worktree" note that only fires on `main`/`master`). Proven pass on MAIN (`go test ./internal/worktree/...` from main cwd → ok). Recorded in apply-progress deviation 5. No action for this change.
- W2 (info): `sdd-tool` binary not on PATH; supplementary `worktree verify` required an ad-hoc build. Not a change defect.

**SUGGESTION**:
- S1: `test_enriched_list` could assert an `is_main: true` entry with `dirty` status explicitly (covered today via `_status_ex` env; implicit).
- S2: `sdd-tool worktree list --json` returns `null` without a scanner snapshot — worth a doc line in sdd-tool help; unchanged behavior, not introduced here.

### Verdict

PASS WITH WARNINGS — 31/31 tasks complete; 47/47 scenarios compliant (38 runtime-tested, 9 wiring/skill-contract verified); Python 44 passed, Go observer suites pass (focused + on MAIN), sync-skills check clean from MAIN, sdd-tool verify binding signals all pass, orchestrator/skill wiring matches the design verbatim. Warnings are the pre-existing branch-sensitive Go test (W1) and the sdd-tool PATH note (W2); the 3 spec-delta points are by-design and archive-phase responsibility.