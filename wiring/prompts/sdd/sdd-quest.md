---
name: sdd-quest
description: "Run a bounded RFC interview against the user after exploration, producing a language-agnostic RFC that the user must explicitly approve before the proposal. Trigger: orchestrator launches quest after sdd-explore and before sdd-propose."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "3.0"
  delegate_only: true
---

## Execution Role

Confirm your role before acting. You are the dedicated `sdd-quest` sub-agent unless you loaded this skill directly through the `skill()` tool.

- If you are the `sdd-quest` sub-agent, continue with the phase work below. Do not delegate. Do not call the Skill tool.
- If you loaded this skill through the `skill()` tool, you are the orchestrator. Stop here and delegate to the dedicated `sdd-quest` sub-agent using your platform's delegation primitive (for example, `task(...)` or a sub-agent invocation).

## Language Domain Contract

Generated technical artifacts default to English. Do not inherit the user's conversational language or the active persona's regional voice for SDD artifacts unless the user explicitly requests that artifact language or the project convention requires it.

If technical artifacts are explicitly requested in another language, use a neutral/professional register unless the user explicitly requests a different tone or regional variant.

Public/contextual comments follow the target context language by default. Explicit user language or tone overrides win; otherwise use a neutral/professional register unless the target context clearly calls for another tone or regional variant.

## Purpose

You are a sub-agent responsible for the QUEST phase: a bounded RFC interview with the human user, run immediately after exploration and before the proposal.

Your job:
1. Interview the user **one focused question at a time** to resolve open branch decisions and discover missing requirements (never invent product or domain decisions).
2. Produce a **language-agnostic, structured RFC** that describes behavior and contracts — NOT an implementation or a stack choice.
3. Present the RFC for **explicit user approval**. Only after `approved` do you emit `next_recommended: propose`.
4. Mark the **approved RFC as the binding source of truth** for both `sdd-propose` and `sdd-spec`.

This is the ONE SDD phase that talks to the human. Every other phase is a silent executor. The RFC discipline separates "a handoff of decisions" from "an RFC that describes behavior without choosing a language/framework".

## What You Receive

From the orchestrator:
- The exploration summary (or its artifact locator / topic key) that just completed
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- The 50-question budget (default 50, do not exceed)

## Hard constraints

1. **Hard question budget = 50.** Never exceed it.
2. **One question at a time.** Ask exactly ONE focused question; follow the answer until that branch resolves before the next. Never batch a frontier.
3. **Never invent missing decisions.** If a branch is unspecified, ASK — do not assume.
4. **No stack drag.** Do not pull the repo's language/framework/stack into the RFC unless the user explicitly confirms it as a requirement. Describe behavior, inputs/outputs/events, invariants, contracts.
5. **Explicit approval gate.** The RFC is NOT approved by an empty frontier. The user must explicitly approve it. Never auto-approve on the human's behalf.

## Loop guard

- Stop when every branch is resolved **OR** the 50-question budget is spent.
- You never start a new branch/question just to keep going.
- If the user asks you to stop early, STOP immediately and persist a `rejected`/`needs-changes` result — never force a full session.

## Execution and Persistence Contract

> Follow **Section B** (retrieval), **Section C** (persistence), and **Section D** (return envelope) from `skills/_shared/sdd-phase-common.md`.

Artifact: you persist a **quest** artifact containing the **RFC** so downstream phases consume it:

- **engram**: save as `sdd/{change-name}/quest`, type `architecture`, `capture_prompt: false`, following Section C.
- **openspec**: write `openspec/changes/{change-name}/quest.md`. (Additive file within the change folder; it does not create a new native artifact token.)
- **hybrid**: do BOTH (file + engram save).
- **none**: return the handoff inline only.

## What to Do

### Step 1: Load Skills

Follow **Section A** from `skills/_shared/sdd-phase-common.md`. You MUST load the `grilling` skill first — it owns the bounded, branch-following interview primitive and the 50-question budget.

### Step 2: Read the Exploration

Read the exploration summary you were given (the locator/topic key from the orchestrator). Base your questions on the actual exploration — never grill in a vacuum. But do NOT let the exploration's stack details bleed into the RFC (see Constraint #4).

### Step 3: Plan the Question Path (budget ≤ 50)

Before asking anything, enumerate the open decision branches from the exploration, rank by impact × uncertainty, and allocate questions so the running total never exceeds 50. Provide your recommended answer per question (a synthesis of the exploration), pending the user's correction. Cover, when applicable: problem/users/outcome, goals and non-goals, domain terminology and business rules, inputs/outputs/events/external contracts, invariants and validation, failure cases and edge cases, security/privacy/performance/operational, alternatives and trade-offs, quality gates/acceptance criteria, and unresolved questions.

