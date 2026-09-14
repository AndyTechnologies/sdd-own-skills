# Proposal: Unified Workflow Implementation

## Intent

Realize the approved quest flow (`quest.md` §3); binding mandate; 3 human gates + human merge. Not greenfield: flips council ALWAYS→optional, changelog pre→post-archive, flat→3-section RFC schema.

## Scope

### In Scope
- `orchestrator.md` Flow Contract restate (quest §3); bootstrap Q40; return edge ≤2
- Council optional (forecast thresholds, fallback design); axis 2 conditional; changelog post-archive
- Hard gate always (ledger + adversarial verifier); preflight 5th; draft PR; quest 3-section schema
- RED T32/T35/T48 rewrite + T49+; workflow-contract delta; diagram in PR; README pointer

### Out of Scope
Per-RFC gates; auto-merge; RFC formats in orchestrator; main-repo work post-confirmation; `sdd-tool` CLI changes.

## Capabilities

Contract for sdd-spec. Sole affected: `workflow-contract`.

### New Capabilities
None — new behavior becomes ADDED requirements in the delta.

### Modified Capabilities
- `workflow-contract` — MODIFIED: council-chain (optional, thresholds), archive-close (post-archive changelog), axis 2 conditional, hooks, overlays, RED T32+; ADDED: hard gate, bootstrap, PR lifecycle, preflight 5th, quest schema, return edge, gh-mcp check.

## Approach

Contract-first (explore #1): restate quest §3 once as sole Flow Contract; sequential flips + RED after each; additive bootstrap, worktree+PR, hard gate (T31/F4 byte-stable), schema; rewrite T32/T35/T48, add T49+, delta, ship diagram.

Forks: council↔arch-lint — quest fixes order (arch-lint pre-council); confirmed axis1 → council → axis2 → tasks. Hard-gate executor — NOT in quest; recommend prompt-defined `sdd-hard-gate`; PENDING design. Council trigger — quest fixes: forecast thresholds, fallback design binding. PR tools — no-git-crudo spec + Q8: `gh-git-mcp` two-phase; preflight checks availability.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `wiring/prompts/sdd/*` + `wiring/opencode.sdd.json` | Modified | Flow Contract, hooks, schema, agent |
| `skills/sdd-*`, `overlays/commands/*`, `tests/run_red_checks.sh` | Modified | Schema, axis 2, trigger, T32/T35/T48, T49+ |
| `openspec/specs/workflow-contract/spec.md`, `docs/diagrams/*`, `README.md` | Modified/Added | Delta, ship diagram, pointer |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Council flip misses pins (T32/T35, spec, overlays) | High | RED after each flip |
| Changelog flip vs archived `sdd-tool` order | High | Flip T48+spec+SKILL together |
| Hard gate replaces F4 hook | Med | Additive; T31 stable |
| Diagram/phase-common outside repo | Med | `overlays/shared` only; PR evidence |

## Rollback Plan

Revert branch (PR unmerged → nothing ships); restore installed state via `./sync-skills.sh` (strip/append idempotent); gate: `--check` 0 desyncs + RED green.

## Dependencies

- `gh-git-mcp` provisioned (setup.sh 5d); `sdd-tool` canonical path; native `sdd-attempt`/`sdd-verify-validate`
- Approved `quest.md` (present)

## Success Criteria

- Zero mid-phase lookups; zero `sdd-tool` not-found; all phases `--cwd <worktree>`
- Draft PR from start, incremental commits, mark-ready; merge human; 3 gates
- Hard gate + arch-lint always (axis 2 iff council); changelog post-archive
- RED green incl. T49+; `sync-skills.sh --check` 0 desyncs; diagram in PR