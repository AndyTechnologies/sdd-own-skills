# Proposal: Architecture Principles — Quest Branch, Lint Axis 3, Plan Checklist

## Intent

Close repo↔deployed drift (HEAD f9ec832 stale vs runtime quest v4.0, lint v2.0, new orchestrator chain, 4 unversioned prompts) and add a verifiable principles loop: quest architecture branch, lint axis 3, plan checklist.

## Scope

### In Scope
- **Baseline import (user-approved)**: import deployed state — quest v4.0, lint v2.0, orchestrator contract, 4 prompts (`sdd-architecture-plan`, `sdd-hard-gate`, `sdd-hard-verify`, `sdd-pre-experience`), `sdd-architecture-plan` agent; co-update T34/T35/T37.
- **Shared catalog** `skills/_shared/architecture-principles.md`: P01..P10 + A01..A11, per-principle name/definition/evidence/severity + anti-pattern table; joins sync-skills.sh copy-only-if-missing loop.
- **Quest arch branch**: 8 base questions, declarative branch/trigger table, stack trigger, early-stop, budget 20, gap classification.
- **Lint axis 3**: P01..P10/A01..A11, severity + findings, `axis_3 pass|fail`; N/A-justified suppresses; dual axis2+axis3 signal.
- **Plan checklist**: mandatory `## Principios no verificables` in arch-plan.md; missing title → axis 2 fail-closed.
- **Fixtures + RED**: `tests/fixtures/arch-principles/` (clean + dirty per family), new T49+; 0 regressions T01–T48/T42b/T47b.

### Out of Scope
Product Quest (50, untouched) · external refactor · parallel JSON catalog · scripted branching.

## Capabilities

> Contract for sdd-spec.

### New Capabilities
- `architecture-principles`: shared catalog, consumed by path
- `architecture-quest-branch`: questioning + branching + early-stop
- `architecture-lint-axis3`: checks, severity, verdict, acta interplay
- `architecture-plan-checklist`: checklist + fail-closed gate

### Modified Capabilities
None.

## Approach

Import deployed bytes as canonical + co-update pins; layer deltas: catalog + shared-loop deploy; quest rework (budget 20); lint axis 3; plan checklist; fixtures + T49+. Single PR, accepted size:exception.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `skills/sdd-quest/SKILL.md` | Mod | v4.0 baseline + rework |
| `skills/sdd-architecture-lint/SKILL.md` | Mod | v2.0 baseline + axis 3 |
| `skills/_shared/architecture-principles.md` | New | Catalog |
| `wiring/prompts/sdd/*.md` (5) | Mod | Orchestrator + 4 prompts |
| `wiring/opencode.sdd.json` | Mod | `sdd-architecture-plan` agent |
| `sync-skills.sh` | Mod | SHARED loop + OWN_PROMPTS |
| `tests/` | Mod/New | T34–37, T49+, fixtures |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Import diverges from deployed | Med | Byte-copy; T-pins |
| Catalog drift (3 consumers) | Med | Single file; fixtures |
| Fail-closed gates block flow | Low | N/A-justified; advisory verdict |

## Rollback Plan

Revert to HEAD f9ec832 (single-PR revert); deployed runtime unaffected — sync gates on `--check`. Deltas: remove catalog + revert edits; re-run `--check` + RED for zero residual.

## Dependencies

sync-skills.sh shared loop · RED harness + fixtures.

## Success Criteria

- [ ] `--check` zero desyncs; RED T01–T48 + T49+
- [ ] Fixtures match expected axis-3 results
- [ ] Arch quest ≤ 20; stack trigger gates; gaps classified
- [ ] arch-plan.md checklist; missing title fails axis 2