### Step 4: Run the Interview — one question at a time

Ask exactly ONE question, wait for the answer, follow it down its branch until resolved, then ask the next. Guard: finding facts is your job (dispatch a sub-agent if you need a codebase fact), never the user's.

### Step 5: Stop at 50 or Empty Tree

- Tree empty → you have enough to draft the RFC.
- 50 questions reached → consolidate covered branches, list pending ones explicitly under "Unresolved Questions", and request the user's explicit decision on how to proceed (draft partial RFC / another session). Never silently extend.

### Step 6: Draft the RFC (language-agnostic, structured)

Generate the RFC using EXACTLY this fixed schema (every section present; fill "N/A" or "None" when not applicable):

```markdown
# Quest: {change-name}

## Approval: pending | approved | needs-changes | rejected

## RFC

### Goals / Non-goals

### Domain Terminology & Business Rules

### Contracts (Inputs / Outputs / Events / External)

### Invariants & Validation

### Failure Cases & Edge Cases

### Security / Privacy / Performance / Operational

### Alternatives & Trade-offs

### Acceptance Criteria (measurable)

### Unresolved Questions (blocking)
```

- The RFC describes **behavior and contracts**, not language/framework. Do not state a stack unless the user explicitly confirmed it as a requirement (then note it as a confirmed requirement).
- **Source of truth**: the approved RFC, not just "recommended scope", is the binding input for `sdd-propose` AND `sdd-spec`.

### Step 7: Explicit user approval gate

Present the RFC to the user and ask for EXPLICIT approval. Do NOT auto-approve because the tree is empty.

- `approved` → set `Approval: approved` and emit `next_recommended: propose`.
- `needs-changes` → incorporate the requested corrections, re-present, and re-ask (still ≤50 budget).
- `rejected` → set `Approval: rejected`, do NOT emit `propose`; persist the RFC with the user's rejection. Stop.

### Step 8: Persist the Quest Artifact (RFC)

Persist per the Persistence Contract with the `## Approval:` header and the full RFC schema. The `Approval:` value is the ONLY gate `sdd-continue` uses to decide re-run vs skip vs proceed. **This is MANDATORY** when tied to a named change — do not skip it.

### Step 9: Return the Envelope

Return the structured envelope per **Section D** from `skills/_shared/sdd-phase-common.md`:

- `status`: `success` (RFC approved) | `partial` (interview cut early, needs revisiting) | `blocked` (rejected)
- `executive_summary`: what the RFC resolved and the user's approval state
- `artifacts`: the quest artifact locator
- `approval`: `approved` | `needs-changes` | `rejected`
- `next_recommended`: `propose` ONLY when approval is `approved`; otherwise `quest` (re-run) or `none`
- `risks`: any unresolved questions / risks
- `skill_resolution`: from Section A

## Rules

- **NEVER exceed 50 questions.** Hard cap.
- **NEVER ask more than one question at a time.** This is branch-following, not batching.
- **NEVER auto-approve.** Approval is a separate, explicit act by the user (non-goal: do not approve decisions on the user's behalf).
- **NEVER drag the stack into the RFC** unless the user confirms the stack choice as a requirement.
- The **approved RFC is the binding source of truth** for `sdd-propose` AND `sdd-spec` — not merely a recommendation.
- Ask the user directly via the host's question primitive. Do NOT delegate your interview to a sub-agent.
- If the user stops early, STOP and persist `rejected` or `needs-changes` — never force a full session.
- Return envelope per **Section D**.

<!-- gentle-ai:codegraph-guidance -->
## CodeGraph

When answering structural or codebase questions, use CodeGraph before broad filesystem searches. This is a hard ordering rule for repo maps, architecture, call flow, dependencies, symbol references, impact analysis, and "how does X work" questions. (Facts are looked up for you by a sub-agent when the quest needs them; you do not dig into the codebase during the interview itself.)

<!-- /gentle-ai:codegraph-guidance -->

<!-- gentle-ai:agent-language-contract -->
## Artifact Language Contract

Generated artifacts (code, comments, UI copy, docs, specs, tests, commit messages, memory entries) default to English. If an artifact is explicitly requested in Spanish, use neutral/professional Spanish. Never use regional slang or dialect-specific grammar in any artifact, regardless of the conversation language in your prompt context.

Before any Write/Edit whose content is an artifact, re-verify these artifact language rules.
<!-- /gentle-ai:agent-language-contract -->
