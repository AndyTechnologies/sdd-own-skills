# Design: sdd-council (F4 Council Chain)

## Technical Approach

Convert rule 4's prose into enforceable machinery. A support-phase skill (`sdd-council`), an organic hook never touching `nextRecommended`, orchestrates 3 lens agents via `task()`, persists an acta, feeds it to extended `sdd-architecture-lint`. Fires ALWAYS after design; config root gets `subagent_depth: 2` via EXTENDED sync step-3 merge.

## Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Skill structure (O2)** | Single `sdd-council` skill, 3 lens sections (arch/product/risk) | One full-install; single lens-framing source; per-lens skills over-engineered (RFC permits 'lens section'). |
| **Prompt wiring (O1)** | `sdd-council` file-based ({file:…/sdd-council.md}); lenses inline | Council prompt substantial/versionable (mirrors `sdd-rfc-author.md`); lens prompts tiny; small `OWN_PROMPTS`. |
| **Lens orchestration + depth (O3-runtime)** | `sdd-council` orchestrates lenses via own `task` allow-list; ROOT knob `subagent_depth: 2` | Nested task-permission: council `task`-allows the 3 lenses; orchestrator needs only `sdd-council`. Depth ROOT-only (`task.ts:106-115` reads `?? 1`); agent.ts has NO field; per-agent PR #37226 unmerged. Top-level fragment key — documented only-SDD-keys exception (SDD-runtime requirement); sync edit REQUIRED (current merge drops root keys, sync-skills.sh:801/861). Extension: jq `| .subagent_depth = ($f.subagent_depth // $u.subagent_depth)`; python: copy fragment root key when present — idempotent. **Fragment wins** (like `agent.*`, not `default_agent` on-absent — pipeline invariant; pre-value in `.bak`; T38 deterministic). |
| **Arch-lint opt-out** | `N/A` skip removed; valid only empty/trivial | Behavior change; overlays update atomically. |
| **Round state** | Council stateless; retry budget in orchestrator | No round corruption. |
| **Acta writer** | Single writer (`sdd-council`) persists file + Engram | No half-persisted acta; missing = fail-closed. |

## Data Flow

```
design done → hook (ALWAYS) → task(sdd-council)
→ 3 parallel lenses → consolidate → acta (file + Engram)
→ verdict: convergence | fork | reframe (≤2 rounds)
CONVERGENCE → proceed; FORK → user; round-2 unresolved → STOP
→ arch-lint ← acta MANDATORY (fail-closed); axes 1+2
PASS → tasks | FAIL → redesign (max 1 retry → STOP)
```

## File Changes

| File | Action | Description |
|---|---|---|
| `skills/sdd-council/SKILL.md` | Create | Lens sections, parallel orchestration, fork/convergence, 2-round cap, acta format, invariants. |
| `wiring/opencode.sdd.json` | Modify | Add `sdd-council` (file-based, subagent, own allow-list) + 3 inline lenses; orchestrator allow-list gains `sdd-council`; top-level `subagent_depth: 2`. No `__managed_by`, no `mcp`. |
| `sync-skills.sh` | Modify | Extend step-3 merge (jq + python) to carry root `subagent_depth` (fragment-wins, idempotent). |
| `wiring/prompts/sdd/sdd-council.md` | Create | Council prompt; add to `OWN_PROMPTS` (sync-skills.sh:105). |
| `wiring/prompts/sdd/orchestrator.md` | Modify | Rule 4 (L493) + hook item 3 (L373): council ALWAYS → arch-lint ALWAYS (acta); forks→user; 2-round STOP. F4 (L405-414) + consent byte-stable (T31). |
| `skills/sdd-architecture-lint/SKILL.md` | Modify | Axis 2: acta mandatory (fail-closed), verify decision titles; axis 1 preserved; `N/A` only empty/trivial. |
| `overlays/commands/sdd-{continue,ff}.md` | Modify | ALWAYS council → arch-lint(acta). |
| `tests/run_red_checks.sh` | Modify | Append T32+ (below). |

`sdd-new.md`: no council hook — stops at propose; fires on `/sdd-continue`.

## Interfaces / Contracts

**Agent wiring** — `sdd-council` (file-based `{file:…/sdd-council.md}`, subagent) with `permission.task` = `{"*":"deny","sdd-council-arch":"allow","sdd-council-product":"allow","sdd-council-risk":"allow"}`; lens agents (inline, subagent) read their lens section, no `task`.

**Acta format** (`openspec/changes/{change}/council.md` + Engram `sdd/{change}/council`): `## Lens Verdicts`, `## Decision` (titled), `## Convergence`, `## Round`, `## Selected Option` (forks).

**Hook text** (rule 4 L493; Organic hooks item 3 L373): council ALWAYS after design (lenses, acta, convergence, forks→user, 2-round STOP); arch-lint ALWAYS (acta mandatory); ≤1 retry, then STOP.

**Arch-lint axis 2 flow**: acta missing → fail (halt); else verify each titled Decision vs `design.md` (✅/⚠️/❌).

## Testing Strategy

### Threat Matrix
All rows `N/A` — no shell/git/gh/PR/exec boundary. The `task()` boundary = ROOT `subagent_depth` knob (global; `task.ts:106-115`) + `task` allow-list; blast radius bounded — authorization stays per-agent. Data/config controls — **design requirements** → RED (T38-T39).

| Layer | What | Approach |
|---|---|---|
| RED T32 | council ALWAYS after design | grep rule 4 + Organic hooks |
| RED T33 | orchestrator→council; council→3 lenses | grep JSON |
| RED T34 | `sdd-council.md` in `OWN_PROMPTS` + exists | grep :105 + file |
| RED T35 | acta mandatory, fail-closed | grep arch-lint |
| RED T36 | convergence; forks→user; 2-round STOP | grep skill + orchestrator |
| RED T37 | no `mcp` key (protect T02) | jq assert |
| RED T38 | root `subagent_depth: 2` — fragment + installed config | `jq -e '.subagent_depth == 2'` both |
| RED T39 | extended merge carries key, both engines | sync `--check` jq + python (hide jq from PATH); zero desync |
| Regression | T28-T31 pass; T30 zero-desync | suite + sync --check |

Release smoke (optional): live orchestrator→council→1-lens round proves the depth-2 grant.

## Migration / Rollout

No data migration; additive. Rollback = revert; pre-value in `.bak`.

## Open Questions

None. O1-O3 + root knob resolved; hook placement pinned by RED.