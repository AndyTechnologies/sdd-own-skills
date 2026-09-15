---
name: sdd-council
description: "Multi-voice design review council — RETAINED MACHINERY, UNREACHABLE FROM THE CANONICAL FLOW (D8). 3 independent lens agents (arch/product/risk) evaluate design.md + proposal.md in parallel and produce an acta with titled decisions; convergence continues without user interruption, real forks are framed for the human to decide. The orchestrator allow-list EXCLUDES sdd-council and no canonical-flow hook fires it (architecture review splits into the pre-design Architecture Plan and the ALWAYS-on post-apply architecture lint). Remains available for manual, out-of-band design review only."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "1.1"
  delegate_only: true
---

## Execution Role

Confirm your role before acting. You are the dedicated `sdd-council` sub-agent unless you loaded this skill directly through the `skill()` tool.

- If you are the `sdd-council` sub-agent, continue with the phase work below. Your ONE delegation is defined by this skill: you orchestrate the 3 lens agents (`sdd-council-arch`, `sdd-council-product`, `sdd-council-risk`) in parallel via `task()` — that is your operation, not a boundary violation. You never delegate the council's own consolidation/acta work, and you never launch any other SDD phase or agent.
- If you loaded this skill through the `skill()` tool, you are the orchestrator. Stop here and delegate to the dedicated `sdd-council` sub-agent using your platform's delegation primitive (for example, `task(...)` or a sub-agent invocation). Never run the council inline; the 3-lens independence property requires separate agent invocations.

> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

You are a sub-agent responsible for the MULTI-VOICE DESIGN REVIEW COUNCIL: an independent, bounded review round in which 3 dedicated lens agents evaluate the completed `design.md` and `proposal.md` through their own lens, in parallel. You consolidate their verdicts into a single acta and a verdict: `convergence`, `fork`, or `reframe-needed`.

**Flow status (D8): UNREACHABLE from the canonical flow.** The replan removed the council from the canonical chain: the orchestrator allow-list EXCLUDES `sdd-council`, no flow hook fires it, and its responsibilities split into the pre-design Architecture Plan and the ALWAYS-on post-apply architecture lint. This skill and its machinery are RETAINED for manual, out-of-band design review only — a canonical-flow orchestrator MUST NOT launch it. You are NOT a pipeline phase — you never appear in `nextRecommended` and never alter it. The council NEVER decides forks alone and NEVER relaunches design.

## What You Receive

From the orchestrator:
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- The `design.md` locator (required)
- The `proposal.md` locator (optional — if absent, the council proceeds with `design.md` only and the acta notes `proposal.md` was absent)
- The round number (1 for the initial round; 2 only when the orchestrator launches a re-framing round with fresh voices)

## Execution and Persistence Contract

> Follow **Section B** (retrieval) and **Section C** (persistence) from `skills/_shared/sdd-phase-common.md`.

- **engram**: Read `sdd/{change-name}/design` (required) and `sdd/{change-name}/proposal` (when present). Save the acta as `sdd/{change-name}/council`. Do NOT modify the design.
- **openspec**: Read `openspec/changes/{change-name}/design.md` and `proposal.md` (when present). Write the acta at `openspec/changes/{change-name}/council.md`. Follow `skills/_shared/openspec-convention.md`.
- **hybrid**: Do BOTH (file + Engram mirror `sdd/{change-name}/council`).
- **none**: Return the acta inline only.

## Invariants (HARD)

1. **The council is UNREACHABLE from the canonical flow (D8).** No canonical-flow hook fires it — the orchestrator allow-list excludes `sdd-council` and the prompt never routes to it. Any invocation is manual/out-of-band. The retained machinery below is only for that case.
2. **The council NEVER decides forks alone.** When 2+ divergent options exist, you return them framed to the orchestrator, which presents them to the user. The model never resolves a fork autonomously.
3. **Convergence does NOT interrupt the user.** When all 3 lenses agree on a single viable option, the acta records `convergence` and the chain continues without any user confirmation.
4. **The council NEVER relaunches design.** You are read-only with respect to `design.md`. Only the orchestrator re-launches design (specifically when arch-lint fails and the acta shows decisions were not applied).
5. **Max 2 rounds.** The council runs at most 2 rounds (initial + 1 re-frame with fresh voices). The round budget is tracked by the ORCHESTRATOR, not by this skill — you are stateless across invocations and record only the round number you are told.
6. **The acta is the binding trace document (retained machinery).** For manual reviews the acta is persisted before downstream review; in the canonical flow, post-apply arch-lint axis 2 consumes the `arch-plan.md` acta (D9) — never the council acta.

## Lens Sections

Each lens agent reads ONLY its own lens section below plus `design.md` + `proposal.md`. Lenses run in parallel via `task()` and cannot see each other's output — that independence is the point. The inline lens-agent prompts reference these headers verbatim.

## Lens: Architecture (`sdd-council-arch`)

Evaluate design soundness and structural integrity. Verify whether the proposed architecture honors clean/hexagonal principles where the design introduces boundaries: new layers, ports & adapters, dependency injection, module boundaries, and external access. Check dependency direction (inward toward the core), domain isolation, and whether the smallest correction was chosen. Yield one structured verdict: the single viable option you support (or a divergent option with rationale), plus your top concerns.

## Lens: Product/UX (`sdd-council-product`)

Evaluate whether the design serves the user outcome and stays honest to the approved spec and proposal. Check scope fit (nothing dropped, nothing invented), API/UX usability of the proposed interfaces, acceptance-criteria achievability, and whether the design's choices are the smallest ones that satisfy the product intent. Yield one structured verdict: the single viable option you support (or a divergent option with rationale), plus your top concerns.

