# Architecture Lint — sdd-tool (independent re-verification)

**Change**: sdd-tool
**Phase**: sdd-architecture-lint (post-design council, pre-tasks)
**Round**: 2 — fresh independent verification of the REVISED design against the council acta (supersedes prior `arch-lint.md` retry round)
**Date**: 2026-09-08
**Verdict**: FINDINGS — 1 medium (D1 proposal reconciliation declared-but-not-materialized) + 1 low (D2 not propagated to spec deltas). All architecture-boundary concerns conform. The design does NOT need a re-launch.

## Executive Summary

The revised `design.md` ("Revised against council acta (binding) + arch-lint findings") now incorporates all acta decisions on the design side: **D2** asymmetric fail-open (reads warn-and-continue; writes loud-fail non-zero naming the lost write), **D3** one shared pure `Scrub` extended to retro bodies with the full `ghp_|gho_|ghu_|ghs_|ghe_|github_pat_` prefix set, **D4** rollback via REAL `./sync-skills.sh`, and **D5** loud scanner-parse failure with an explicit process-lifetime snapshot contract in the dashboard UI — plus the council-arch lens concern (F6): the scanner snapshot is now LAZY per command, not an eager `PersistentPreRunE` parse. Axis 1 (clean/hexagonal) conforms on every boundary the design introduces. The one substantive residue is NOT architectural: the design asserts `proposal.md` was reconciled to the direct-edit (D1), but the actual `proposal.md` still lists the forbidden `overlays/skills/sdd-changelog/` file; a second, low-severity gap appeared in the spec deltas, which still describe uniform fail-open instead of the acta's asymmetric class split. **The design is architecturally sound and must NOT be re-launched;** the two findings are artifact-level consistency fixes the orchestrator can apply directly before tasks freeze.

## Axis 1 — Boundaries Reviewed (REVISED design)

**Boundaries reviewed**: module boundaries (`srv/sdd-tool/internal/*`), ports & adapters (Store, Repository, engram adapter), dependency injection (lazy scanner snapshot), domain isolation (scrub/precis/signals), external access (git, gentle-ai, engram, sqlite).

| Concern | Verdict | Rationale |
|---------|---------|-----------|
| New layers / module boundaries | ✅ Conforms | `cmd/sdd-tool/main.go` (composition root) → `internal/{scanner,retro,worktree,incidents,dashboard,engram}`. Facade (scanner), Strategy (`Store` pair), Adapter (engram), Repository (incidents) stay textbook-appropriate; dependencies point inward. No outward dependency inversion introduced. |
| Ports & adapters | ✅ Conforms | External concerns remain behind ports: `gentle-ai sdd-status` subprocess → scanner facade; engram subprocess → adapter; SQLite → `Repository`; openspec files → `openspecStore`; git → read-only convention-derived probes (`git -C` only, never user argv). The asymmetric fail-open (D2) is command-class policy at the handler/facade layer, not a port leak. |
| Dependency injection | ✅ Conforms | The prior risk (eager `PersistentPreRunE` parse for ALL commands) is gone: D4 builds `Scanner.Snapshot` lazily, only when a listing surface requires it (`retro lookup`, `worktree list\|verify`, `dashboard --json`, `bug list`); mutating commands (`bug record`, `retro persist`) never invoke or wait on the parse (design L17, L7). Store mode and `--db` are injected inputs, never derived from `sdd-status.artifactStore`. |
| Domain isolation | ✅ Conforms | Precis cap/dedupe, shared pure `Scrub(string) string`, and the 3-signal verify stay framework-free; cobra/bubbletea/lipgloss confined to `cmd/` and `internal/dashboard`. Fail-open class policy and snapshot laziness are orchestration concerns, not core-domain coupling. |
| External access | ✅ Conforms | All outbound access routed through adapters; "never writes `~/.engram/engram.db`" (subprocess-only) preserved; data flow (L27–34) confirms adapter-outer ordering with the read/write exit-code split. |

## Axis 2 — Council Acta Verification (title-by-title, MANDATORY)

The acta's `## Convergence` is `convergence` (not fork): all three lenses converged on D1(b)/direct edit, and the revised design's D1 chose (b). Consistent. ✅

