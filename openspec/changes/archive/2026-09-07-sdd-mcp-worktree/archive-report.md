# Archive Report: sdd-mcp-worktree

**Change**: sdd-mcp-worktree
**Archived**: 2026-09-07
**Archive location**: `openspec/changes/archive/2026-09-07-sdd-mcp-worktree/`
**Stores**: hybrid (OpenSpec filesystem + Engram mirror topic `sdd/sdd-mcp-worktree/archive-report`)
**Phase**: Phase 1 Lane C — bootstrap exception, no worktree (Phase 0 exception under the shared-worktree-binding clause)

## Final State (at close)

The change is fully implemented, verified, and closed. Per the launch prompt's final-state facts (which outrank intermediate snapshots), the work completed after `apply-progress` and `verify-report` were persisted: the verify envelope was fixed by the orchestrator and re-validated (`gentle-ai sdd-verify-validate --input ... --requirements 10 --scenarios 26` → `valid:true`, `verdict:pass`), the RED suite was confirmed green end-to-end, and a minimal deploy sync ran. The `verify-report.md` in this archive carries the canonical `gentle-ai.verify-result/v1` envelope and IS the authoritative close-state verification snapshot.

| Fact | Value |
|------|-------|
| Verify verdict | PASS — `gentle-ai.verify-result/v1` envelope: verdict pass, 0 blockers, 0 CRITICAL, 10/10 requirements, 26/26 scenarios |
| Envelope hashes | evidence_revision `sha256:56ca175ff643448ab69fbc040d8665e350a75c4317b54d425736baa4614a0235`; test_output_hash `sha256:2069c853d1b4e6b4697f2c561daf36c854da2308083232af46506b5ffac26444`; build_output_hash `sha256:0450545874ec3cb0e3717232889bab044bedb2112c9a7c0b0505583de2660d2d` |
| Tasks | 24/24 complete (`[x]` in tasks.md; 0 unchecked) |
| RED suite | **27/27 PASS, 0 FAIL, 0 SKIP, exit 0** (`bash tests/run_red_checks.sh`) |
| Sync gate | `./sync-skills.sh --check` exit 0 — `sincronizado (cero desyncs)` |
| Syntax gates | `bash -n` clean (setup.sh, sync-skills.sh, tests/run_red_checks.sh); `python3 -m py_compile` clean (all server files, incl. tool_handlers) |
| Runtime probes | F6 driver 45/45 PASS; existing-token network degrade 4/4 PASS; dry-run selector plan exit 0 + HOME snapshot byte-identical |
| Footprint | 16 files modified, 648 insertions / 83 deletions (net 565); untracked added: `srv/gh-mcp-server/src/tool_handlers/worktree_mutation.py`, `openspec/changes/sdd-mcp-worktree/`, `openspec/specs/workflow-contract/` (Phase 0 prior change), `openspec/changes/archive/2026-09-07-sdd-workflow-contract/` (Phase 0 prior change) |
| Deploy | Minimal `./sync-skills.sh --skip-gentleai-sync --skip-opencode` ran post-apply (2 files updated: skill 6c + overlay sdd-phase-common) — deployed copies in `~/.config/sdd-own` are current |

## What Shipped

Three coordinated surface changes under RFC AC1-AC8:

