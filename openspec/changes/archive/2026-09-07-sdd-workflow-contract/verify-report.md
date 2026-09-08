```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:5d63e776f6808833f9d9990edd94f145e440f3434ea998dfc35e51b2c3e64ef4
verdict: pass
blockers: 0
critical_findings: 0
requirements: 7/7
scenarios: 18/18
test_command: ./sync-skills.sh --check
test_exit_code: 0
test_output_hash: sha256:0450545874ec3cb0e3717232889bab044bedb2112c9a7c0b0505583de2660d2d
build_command: bash -n sync-skills.sh
build_exit_code: 0
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Verification Report

**Change**: sdd-workflow-contract
**Version**: N/A (Phase 0 config/contract text change)
**Mode**: Standard (pure config repo; NO strict TDD, no test runner — verification per launch contract = `bash -n` + `./sync-skills.sh --check` + contract greps)

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 10 |
| Tasks complete | 10 |
| Tasks incomplete | 0 |

All 10 tasks marked `[x]` in both Engram topic `sdd/sdd-workflow-contract/tasks` (obs #429) and `openspec/changes/sdd-workflow-contract/tasks.md`.

### Build & Tests Execution

**Build (syntax)**: ✅ Passed
```text
$ bash -n sync-skills.sh
exit 0 (no output — no syntax errors)
```

**Test (sync check — AC gate)**: ✅ Passed (exit 0)
```text
$ ./sync-skills.sh --check
  [up-to-date] ... (all installed paths)
  Actualizados : 0
  Errores      : 0
  Estado       : sincronizado (cero desyncs)