| Acta Decision | Verdict | Evidence |
|---------------|---------|----------|
| D1 changelog direct edit | ⚠️ Partial | Mechanism fully incorporated: D1 (design L11) chooses (b) direct edit of `skills/sdd-changelog/SKILL.md`; File Changes L46 lists the Modify row "Pre-archive verify-report input (D1)"; Technical Approach L7 "edited in place (D1)"; verify-report pre-archive + "absent archive-report → blocked post-archive only" stated verbatim per acta. Grounded: `sync_dir` real-mode `cp -R` clobbers the destination (sync-skills.sh L358), `--check` reports `[DESYNC]` only (L372). **BUT the acta's reconciliation clause is NOT materialized**: design D1 declares "`proposal.md` … is corrected to `skills/sdd-changelog/SKILL.md — Modified (direct edit)` … (D1 resolved)", while the ACTUAL `proposal.md` still lists `overlays/skills/sdd-changelog/SKILL.md — New` (L47), "sdd-changelog thin overlay" (L13), and rollback "Strip overlay clauses (… sdd-changelog)" (L64). The design-side guard rail "Executors MUST NOT create `overlays/skills/sdd-changelog/`" mitigates, but the binding proposal artifact still contradicts. |
| D2 asymmetric fail-open | ✅ Applied | D2 (L12–15) splits by command class: reads (`retro lookup`, `worktree list\|verify`, `dashboard`, `bug list`) warn-and-continue fail-open; data-producing (`retro persist`, `bug record`, `bug resolve`) exit non-zero with a loud, non-ignorable FAIL-OPEN marker naming the lost write ("FAIL-OPEN: retro persist lost write to engram store — output not persisted"). Data Flow (L31–33) distinguishes read exit 0\|1 vs write exit non-zero + marker; Technical Approach L7 states "Fail-open is asymmetric". Matches acta D2 exactly. |
| D3 scrub scope extension | ✅ Applied | D6 (L19): "scrub = ONE shared pure function applied uniformly to incident summaries AND retro bodies (acta D3)". Scrub spec (L66–72) covers `ghp_\|gho_\|ghu_\|ghs_\|ghe_\|github_pat_`, PEM blocks, key/value pairs, absolute paths; applied to retro `--body`/`--body-file`; L115 confirms `ghe_`/`github_pat_` now covered and the engram long-lived-memory rationale. Matches acta D3. |
| D4 rollback via real sync | ✅ Applied | Rollout/Rollback (L105): reverting the changelog direct edit "additionally requires `./sync-skills.sh` in REAL mode to propagate the reverted canonical to `~/.config/sdd-own/skills/sdd-changelog/`"; `--check` alone only REPORTS DESYNC; rollback gate = zero-desync check AFTER the real sync. Grounded: sync-skills.sh L358 (real `cp` overwrite) and L372 (`[DESYNC]` report-only). Matches acta D4. |
| D5 scanner failure loud, snapshot explicit | ✅ Applied | D4 (L17): "Parse failure ⇒ exit non-zero loudly, never fabricate empty worktree/dashboard surfaces (acta D5)". D7 (L20): "UI help line documents that the snapshot is process-lifetime and `r` re-parses once per keypress … never fabricates empty surfaces". Data Flow (L34) same. Matches acta D5. |

## Findings

