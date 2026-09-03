---
name: skill-sdd-blueprint
description: "Blueprint for creating new SDD phase/support skills. Document how to design, wire, and persist a new SDD skill so it joins the pipeline organically without touching nextRecommended or over-engineering. Trigger: creating a new SDD phase, wiring a new SDD phase, or adding a support phase to sdd-continue."
disable-model-invocation: false
user-invocable: true
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "1.0"
---

# sdd-skill-blueprint — How to add a new SDD skill

Use this when you want to add a new phase or support skill to the SDD pipeline. It centralizes the design decisions and wiring rules learned building the quest, changelog, impact, and architecture-lint phases — so the pattern is not reinvented each time.

## Two kinds of SDD skills

Decide which kind your new skill is BEFORE writing it. This determines everything downstream.

| | Pipeline phase | Support phase |
|---|---|---|
| Examples | quest, explore, propose, spec, design, tasks, apply, verify, archive | research, architecture-lint, changelog |
| When it runs | A required step of the dependency graph | Opt-in, at a hook point |
| Decided by | Native `nextRecommended` token | Orchestrator artifact/state inspection in `sdd-continue` step 4 |
| Touches `nextRecommended`? | Yes (it IS a token) | **NO — never** |
| Organic model | pipeline | quest / research pattern |

**The rule that preserves the SDD philosophy:** a NEW phase almost never needs to touch `nextRecommended` (that set is bounded and native-owned). Prefer making it a **support phase** wired through the `SUPPORT-CONDITIONAL` block. Only a genuinely mandatory pipeline step belongs in `nextRecommended`, and adding one there requires changing the native status contract — a heavier change you should avoid unless truly necessary.

## The two organic wiring patterns

Both are wired by the ORCHESTRATOR in `sdd-continue`, step 4 (`QUEST-CONDITIONAL` / `SUPPORT-CONDITIONAL`), detected by **artifact presence/state**, never by a status token.

- **QUEST pattern** (pre-hook): runs before a phase when a marker is absent or in a state. E.g. quest runs before explore when there is no `## Approval: approved` artifact.
- **RESEARCH pattern** (post-hook / side-hook): runs at/after a phase when the orchestrator's trigger fires, and produces an advisory artifact. E.g. architecture-lint after design when boundaries are touched; changelog automatically after archive.

## Design checklist for a new SDD skill

1. **Classify** — pipeline phase or support phase? (If support phase, continue.)
2. **Pick the hook** — where in `quest → explore → propose → [spec ∥ design] → tasks → apply → verify → archive` does it attach, and BEFORE/AFTER which phase? Detect by artifact state, not `nextRecommended`.
3. **Define the organic opt-out** — when should this NOT run / produce nothing? Every support phase needs a real `N/A`/`None` escape so it never manufactures work (changelog: no consumer-facing change; impact: greenfield; architecture-lint: no boundary). This is the anti-over-engineering gate.
4. **Independent eye** — if the phase judges quality (lint, review), it MUST be a separate sub-agent from the phase it reviews (no self-audit). Reuse the Section D envelope from `sdd-phase-common.md`.
5. **Reuse the phase contract** — follow `_shared/sdd-phase-common.md` (Sections A–F): executor-only, retrieval by reported store, persistence by store, return envelope, Key Learnings. Never re-derive the store.
6. **Version the frontmatter** — bump `metadata.version` and set `delegate_only: true` for sub-agent phases (matching the existing SDD skills).

## Wiring the new support phase into sdd-continue

Add it to the `SUPPORT-CONDITIONAL` block in `sdd-continue.md` step 4, with:
- its trigger (what artifact/change state the orchestrator inspects)
- whether it is automatic (like changelog post-archive) or decision-based (like architecture-lint)
- its organic opt-out condition

Then add the delegation note in step 5 (delegate with exact skill path in `## Skills to load before work`, never run inline).

## Persistence + sync (the source-of-truth discipline)

- The canonical skill lives in **this repo** `skills/{skill-name}/SKILL.md`.
- It is mirrored to `~/.agents/skills/` and `~/.config/opencode/skills/` (both read by opencode and pi) via `./sync-skills.sh`.
- Wiring (`wiring/commands`, `wiring/prompts`, `wiring/_shared`) also mirrors — `wiring/commands/sdd-continue.md` is what rutea the phases.
- After ANY change to a skill or wiring, run `./sync-skills.sh --check` to verify, then `./sync-skills.sh` to push the mirror.
- Never edit only the global copies — the repo copy is canonical.

## Anti-over-engineering guard (the requirement)

1. **One sub-agent, one artifact** — a support phase produces ONE advisory artifact; it does not spawn its own pipeline or a chain of sub-agents.
2. **`N/A` is valid output** — when the trigger doesn't apply, the phase says so and stops. A phase that never returns `N/A` is over-engineered.
3. **No self-audit** — quality-linting phases are separate sub-agents, never the reviewed phase auditing itself.
4. **No new status tokens** — never invent a `nextRecommended` value; keep support phases out of the native contract.
5. **Minimal by default** — the smallest skill that captures the decision and its wiring. When in doubt, return `N/A`.

## References

- `../_shared/sdd-phase-common.md` — the executor/persistence/return-envelope contract every SDD phase follows.
- `../_shared/sdd-status-contract.md` — why `nextRecommended` is bounded and support phases stay out of it.
- `../../wiring/commands/sdd-continue.md` — where the `QUEST-CONDITIONAL` and `SUPPORT-CONDITIONAL` blocks live.
- `~/.config/opencode/skills/skill-creator/SKILL.md` — generic LLM-first skill creation rules.
