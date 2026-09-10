# Archive Report: worktree-lifecycle-v2

**Change**: worktree-lifecycle-v2
**Archived on**: 2026-09-09
**Archived to**: `openspec/changes/archive/2026-09-09-worktree-lifecycle-v2/`
**Artifact store mode**: openspec
**Final status**: success

## Verdict Summary (final state)

The change was implemented, verified, and shipped as designed (with three spec-delta amendments described below). Final close state:

| Metric | Value |
|--------|-------|
| Tasks | 31/31 complete (`[x]` in tasks.md, 0 unchecked) |
| Python suite | 44/44 pass (`pytest tests/test_worktree_state.py` exit 0) |
| Go observer focused suite | 11/11 pass on main context |
| Go full suite (feature-branch cwd) | 1 pre-existing branch-sensitive failure (`TestVerifyOnMain`, W1) — passes on MAIN by design, not change-caused |
| `sync-skills.sh --check` | exit 0 from MAIN (0 desyncs); exit 1 from worktree with exactly the 2 intended desyncs (SKILL.md, orchestrator.md) |
| Verify verdict | PASS (envelope `pass_with_warnings`); validated by `gentle-ai sdd-verify-validate` (requirements 19, scenarios 47) |
| Scenarios | 47/47 (38 runtime-tested, 9 wiring/skill-contract) |
| Requirements | 19/19 |
| CRITICAL / BLOCKER | 0 / 0 |
| Warnings | W1 (pre-existing `TestVerifyOnMain` branch-sensitivity, by design), W2 (sdd-tool not on PATH — advisory) |
| Changelog | Emitted pre-archive (2026-09-09) in the worktree `CHANGELOG.md` under `[Unreleased]`; semver **minor**. Not re-emitted. |

## Spec-Delta Synced (MANDATORY)

The design deliberately outran the spec (recorded in tasks.md §Spec-Delta Items lines 76–80 and verify-report §Spec-Delta Note). The three mandated points were synced into the corresponding delta spec files during this archive phase, then composed/copied into the main specs. All amended content is explicitly marked inline with an archive-amendment banner.

| # | Delta point | Where synced |
|---|-------------|--------------|
| (a) | v1/≠2 lock classification is PID-liveness-aware: `v1 ∧ pid dead → stale → claimable`; `v1 ∧ pid alive → active_other → deny`. Replaces the unconditional "Legacy v1 lock treated as stale" scenario. | `openspec/specs/worktree-lifecycle/spec.md` — split `Legacy v1 lock with dead PID treated as stale` (claimable) + `Legacy v1 lock with live PID classified as active other` (deny `owned_by_other`) |
| (b) | `git_worktree_acquire` signature gains optional `store` param defaulting to `"hybrid"` (lock v2 requires it; callers may override). | `openspec/specs/worktree-lifecycle/spec.md` (Acquire tool req) + `openspec/specs/gh-git-mcp-server/spec.md` (Worktree acquire tool req) |
| (c) | `already_mine` requires owner AND session match; session is load-bearing — same owner with a different session → `exists_active_other` → deny `owned_by_other`. | `openspec/specs/worktree-lifecycle/spec.md` (Active mine scenario + new "Acquire same owner different session" scenario) + `openspec/specs/gh-git-mcp-server/spec.md` (Acquire denies active other scenario) |

Additionally, the `exists_inactive` gloss was corrected per the design decision table (inactive = worktree, no lock → `attached`; stale = lock + dead PID → `claimed`) and the 4th def-domain copy carries the amendment banner.

**Spec delta syncs performed**:
- `openspec/specs/worktree-lifecycle/spec.md` — created (full spec; amended at archive)
- `openspec/specs/crash-recovery/spec.md` — created (full spec)
- `openspec/specs/gh-git-mcp-server/spec.md` — composed (native `sdd-archive-compose`; delta amended at archive)
- `openspec/specs/git-worktrees-skill/spec.md` — composed (native `sdd-archive-compose`)

## Composition Evidence

Native composition for the two existing main specs (manual Read/Edit merge NOT used — model-driven merges are how archives previously dropped requirements):

```bash
gentle-ai sdd-archive-compose \
  --canonical "openspec/specs/gh-git-mcp-server/spec.md" \
  --delta "openspec/changes/worktree-lifecycle-v2/specs/gh-git-mcp-server/spec.md" \
  --output "openspec/specs/gh-git-mcp-server/spec.md.compose-tmp" \
  && mv "openspec/specs/gh-git-mcp-server/spec.md.compose-tmp" "openspec/specs/gh-git-mcp-server/spec.md"
# exit 0 — composed; 13 requirements preserved (11 original + acquire + release)

gentle-ai sdd-archive-compose \
  --canonical "openspec/specs/git-worktrees-skill/spec.md" \
  --delta "openspec/changes/worktree-lifecycle-v2/specs/git-worktrees-skill/spec.md" \
  --output "openspec/specs/git-worktrees-skill/spec.md.compose-tmp" \
  && mv "openspec/specs/git-worktrees-skill/spec.md.compose-tmp" "openspec/specs/git-worktrees-skill/spec.md"
# exit 0 — composed; 4 requirements preserved (3 original + revised lifecycle extension)
```

The two new full-spec domains (`worktree-lifecycle`, `crash-recovery`) were copied mechanically with `cp` → `diff -r` (empty) → `mv` — never Read → Write through the model.

