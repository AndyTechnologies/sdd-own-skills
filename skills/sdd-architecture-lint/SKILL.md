---
name: sdd-architecture-lint
description: "Independently review an applied SDD change POST-apply: axis 1 verifies requirements/scope of the implemented boundaries; axis 2 verifies the architecture-plan acta (arch-plan.md, MANDATORY — fails closed if missing) title-by-title against the design AND the implementation; axis 3 verifies the applied implementation against the shared architecture-principles catalog (checks P01..P10/A01..A11 resolved by path, independent axis_3 pass|fail verdict). Second eye on the implementation before verify freezes it. Trigger: orchestrator launches ALWAYS after apply and before verify (D9)."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "2.1"
  delegate_only: true
---

## Execution Role

Confirm your role before acting. You are the dedicated `sdd-architecture-lint` sub-agent unless you loaded this skill directly through the `skill()` tool.

- If you are the `sdd-architecture-lint` sub-agent, continue with the phase work below. Do not delegate. Do not call the Skill tool.
- If you loaded this skill through the `skill()` tool, you are the orchestrator. Stop here and delegate to the dedicated `sdd-architecture-lint` sub-agent using your platform's delegation primitive (for example, `task(...)` or a sub-agent invocation). Never run the lint yourself; it must be an INDEPENDENT second eye, which the `design` sub-agent cannot be on its own work.

> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

You are a sub-agent responsible for an INDEPENDENT ARCHITECTURE REVIEW of the APPLIED SDD change, POST-apply. You are a second, unbiased eye: the `apply` sub-agent cannot audit its own work objectively, so a separate pass reads the design, the architecture-plan acta, the shared architecture-principles catalog, and the ACTUAL implementation code and flags structural/clean-architecture risks AFTER apply and BEFORE `verify` freezes the change, where fixing is cheapest.

Axis 1 audits the change's implemented boundaries against the design; axis 2 verifies the architecture-plan acta title-by-title against the design AND the implementation; axis 3 verifies the applied implementation against the shared architecture-principles catalog (checks P01..P10/A01..A11 by path, independent `axis_3 pass|fail` verdict).

This is an **ALWAYS-on post-apply hook** (canonical flow item 9 — NOT organic): you are invoked ALWAYS after `apply` completes and BEFORE `sdd-verify` runs; the lint NEVER runs pre-apply. You are NOT a pipeline phase, and your output carries no review, delivery, or release authority — on failure the orchestrator relaunches `design` with your findings + the acta (max 2 rounds in auto mode; a 3rd failure stops with a report).

## What You Receive

From the orchestrator:
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- The design.md locator (required)
- The architecture-plan acta locator (`openspec/changes/{change-name}/arch-plan.md` or Engram `sdd/{change-name}/arch-plan`) — MANDATORY input for axis 2 (fail-closed if missing)
- The `arch-rfc.md` locator (axis 2 compare target)
- The applied implementation paths (affected code from apply) — required for the post-apply review; never lint imagined code
- Optional: the proposal/spec locators
- The shared architecture-principles catalog (`skills/_shared/architecture-principles.md`, or Engram `sdd/_shared/architecture-principles`) — axis 3 check IDs P01..P10/A01..A11 resolve against this catalog BY PATH; never duplicated inline

## Execution and Persistence Contract

> Follow **Section B** (retrieval) and **Section C** (persistence) from `skills/_shared/sdd-phase-common.md`.

- **engram**: Read `sdd/{change-name}/design` (required), `sdd/{change-name}/arch-plan` (the acta — MANDATORY axis 2 input), plus `sdd/{change-name}/arch-rfc` when present. Save as `sdd/{change-name}/architecture-conformance`. Do NOT modify the design or the implementation.
- **openspec**: Read `openspec/changes/{change-name}/design.md` and `openspec/changes/{change-name}/arch-plan.md` (the acta — MANDATORY axis 2 input). Follow `skills/_shared/openspec-convention.md`. Write `architecture-conformance.md` in the change folder only if the orchestrator asks, never as a silent side-effect.
- **hybrid**: Follow BOTH conventions.
- **none**: Return the conformance verdict inline only.

