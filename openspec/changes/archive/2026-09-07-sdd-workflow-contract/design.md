# Design: Workflow Contract (Phase 0)

## Technical Approach

Phase 0 lands the enforceable SDD workflow contracts from the approved RFC/spec as **prompt + overlay text** in two canonical repo-owned surfaces: (1) a new `### SDD Workflow Contract` section plus a delegation-table flip in `wiring/prompts/sdd/orchestrator.md`; (2) four new `sdd-own`-marked shared-executor blocks appended to `overlays/shared/sdd-phase-common.md`. No agent wiring, no MCP registration, and no worktree tools are needed — both MCP surfaces (`github` remote, `gh-git-mcp` local) are verified registered in the real `opencode.jsonc`. This is a config/infrastructure text change: no executable code, no routes, no shell/process boundary is modified.

## Architecture Decisions

| Decision | Option | Tradeoff | Verdict |
|----------|--------|----------|---------|
| orchestrator.md section placement | Append after `### Result Contract` (line 470), before `<!-- gentle-ai:sdd-model-assignments -->` | vs. after `Automatic Mode Gatekeeper` | **Append after Result Contract** — keeps all `## SDD Workflow` policy subsections contiguous and references the preceding delegation table + Result Contract directly. Canonical file, so no strip+append constraint. |
| Flip mechanism | Edit line 73 `✅` → `❌` + name MCP surfaces | vs. leave and only reword | **Flip** — line 73 is the no-git-crudo enforcement point; must read ❌ per spec AC. |
| Marker ids (4 blocks) | `shared-untrusted-data` `shared-no-git-crudo` `shared-worktree-binding` `shared-result-contract-strictness` | kebab-case matching existing convention | **Adopted** — unique against existing ids (`shared-language-domain-contract`, `shared-quest-explore-contract`, `design-domain-skills`), stable across re-syncs. |
| Wording pins | Keep spec's exact canonical phrases greppable | vs. rewrite in free prose | **Keep spec phrases** — fixes contract-grep ACs and later-phase preservation. |
| Exclusion of Alan base | Orchestrator.md edited directly; sdd-phase-common via overlay strip+append | — | **Verified** — orchestrator.md is repo-owned (Alan doesn't manage that path); shared blocks use the strip+append mechanic, never touching Alan's `_shared` base. |

`design-patterns` gate: no GoF/system pattern applies — these are policy contracts, not object/resource abstractions. The relevant "pattern" is the repo's own managed-block overlay pattern (strip+append), already established and re-verified for idempotency; no new pattern introduced.

## Data Flow

    RFC/spec (binding) ──► design.md (Phase 0 text contract)
            │
            ├─► orchestrator.md  ── line 73 flip + ### SDD Workflow Contract (6 clauses)
            │
            └─► overlays/shared/sdd-phase-common.md ── 4 sdd-own blocks
                    └─► sync-skills.sh strip+append ──► installed _shared base (Alan preserved)

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `wiring/prompts/sdd/orchestrator.md` | Modify | Line 73 flip (`git, gh` ✅→❌, name `github`/`gh-git-mcp` surfaces); new `### SDD Workflow Contract (MANDATORY)` section after `### Result Contract` covering organic zero-prompt default, untrusted-data, external-gap research routing, council-chain target flow, worktree lifecycle + Phase 0 exception, bounded parallelism. |
| `overlays/shared/sdd-phase-common.md` | Modify | Append 4 `sdd-own` blocks: `shared-untrusted-data`, `shared-no-git-crudo`, `shared-worktree-binding`, `shared-result-contract-strictness`. |

## Interfaces / Contracts

Overlay block shape (strip+append-safe, per sync-skills.sh `apply_overlay`):

```
<!-- sdd-own:shared-<name>:start -->
<contract rules in SHALL wording>
<!-- sdd-own:shared-<name>:end -->
```

Greppable canonical pins (must survive into tasks/apply verbatim): `no-git-crudo` · `fail-closed` · `one writer per worktree` · `max 2` background · `max 1 retry` / `STOP` · worktree `--cwd <worktree>` · `Phase 0` exception · `sdd/{change-name}/council` acta.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Config | overlay idempotency | `./sync-skills.sh --check` reports zero desyncs (AC); idempotent re-run is byte-identical (`[up-to-date]`). |
| Config | no-git-crudo flip | grep `git, gh` cell = ❌; MCP surfaces named. |
| Config | contract-grep ACs | grep canonical pins present in orchestrator.md + phase-common + installed overlays. |
| Config | bash syntax | `bash -n sync-skills.sh` (verify build_command). |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary is changed. Phase 0 writes prompt/overlay contract text only; the no-git-crudo and fail-closed rules govern future apply/verify behavior but introduce no executable surface in this change.

## Migration / Rollout

No data migration. Rollout is the sync itself: after edits, run `./sync-skills.sh --check`, then real (or `--skip-opencode`). Rollback: revert line 73, remove the SDD Workflow Contract section, strip the 4 blocks, re-sync.

## Open Questions

- [ ] None — no design fork with real tradeoffs. Placement, markers, and wording are all determined by repo mechanics (strip+append, marker convention, AC wording) with a single obvious choice each. Fast-path.
