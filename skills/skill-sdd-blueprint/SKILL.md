---
name: skill-sdd-blueprint
description: "Blueprint for creating new SDD phase/support skills. Document how to design, wire, and persist a new SDD skill so it joins the pipeline organically without touching nextRecommended or over-engineering. Trigger: creating a new SDD phase, wiring a new SDD phase, or adding a support phase to the SDD pipeline."
disable-model-invocation: false
user-invocable: true
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "3.0"
---

# sdd-skill-blueprint — How to add a new SDD skill

Use this when you want to add a new phase or support skill to the SDD pipeline. It centralizes the design decisions and wiring rules learned building the product/architecture quests, the RFC author, the architecture plan, and the architecture lint — so the pattern is not reinvented each time.

## Two kinds of SDD skills

Decide which kind your new skill is BEFORE writing it. This determines everything downstream.

| | Pipeline phase | Support phase |
|---|---|---|
| Examples | product-quest, architecture-quest, explore, propose, spec, design, tasks, apply, verify, archive | research, architecture-lint |
| When it runs | A required step of the dependency graph | Opt-in, at a hook point |
| Decided by | Native `nextRecommended` token | Routing extension block (`sdd-own:agent-routing`) + orchestrator artifact/state inspection |
| Touches `nextRecommended`? | Yes (it IS a token) | **NO — never** |
| Organic model | pipeline | quest / research pattern |

**The rule that preserves the SDD philosophy:** a NEW phase almost never needs to touch `nextRecommended` (that set is bounded and native-owned). Prefer making it a **support phase** wired through the **routing extension** (`wiring/sdd-own-routing.md`, spliced by Paso 3b). Only a genuinely mandatory pipeline step belongs in `nextRecommended`, and adding one there requires changing the native status contract — a heavier change you should avoid unless truly necessary.

## The two organic wiring patterns

Both are wired by the ORCHESTRATOR through the **routing extension** — the block `<!-- sdd-own:agent-routing:start --> … <!-- sdd-own:agent-routing:end -->` injected by `sync-skills.sh` **Paso 3b** into the `<!-- gentle-ai:agent-routing -->` section of the INLINE orchestrator prompt (Alan-owned, ~86k chars). The routing block is the authority the orchestrator follows on EVERY entry route (command, natural language, auto mode), detected by **artifact presence/state**, never by a status token.

- **QUEST pattern** (pre-hook): runs before a phase when a marker is absent or in a state. E.g. product-quest runs after explore when there is no `product-rfc.md` with `## Approval: approved`; architecture-quest runs before the architecture plan when there is no `arch-rfc.md` and a design phase is ahead.
- **RESEARCH pattern** (post-hook / side-hook): runs at/after a phase when the orchestrator's trigger fires, and produces an advisory artifact. E.g. architecture-lint runs ALWAYS after apply as part of the apply verification, checking the implementation against the generated RFCs, the arch-plan acta (when one was produced), and the shared principles catalog.

> **Lesson from the v3.0 migration:** hooks once lived in the file-based orchestrator contract (`wiring/prompts/sdd/orchestrator.md` of ours) + command overlays (`/sdd-new`, `/sdd-continue`, `/sdd-ff`). gentle-ai v3 made the orchestrator prompt INLINE (Alan-owned), so our file-based contract no longer existed to be read and the command overlays were pruned — the hooks would have silently stopped firing. The routing extension (Paso 3b splice into the `agent-routing` section) is now the ONLY home for orchestrator-level hooks. Alan's commands and inline prompt are never edited; the routing block is the only byte we own inside that prompt.

## Design checklist for a new SDD skill

1. **Classify** — pipeline phase or support phase? (If support phase, continue.)
2. **Pick the hook** — where in `explore → product-quest → [product RFC gate] → arch-quest → [arch RFC gate] → arch-plan → design → tasks → apply → architecture-lint → verify → archive` does it attach, and BEFORE/AFTER which phase? Detect by artifact state, not `nextRecommended`.
3. **Define the organic opt-out** — when should this NOT run / produce nothing? Every support phase needs a real `N/A`/`None` escape so it never manufactures work (research: no external evidence needed; architecture-lint: `N/A` only for an empty/trivial design, otherwise it ALWAYS runs as part of the apply verification). This is the anti-over-engineering gate.
4. **Independent eye** — if the phase judges quality (lint, review), it MUST be a separate sub-agent from the phase it reviews (no self-audit). Reuse the Section D envelope from `sdd-phase-common.md`.
5. **Reuse the phase contract** — follow `_shared/sdd-phase-common.md` (Sections A–F): executor-only, retrieval by reported store, persistence by store, return envelope, Key Learnings. Never re-derive the store.
6. **Version the frontmatter** — bump `metadata.version` and set `delegate_only: true` for sub-agent phases (matching the existing SDD skills).

