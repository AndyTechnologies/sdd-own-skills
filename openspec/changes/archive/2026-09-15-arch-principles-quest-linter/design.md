# Design: Architecture Principles — Quest Branch, Lint Axis 3, Plan Checklist

## Technical Approach

Import deployed bytes as canonical (quest v4.0, lint v2.0, orchestrator, 4 prompts, `sdd-architecture-plan` agent), co-updating T34/T35 (`--check` green). Four deltas: shared catalog via the copy-only-if-missing loop; quest rework — 8 base questions + branch table, budget 20; lint axis 3 (independent verdict); mandatory `## Principios no verificables` checklist as ONE dual-signal/N-A contract. Verified by fixtures + T49+. No GoF pattern: catalog = data module (state machine is a non-goal).

## Architecture Decisions

| # | Decision | Alternatives | Why |
|---|---|---|---|
| D1 | Catalog: one file, three consumers, by path | Per-skill copies (drift); parallel JSON (non-goal) | RFC seam; S3 |
| D2 | Schema byte-pinned: P01..P10 + A01..A11; `Default severity` = `blocker` (downgrade → warning is a finding rule, L4) | Free-form | Deterministic fixtures/greps (S4) |
| D3 | Corpus: P-names = acta P-seeds; A01..A11 = Product RFC's binding 11: distributed-monolith, premature-microservices, shared-DB-as-integration, over-engineering, mutable-global-state, excessive-sync, god-object, mud-ball, framework-addiction, copy-paste, excessive-chain-of-responsibility | Acta's provisional A-seeds | RFC corpus user-approved; acta flags A-seeds provisional; axis-3/S4 key on IDs |
| D4 | Checklist states `applicable|direction-evidence|n-a-justified`; runs unless N/A-justified; contradiction → dual signal; literal anchor fail-closed | Two separate mechanics | T35-pinned |
| D5 | Axis 3 inside lint; `fail` iff ≥1 blocker; findings = ID+severity+evidence; ambiguity → warning | New lint skill | Single second-eye flow |
| D6 | Quest: 8 dimensions + table-driven branches, declared precedence | Principle-by-principle | Budget 20 forces context selection |
| D7 | Shared loop += `architecture-principles.md` (4 loops) | New deploy mechanism | Reuses presence-check |
| D8 | Byte-exact import; T34→7 prompts; T35→axis-3 strings; T37 unchanged | Drift tolerated | `--check` green |
| D9 | Fixtures + `expected.json` | Ad-hoc greps | Machine-readable RED (L2/L3) |

## Data Flow

    orchestrator → Quest: 8 context Qs → branch table ──► RFC Q&A (+ classified gaps)
         skills/_shared/architecture-principles.md ◄── by path: quest/plan/lint
    plan → arch-plan.md += ## Principios no verificables (21-state rows)
    apply → lint axes 1+2 (anchor fail-closed, N/A warning) + axis3 → pass|fail report

## File Changes

| File | Action | Notes |
|---|---|---|
| `skills/_shared/architecture-principles.md` | Create | Catalog |
| `skills/sdd-quest/SKILL.md` | Modify | v4.0 + rework |
| `skills/sdd-architecture-lint/SKILL.md` | Modify | v2.0 + axis3 + gate |
| `wiring/prompts/sdd/orchestrator.md` | Modify | deployed bytes |
| `wiring/prompts/sdd/sdd-architecture-plan.md` | Create | v3.0 + checklist |
| `wiring/prompts/sdd/{sdd-hard-gate,sdd-hard-verify,sdd-pre-experience}.md` | Create | verbatim |
| `wiring/opencode.sdd.json` | Modify | agent + allow-list |
| `sync-skills.sh` | Modify | loops += catalog; OWN_PROMPTS += 4 |
| `tests/run_red_checks.sh` | Modify | T34/T35; T49+ |
| `tests/fixtures/arch-principles/` | Create | clean/21 dirty/multi/missing-checklist/translated-anchor/expected.json |

## Interfaces / Contracts

```markdown
## Principles
### P01 — <Name>
- Definition: <...>
- Concrete evidence: <grep trigger>
- Default severity: blocker
## Anti-patterns
| ID | Name | Definition | Concrete evidence | Default severity |
```

**8 base quest dimensions** (acta-bound: Q3/Q4): scope/surface · boundary structure · stack driver · distribution · data & persistence · state & concurrency · integration/framework · non-functional envelope. Branch rows: trigger · catalog IDs · questions · early-stop · precedence.

**Checklist row**: `| {ID} | {state} | {evidence|justification} |`; omitted section → axis 2 fail-closed; N/A unjustified → axis 2 warning. **Envelope**: `axis_3 pass|fail` + per-check `{id, severity, evidence}`.

## Testing Strategy

| RED | Focus | Approach |
|---|---|---|
| T49 | Catalog schema/corpus | grep labels, 10+11, severities |
| T50 | Catalog↔lint sync (S4) | IDs both directions |
| T51 | Single path (S3) | 3 consumers grep path |
| T52 | Shared-loop join (S1/S2) | 4 loops + copy-only-if-missing + `--check` |
| T53 | Quest rework | 8 dimensions, table, budget 20, stack gate, gaps |
| T54 | Checklist contract | literal anchor, fail-closed, translated rejected |
| T55–T59 | Axis-3 fixtures | clean pass; per-family IDs; multi set; N/A suppress; dual signal |
| T60 | Wiring (B5) | agent key + allow-list |

Cheap greps/jq; suite < 2 min; T01–T48 green.

## Threat Matrix

| Boundary | Applicability | Response | RED |
|---|---|---|---|
| Docs-like paths (catalog) | Applicable — new shared data file | Consumed by path as data, never executed | T51; no shebang |
| Git/PR ops | N/A — orchestrator-side only | — | — |
| Shell/subprocess (sync/RED) | Applicable — `cp` installs, `--check` runs | Copy-only-if-missing; check gates installs | T52 + T39 leg |

## Migration / Rollout

Single PR: baseline → deltas → fixtures. `--check` gates; rollback = revert to f9ec832 (zero residual desyncs).

## Open Questions

None blocking. Note: acta A-row subjects are provisional seeds; axis 3/S4 key on IDs, so catalog names govern future acta checklist subjects.