1. **`srv/gh-mcp-server` (F6)** — three worktree lifecycle tools (`git_worktree_add`, `git_worktree_list`, `git_worktree_remove`) under the existing two-phase `destructive_flow` pattern; worktree root convention `~/.agent_worktrees/<basename(repo_path)>/<change>` + branch `sdd/<change>`; `.codegraph/` init + `.sdd-agent-lock` (`pid`/`session`/`owner`/`timestamp`); removal pre-checks outside the two-phase path (dirty_worktree, active_agents via `kill -0`, owned_by_other); safe-slug `^[A-Za-z0-9][A-Za-z0-9._-]*$` (never raw paths → `invalid_parameter`); E1 echo protocol (dry_run → display_data; `confirmed:true` + `confirmed_data` EXACT) in all 7 two-phase descriptions; `confirm_required` as actionable name-field marker on `ok()` envelopes, never an `error.type`; error catalog grows to 12 types (+ worktree_exists, active_agents, owned_by_other; dirty_worktree now emitted). Surface: **26 tools / 5 families** (registered in `__init__.py`, `git_worktree_list` in `local_read.py`).
2. **`setup.sh` (F5)** — `degrade()` (`[aviso]` + `network_degraded=1` + return 0) at the two network-fatal insertion points (L308-310 prompt_new_token, L829-832 `--check` structural); 401/invalid-token stays fatal (exit 2); interactive MCP runtime selector step 5g (TTY pty toggle, no-TTY/`--check`/`--dry-run` → ALL, no persistence); `SELECTED_RUNTIMES[]` merge-loop skip; C2 `selectors` + `permission_roots` `["~/agent_worktrees/**"]` in `wiring/mcp.d/*.json`; `wiring/opencode.sdd.json` untouched.
3. **Lockstep + skill 6c (B1)** — `wiring/prompts/sdd/orchestrator.md` clause 5 → `~/.agent_worktrees/<repo-name>/<change-name>` with Phase 0 exception text; `overlays/shared/sdd-phase-common.md` `shared-worktree-binding` flip; additive 6c section appended to `skills/using-git-worktrees/SKILL.md` (MCP-native lifecycle, removal safety, no raw `git worktree`); existing content byte-identical.

## Verification Summary

Per `verify-report.md` in this archive (canonical envelope, persisted at close): all domains VERIFIED — `srv/gh-mcp-server` (F6: RED T26/T27, 26 tools/5 families, 12-type catalog, ECHO_PROTOCOL 7 citations, independent runtime driver 45/45 PASS), `github-mcp-setup` (F5: RED 27/27 incl. T06-T25, 401 fatal preserved, existing-token degrade probe 4/4, dry-run selector probe exit 0), `git-worktrees-skill` (sync `--check` 0 desyncs, 6c additive-only, old `<repo-name>-worktrees/<` convention 0 hits in changed files). Drift/scope audit: footprint exactly as claimed, `wiring/opencode.sdd.json` untouched, no Alan base edits, no commits (no-git-crudo respected). Two WARNING follow-ups (W1 README L166 exit-semantics note; W2 stale worktree-location guidance in `skills/_shared/codegraph.md` L19 + global `~/.config/opencode/AGENTS.md` L8) — both non-blocking and explicitly **out of scope for this change**; recorded as follow-ups, NOT implemented.

## Spec Sync

All three delta domains already had main specs, so the deltas were MERGED (no mechanical copies):

| Domain | Action | Details |
|--------|--------|---------|
| git-worktrees-skill | Updated | +1 ADDED requirement (`MCP worktree lifecycle extension`, 4 scenarios); 1 MODIFIED (`Non-regression` → additive-only constraint + `Suite integrity with extension (AC7)` scenario) |
| gh-git-mcp-server | Updated | +4 ADDED requirements (`Worktree add tool` 3 sc, `Worktree list tool` 1 sc, `Worktree remove tool` 5 sc, `Worktree error catalog extension` 1 sc); 1 MODIFIED (`Tool surface completeness` → 26 tools/5 families + full 12-type catalog + `confirm_required` marker semantics) |
| github-mcp-setup | Updated | +2 ADDED requirements (`Network degrade tolerance` 4 sc, `Interactive MCP runtime selector` 4 sc); 1 MODIFIED (`Check and dry-run reports` → network status + selector output + degrade-as-warning) |

Total: 7 requirements added, 3 requirements modified, 0 removed. No destructive deltas — the `config.yaml` archive rule ("warn before merging destructive overlay deltas") did not trigger.

**Merge decision recorded**: the delta MODIFIED blocks carried change-history trace parentheticals (`(Previously: ...)`); these were dropped from the merged main-spec requirement bodies to keep the source-of-truth specs current-state only (consistent with the existing main specs, which carry no history notes). Scenario names and content otherwise verbatim from the deltas, including AC-tagged names.