```

**Coverage**: ➖ N/A (no code coverage in a config repo; contract-grep ACs serve as coverage evidence, all verified below on BOTH repo source and installed copies).

### Spec Compliance Matrix

| Req | Scenario | Evidence (contract line/grep, installed) | Result |
|-----|----------|------------------------------------------|--------|
| 1 No-raw-git delegation | Greppable no-git-crudo flip | orchestrator.md line 73: `\| Bash for state (\`git\`, \`gh\`) \| ❌ \`github\`/\`gh-git-mcp\` only (\`no-git-crudo\`; local supervised two-phase) \| — \|`; `no-git-crudo` present in orchestrator + installed overlay `shared-no-git-crudo` | ✅ COMPLIANT |
| 1 No-raw-git delegation | Agent attempts raw git via bash | Installed overlay `shared-no-git-crudo`: "Raw git via bash is a `no-git-crudo` violation... MUST route the call through `gh-git-mcp` (or `github`) instead of bash" | ✅ COMPLIANT |
| 2 Untrusted-data fail-closed | Malformed command never executed | Orchestrator clause 2: "rejected `fail-closed` (rejection + finding + blocked work unit)"; overlay `shared-untrusted-data` bullet 2: "rejected `fail-closed` and the work unit is blocked with a finding" | ✅ COMPLIANT |
| 2 Untrusted-data fail-closed | Well-formed command executes | Overlay `shared-untrusted-data` bullet 1: "Every suggested command MUST be delimited and shape-validated before execution. Tokens are explicit and closed-domain" | ✅ COMPLIANT |
| 2 Untrusted-data fail-closed | Verify evidence claim invalid shape | Orchestrator clause 2: "a claim lacking the required structure is treated as untrusted and the phase result is not trusted"; overlay bullet 3 identical | ✅ COMPLIANT |
| 3 External-knowledge-gap research routing | Pre-declared gap runs in parallel | Orchestrator clause 3: "Pre-declared gap → research runs IN PARALLEL with explore, both consuming the approved RFC" | ✅ COMPLIANT |
| 3 External-knowledge-gap research routing | Gap detected post-explore runs once serially | Orchestrator clause 3: "Gap detected post-explore → research runs SERIALLY exactly once before propose, reusing explore context" | ✅ COMPLIANT |
| 3 External-knowledge-gap research routing | No gap, no research | Orchestrator clause 3: "No gap → no research is forced. This preserves the research-lifecycle offer-next semantics" | ✅ COMPLIANT |
| 4 Council-chain target flow | Happy-path chain | Orchestrator clause 4: "design → council → arch-lint → gate. Council ALWAYS fires with multi-voice framing and the user decides; council persists an acta at `sdd/{change-name}/council` and NEVER relaunches design" | ✅ COMPLIANT |
| 4 Council-chain target flow | Arch-lint failure retried once then STOP | Orchestrator clause 4: "Auto mode allows `max 1 retry`; a second failure MUST `STOP` with a report (no loop-until-clean)" | ✅ COMPLIANT |
| 4 Council-chain target flow | No-forks fast-path | Orchestrator clause 4: "A no-forks design takes a fast-path confirmation, but arch-lint still always fires" | ✅ COMPLIANT |
| 5 Worktree lifecycle | Bootstrap location and binding | Orchestrator clause 5: "`<repo-parent>/<repo-name>-worktrees/<change-name>` — NEVER `/tmp`... own `.codegraph/` index (never copied/symlinked), a unique branch `sdd/<change>`, and all phases run `--cwd <worktree>`"; overlay `shared-worktree-binding` identical | ✅ COMPLIANT |
| 5 Worktree lifecycle | Worktree removal safety check | Orchestrator clause 5: "removed via supervised MCP with a safety check (no uncommitted changes + no active agents); removal is skipped/deferred if unsafe" | ✅ COMPLIANT |
| 5 Worktree lifecycle | Phase 0 bootstrap exception | Orchestrator clause 5 + overlay `shared-worktree-binding`: "**Phase 0 exception**: Phase 0 runs WITHOUT auto-worktree (the worktree MCP tools are not yet installed — documented chicken-and-egg bootstrap exception)" | ✅ COMPLIANT |
| 6 Bounded parallelism | Max two background tasks | Orchestrator clause 6: "Background tasks are capped at `max 2`; foreground is reserved for writers and dependent phases"; overlay identical | ✅ COMPLIANT |
| 6 Bounded parallelism | One writer per worktree | Orchestrator clause 6: "There is `one writer per worktree`; parallel writers are allowed only across distinct worktrees"; overlay: "Parallel writers are allowed ONLY across distinct worktrees" | ✅ COMPLIANT |
| 7 Result-contract strictness | Success without artifact fails gate | Overlay `shared-result-contract-strictness`: "Any phase that reports success without a recoverable artifact MUST FAIL the gate: phase success without a retrievable artifact is not trusted" | ✅ COMPLIANT |
| 7 Result-contract strictness | Complete result contract | Overlay `shared-result-contract-strictness`: "The declared artifact MUST exist and be readable in the active backend before the gate advances" | ✅ COMPLIANT |

**Compliance summary**: 18/18 scenarios compliant, 7/7 requirements implemented.

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| No-raw-git delegation | ✅ Implemented | Line 73 cell = ❌, surfaces named, `no-git-crudo` pinned in both files (1 occurrence each). |
| Untrusted-data fail-closed | ✅ Implemented | `fail-closed` pinned (1 each); 3 bullets + orchestrator clause 2. |
| Research routing | ✅ Implemented | Orchestrator clause 3 covers pre-declared/parallel, post-explore/serial-once, no-gap. |
| Council-chain target flow | ✅ Implemented | `max 1 retry`/`STOP`/acta path/arch-lint always — all present. |
| Worktree lifecycle | ✅ Implemented | `--cwd <worktree>` pinned once per file; Phase 0 exception documented. |
| Bounded parallelism | ✅ Implemented | `max 2` + `one writer per worktree` pinned. |
| Result-contract strictness | ✅ Implemented | 4th overlay block with 2 bullets. |

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Section placement after Result Contract, before Review Workload Guard | ✅ Yes | Line 468 `### Result Contract` → 472 `### SDD Workflow Contract (MANDATORY)` → 488 `### Review Workload Guard (MANDATORY)`. |
| Flip mechanism (line 73 ✅→❌ + name MCP surfaces) | ✅ Yes | Exact cell content per design; minimal 1-line diff. |
| Marker ids (shared-untrusted-data, shared-no-git-crudo, shared-worktree-binding, shared-result-contract-strictness) | ✅ Yes | 4 new blocks; total 6 with pre-existing `shared-language-domain-contract` + `shared-quest-explore-contract` in installed file. |
| Wording pins verbatim | ✅ Yes | All 8 design pins greppable in installed copies. |
| Exclusion of Alan base | ✅ Yes | orchestrator.md is repo-owned (installed via symlink to sdd-own original, identical bytes); shared file = Alan base intact + 6 sdd-own blocks via strip+append. |
| `sdd/{change-name}/council` acta pin | ✅ Yes | Present in clause 4. |

### Issues Found

**CRITICAL**: None
**WARNING**: None

**SUGGESTION**:
1. Overlay fragment `overlays/shared/sdd-phase-common.md` ends without trailing newline (`\ No newline at end of file`) while the installed merged file has one. Harmless today (sync strip+append is byte-deterministic and `--check` passes), but adding a trailing newline to the fragment would remove the only diff noise between source and installed.
2. Task 3.1's literal grep `grep -n 'git, gh'` cannot match the markdown cell because of the backtick between `git` and `, gh` (pre-existing in the original file, not introduced by this change). Verification used row-level grep `Bash for state` instead; the AC itself (❌ + surfaces named) is satisfied. Consider re-wording the task grep for future changes touching this row.

### Known LOW risks from apply — resolution status

| Risk | Status |
|------|--------|
| (a) literal grep `git, gh` can't match markdown source (backtick) | ✅ Resolved — row-level grep `Bash for state` shows `❌ github/gh-git-mcp only (no-git-crudo; local supervised two-phase)`. |
| (b) `--check` at end of apply reported the 2 pre-sync desyncs | ✅ Resolved — rollout sync ran post-apply; re-run of `./sync-skills.sh --check` in verify reports `cero desyncs`, 0 errors, 0 updated. |

### Adversarial Pass

- **No-rewrite of Alan bases**: ✅ orchestrator.md is a repo-owned file (not managed by Alan); its installed path `~/.config/opencode/prompts/sdd/orchestrator.md` is a symlink to the sdd-own original and is byte-identical to the wiring source. The shared file `~/.agents/skills/_shared/sdd-phase-common.md` retains Alan's base (Sections A–F + language contract) intact with only the 6 sdd-own blocks appended. `./sync-skills.sh --check` confirms the strip+append overlay state is exactly as expected.
- **gentle-ai markers intact**: ✅ All `<!-- gentle-ai:... -->`/`<!-- /gentle-ai:... -->` markers unchanged (opencode-desktop-delegation-progress, sdd-model-assignments, opencode-background-subagents, agent-routing); the new section sits between markers, not inside them.
- **Delegation table coherence**: ✅ Only the `Bash for state (git, gh)` row flipped; the 6 other rows untouched (verified via git diff — 1 deletion + 17 additions total).
- **Content drift from spec**: ✅ None — exact canonical phrases (`no-git-crudo`, `fail-closed`, `one writer per worktree`, `max 2`, `max 1 retry`, `STOP`, `--cwd <worktree>`, `Phase 0`, `sdd/{change-name}/council`) preserved verbatim in orchestrator clauses 1–6 and the 4 overlay blocks.

### Verdict

**PASS** — All 18 spec scenarios covered by runtime-checked evidence (contract greps + `bash -n` + `./sync-skills.sh --check` zero desyncs) on both repo source and installed copies; design decisions all followed; zero critical/warning findings.