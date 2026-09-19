# Task file — redesign-v3-unified

- **Objective**: Migrate sdd-own-skills to gentle-ai v3.x ODD-first: stop replacing the orchestrator prompt, extend only via the managed `agent-routing` section (post-sync injection) plus the surviving own skills/agents; split the quest into product + architecture quests with a unified post-exploration flow.
- **Problem**: v3.0.x inlines the orchestrator prompt (`agent.gentle-orchestrator.prompt`), `architecture-plan` is no longer a planner token, and ODD is the mandatory default workflow. Our v2-era full orchestrator replacement and extra phases (council, hard-gate, hard-verify, pre-experience, changelog) are obsolete and would fight the native sync.
- **Why**: User directive — "olvida todos nuestros cambios", keep only quest + arch-plan + arch-linter, adapt to ODD; later confirmed agents `sdd-rfc-author` and `sdd-architecture-plan` stay as own delegable agents; quests also run in ODD; unified post-exploration placement; prune everything else ("poda total").
- **Scope**: repo `sdd-own-skills` source (skills/, wiring/, overlays/, sync-skills.sh). No changes to Alan's files or native gentle-ai.
- **Constraints**: never edit `~/.config/opencode/opencode.json(c)` directly; edits flow only through repo + sync; never touch Alan's original files; own prompts only via `OWN_PROMPTS`; artifact language: English defaults per Language Domain Contract.
- **Authorized scope**: full implementation of the tasks below in this repo.

## Checklist

### T01 — Split quest into two skills (DONE after writer)
- [x] Delete `skills/sdd-quest/` (21.4K, two-branch quest)
- [x] Create `skills/sdd-product-quest/SKILL.md` (product branch, budget 50, gate → product-rfc.md via sdd-rfc-author)
- [x] Create `skills/sdd-architecture-quest/SKILL.md` (architecture branch, budget 20, gate → arch-rfc.md via sdd-rfc-author)
- [x] Both: interview happens AFTER exploration (orchestrator receives explore summary + collected Q&A), orchestrator-inline, `delegate_only`, one question at a time

### T02 — Agents kept as own (delegable)
- [x] `sdd-rfc-author.md` prompt updated: parametric branch `product|architecture`, produces ONE RFC of the active branch
- [x] `sdd-architecture-plan.md` prompt: input = arch-rfc + explore; output = arch-plan.md acta; keep bounded correction (max 2 rounds)

### T03 — Routing extension source
- [x] Create `wiring/sdd-own-routing.md` — routing-only block to inject inside `<!-- gentle-ai:agent-routing -->` section
- [x] Content: unified flow (Explore → product-quest → gate → product-rfc → arch-quest → gate → arch-rfc → arch-plan → natural flow), SDD = mandatory quest, ODD = trigger-based (≥2 gaps), lint after apply

### T04 — Fragment rewrite
- [x] `wiring/opencode.sdd.json`: gentle-orchestrator carries ONLY `permission` (drop `prompt`/`description`/`variant` so inline Alan prompt survives merge)
- [x] Keep agents: sdd-architecture-lint, sdd-architecture-plan (one entry, duplicate removed), sdd-rfc-author
- [x] Remove: sdd-council*, sdd-changelog, sdd-hard-gate, sdd-hard-verify, sdd-pre-experience
- [x] Keep `subagent_depth`, `default_agent`, `$schema`

### T05 — Prune prompts + skills
- [x] `OWN_PROMPTS=(sdd-rfc-author.md sdd-architecture-plan.md)` in sync-skills.sh
- [x] Delete `wiring/prompts/sdd/{orchestrator,sdd-council,sdd-hard-gate,sdd-hard-verify,sdd-pre-experience}.md`
- [x] Delete `skills/{sdd-council,sdd-changelog}/`

### T06 — Overlay prune (poda total)
- [x] Delete `overlays/skills/{sdd-apply,sdd-design,sdd-explore,sdd-onboard,sdd-propose,sdd-spec,sdd-tasks,sdd-verify}/`
- [x] Delete `overlays/commands/{sdd-continue,sdd-ff,sdd-new}.md`
- [x] Keep `overlays/shared/sdd-phase-common.md`

