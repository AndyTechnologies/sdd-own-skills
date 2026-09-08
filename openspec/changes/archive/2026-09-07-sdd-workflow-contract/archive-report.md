# Archive Report: sdd-workflow-contract

**Change**: sdd-workflow-contract
**Archived**: 2026-09-07
**Archive location**: `openspec/changes/archive/2026-09-07-sdd-workflow-contract/`
**Stores**: hybrid (Engram topic `sdd/sdd-workflow-contract/archive-report` + OpenSpec)

## Final State (at close)

The change is fully deployed, verified, and closed. No work occurred after `verify-report` was persisted; `verify-report` (Engram obs #432, openspec `verify-report.md`) IS the authoritative close-state snapshot.

| Fact | Value |
|------|-------|
| Verify verdict | PASS — 18/18 scenarios, 7/7 requirements, 0 CRITICAL, 0 WARNING, 0 blockers |
| Tasks | 10/10 complete (`[x]` in tasks.md; 0 unchecked) |
| Build | `bash -n sync-skills.sh` exit 0 |
| Test gate | `./sync-skills.sh --check` exit 0 — `sincronizado (cero desyncs)` |
| Rollout sync | Ran post-apply in real mode (`--skip-gentleai-sync --skip-opencode`); `--check` confirms cero desyncs — change fully deployed to installed copies |
| Main spec | `openspec/specs/workflow-contract/spec.md` — Created (full spec, 7 requirements, 18 scenarios) |

## Deployed Surfaces / Evidence

1. **`wiring/prompts/sdd/orchestrator.md`** (repo-owned, installed via symlink to the sdd-own original, byte-identical):
   - Line 73 delegation flip: `Bash for state (git, gh)` ✅ → ❌, naming MCP surfaces (`github` remote; `gh-git-mcp` local, supervised two-phase) with gate word `no-git-crudo`.
   - New `### SDD Workflow Contract (MANDATORY)` section after `### Result Contract`, before `### Review Workload Guard`, covering 6 clauses: organic zero-prompt default; untrusted-data fail-closed; external-gap research routing; council-chain target flow (max 1 retry, second failure STOP, council never relaunches design, `sdd/{change-name}/council` acta); worktree lifecycle + Phase 0 exception; bounded parallelism (max 2 background, one writer per worktree).
2. **`overlays/shared/sdd-phase-common.md`** — 4 new `sdd-own`-marked blocks appended: `shared-untrusted-data`, `shared-no-git-crudo`, `shared-worktree-binding`, `shared-result-contract-strictness` (6 total sdd-own blocks in the installed shared file: + 2 pre-existing).
3. **Rollout sync** converged: installed `~/.config/opencode/prompts/sdd/orchestrator.md` (symlink) and `~/.agents/skills/_shared/sdd-phase-common.md` (Alan base intact + 6 blocks) both match repo source; `./sync-skills.sh --check` reports cero desyncs. Alan's base files untouched (strip+append mechanic only).

## Verification Summary

Per `verify-report` (Engram obs #432, persisted at close — the authoritative snapshot): spec compliance matrix shows 18/18 scenarios COMPLIANT across all 7 requirements (no-raw-git delegation, untrusted-data fail-closed, research routing, council-chain target flow, worktree lifecycle, bounded parallelism, result-contract strictness); coherence table confirms all design decisions followed (section placement, flip mechanism, marker ids, verbatim wording pins, Alan-base exclusion); adversarial pass confirms no rewrite of Alan bases, gentle-ai markers intact, delegation table minimally diffed (1 deletion + 17 additions), zero content drift from spec. All canonical pins (`no-git-crudo`, `fail-closed`, `one writer per worktree`, `max 2`, `max 1 retry`, `STOP`, `--cwd <worktree>`, `Phase 0`, `sdd/{change-name}/council`) verified greppable in both repo source and installed copies.

## Spec Sync

| Domain | Action | Details |
|--------|--------|---------|
| workflow-contract | Created | Full-domain spec copied mechanically to `openspec/specs/workflow-contract/spec.md` (7 requirements, 18 scenarios); `diff -r` source-vs-destination readback EMPTY (byte-identical, exit 0) |

## Archive Move

- Source `openspec/changes/sdd-workflow-contract/` moved to `openspec/changes/archive/2026-09-07-sdd-workflow-contract/` with plain `mv` — `git mv` inapplicable because the change folder is untracked in git; `mv` is a filesystem operation and complies with the `no-git-crudo` contract (no raw git commands run). Pre-move recursive snapshot compared with `diff -r` after the move: EMPTY (byte-identical, exit 0).
- Archive contains all artifacts: quest.md, exploration.md, proposal.md, specs/workflow-contract/spec.md, design.md, tasks.md, apply-progress.md, verify-report.md (+ this additive archive-report.md, excluded from the readback).
- Archived `tasks.md`: 10/10 `[x]`, 0 unchecked — Task Completion Gate passed with no reconciliation needed.
- Active changes directory no longer contains this change.

## Rollback Path

1. Revert `wiring/prompts/sdd/orchestrator.md` line 73 from ❌ → ✅.
2. Remove the `### SDD Workflow Contract (MANDATORY)` section (single contiguous block).
3. Strip the 4 `sdd-own`-marked blocks (`shared-untrusted-data`, `shared-no-git-crudo`, `shared-worktree-binding`, `shared-result-contract-strictness`) from `overlays/shared/sdd-phase-common.md` (idempotent strip by marker id).
4. Run `./sync-skills.sh --check` to confirm cero desyncs after rollback.

## Follow-ups (SUGGESTIONs from verify-report, non-blocking)

1. `overlays/shared/sdd-phase-common.md` ends without a trailing newline (`\ No newline at end of file`) while the installed merged file has one — harmless today (sync strip+append is byte-deterministic, `--check` passes), but adding a trailing newline removes the only diff noise between source and installed. LOW.
2. Task 3.1's literal grep `grep -n 'git, gh'` cannot match the markdown cell because of the backtick between `git` and `, gh` (pre-existing in the original file). Verification used the row-level grep `Bash for state` instead; the AC itself (❌ + surfaces named) is satisfied. Consider rewording the task grep for future changes touching that row. LOW.

## Traceability — Engram observations read

| Artifact | Topic key | Obs ID |
|----------|-----------|--------|
| quest (RFC, approved) | `sdd/sdd-workflow-contract/quest` | #423 |
| exploration | `sdd/sdd-workflow-contract/explore` | #424 |
| proposal | `sdd/sdd-workflow-contract/proposal` | #426 |
| spec | `sdd/sdd-workflow-contract/spec` | #427 |
| design | `sdd/sdd-workflow-contract/design` | #428 |
| tasks | `sdd/sdd-workflow-contract/tasks` | #429 |
| apply-progress | `sdd/sdd-workflow-contract/apply-progress` | #430 |
| verify-report | `sdd/sdd-workflow-contract/verify-report` | #432 |
| discovery (grep nuance) | (apply discovery) | #431 |
| session summary (context) | — | #425 |

## Intentional Overrides / Warnings

None. No CRITICAL issues, no stale checkboxes, no partial-artifact archive.

## SDD Cycle Complete

The change has been fully planned (quest → explore → propose → spec → design), implemented (apply 10/10), verified (PASS, 18/18 scenarios), and archived. Contract text for the later hardening / council-chain / mcp-worktree phases is live in the installed orchestrator prompt and shared phase-common overlay.