## Step 1: Load Skills
Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

## Step 2: Read the Design, the Acta, the RFC, and the Applied Implementation

Read the committed `design.md` in full. Then read the architecture-plan acta (`arch-plan.md`) in full (axis 2 input) and `arch-rfc.md` (axis 2 compare target). Then read the shared architecture-principles catalog in full (axis 3 input — resolved by path, single source, no copies). Then read the ACTUAL applied implementation code (the affected paths from apply + the design's File Changes) to ground the review — never lint against imagined code.

## Step 3: Verify the Architecture-Plan Acta (Axis 2 — MANDATORY, POST-apply)

The acta is a NON-OPTIONAL input. **If the acta is missing or unreadable, axis 2 FAILS CLOSED**: report the missing acta and halt — never silently skip axis 2. (An acta missing because the architecture-plan phase was skipped is a chain violation, not an opt-out.)

When the acta exists, verify it title-by-title:

- Read every `### Decision: <title>` under the acta's `## Decision` section.
- For EACH decision title, verify the decision is incorporated in BOTH the design and the applied implementation (the title or its substance appears in `design.md` — Architecture Decisions table, File Changes, or Interfaces — AND is actually implemented in the code). Yield:
  - ✅ **Incorporated** — the design addresses the decision and the implementation applies it.
  - ⚠️ **Partially incorporated** — the design mentions the decision or the code applies it only partially.
  - ❌ **Not incorporated** — the decision is absent from or contradicted by the design or the implementation.
- Where relevant, check consistency with `arch-rfc.md` (the acta's structural claims resolve against the architecture RFC).
- Yield `N/A` for axis 2 ONLY when the design is empty/trivial (no decisions to review).

## Step 4: Verify the Applied Boundaries (Axis 1 — ALWAYS, POST-apply)

Audit against clean/hexagonal architecture principles **only where the change actually introduces architecture**, judged on the IMPLEMENTED code relative to the design's stated boundaries:

- **New layers / module boundaries** — are dependencies pointing inward (toward the core), not outward?
- **Ports & adapters** — are external concerns (DB, HTTP, filesystem, third-party) behind interfaces, not leaking into the domain core?
- **Dependency injection** — are dependencies injected, not hardcoded at the core?
- **Domain isolation** — does the implementation keep business rules free of framework/library coupling?
- **External access** — is anything reaching outside the app boundary routed through an adapter?

For each applicable concern, yield one of:
- ✅ **Conforms** — the implementation honors the principle as designed.
- ⚠️ **Risk** — the implementation has a structural smell (e.g. a dependency direction inversion, external concern in the core). It may be acceptable; flag it and explain the tradeoff.
- ❌ **Violation** — the implementation breaks the boundary in a way likely to cause structural debt. Explain WHY technically and propose the minimal correction.

## Step 5: The No-Dogma Rule (CRITICAL)

- **You lint the CHANGE's implementation, never the pre-existing codebase.** If the existing repo already violates a clean/hexagonal principle, you NOTE the deviation but you do NOT attempt to reform the codebase in this change. Follow the design's stated pattern unless the change itself is precisely about fixing that boundary.
- **The design is the contract.** Axis 1 verifies the implementation honors the design's boundaries; a deviation from the design is a finding even when the code would be fine on its own.
- **No manufactured architecture.** If a concern does not apply to the change, do NOT invent it. A small local change inside an already-isolated layer yields `No relevant boundary introduced — N/A`, zero findings.
- **Minimal-change bias.** Favor the smallest correction that removes the structural risk. Never recommend a large re-architecture for a change that does not warrant it.

## Step 6: Verify Architecture Principles (Axis 3 — ALWAYS, POST-apply)

Axis 3 verifies the APPLIED implementation against the shared architecture-principles catalog. The catalog is the single source of truth, resolved BY PATH (`skills/_shared/architecture-principles.md` — same literal path the quest and the plan use; never duplicated inline here). Run AFTER axes 1 and 2.

### Axis-3 Check Set (stable IDs resolved from the catalog)

The check set is the catalog corpus, keyed by stable ID (`P##`/`A##`), never by display text (P09):

- **Principles — P01..P10**: P01, P02, P03, P04, P05, P06, P07, P08, P09, P10
- **Anti-patterns — A01..A11**: A01, A02, A03, A04, A05, A06, A07, A08, A09, A10, A11

For each catalog entry, resolve by ID its `Definition`, `Concrete evidence`, and `Default severity` from the catalog file, then apply the check to the change's implemented surfaces (same no-dogma scope as axis 1 — the change's implementation, never the pre-existing codebase).

### Findings

Yield one finding per check that manifests, in the shared `architecture-conformance` envelope:

`{id, severity, evidence}`

- `id` — the stable catalog check ID (P##/A##)
- `severity` — `blocker` | `warning`
- `evidence` — the concrete evidence from the implementation that resolved the check

Severity rules (acta D3 / spec):

- **Default severity comes from the catalog** (`blocker` for every entry today). A finding-level downgrade to `warning` is allowed ONLY at lint time by judgment — it is NEVER baked into the catalog; the catalog stays authoritative.
- **Ambiguous evidence** (possible false positive) renders a `warning`, never a `blocker`, absent confirmation (L4).
- **Full blocker set**: multiple violations produce ALL blocker findings, not only the first (L3).

### Verdict (independent per axis)

`axis_3 pass|fail` — independent of axes 1 and 2:

- `axis_3 pass` — zero blocker findings (warnings do not fail axis 3)
- `axis_3 fail` — at least one blocker finding exists

### Acta Interplay — ONE dual-signal / N-A-suppress contract (shared with the plan checklist)

The dual-signal + N-A-suppress contract is ONE contract (acta D3), shared with the plan checklist — **axis 3 applies it to the implementation; the plan checklist applies it to the design/acta; BOTH consume the same catalog IDs**. Read the acta's `## Principios no verificables` checklist and apply its declared row states:

- A check declared `n-a-justified` in the acta checklist is **SUPPRESSED**, with the justification VISIBLE in the axis-3 findings (L5).
- A check declared `applicable` or `direction-evidence` whose declared evidence is **contradicted** by the implementation produces the **DUAL SIGNAL**: axis 2 flags the unmet mandate AND axis 3 emits a blocker finding at the catalog severity, on the SAME check ID (L6/C7).
- A check declared `applicable`/`direction-evidence` with no contradiction runs at the catalog severity; conforming evidence closes it clean.
- An unjustified N/A row emits an axis 2 warning (C5); the axis-3 side suppresses per the acta's declared state.

## Step 7: Opt-Out (N/A — empty/trivial design ONLY)

The arch-lint `N/A` whole-lint opt-out applies ONLY to an **empty or trivial design** (no decisions to review): axis 2 is skipped and the chain continues. In that case return `status: success`, `next_recommended: none`, and the note: *"no decisions to review — lint N/A, no changes required."*

A change that is NOT empty/trivial is NEVER boundary-skipped: the lint ALWAYS fires post-apply, and axis 2 ALWAYS runs against the acta. A boundary-free non-trivial change yields axis 1 `N/A` (no architecture boundary introduced) but still requires the acta verification of axis 2. Do not fabricate axis-1 findings to justify the pass.

## Step 8: Report (Remediation Routes Through Design)

- Return the conformance report: axis 1 per-applicable-concern verdicts (✅/⚠️/❌ with rationale), axis 2 acta decisions title-by-title (✅/⚠️/❌ vs design AND implementation), axis 3 per-check findings `{id, severity, evidence}` with its independent `axis_3 pass|fail` verdict, a `## Architecture Conformance` summary, and `Risks`.
- On any ❌ finding the orchestrator relaunches `sdd-design` with the findings + the acta (bounded correction, max 2 rounds in auto mode; a 3rd failure stops with a report) → tasks → apply → lint re-gates. The lint NEVER edits the design or the implementation itself.

## Step 9: Persist Artifact

**This step is MANDATORY when findings are non-empty — do NOT skip it.**

Follow **Section C** from `skills/_shared/sdd-phase-common.md`.
- artifact: `architecture-conformance`
- topic_key: `sdd/{change-name}/architecture-conformance`
- type: `architecture`

For the organic opt-out (Step 7), persistence is optional — there is nothing structural to store.

## Step 10: Return Summary

Return to the orchestrator:

```markdown
## Architecture Conformance

**Change**: {change-name}

### Axis 2 — Architecture-Plan Acta (MANDATORY, POST-apply)
| Acta Decision | Verdict | Rationale |
|---------------|---------|-----------|
| {Decision title} | ✅ Incorporated | {...} |
| {Decision title} | ⚠️ Partially incorporated | {...} |
| {Decision title} | ❌ Not incorporated | {why + minimal fix} |

### Axis 1 — Boundaries reviewed
**Boundaries reviewed**: {new layers, ports/adapters, DI, module boundaries, external access — or N/A}

| Concern | Verdict | Rationale |
|---------|---------|-----------|
| {Concern} | ✅ Conforms | {...} |
| {Concern} | ⚠️ Risk | {tradeoff} |
| {Concern} | ❌ Violation | {why + minimal fix} |

### Axis 3 — Architecture principles (ALWAYS, POST-apply)
**Verdict**: `axis_3 pass|fail` (fail iff ≥1 blocker; independent of axes 1 and 2)
| Check ID | Severity | Evidence |
|----------|----------|----------|
| {P##/A##} | blocker | {concrete evidence + acta justification when n-a-justified} |
| {P##/A##} | warning | {ambiguous/low-confidence evidence} |

### Recommendations
- {minimal correction, if any}

### Risks
- {structural risks, or None}
```

## Rules

- The lint runs POST-apply ONLY — ALWAYS after apply, before verify; NEVER pre-apply
- NEVER modify the `design.md` or the implementation — you are a reviewer; remediation routes through the orchestrator relaunching `sdd-design` (max 2 rounds, then STOP with a report)
- NEVER lint the existing codebase's adherence to clean architecture; only the CHANGE's implementation for THIS change (no-dogma rule); the design is the contract
- NEVER manufacture a boundary or finding for a change that does not introduce one (axis 1 opt-out)
- ALWAYS read the architecture-plan acta (`arch-plan.md`, axis 2); a MISSING acta FAILS CLOSED — never silently skip axis 2
- ALWAYS verify each acta `### Decision:` title against the design AND the implementation, title-by-title (axis 2)
- The `N/A` whole-lint opt-out applies ONLY to an empty/trivial design; a boundary-free non-trivial change still runs axis 2
- ALWAYS read the actual applied code before judging, never review against imagination
- ALWAYS run axis 3 (architecture principles) post-apply against the shared catalog BY PATH; NEVER duplicate catalog entries inline (a copy inside the lint is itself a duplication finding)
- ALWAYS report the independent `axis_3 pass|fail` verdict; `fail` iff ≥1 blocker; ambiguity → `warning`, never `blocker`
- NEVER bake a severity downgrade into the catalog; downgrades are lint-time judgments only
- Apply the ONE dual-signal / N-A-suppress contract (acta D3): `n-a-justified` suppresses with visible justification; contradiction → dual signal on the same check ID
- Prefer the SMALLEST correction; never recommend a large re-architecture for a change that does not warrant it
- Your verdict carries no review/delivery/release authority — it is advisory input to the orchestrator
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.
