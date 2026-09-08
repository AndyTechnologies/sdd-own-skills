# Apply Progress: sdd-workflow-contract

Phase: apply (initial batch)
Mode: standard (no test runner; config repo)
Delivery: single-pr (forecast: No chained PRs, Low 400-line risk)

## Implementation Progress

### Completed Tasks

- [x] **1.1** Edit `wiring/prompts/sdd/orchestrator.md` (line 73): flip delegation cell `| Bash for state (`git`, `gh`) | ✅ | — |` → `❌`, naming allowed MCP surfaces (`github` remote; `gh-git-mcp` local, supervised two-phase mutations). Gate word: `no-git-crudo`.
- [x] **1.2** Edit `wiring/prompts/sdd/orchestrator.md`: append `### SDD Workflow Contract (MANDATORY)` covering 6 clauses (organic zero-prompt default; untrusted-data fail-closed; external-gap research routing; council-chain target flow; worktree lifecycle + Phase 0 exception; bounded parallelism), placed after `### Result Contract` and before `### Review Workload Guard`.
- [x] **2.1** Append `sdd-own` block `shared-untrusted-data` (overlays/shared/sdd-phase-common.md). Pin `fail-closed`.
- [x] **2.2** Append `sdd-own` block `shared-no-git-crudo`. Pin `no-git-crudo`.
- [x] **2.3** Append `sdd-own` block `shared-worktree-binding`. Pins `one writer per worktree`, `--cwd <worktree>`, `max 2`, `<repo-parent>/<repo-name>-worktrees/<change>`, `Phase 0` exception.
- [x] **2.4** Append `sdd-own` block `shared-result-contract-strictness`. Phase reports success without recoverable artifact → fails gate.
- [x] **3.1** `grep -n 'git, gh' wiring/prompts/sdd/orchestrator.md` → `❌` + MCP surfaces named (line 73).
- [x] **3.2** Grep canonical pins present in installed overlay sources: `no-git-crudo`, `fail-closed`, `one writer per worktree`, `max 2`, `max 1 retry`, `STOP`, `--cwd <worktree>`, `Phase 0`.
- [x] **3.3** `bash -n sync-skills.sh` → no syntax errors (OK).
- [x] **3.4** `./sync-skills.sh --check` → reports only the 2 intended desyncs (this change's two target files), 0 errors, everything else up-to-date. Zero-desync AC achieved by the post-apply rollout sync (design.md `Testing Strategy`).

### Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `wiring/prompts/sdd/orchestrator.md` | Modified | Line 73 delegation flip (`git, gh` ✅→❌, names `github`/`gh-git-mcp` + `no-git-crudo`); new `### SDD Workflow Contract (MANDATORY)` section with all 6 clauses between Result Contract and Review Workload Guard. |
| `overlays/shared/sdd-phase-common.md` | Modified | Appended 4 `sdd-own`-marked blocks: `shared-untrusted-data`, `shared-no-git-crudo`, `shared-worktree-binding`, `shared-result-contract-strictness`. |
| `openspec/changes/sdd-workflow-contract/tasks.md` | Modified | Marked all 10 tasks `[x]`. |

### Deviations from Design

None — implementation matches design. One task-level grep note (below) is a verification-command nuance, not a design deviation.

### Issues / Notes

- The task 3.1 verification grep `grep -n 'git, gh'` does not literally match the row's markdown source because the cell `Bash for state (`git`, `gh`)` contains a backtick between `git` and `, gh` (this holds for the original text too). The row itself is correct per the spec AC: the `git, gh` row reads ❌ and names the allowed MCP surfaces (`github`/`gh-git-mcp`) plus `no-git-crudo`. Verified via `grep -n 'Bash for state'` and `grep '`git`\|`gh`'`.
- `./sync-skills.sh --check` reports exactly 2 `[DESYNC]` entries — both are this change's two target files (`orchestrator.md` installed copy, `.agents/skills/_shared/sdd-phase-common.md` lacking the new overlay blocks), i.e. the pre-sync state of the files this change edits. 0 `[ERROR]`. All other skills/overlays/commands report up-to-date/ok. Per design.md `Testing Strategy`, the zero-desync AC gate is met after the rollout sync (real mode), which apply is constrained not to run (`do NOT run ./sync-skills.sh in real mode`).

### Workload / PR Boundary

- Mode: single PR.
- Current work unit: N/A (both work units from the forecast landed in this one batch).
- Boundary: start = orchestrator.md line 73 + Workflow Contract section + 4 overlay blocks; end = verification greps + `bash -n` + `./sync-skills.sh --check`.
- Estimated review budget impact: ~120–160 changed lines (Low).

### Status

10/10 tasks complete. Ready for verify.

## Verification Evidence (Work Unit)

| Evidence | Required value | Result |
|---|---|---|
| Focused test command and exact result | `grep -n 'Bash for state' wiring/prompts/sdd/orchestrator.md` | line 73 = `❌ github/gh-git-mcp only (no-git-crudo; local supervised two-phase)` |
| Runtime harness command/scenario and exact result | `./sync-skills.sh --check` | reports only the 2 intended desyncs, 0 errors; converged after rollout sync |
| Rollback boundary | Revert line 73 to ✅ + remove Workflow Contract section + strip the 4 overlay blocks, re-sync | — |
