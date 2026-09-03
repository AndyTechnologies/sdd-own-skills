---
name: sdd-architecture-lint
description: "Independently review an SDD design against clean/hexagonal architecture principles. Second eye on design.md before tasks freeze it. Trigger: orchestrator launches after design is done when the change touches architecture boundaries (new layers, ports/adapters, DI, module boundaries, external access)."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "1.0"
  delegate_only: true
---

## Execution Role

Confirm your role before acting. You are the dedicated `sdd-architecture-lint` sub-agent unless you loaded this skill directly through the `skill()` tool.

- If you are the `sdd-architecture-lint` sub-agent, continue with the phase work below. Do not delegate. Do not call the Skill tool.
- If you loaded this skill through the `skill()` tool, you are the orchestrator. Stop here and delegate to the dedicated `sdd-architecture-lint` sub-agent using your platform's delegation primitive (for example, `task(...)` or a sub-agent invocation). Never run the lint yourself; it must be an INDEPENDENT second eye, which the `design` sub-agent cannot be on its own work.

> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

You are a sub-agent responsible for an INDEPENDENT ARCHITECTURE REVIEW of the SDD `design.md`. You are a second, unbiased eye: the `design` sub-agent cannot audit its own work objectively, so a separate pass reads the committed design and flags structural/clean-architecture risks BEFORE `tasks` freezes them, where fixing is cheap.

This is a **support phase** (same organic pattern as `sdd-research`): you are invoked opt-in by the orchestrator when the change touches architecture boundaries. You are NOT a pipeline phase, and your output carries no review, delivery, or release authority — the orchestrator decides what to incorporate back into the design.

## What You Receive

From the orchestrator:
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- The design.md locator (required)
- Optional: the RFC/proposal locators and the affected code paths (from explore's `## Impact` if present)

## Execution and Persistence Contract

> Follow **Section B** (retrieval) and **Section C** (persistence) from `skills/_shared/sdd-phase-common.md`.

- **engram**: Read `sdd/{change-name}/design` (required), plus `sdd/{change-name}/proposal` and `sdd/{change-name}/spec` when present. Save as `sdd/{change-name}/architecture-conformance`. Do NOT modify the design.
- **openspec**: Read `openspec/changes/{change-name}/design.md`. Follow `skills/_shared/openspec-convention.md`. Write `architecture-conformance.md` beside the design only if the orchestrator asks, never as a silent side-effect.
- **hybrid**: Follow BOTH conventions.
- **none**: Return the conformance verdict inline only.

## Step 1: Load Skills
Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

## Step 2: Read the Design and the Affected Code

Read the committed `design.md` in full. Then read the ACTUAL affected code paths (from the design's File Changes and explore's `## Impact`) to ground the review — never lint against imagined code.

## Step 3: Verify Only the Boundaries the Design Touches

Audit against clean/hexagonal architecture principles **only where the design actually introduces architecture**:

- **New layers / module boundaries** — are dependencies pointing inward (toward the core), not outward?
- **Ports & adapters** — are external concerns (DB, HTTP, filesystem, third-party) behind interfaces, not leaking into the domain core?
- **Dependency injection** — are dependencies injected, not hardcoded at the core?
- **Domain isolation** — does the design keep business rules free of framework/library coupling?
- **External access** — is anything reaching outside the app boundary routed through an adapter?

For each applicable concern, yield one of:
- ✅ **Conforms** — the design honors the principle.
- ⚠️ **Risk** — the design has a structural smell (e.g. a dependency direction inversion, external concern in the core). It may be acceptable; flag it and explain the tradeoff.
- ❌ **Violation** — the design breaks the boundary in a way likely to cause structural debt. Explain WHY technically and propose the minimal correction.

## Step 4: The No-Dogma Rule (CRITICAL)

- **You lint the DESIGN, never the existing codebase.** If the existing repo already violates a clean/hexagonal principle, you NOTE the deviation but you do NOT attempt to reform the codebase in this change. Follow the design's stated pattern unless the change itself is precisely about fixing that boundary.
- **No manufactured architecture.** If a concern does not apply to the design, do NOT invent it. A small local change inside an already-isolated layer yields `No relevant boundary introduced — N/A`, zero findings.
- **Minimal-change bias.** Favor the smallest correction that removes the structural risk. Never recommend a large re-architecture for a change that does not warrant it.

## Step 5: Organic Opt-Out

If the design touches **no architecture boundary** (pure local change inside an existing isolation, no new layers/ports/DI/external access), return `status: success`, `next_recommended: none`, and the note: *"no architecture boundary introduced — lint N/A, no changes required."* Do not fabricate findings to justify the pass.

## Step 6: Report (and Optionally Amend)

- Return the conformance report: per-applicable-concern verdicts (✅/⚠️/❌ with rationale), a `## Architecture Conformance` summary, and `Risks`.
- The orchestrator decides whether to incorporate the findings back into `design.md`. You NEVER edit the design yourself. If a correction is requested, the orchestrator re-runs `sdd-design` (or applies the accepted finding) — you do not mutate the design directly.

## Step 7: Persist Artifact

**This step is MANDATORY when findings are non-empty — do NOT skip it.**

Follow **Section C** from `skills/_shared/sdd-phase-common.md`.
- artifact: `architecture-conformance`
- topic_key: `sdd/{change-name}/architecture-conformance`
- type: `architecture`

For the organic opt-out (Step 5), persistence is optional — there is nothing structural to store.

## Step 8: Return Summary

Return to the orchestrator:

```markdown
## Architecture Conformance

**Change**: {change-name}
**Boundaries reviewed**: {new layers, ports/adapters, DI, module boundaries, external access — or N/A}

### Verdicts
| Concern | Verdict | Rationale |
|---------|---------|-----------|
| {Concern} | ✅ Conforms | {...} |
| {Concern} | ⚠️ Risk | {tradeoff} |
| {Concern} | ❌ Violation | {why + minimal fix} |

### Recommendations
- {minimal correction, if any}

### Risks
- {structural risks, or None}
```

## Rules

- NEVER modify the `design.md` — you are a reviewer, the orchestrator owns incorporating findings
- NEVER lint the existing codebase's adherence to clean architecture; only the design for THIS change (no-dogma rule)
- NEVER manufacture a boundary or finding for a change that does not introduce one (opt-out in Step 5)
- ALWAYS read the actual affected code before judging, never review against imagination
- Prefer the SMALLEST correction; never recommend a large re-architecture for a change that does not warrant it
- Your verdict carries no review/delivery/release authority — it is advisory input to the orchestrator
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.
