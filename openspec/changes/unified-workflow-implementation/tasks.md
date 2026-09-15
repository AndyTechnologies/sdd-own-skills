# Tasks: Unified Workflow Implementation

## Review Workload Forecast

Estimated changed lines: ~700 authored (+~900 generated diagram)

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

PR split: U1→PR1 · U2/U3→PR2 · U4→PR3 · U5→PR4

## Phase 1 — Orchestrator Contract (U1 → PR 1)

```sh
start: grep -n "Council + Architecture" wiring/prompts/sdd/orchestrator.md
finish: grep -q "Unified Flow Contract" wiring/prompts/sdd/orchestrator.md
verification: bash -n tests/run_red_checks.sh
rollback: N/A: PR revert via gh-git-mcp
```

- [x] 1.1 `wiring/prompts/sdd/orchestrator.md`: add `### Unified Flow Contract` after `SDD Session Preflight`
- [x] 1.2 `wiring/prompts/sdd/orchestrator.md`: rule 4 + hooks item 3 → axis 1 ALWAYS → council OPTIONAL thresholds → axis 2 conditional; max 1 retry STOP
- [x] 1.3 `wiring/prompts/sdd/orchestrator.md`: preflight canonical 3 groups (runtime block, no 4th/5th canonical group) + separate worktree/`gh-git-mcp` confirm, bootstrap Q40, PR lifecycle, return edge ≤2, handoff-by-path
- [x] 1.4 `wiring/prompts/sdd/orchestrator.md`: hard gate appended after F4 marker; F4 byte-stable (T31)
- [x] 1.5 `wiring/prompts/sdd/orchestrator.md`: D4 atomic — sdd-tool-integration → changelog(archive-report) → retro → PR ready; flip `skills/sdd-changelog/SKILL.md`; T48 rewrite (3 surfaces + `specs/workflow-contract/spec.md` (read-only))

## Phase 2 — Prompts + Wiring (U2 → PR 2)

```sh
start: grep -n "OWN_PROMPTS=" sync-skills.sh
finish: grep -q "sdd-hard-gate" wiring/opencode.sdd.json
verification: bash -n sync-skills.sh
rollback: N/A: PR revert via gh-git-mcp
```

- [ ] 2.1 `wiring/prompts/sdd/sdd-rfc-author.md`: 3×9 schema; needs-changes branch ≤50 + quest path
- [ ] 2.2 `wiring/prompts/sdd/sdd-council.md`: trigger ALWAYS → OPTIONAL
- [ ] 2.3 Create `wiring/prompts/sdd/sdd-hard-gate.md`: adversarial specs-vs-code, `sdd-attempt` ledger, verdict pass|edge≤2|stop
- [ ] 2.4 `wiring/opencode.sdd.json`: register `sdd-hard-gate` + orchestrator allow; no `mcp`/`__managed_by`; `sync-skills.sh` `OWN_PROMPTS` += `sdd-hard-gate.md`

## Phase 3 — Skills + Overlays (U3 → PR 2)

```sh
start: grep -n "axis" skills/sdd-architecture-lint/SKILL.md
finish: grep -q "acta unreadable" skills/sdd-architecture-lint/SKILL.md
verification: bash -n sync-skills.sh
rollback: N/A: PR revert via gh-git-mcp
```

- [ ] 3.1 `skills/sdd-quest/SKILL.md` Step 6 → 3×9; `skills/sdd-council/SKILL.md` trigger OPTIONAL
- [ ] 3.2 `skills/sdd-architecture-lint/SKILL.md`: `axis: 1|2` + acta locator; axis 2 conditional; fail-closed iff acta unreadable
- [ ] 3.3 `overlays/commands/sdd-continue.md` + `overlays/commands/sdd-ff.md` item 6: axis 1 always → council OPTIONAL → axis 2 conditional; `overlays/commands/sdd-new.md`: preflight canonical 3 (runtime) → separate worktree/`gh-git-mcp` confirm → init → worktree + PR draft → quest

## Phase 4 — RED Rewrite + Rollout (U4 → PR 3)

```sh
start: bash tests/run_red_checks.sh
finish: bash sync-skills.sh --check
verification: bash tests/run_red_checks.sh
rollback: N/A: re-run sync --check after revert
```

- [ ] 4.1 Rewrite T32 (council OPTIONAL) + T35 (axis 2 conditional, fail-closed)
- [ ] 4.2 Append T49–T53: bootstrap, quest 3×9, PR draft/merge-human/`gh-git-mcp`, hard gate (`sdd-attempt`+F4), preflight canonical 3-groups-only + separate worktree confirm, thresholds/return edge/`council: required`
- [ ] 4.3 Pins: lens allow-lists; orchestrator allow `sdd-council`; no `__managed_by`; T31 = F4 block, not offsets
- [ ] 4.4 Run `./tests/run_red_checks.sh` pre-sync (red-first)
- [ ] 4.5 Deploy `./sync-skills.sh --skip-gentleai-sync`; `--check` 0 desyncs + RED green (T30/T31/T34/T48)

## Phase 5 — Docs (U5 → PR 4)

```sh
start: ls docs/diagrams/
finish: test -f docs/diagrams/sdd-workflow-unified.html
verification: grep -q "sdd-workflow-unified" README.md
rollback: N/A: PR revert via gh-git-mcp
```

- [ ] 5.1 Copy `docs/diagrams/sdd-workflow-unified.html` + `.visual-check.json` (main repo (read-only)); swap `README.md` flow ref
- [ ] 5.2 Archive note: compose delta into `specs/workflow-contract/spec.md` via native `gentle-ai sdd-archive-compose --canonical <path> --delta <path>` at archive (never manual merge)