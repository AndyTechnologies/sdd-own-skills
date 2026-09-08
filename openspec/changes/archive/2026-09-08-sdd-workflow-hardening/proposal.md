# Proposal: SDD Workflow Hardening

## Intent

Phase 0 landed workflow contracts as prompt/overlay text only — nothing operationalizes them inside executor skills. This change enforces F1+F2+F3+F4: machine-checkable SWU shape, fail-closed validation at apply/verify, config-protection, and the post-verify RDD hook that finally triggers the review lifecycle.

## Scope

### In Scope
- 3 NEW overlay files (strip+append on Alan's untouched bases):
  - `overlays/skills/sdd-tasks/SKILL.md` — block `sdd-own:sdd-tasks-swu-shape` (F1 emission: explicit start/finish/verification/rollback tokens + machine-checkable shape; never free-form prose)
  - `overlays/skills/sdd-apply/SKILL.md` — blocks `sdd-own:sdd-apply-swu-validate` (F1: shape-validate before execute; malformed → fail-closed rejection + finding + blocked unit; no approx/paraphrase/group) + `sdd-own:sdd-apply-edit-authority` (F3: no config edits outside authorized roots without consent; `blocked(edit_authority_missing)` two-exit relay)
  - `overlays/skills/sdd-verify/SKILL.md` — blocks `sdd-own:sdd-verify-evidence-shape` (F1 fail-closed duro: malformed evidence discarded → unit `not-verifiable` → blocks until apply corrects; no degrade) + `sdd-own:sdd-verify-edit-authority` (F3: only write target is change's own verify-report)
- ONE additive orchestrator.md hook (F4): new clause between `### Automatic Mode Gatekeeper` (L377-403) and `### Native Runtime Attempt Authority` (L405) — post-verify + RDD ON → selectorless preflight; consent/v3 relayed losslessly in interactive AND auto (never skips human authorization); decline → candidate-scoped, re-enter STATUS, pipeline continues to archive.
- Tests: `tests/run_red_checks.sh` Grupo 7 after T27 — T28 contract-pin greps, T29 SWU shape probe, T30 sync idempotency/id hygiene, T31 F4 hook pins.

### Out of Scope
- No rewrite of Phase 0 contract text (`shared-untrusted-data` block, orchestrator rule 2).
- No permissions wiring, MCP registration, `wiring/opencode.sdd.json` merge, new features.
- No change to Review Execution Contract mechanics, RDD switch semantics, or Native RAR lens planning.
- No review-gated archive (decline → pipeline continues; review is informational for delivery).

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `workflow-contract`: F1 — SWU commands carry explicit tokens + machine-checkable shape; verify fail-closed duro. F3 — apply/verify protect config surfaces via `blocked(edit_authority_missing)`. F4 — post-verify hook triggers review preflight when RDD ON.

## Approach

Exploration Approach 1: one overlay file per executor skill, 5 unique `sdd-own` ids, anchors by section heading (resist base drift). F4: single additive hook clause placed between gatekeeper and runtime-attempt sections. All canonical pins verbatim from shared block/orchestrator rule 2. Behavioral breaks: (a) prose-shaped tasks artifacts fail closed at apply until regenerated; (b) post-verify 4R preflight now fires when RDD is ON (consent relayed always).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `overlays/skills/sdd-tasks/SKILL.md` | New | F1 SWU emission shape |
| `overlays/skills/sdd-apply/SKILL.md` | New | F1 validate + F3 authority |
| `overlays/skills/sdd-verify/SKILL.md` | New | F1 duro + F3 authority |
| `wiring/prompts/sdd/orchestrator.md` | Modified | F4 post-verify hook clause (additive) |
| `tests/run_red_checks.sh` | Modified | Grupo 7 (T28–T31) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Wording drift vs shared block | Med | Pins verbatim; T28 greps |
| Old-shape tasks blocked at apply | High | Intended fail-closed; regenerate tasks.md |
| Sync id collision/bad marker | Low | T30 + `--check`; ids verified unique |
| F4 adds interaction point per change | Low | Accept per user decision; decline keeps pipeline moving |

## Rollback Plan

Strip the 5 `sdd-own` blocks from the 3 overlay files, revert the orchestrator.md hook clause, re-run `./sync-skills.sh` → installed bases return byte-identical to Alan's; drop Grupo 7 from tests. `--check` zero-desync before/after.

## Dependencies

- Alan bases `sdd-tasks` v2.0 / `sdd-apply` v3.0 / `sdd-verify` v3.0 (append-only).
- `sync-skills.sh` strip+append mechanics.

## Decision Log

- **D1 (user, confirmed)**: scope = F1+F2+F3+F4 (user chose F4 inside this change).
- **D2 (user, confirmed)**: verify enforcement = fail-closed duro (`not-verifiable` + block until apply corrects).
- **D3 (user, confirmed)**: F4 consent decline → pipeline continues to archive (review is informational).
- **D4 (exploration)**: Approach 1 — 3 overlays + F4 hook + Grupo 7 (T28–T31).

## Success Criteria

- [ ] `./sync-skills.sh --check` zero desyncs
- [ ] T28–T31 green; shape probe asserts 4 tokens + fail-closed chain + F4 hook pins
- [ ] Old-shape tasks artifact fails closed at apply
- [ ] Canonical pins greppable in installed tasks/apply/verify + orchestrator.md
- [ ] Orchestrator.md Review Execution Contract sections untouched except new hook
