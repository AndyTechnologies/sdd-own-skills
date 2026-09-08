# Tasks: sdd-council (F4 Council Chain)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 600–750 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: skill+pipeline → PR 2: sync/orchestrator → PR 3: arch-lint/overlays/RED |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

Budget 800; estimate crosses default 400 → single-pr needs `size:exception` unless chain resolves.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | skill + prompt + wiring | PR 1 | `./tests/run_red_checks.sh` | `./sync-skills.sh --check --skip-gentleai-sync` | delete `skills/sdd-council/`, `wiring/prompts/sdd/sdd-council.md`, revert agent blocs |
| 2 | sync merge + depth + orchestrator | PR 2 | `./tests/run_red_checks.sh` (T38/T39) | real `./sync-skills.sh`; `.subagent_depth == 2` installed | `jq 'del(.subagent_depth)'` installed + revert sync |
| 3 | arch-lint axis 2 + overlays | PR 3 | `./tests/run_red_checks.sh` (T35) | `./sync-skills.sh --check` | revert arch-lint + overlays |

```sh
start: N/A: task artifact; edit boundaries set per unit
finish: N/A: single-pr delivery; units merge into one PR
verification: ./tests/run_red_checks.sh
rollback: N/A: per-unit rollback boundaries above
```

## Phase 1: Foundation

- [x] 1.1 Create `skills/sdd-council/SKILL.md`: 3 lens sections (arch/product/risk), parallel `task()` orchestration, convergence/fork/re-frame rules, 2-round cap, acta format (`## Lens Verdicts`/`## Decision`/`## Convergence`/`## Round`/`## Selected Option`); invariants — never decides forks alone, never relaunches design, read-only `design.md`, stateless, absent from `nextRecommended`.
- [x] 1.2 Create `wiring/prompts/sdd/sdd-council.md` (council prompt: lens dispatch, convergence vs fork framing).
- [x] 1.3 Register 4 agents in `wiring/opencode.sdd.json`: `sdd-council` (file prompt, `permission.task = {"*":"deny", 3 lenses:"allow"}`) + 3 inline lenses (subagent, hidden, `permission: {}`); NO `__managed_by`; NO `mcp`; `gentle-orchestrator` allow-list gains `sdd-council`.
- [x] 1.4 Add `sdd-council.md` to `OWN_PROMPTS` (`sync-skills.sh:105`).

## Phase 2: Core

- [x] 2.1 Add top-level `"subagent_depth": 2` to `wiring/opencode.sdd.json` (only-SDD-keys exception).
- [x] 2.2 Extend jq merge (L801): `| .subagent_depth = ($f.subagent_depth // $u.subagent_depth)` — fragment-wins, idempotent.
- [x] 2.3 Extend python fallback (L859-866): copy `frag["subagent_depth"]` when present; idempotent. Touch NO agent logic/`.bak` (L891).
- [x] 2.4 Rewrite `orchestrator.md` rule 4 (L493): design → council (ALWAYS) → arch-lint (ALWAYS, acta mandatory) → gate; auto max 1 retry; convergence no interruption; forks → user lossless blocking prompt; max 2 rounds STOP. Keep F4 (L405-414) + consent byte-stable (T31).
- [x] 2.5 Extend hooks item 3 (L371-375) to council → arch-lint(acta) → gate (T32).

## Phase 3: Integration

- [x] 3.1 Add axis 2 to `skills/sdd-architecture-lint/SKILL.md`: verify each acta `## Decision` title-by-title vs design (✅/⚠️/❌); acta MANDATORY, fail-closed if missing; `N/A` only empty/trivial design; axis 1 unchanged (T35).
- [x] 3.2 `overlays/commands/sdd-continue.md` SUPPORT-CONDITIONAL: council ALWAYS → arch-lint(acta) ALWAYS; drop boundary skip.
- [x] 3.3 `overlays/commands/sdd-ff.md` item 6: flip to ALWAYS council → arch-lint(acta).

## Phase 4: Testing

- [x] 4.1 Append T32+ to `tests/run_red_checks.sh` (T28/T29/T31 pattern): T32 council ALWAYS (hooks); T33 orchestrator→council + council→3 lenses; T34 OWN_PROMPTS + file; T35 acta fail-closed; T36 convergence fast-path + forks→user + 2-round STOP.
- [x] 4.2 T37 no-`mcp` on FRAGMENT only (installed config legitimately has mcp).
- [x] 4.3 T38: `jq -e '.subagent_depth == 2'` fragment AND installed (strict-JSON parse).
- [x] 4.4 T39: extended merge BOTH engines — `--check` with jq; then hide jq (force python); zero DESYNC both.
- [x] 4.5 Amend `AGENTS.md` merge rules with `subagent_depth` sanction note (R1).

## Phase 5: Apply Sequencing

- [x] 5.1 (R2) First RED run BEFORE sync → T38/T39/T30 DESYNC expected-then-clean; test comments name it; then one real `./sync-skills.sh`; T30 comment "full sync applied by orchestration" sets convention.
- [x] 5.2 (R3) Rollback leaks key (additive merge; `.bak` stale Sep 4): `jq 'del(.subagent_depth)'` installed + revert fragment + revert sync; document in handoff.
- [x] 5.3 Final: `./sync-skills.sh --check --skip-gentleai-sync` → 0 desyncs AND `./tests/run_red_checks.sh` green (>= 31 + new).