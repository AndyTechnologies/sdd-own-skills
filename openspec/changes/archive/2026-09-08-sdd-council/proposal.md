# Proposal: sdd-council (F4 Council Chain)

## Intent

Orchestrator rule 4 describes a post-design multi-voice council with convergence/fork logic and acta persistence, but none of this machinery exists. This change builds it: a new skill, 4 agents, orchestrator hooks, arch-lint extension, and RED checks — converting aspirational prose into enforceable pipeline behavior.

## Scope

### In Scope

- `skills/sdd-council/SKILL.md` — new exclusive skill: 3 lens sections (arch/product/risk), parallel `task()` orchestration, convergence/fork/re-frame rules, 2-round hard cap, acta format
- `wiring/opencode.sdd.json` — 4 agents: `sdd-council` (file-based, own `task` allow-list for lenses), `sdd-council-arch`, `-product`, `-risk` (inline, subagent, hidden, `permission: {}`); `gentle-orchestrator` task allow-list gains `sdd-council`
- `wiring/prompts/sdd/sdd-council.md` — file-based prompt (sdd-rfc-author.md pattern); added to `OWN_PROMPTS` (sync-skills.sh:105)
- `wiring/prompts/sdd/orchestrator.md` — rewrite rule 4 + extend Organic hooks item 3: council ALWAYS → arch-lint ALWAYS (acta mandatory) → gate; auto max 1 retry; convergence = no interruption; forks → user; max 2 rounds STOP. F4 post-verify text + consent strings byte-stable (T31)
- `skills/sdd-architecture-lint/SKILL.md` — axis 2: acta title-by-title verification; acta mandatory (fail-closed on missing); `N/A` preserved only for empty/trivial design
- Command overlays: `sdd-continue.md` SUPPORT-CONDITIONAL + `sdd-ff.md` item 6 — ALWAYS council → arch-lint(acta); evaluate `sdd-new.md`
- `tests/run_red_checks.sh` — T32+ pins: hook pins, acta-as-lint-input, convergence fast-path, forks → user, 2-rounds STOP, task allow-list asserts, OWN_PROMPTS assert, no-mcp assert

### Out of Scope

- Per-lens skills (3 separate full-installs) — deferred unless arch-lint reverse evidence demands it
- Automatic fork resolution / voting — the human decides forks, always
- `nextRecommended` changes — council is an organic hook, not a pipeline token
- Reuse of gentle-ai 4R review agents — only lens categorization concept borrowed

## Capabilities

### New Capabilities

- `sdd-council`: Multi-voice post-design review with convergence/fork logic, acta persistence, 2-round cap, and arch-lint integration

### Modified Capabilities

- `workflow-contract`: Council-chain target flow requirement gains concrete machinery (skill + agents + hooks); arch-lint boundary-free skip removed

## Approach

Three canonical choices carried from exploration:

| Choice | Decision | Rationale |
|--------|----------|-----------|
| **O1** Agent prompt wiring | File-based `sdd-council.md` + inline lens agents | Orchestrator prompt is substantial (acta format, flows); lens prompts are tiny. Matches existing mixed precedent (sdd-rfc-author file-based + sdd-architecture-lint inline). |
| **O2** Skill structure | Single `sdd-council` skill, 3 lens sections | One full-install; lens sections inside the skill. Matches RFC "lens skill or lens section" wording. 3 separate skills is over-engineering. |
| **O3** Lens orchestration | `sdd-council` agent orchestrates lenses internally | Matches RFC flow diagram. Requires `sdd-council` to have its own `task` allow-list for the 3 lens agents (wiring point). |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `skills/sdd-council/` | New | Exclusive skill with council orchestration contract |
| `skills/sdd-architecture-lint/SKILL.md` | Modified | Axis 2 (acta verification), mandatory acta input |
| `wiring/opencode.sdd.json` | Modified | 4 new agents + orchestrator task allow-list extension |
| `wiring/prompts/sdd/sdd-council.md` | New | File-based prompt for council orchestrator agent |
| `wiring/prompts/sdd/orchestrator.md` | Modified | Rule 4 rewrite, Organic hooks item 3 extension |
| `overlays/commands/sdd-continue.md` | Modified | SUPPORT-CONDITIONAL council → arch-lint chain |
| `overlays/commands/sdd-ff.md` | Modified | Item 6: ALWAYS arch-lint after council |
| `tests/run_red_checks.sh` | Modified | T32+ RED checks appended |
| `sync-skills.sh` | Unchanged | Auto-discovers new skill; additive agent merge |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `sdd-council` lacks `task` permission for lens agents → parallel flow breaks | Med | RED check pins `sdd-council`'s task allow-list; wiring review |
| T30 desync from file-based prompt not in `OWN_PROMPTS` | Med | RED check pins `OWN_PROMPTS` includes `sdd-council.md` |
| T31 pin interference from rule 4 rewrite | Low | F4 post-verify text (lines 405-414) byte-stable; only rule 4 prose changes |
| Arch-lint `N/A`-skip removal inconsistent across entry routes | Low | Command overlays + orchestrator hooks updated atomically |
| Partial acta write (file written, Engram not) → arch-lint false fail-closed | Low | Fail-closed is the safe direction; single writer contract in skill |

## Rollback Plan

Revert the commit touching these files. No migration data to roll back — council is additive machinery. The orchestrator rule 4 and Organic hooks revert to prose-only. Arch-lint reverts to boundary-conditional skip.

## Dependencies

- `openspec/changes/sdd-council/quest.md` (approved RFC) — binding mandate
- `openspec/changes/sdd-council/exploration.md` (validated) — technical grounding
- `openspec/specs/workflow-contract/spec.md` — council-chain requirement exists; this change fulfills it

## Success Criteria

- [ ] `skills/sdd-council/SKILL.md` exists with lens definitions, convergence/fork rules, 2-round cap, acta format
- [ ] 4 agents in `wiring/opencode.sdd.json` with no `__managed_by`; orchestrator task allow-list includes `sdd-council`; `sdd-council` has task allow for 3 lens agents
- [ ] `wiring/prompts/sdd/sdd-council.md` exists and is in `OWN_PROMPTS`
- [ ] Orchestrator rule 4 + Organic hooks describe the enforceable council → arch-lint(acta) → gate chain
- [ ] Arch-lint axis 2 verifies acta decisions title-by-title; missing acta = fail-closed
- [ ] T32+ RED checks pass covering all invariants
- [ ] `./sync-skills.sh --check` reports 0 desyncs
- [ ] F4 post-verify and consent strings byte-stable (T31 green)

## Review Workload Forecast

- **Estimated changed lines**: ~350-500 (skill ~100, agents ~80 in JSON, orchestrator ~60, arch-lint ~40, overlays ~30, RED checks ~80, prompt file ~60)
- **Chained PRs recommended**: Yes
- **Decision needed before apply**: Yes (delivery strategy)
- **400-line budget risk**: Medium

> The changed-line estimate approaches or exceeds the 400-line review budget. Chained PRs are recommended. The delivery strategy decision should be confirmed before apply.

## Key Learnings

1. Council is an organic support phase — it must never touch nextRecommended or the pipeline token set.
2. The `sdd-council` agent needs its own `task` allow-list to spawn the 3 lens agents — this is a hard wiring requirement, not a style choice.
3. F4 post-verify consent strings in orchestrator.md (lines 405-414) must remain byte-stable for T31 to keep passing.