**Informational nuance (non-blocking, cross-requirement)**: the main spec's `Typed output envelope` requirement (`Failure envelope` scenario) still lists `confirm_required` among `error.type` values — it was not touched by the delta. The merged `Tool surface completeness` (delta MODIFIED) states `confirm_required` is a summary marker on `ok()` envelopes, never an `error.type` (0 `err("confirm_required")` hits verified). Recorded for completeness; the stricter marker-only reading is the verified-correct one.

## Archive Move

- Source `openspec/changes/sdd-mcp-worktree/` moved to `openspec/changes/archive/2026-09-07-sdd-mcp-worktree/` with plain `mv` — the change folder is untracked in git (`git mv` inapplicable); `mv` is a filesystem operation and complies with the `no-git-crudo` contract (no raw git commands run). Pre-move recursive snapshot compared with `diff -r` after the move: **EMPTY** (byte-identical, exit 0) — the only passing evidence per the Mechanical Copy Contract.
- Archive contains all artifacts: quest.md, exploration.md, proposal.md, council.md, specs/ (3 delta domains), design.md, tasks.md, apply-progress.md, verify-report.md (+ this additive archive-report.md, excluded from the readback).
- Archived `tasks.md`: 24/24 `[x]`, 0 unchecked — Task Completion Gate passed with no reconciliation needed.
- Active changes directory no longer contains this change.

## Follow-ups (out of scope — NOT implemented in this change)

1. **W1** — `README.md` L166 exit-semantics note: still reads exit 2 = "red/API inalcanzable"; under the new D-F5-2 mapping network failure at token validation degrades (`[aviso]` + exit 0). Doc-only; update in a small follow-up.
2. **W2** — `skills/_shared/codegraph.md` L19 (repo canonical) + global `~/.config/opencode/AGENTS.md` L8 still teach the old `<repo-parent>/<repo-name>-worktrees/<worktree-name>` convention. One follow-up change (deployed only-if-missing for codegraph.md; globals are user-stewardship).

## Runtime Token

Archive does not settle the native runtime token `sha256:52ea38d007671f8fa3fcf622ef7be50f21aa2e7f8bdd09ca4d750823d49955ec` (objective `lane-c-archive`, max_attempts 1, max_changed_lines 200) — the orchestrator settles it. The verify-phase token `sha256:56ca175ff643448ab69fbc040d8665e350a75c4317b54d425736baa4614a0235` is likewise a `lane-c-verify` token for the orchestrator, not settled here.

## Traceability — artifacts read (openspec paths) and Engram mirror observations

| Artifact | OpenSpec path | Engram obs ID |
|----------|---------------|---------------|
| quest (RFC, approved) | `openspec/changes/sdd-mcp-worktree/quest.md` → archived | #441 |
| exploration | `exploration.md` → archived | #442 |
| proposal | `proposal.md` → archived | #443 |
| spec (3 delta domains) | `specs/{github-mcp-setup,gh-git-mcp-server,git-worktrees-skill}/spec.md` | #444 |
| council | `council.md` → archived | #452 |
| design | `design.md` → archived | #448 |
| architecture lint | (independent review) | #453 |
| tasks | `tasks.md` → archived | #458 |
| apply-progress | `apply-progress.md` → archived | #463 |
| verify-report | `verify-report.md` → archived (canonical envelope) | #467 |
| session summary (context) | — | #460 |

## Intentional Overrides / Warnings

None. No CRITICAL issues, no stale checkboxes, no partial-artifact archive, no destructive deltas. The only merge judgment call (dropping `(Previously: ...)` trace parentheticals from merged requirement bodies) is documented above.

## SDD Cycle Complete

The change has been fully planned (quest → explore → propose → spec → council → design → arch-lint → tasks), implemented (apply 24/24), verified (PASS, `gentle-ai.verify-result/v1`, 26/26 scenarios, RED 27/27), deployed (minimal sync, 0 desyncs), and archived. Main specs `openspec/specs/{github-mcp-setup,gh-git-mcp-server,git-worktrees-skill}/spec.md` now reflect the new behavior. MCP-native worktree lifecycle + resilient setup.sh are live.