## Wiring the new support phase (three mandatory homes)

A support phase is NOT wired until it has all three homes. Missing any one of them reproduces the v3.0 regression (hook silently absent on all entry routes).

1. **The routing extension (MANDATORY — the authority).** Add the trigger to `wiring/sdd-own-routing.md` — the block that Paso 3b splices into the `agent-routing` section of the inline orchestrator prompt: which artifact/change state the orchestrator inspects, whether it is automatic (e.g. arch-plan between arch-rfc and design) or decision-based (e.g. quest offer), and its organic opt-out condition. This is what makes the hook fire on EVERY entry route. Alan's sections of that prompt are never touched.
2. **The agent wiring (`wiring/opencode.sdd.json`) + prompt (if file-based sub-agent).** If the phase delegates to a named sub-agent: add its entry (agent) and reference it from the orchestrator `permission` allow-list (`task.*` entries — the persistence of "who may launch it"). File-based sub-agents (like `rfc-author`, `architecture-plan`) get a short prompt in `wiring/prompts/sdd/<name>.md` pointing at their canonical skill. Skill-based sub-agents (like the quests, `sdd-research` (native), `architecture-lint`) need only the allow-list entry.
3. **The skill itself.** `skills/{skill-name}/SKILL.md` with the delegation note (delegate with exact skill path in `## Skills to load before work`, never run the support phase inline).

Note: `overlays/shared/sdd-phase-common.md` is the ONLY surviving overlay. Use it solely for shared cross-skill contracts (all phases read it); never use an overlay for wiring — a hook is wired exclusively through `wiring/sdd-own-routing.md`.

## Persistence + sync (the source-of-truth discipline)

- The canonical skill lives in **this repo** `skills/{skill-name}/SKILL.md`.
- It is mirrored to `~/.agents/skills/` and `~/.config/opencode/skills/` (both read by opencode and pi) via `./sync-skills.sh`.
- Wiring mirrors too: `wiring/sdd-own-routing.md` (routing extension, spliced by Paso 3b), `wiring/opencode.sdd.json` (agent entries + orchestrator allow-list), `wiring/prompts/sdd/` (the file-based sub-agent prompts); the shared support files live in `skills/_shared` (referenced by the skills as `skills/_shared/…`).
- After ANY change to a skill or wiring, run `./sync-skills.sh --check` to verify, then `./sync-skills.sh` to push the mirror.
- Never edit only the global copies — the repo copy is canonical. The inline orchestrator prompt in the real opencode config is Alan-owned: never put hooks there directly; they live in the routing block.

## Anti-over-engineering guard (the requirement)

1. **One sub-agent, one artifact** — a support phase produces ONE advisory artifact; it does not spawn its own pipeline or a chain of sub-agents.
2. **`N/A` is valid output** — when the trigger doesn't apply, the phase says so and stops. A phase that never returns `N/A` is over-engineered.
3. **No self-audit** — quality-linting phases are separate sub-agents, never the reviewed phase auditing itself.
4. **No new status tokens** — never invent a `nextRecommended` value; keep support phases out of the native contract.
5. **Minimal by default** — the smallest skill that captures the decision and its wiring. When in doubt, return `N/A`.
6. **No orphan hooks** — a support phase whose trigger is NOT in the routing extension (`wiring/sdd-own-routing.md`) is not wired; it can be silently lost in a future refactor.
7. **No edits to Alan's inline prompt** — the routing block is the only sanctioned byte inside it.

## References

- `../_shared/sdd-phase-common.md` — the executor/persistence/return-envelope contract every SDD phase follows.
- `../_shared/sdd-status-contract.md` — why `nextRecommended` is bounded and support phases stay out of it.
- `../../wiring/sdd-own-routing.md` — the routing extension; the mandatory home of every orchestrator-level support-phase trigger (spliced by Paso 3b).
- `../../wiring/opencode.sdd.json` — the merge-safe fragment: agent entries + the orchestrator `permission` allow-list.
- `../../wiring/prompts/sdd/rfc-author.md`, `../../wiring/prompts/sdd/architecture-plan.md` — reference examples of file-based sub-agent prompts.
- `../../overlays/shared/sdd-phase-common.md` — the only surviving overlay (shared cross-skill contracts).
- `~/.config/opencode/skills/skill-creator/SKILL.md` — generic LLM-first skill creation rules.