## Verification — Mechanical Copy Contract

### Archive move readback (MANDATORY `diff -r`)

```text
=== ARCHIVE READBACK diff -r (snapshot vs destination) ===
=== ARCHIVE READBACK: EMPTY DIFF OK ===
```

Empty diff — no differences between the pre-move recursive snapshot and the archived tree. The move used `git mv` first (failed: untracked source; git reported "source directory is empty"), then the plain `mv` fallback after verifying source was unchanged against the snapshot. Source path `openspec/changes/worktree-lifecycle-v2` is gone; destination `openspec/changes/archive/2026-09-09-worktree-lifecycle-v2/` contains all artifacts.

```text
=== diff worktree-lifecycle (copy phase) ===
DIFF_EMPTY_OK worktree-lifecycle
=== diff crash-recovery (copy phase) ===
DIFF_EMPTY_OK crash-recovery
```

Empty diffs — byte-identical mechanical copies for both new full-spec domains.

### Archive contents

```
archive/2026-09-09-worktree-lifecycle-v2/
├── apply-progress.md
├── arch-lint.md
├── council.md
├── design.md
├── proposal.md
├── specs/
│   ├── crash-recovery/spec.md
│   ├── gh-git-mcp-server/spec.md
│   ├── git-worktrees-skill/spec.md
│   └── worktree-lifecycle/spec.md
├── tasks.md        (31/31 [x], 0 unchecked)
└── verify-report.md
```

### Verification checkboxes

- [x] Main specs updated correctly (2 composed + 2 created full specs)
- [x] Change folder moved to archive
- [x] Archive contains all artifacts (proposal, specs ×4, design, tasks, apply-progress, verify-report, council, arch-lint)
- [x] Archived `tasks.md` has no unchecked implementation tasks (0 `[ ]`)
- [x] Active changes directory no longer has this change (`openspec/changes/worktree-lifecycle-v2` absent)
- [x] Verbatim `diff -r` readback output included in result and empty (no differences)

## Final-State Facts and Source Reconciliation

Per the Final-State Authority hierarchy, these launch-prompt facts outrank stale intermediate snapshot claims:

1. **Apply**: 31/31 complete; Python 44/44; Go focused 11/11 on main context; `sync-skills.sh --check` exit 0 from MAIN (0 desyncs), exit 1 from worktree with exactly the 2 intended desyncs (SKILL.md, orchestrator.md). Consistent with `apply-progress` (written at apply-close) and `tasks.md` (all `[x]`).
2. **Verify**: verdict PASS (`pass_with_warnings`), 47/47 scenarios (38 runtime, 9 wiring), 19/19 requirements, 0 CRITICAL/0 BLOCKER. W1 = pre-existing `TestVerifyOnMain` branch-sensitivity (passes on MAIN by design); W2 = sdd-tool not on PATH. Consistent with `verify-report` (written at verify-close). Both `apply-progress` and `verify-report` are intermediate snapshots describing state at their write time; archive close state is unchanged for all completed/verified facts.
3. **Changelog already emitted (pre-archive hook)**: entry appended to worktree `CHANGELOG.md` under `[Unreleased]` (root path); semver **minor**. Not re-emitted per orchestrator order. **Caveat recorded for delivery**: worktree CHANGELOG was a stale copy vs main's working tree (main carries ~10 uncommitted entries from earlier hooks); reconcile both at merge time so main's lines are not lost.
4. **Retro persist (sdd-tool)**: unavailable — binary `~/.config/sdd-own/bin/sdd-tool` NOT installed; advisory only, does not block archive. No recovery action required for this archival.
5. **Spec-delta synced**: the 3 mandated points (a)(b)(c) above. Verified against the 44-test Python suite and 11-test Go observer suite; no spec row contradicted.

## Deviations and Intentional Choices

No CRITICAL issues were open at close. Verify warnings W1 (pre-existing branch-sensitive Go test, passes on MAIN by design) and W2 (sdd-tool PATH note) are documented and non-blocking; no archive-time CRITICAL was overridden. The spec-delta amendments (a)(b)(c) are DESIGN-correct (council risks 1-3, resolved by design convergence; verified by tests) and were synced per the archive mandate, not as a verification defect.

Deviation D1 (ghost-corrupt harden, superset) and D2-D4 (test infra, already_mine short-circuit, release not_found split) are documented in `apply-progress.md` and `verify-report.md`; none contradict the spec or design.

## Worktree Removal Notice

Per repo convention, the orchestrator should remove the implementation worktree at the delivery/merge boundary:

- **Worktree path**: `/home/andy/.agent_worktrees/sdd-own-skills/worktree-lifecycle-v2` (branch `sdd/worktree-lifecycle-v2`, uncommitted)
- The archive closes the CHANGE, not the DELIVERY. The worktree holds the uncommitted implementation (Python, Go, wiring, skill, CHANGELOG) that must be merged to main before removal.
- Removal must go through the supervised `git_worktree_remove` MCP tool per no-git-crudo; dirty pre-check + owner match required.
- Reconcile the worktree `CHANGELOG.md` vs main at merge time (see caveat above).

## Retro Persist

`sdd-tool` binary not installed; `retro` persist did not run. Advisory fail-open, no archive impact.