| # | Axis | Severity | Title | Evidence |
|---|------|----------|-------|----------|
| F4 | 2 | medium | Acta D1 reconciliation declared in design but NOT applied to `proposal.md` | design D1 (L11) asserts "`proposal.md` affected-areas row … is corrected to `skills/sdd-changelog/SKILL.md — Modified` … rollback references … replaced … (D1 resolved)". Actual `proposal.md`: L47 `overlays/skills/sdd-changelog/SKILL.md — New`, L13 "sdd-changelog thin overlay", L64 rollback "Strip overlay clauses (orchestrator.md, sdd-changelog)". The design-side prohibition (L11 "Executors MUST NOT create `overlays/skills/sdd-changelog/`") covers tasks fed by the design, but a proposal-fed executor or reviewer cross-checking proposal vs design can still re-introduce the overlay file the council convened to forbid. |
| F7 | 2 | low | Acta D2 not propagated to the spec deltas (verification contract lags design) | `specs/sdd-tool-cli/spec.md` L43: "Any tool absence or subcommand error SHALL exit non-zero without blocking the SDD flow" — uniform, no read/write class split; no scenario asserting the write-class loud FAIL-OPEN marker or "never silent success". `specs/workflow-contract/spec.md` L89 similarly uniform ("any tool absence or error degrades executors to exactly the pre-tool behavior"). Since `sdd-verify` validates against specs, the acta's loud-write contract could pass verification untested. Minimal fix: split the CLI spec's Fail-open requirement into read-class (warn+continue) and write-class (loud marker + non-zero, never silent success) scenarios. |

## Closed Findings (prior round re-check)

| Prior | Status | Evidence (CURRENT design.md) |
|-------|--------|------------------------------|
| F1 / acta D2 (high) | ✅ closed | D2 L12–15 + L7 + L31–33: reads warn-and-continue; writes exit non-zero with loud FAIL-OPEN marker naming the lost write; never silent data loss. |
| F2 / acta D4 (medium) | ✅ closed | L105: real-mode `./sync-skills.sh` in rollback; `--check` DESYNC-report-only; zero-desync gate after real sync. |
| F3 / acta D3 (medium) | ✅ closed | D6 L19 shared pure `Scrub` for incidents AND retro bodies; L66–72 full prefix set incl. `ghe_` and `github_pat_`; L115 rationale. |
| F5 / acta D5 (low) | ✅ closed | D4 L17 + D7 L20 + L34: loud non-zero on parse failure, never fabricate empty surfaces; UI help line documents process-lifetime snapshot + `r` re-parse. |
| F6 lazy scanner (low) | ✅ closed | D4 L17: lazy per-command snapshot, built only for listing surfaces, NOT in `PersistentPreRunE`; mutating commands never invoke/wait on the parse. Council-arch lens concern resolved. |

## Recommendations

1. **No design re-launch.** The design is architecturally clean (axis 1 conformant; the only prior axis-1 risk — eager DI — is resolved). None of the acta decisions are missing from the design.
2. **Before tasks freeze (orchestrator applies accepted findings, per arch-lint contract):** reconcile `proposal.md` — L47 affected-areas row → `skills/sdd-changelog/SKILL.md | Modified | direct edit (verify-report pre-archive input)` (drop `overlays/skills/sdd-changelog/` New row); L64 rollback → "revert the direct edit + real-sync redeploy (acta D4)"; L13 scope wording "thin overlay" → "direct edit". This materializes the acta D1 reconciliation clause the design currently only declares.
3. **Spec delta fix (F7):** split `sdd-tool-cli` spec "Fail-open execution" into read-class vs write-class scenarios asserting the loud FAIL-OPEN marker and non-zero exit for `retro persist`/`bug record`/`bug resolve` — so verify exercises the acta D2 contract.
4. **D1 gate:** the maintainer-acknowledgment question is closed on the design side (Open Questions L109: "None — D1 maintainer change is resolved above"): the mechanism change (direct edit + real-sync rollback) is stated as the binding decision.

## Risks

- **Residual F4 (medium, owned by orchestrator):** if `proposal.md` is not reconciled before apply, a proposal-fed executor may create `overlays/skills/sdd-changelog/` — re-introducing the exact AC1 DESYNC failure the council convened to avoid. Low probability (design prohibition is explicit) but the contradiction sits on a binding artifact.
- **F7 (low):** verification may green-light the change without ever exercising the write-class loud-fail marker, leaving the asymmetric contract untested.
- No architectural risk on the revised design: axis 1 conforms; the design follows the repo's own sync/wiring model rather than reforming it (no-dogma rule).

## Artifact Locators

- OpenSpec (OVERWRITTEN, round 2): `openspec/changes/sdd-tool/arch-lint.md`
- Engram (updated, upsert): topic `sdd/sdd-tool/arch-lint` (type `architecture`, capture_prompt false, project `sdd-own-skills`)