### T07 — Sync: routing extension step (Paso 3b)
- [x] In `sync-skills.sh`, after Paso 3 (opencode merge) and before Paso 4 (registries): inject `wiring/sdd-own-routing.md` inside the `<!-- gentle-ai:agent-routing -->` section of `agent.gentle-orchestrator.prompt` in the real config
- [x] Strip own block first (idempotent), append routing-only block, honor --check/--dry-run and .bak
- [x] Never touch the rest of the orchestrator prompt

### T08 — Verify
- [x] `./sync-skills.sh --check` reports zero desyncs
- [x] `./sync-skills.sh --dry-run` shows expected pending actions
- [x] Real sync; confirm config still has Alan's inline orchestrator prompt + our routing block inside agent-routing
- [x] `./sync-skills.sh --registries sdd-own-skills` refreshes .atl

## Progress
- All tasks T01–T08 verified DONE with observed evidence (see Verification evidence). Post-migration hygiene fixes also applied and re-verified (debris leak, dangling symlink, T39 shim robustness).

## Next step
- None — change complete. Archive optional; no SDD artifacts were used (ODD path).

## Verification evidence
- T01: `skills/sdd-product-quest/SKILL.md` + `skills/sdd-architecture-quest/SKILL.md` exist, `delegate_only`, budgets 50/20, gates → RFC; `skills/sdd-quest/` deleted (git status D). Suite T50 ("quest split 50/20 + 2 gates") PASS.
- T02: suite T49 ("rfc-author prompt-defined: file-based en fragment, nunca skill target, branch-parametric") PASS; T54 ("arch-plan acta + user gate: post-spec pre-design, resolvable, fail-closed, user gate") PASS.
- T03: `wiring/sdd-own-routing.md` exists; injected block `sdd-own:agent-routing` present in real config exactly 1 start / 1 end, INSIDE `<!-- gentle-ai:agent-routing -->` (positions alan_open=71853 < own_start=90301 < alan_close=91635; prompt 91664 chars = Alan 3.4.0 base 90330 + block ~1334). Suite T51 ("routing lean: sin PR/merge/MCP... clausula 100% native") PASS.
- T04: real config top-level keys `[$schema, agent, default_agent, mcp, permission, share, subagent_depth]`; own agents present: sdd-rfc-author, sdd-architecture-plan, sdd-architecture-lint; absent: council*/changelog/hard-gate/hard-verify/pre-experience; subagent_depth=2; default_agent=gentle-orchestrator. Suite T37/T38 PASS.
- T05: `OWN_PROMPTS=(sdd-rfc-author.md sdd-architecture-plan.md)` in sync-skills.sh; `wiring/prompts/sdd/` has exactly 2 files; prompts/skills deleted (git status D). Suite T48 ("poda prompts/skills: EXACTAMENTE 2 prompts; skills changelog/quest/council ausentes") PASS.
- T06: `overlays/commands/` and `overlays/skills/` deleted from repo (git status D); only `overlays/shared/sdd-phase-common.md` survives with 7 sdd-own blocks (14 markers on installed copy). Suite T31/T32 overlay contract PASS.
- T07: suite T53 ("Paso 3b en sync: orden 3 < 3b < 4 + salteado --skip-opencode + exit contract 0/1/2") PASS; verified directly post `gentle-ai sync` 3.4.0 re-baseline (which had wiped the block — markers 0/0) that our re-sync re-injected 1/1 inside agent-routing.
- T08: `--check` zero desyncs (multiple runs, current); `--dry-run` listed expected pending set (11 skills + 2 prompt symlinks + 1 overlay + config merge + routing extension + .claude/commands) before first real sync; real sync exit 0 (12 updated, 0 errors), config confirmed with Alan inline prompt + routing block inside agent-routing; registries refreshed with absolute path (`--registries /home/andy/Proyectos/sdd-own-skills` → "Skill registry refreshed (34 skills)").
- Post-migration hygiene (this session, after `gentle-ai` 3.4.0 update): overlay tmp leak fixed (`trap 'rm -f "$tmp"' RETURN` in apply_overlay; 1050 debris `*.sdd-own-strip.*` removed) — 0 debris after 3 consecutive suite runs; dangling literal `~/.claude/commands/*.md` symlink removed + guard added; T39 shim hardened (`find rm` in shim, bins resolved from `/usr/bin:/bin` with fallback) after flaky leg-python failure. Suite RED: PASS 70 / FAIL 0 / SKIP 0 (66-79s) on red342/red343/red344, Verde.