## Lens: Risk/Resilience (`sdd-council-risk`)

Evaluate failure modes and operational exposure. Check the design's failure cases and edge cases from the RFC, blast radius, rollback safety, security/privacy posture, performance bounds, and retry/stop behavior. Flag any option that amplifies operational risk without mitigation. Yield one structured verdict: the single viable option you support (or a divergent option with rationale), plus your top concerns.

## What to Do

### Step 1: Load Skills

Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

### Step 2: Read the Inputs (READ-ONLY)

Read the completed `design.md` in full, and `proposal.md` when present. If `proposal.md` is missing, note it in the acta and proceed with `design.md` only. If `design.md` is empty or trivial (no decisions to review), return the retained `N/A` path: acta records `N/A` (no decisions to review) and downstream review skips axis 2 — the review continues without lens dispatch.

### Step 3: Dispatch the 3 Lens Agents in Parallel

Launch `task(sdd-council-arch, sdd-council-product, sdd-council-risk)` in ONE parallel block. Pass each lens agent: the change name, the `design.md` locator, the `proposal.md` locator (when present), and its lens name. Do NOT pass the other lenses' prompts or any prior-round output — fresh voices per round.

### Step 4: Consolidate the Verdicts

Collect the 3 lens verdicts and consolidate exactly as follows:

| Pattern | Verdict | Behavior |
|---|---|---|
| All 3 lenses name the same single viable option | `convergence` | Acta records the converged decision. NO user interruption; the reviewing party routes the outcome. |
| 2 lenses converge on one option, 1 dissents with a distinct viable option | `fork` | Treat as a real fork: 2+ divergent options exist. Frame the options for the user via the orchestrator. |
| 3 lenses diverge into 2+ distinct viable options | `fork` | Frame the options for the user via the orchestrator. |
| Verdicts are incoherent for framing (multiple N/A, lens evaluated the wrong artifact, no clear option space) | `reframe-needed` | Return the diagnosis; the ORCHESTRATOR decides whether to launch round 2 with fresh voices (max 2 rounds total). |
| Any lens agent `task()` fails or times out | dissent/absence | Use the other 2 voices; if no majority → `fork` or `reframe-needed` per the normal rules. The acta records the absence. |

The council NEVER picks an option itself when the verdict is `fork`. Your output is the frame, not the decision.

### Step 5: Write the Acta

Persist the acta with EXACTLY these sections:

```markdown
# Council Acta: {change-name}

## Round
{1 | 2}

## Lens Verdicts

### sdd-council-arch
- Viable option: {option identifier or N/A}
- Verdict: {converge on <option> | propose <option> | dissent | absent}
- Concerns: {top concerns, or None}

### sdd-council-product
- Viable option: {option identifier or N/A}
- Verdict: {converge on <option> | propose <option> | dissent | absent}
- Concerns: {top concerns, or None}

### sdd-council-risk
- Viable option: {option identifier or N/A}
- Verdict: {converge on <option> | propose <option> | dissent | absent}
- Concerns: {top concerns, or None}

## Convergence
{convergence | fork | reframe-needed | N/A}

{fork only →}
## Selected Option
{the option the user selected — filled only after the user decides}

## Decision
### Decision: {titled decision 1}
{the converged/user-selected decision, stated as a binding design directive}

### Decision: {titled decision 2}
{only when more than one decision was made}
```

Titled decisions are the trace contract with downstream design review: each `### Decision:` title is verified against the design, title-by-title. (In the canonical flow, post-apply arch-lint axis 2 consumes the `arch-plan.md` acta — not this one; D9.) Persist per the Persistence Contract: file at `openspec/changes/{change-name}/council.md` (openspec/hybrid) AND Engram topic `sdd/{change-name}/council` (engram/hybrid). The acta MUST be persisted before you return.

### Step 6: Return the Verdict Envelope

Return to the orchestrator per **Section D** from `skills/_shared/sdd-phase-common.md`, with the verdict surfaced explicitly:

- `status`: `success` | `partial` (lens agent absent/failed) | `blocked` (design unreadable)
- `executive_summary`: verdict (`convergence` | `fork` | `reframe-needed` | `N/A`), whether the user must decide, and the acta locator
- `artifacts`: the acta locator(s) written
- `verdict`: `convergence` | `fork` | `reframe-needed` | `N/A`
- `framed_options`: (fork only) the 2+ options framed for the user, in neutral language — never a recommendation among them
- `round`: the round number recorded in the acta
- `next_recommended`: `none` — the orchestrator routes the chain; the council never proposes the next phase
- `risks`: concerns that survived consolidation, or `None`
- `skill_resolution`: from Section A

## Rules

- UNREACHABLE from the canonical flow (D8): the orchestrator allow-list excludes `sdd-council`; no canonical-flow hook fires it — manual/out-of-band invocation only
- ALWAYS read `design.md` in full; never review against imagination
- NEVER modify `design.md` or `proposal.md` — the council is read-only with respect to the design; only the orchestrator re-launches design
- NEVER decide a fork alone — 2+ divergent options are always framed for the user; a user rejection of ALL options STOPs the chain with a report
- NEVER interrupt the user on convergence — the acta records the decision and the chain continues
- NEVER run more than the round you are told; the max-2-rounds budget lives in the orchestrator, and the council is stateless
- NEVER appear in or alter `nextRecommended` — the council is not a pipeline token
- ALWAYS persist the acta before returning
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.