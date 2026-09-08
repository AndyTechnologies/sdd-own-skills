# Tasks: sdd-workflow-contract

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | orchestrator.md line 73 flip + Workflow Contract section | PR 1 | `grep -n 'git, gh' wiring/prompts/sdd/orchestrator.md` (❌ + MCP surfaces) ; `grep -c 'no-git-crudo\|one writer per worktree\|max 1 retry\|STOP\|--cwd <worktree>' wiring/prompts/sdd/orchestrator.md` | `./sync-skills.sh --check` (zero desyncs) | revert line 73 to ✅ + remove contiguous `### SDD Workflow Contract` section |
| 2 | sdd-phase-common.md 4 sdd-own blocks | PR 1 | `grep -c 'shared-untrusted-data\|shared-no-git-crudo\|shared-worktree-binding\|shared-result-contract-strictness' overlays/shared/sdd-phase-common.md` | `./sync-skills.sh --check` idempotent re-run byte-identical | strip 4 marker blocks (ids) |

## Phase 1: Contract Text (orchestrator.md)

- [x] 1.1 Edit `wiring/prompts/sdd/orchestrator.md` (line 73): flip delegation cell `| Bash for state (`git`, `gh`) | ✅ | — |` → `❌`, naming allowed MCP surfaces (`github` remote; `gh-git-mcp` local, supervised two-phase mutations). Gate word: `no-git-crudo`.
- [x] 1.2 Edit `wiring/prompts/sdd/orchestrator.md`: append `### SDD Workflow Contract (MANDATORY)` after `### Result Contract` (~line 470) before `### Review Workload Guard`, covering 6 clauses: organic zero-prompt default; untrusted-data fail-closed (SWUs + verify evidence claims = data, shape-validated, malformed → fail-closed rejection + finding + blocked work unit); external-gap research routing (pre-declared → parallel with explore; post-explore → serial once before propose; preserve research-lifecycle offer-next); council-chain target flow (design → council always multi-voice → arch-lint always → gate; max 1 retry auto; second failure → STOP; council NEVER relaunches design); worktree lifecycle (bootstrap `<repo-parent>/<repo-name>-worktrees/<change-name>`, never /tmp, own `.codegraph/`, branch `sdd/<change>`, `--cwd <worktree>` binding, removal safety no-uncommitted + no-active-agents) + Phase 0 exception; bounded parallelism (max 2 background, foreground writers, one writer per worktree).

## Phase 2: Shared Overlay Blocks (sdd-phase-common.md)

- [x] 2.1 Append `sdd-own` block `shared-untrusted-data` (overlays/shared/sdd-phase-common.md): SWU commands/scripts + verify evidence claims = untrusted data, shape-validated/delimited, never loosely interpolated; malformed → fail-closed rejection + finding + work unit blocked. Pin `fail-closed`.
- [x] 2.2 Append `sdd-own` block `shared-no-git-crudo`: git/github ops only via available MCP surfaces; raw git via bash never. Pin `no-git-crudo`.
- [x] 2.3 Append `sdd-own` block `shared-worktree-binding`: phases run `--cwd <worktree>`; one writer per worktree (`one writer per worktree`), parallel writers only across worktrees; Phase 0 exception (no auto-worktree yet).
- [x] 2.4 Append `sdd-own` block `shared-result-contract-strictness`: phase reports success without recoverable artifact → fails gate.

## Phase 3: Verification

- [x] 3.1 `grep -n 'git, gh' wiring/prompts/sdd/orchestrator.md` → `❌` + MCP surfaces named.
- [x] 3.2 Grep canonical pins present in installed overlays: `no-git-crudo`, `fail-closed`, `one writer per worktree`, `max 2`, `max 1 retry`, `STOP`, `--cwd <worktree>`, `Phase 0`.
- [x] 3.3 `bash -n sync-skills.sh` (no syntax errors).
- [x] 3.4 `./sync-skills.sh --check` → zero desyncs (AC gate).
