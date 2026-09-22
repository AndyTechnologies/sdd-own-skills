---
name: architecture-quest
description: "Architecture question phase — the RFC pre-pass (architecture branch). Bounded RFC interview AFTER exploration AND the approved product RFC, one question at a time, hard budget 20, then an explicit architecture RFC gate; on approval rfc-author assembles arch-rfc.md. Runs whenever the request involves product/feature work or needs architectural decisions (default ODD workflow and explicit SDD)."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "4.1"
  delegate_only: true  # intentional: quest is orchestrator-inline; excluded from registry autocomplete by design
---

## Execution Role

Confirm your role before acting. In OpenCode, **only the orchestrator holds the interactive human channel** (the `question` tool permission); a `task()` sub-agent returns a single final result and cannot sustain a live one-question-at-a-time interview. Therefore the ARCHITECTURE QUEST interview is always performed by whoever holds that channel.

- **If you are the orchestrator** (you loaded this skill through the `skill()` tool): you PERFORM the interview yourself. Do NOT delegate the interview to the `rfc-author` sub-agent — it cannot talk to the human in OpenCode. Proceed with the phase work below, asking the user one focused question at a time via your `question` tool.
- **If you are the `rfc-author` sub-agent**: you do NOT interview the human. You are the RFC author: you receive the user's answers (Q&A pairs) collected by the orchestrator for the architecture branch, assemble them into `arch-rfc.md`, and present the approval gate back to the orchestrator. Do not call the Skill tool or another orchestrator command.

> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

You are responsible for the **ARCHITECTURE QUEST** phase (the architecture branch of the RFC pre-pass): a bounded RFC interview with the human user about architecture and design decisions, run **after** exploration and the approved product RFC, and before the architecture plan. In OpenCode the interviewer is the orchestrator (the only role with the `question` channel); the `rfc-author` sub-agent, when launched, is the RFC author that shapes the collected answers into `arch-rfc.md`.

Your job:
1. Interview the user **one focused question at a time** to discover and pin the architecture constraints and design decisions (never invent architectural decisions or constraints), within the **hard budget of 20**.
2. Produce a **language-agnostic, structured architecture RFC** that describes architecture constraints, modules, interfaces and envelopes — not a step-by-step implementation.
3. Present the architecture RFC for **explicit user approval** at the architecture RFC gate. `needs-changes` reopens the architecture branch only, within its remaining budget.
4. Mark the **approved architecture RFC as the binding mandate** — the source of truth `architecture-plan` must trace to. After the gate approves, delegate the collected Q&A to `rfc-author` for `arch-rfc.md` persistence.

The architecture quest starts from the **approved Product RFC**, the **exploration findings**, and the user's stated architecture intent. Do not re-explore the codebase yourself — the explore phase already produced the findings. This is one of the two SDD phases that talk to the human (the other is the product quest). Every other phase is a silent executor. The RFC discipline separates "a handoff of decisions" from "an RFC that describes behavior without choosing a language/framework".

## What You Receive

From the orchestrator:
- The change/problem statement (from `$ARGUMENTS`) — the Architecture branch's starting point
- The **approved Product RFC** (from the product gate) — the product mandate the architecture must serve
- The **exploration summary / explore findings** — the evidence base the interview builds on (the interview consumes them; it does NOT re-explore the codebase, the explore phase already produced the findings)
- The **user's stated architecture intent** — what the user already declared about architecture during earlier phases
- The branch being interviewed (`architecture` in this skill) — the orchestrator performs the architecture branch second, behind its own RFC gate
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- The branch's hard question budget: **Architecture Quest = 20** (never exceed it)

## Hard constraints

1. **Hard question budget.** Architecture Quest = **20**. Never exceed it; exhaustion stops the branch with a report, never silently extends.
2. **One explicit RFC gate.** The architecture RFC gate (before `rfc-author` runs and before `architecture-plan` starts). The RFC is not approved by an empty frontier — the user must explicitly approve it. Never auto-approve on the human's behalf.
3. **`needs-changes` reopens ONLY the architecture branch.** A gate rejection re-interviews the architecture branch within its REMAINING budget; no other branch is touched by this rejection.
4. **One question at a time.** Ask exactly ONE focused question; follow the answer until that branch resolves before the next. Never batch a frontier.
5. **Never invent missing decisions.** If something is unspecified, ASK — do not assume.
6. **No stack drag.** Do not pull the repo's language/framework/stack into the RFC unless the user explicitly confirms it as a requirement. Describe constraints, boundaries, interfaces, and envelopes — not a step-by-step implementation.
7. **Start from the approved Product RFC + exploration findings + stated intent; stay out of the repo.** The explore phase already produced the findings — do not re-explore the codebase during the interview. Facts about the user's intention and domain come from the user; facts you genuinely need from the environment are looked up for you by a sub-agent (see Step 4) — you do not dig into the codebase yourself.

## Loop guard

- Stop when every branch of the architecture decision tree is resolved **OR** the hard budget is spent (20).
- Gate `approved` → hand off to `rfc-author` (architecture branch only). You never start a new question just to keep going.
- If the user asks you to stop early, STOP immediately and persist a `rejected`/`needs-changes` result — never force a full session.

## Execution and Persistence Contract

> Follow **Section B** (retrieval), **Section C** (persistence), and **Section D** (return envelope) from `skills/_shared/sdd-phase-common.md`.

Artifact: you persist a **quest artifact** containing the **architecture RFC** so downstream phases consume it:

- **engram**: save as `sdd/{change-name}/quest-architecture`, type `architecture`, `capture_prompt: false`, following Section C.
- **openspec**: write `openspec/changes/{change-name}/quest-architecture.md`. (Additive file within the change folder; it does not create a new native artifact token.)
- **hybrid**: do BOTH (file + engram save).
- **none**: return the handoff inline only.

## What to Do

### Step 1: Load Skills

Follow **Section A** from `skills/_shared/sdd-phase-common.md`. You MUST load the `grilling` skill first — it owns the bounded, branch-following interview primitive and the question-budget discipline (Architecture 20).

> **Runtime note (OpenCode):** the interviewer is the orchestrator. If you are the orchestrator and loaded this skill via `skill()`, run Steps 2–5 yourself against the user with your `question` tool. The `rfc-author` sub-agent is not used for the interview; after the user approves the RFC, the orchestrator launches it with the collected Q&A to draft the final canonical RFC, which the orchestrator persists as the binding mandate.

### Step 2: Ground in the Approved Product RFC

You receive the change/problem statement, the **approved Product RFC**, and the exploration findings. If the product RFC is missing or not yet approved, STOP and report `blocked` — the architecture branch cannot run without its product mandate. If the product RFC or problem statement is vague in architectural terms, make clarifying the architecture intent your **first branch**: ask the user about the architectural goals and constraints (for example: modularity, scalability, evolution, quality attributes) before you enumerate the decision tree. Never grill in a vacuum — the approved product RFC, the exploration findings, and the user's stated intent fill it.

### Step 3: Plan the Question Path (branch budget ≤ 20)

Before asking anything, enumerate the open decision branches **from the approved Product RFC, the exploration findings, AND the user's stated architecture intent**, rank by impact × uncertainty, and allocate questions so the running total never exceeds the branch's budget (20). Provide your recommended answer per question (a synthesis of the product RFC, the exploration findings, and your architecture reasoning), pending the user's correction.

The **Architecture branch** covers, when applicable: architecture constraints and decision space, system boundaries and modules, interfaces, data and persistence, security/privacy/operational architecture, scalability and performance envelope, integration architecture, technology constraints (user-confirmed only), unresolved questions (blocking for design).

> **Mechanics (context-driven, table-driven):** the architecture interview is driven by CONTEXT, not a fixed questionnaire. Start from the 8 base architecture context questions and follow the user's answers into deeper branches, using the declarative branch table below. Branches are only explored when their trigger context is present (see the table). The budget (20) is shared across all architecture branches.

**The 8 base architecture context questions** (ask the ones whose context is present; do not ask all 8 blindly):
1. Which subsystems or boundaries does the change cross, and which existing modules/interfaces are touched?
2. Where does the change live relative to existing boundaries (new module, extension, refactor)?
3. What are the user-confirmed tech constraints (language, framework, platform, hosting) — only those the user explicitly confirmed as requirements?
4. Which external systems or services does the change integrate with, and in which direction (provider/consumer)?
5. What data does the change introduce or transform, and where does that data live?
6. Which quality attributes are at stake (performance, scalability, reliability, security, maintainability) and what envelope is required?
7. What is the migration and compatibility story (breaking vs additive, rollout, rollback)?
8. Which operability concerns apply (observability, deployment, configuration, lifecycle)?

**Declarative branch table — trigger → explore:**

| If the user's answer touches on... | Then explore the branch: |
|---|---|
| Boundaries, modules, layers, package structure | Architectural boundaries & module decomposition |
| Interfaces between components/external systems | Interface contracts (APIs, events, conventions) |
| Data models, schemas, migrations, persistence | Data & persistence architecture |
| Concurrency, async, load, scale | Scalability & performance envelope |
| Security, auth, privacy, compliance | Security & privacy architecture |
| Deployment, observability, ops | Operational architecture |
| Tech stack, frameworks, libraries | Technology constraints (USER-CONFIRMED ONLY) |
| Migration, compatibility, rollout | Migration & compatibility strategy |
| Failure, resilience, recovery | Reliability & failure handling |

### Step 4: Run the Interview — one question at a time

Ask exactly ONE question, wait for the answer, follow it down its branch until resolved, then ask the next. Guard: finding facts is your job, never the user's. The primary sources of facts are the **exploration findings**, the **approved Product RFC**, and the **user's stated architecture intent**. During the interview you do not read the codebase yourself; if a question truly requires a fact from the environment (a repo, a tool, an API), delegate a single bounded lookup to a sub-agent and do not block the interview on it — record it as a fact for the RFC once resolved. Do not turn the interview into an exploration pass.

> **Flow discipline (CRITICAL):** the interview is a **continuous stream** driven by the agent holding the `question` channel. After the user answers a question, ask the NEXT question immediately in the same flow — do NOT pause to ask "shall I continue?", do NOT end the turn to wait for a "continúa"/"go on" prompt, and do NOT re-confirm before each new question. Keep asking one after another until the branch tree is empty or the 20-question budget is spent. The ONLY place you stop to get the user's explicit go-ahead is the RFC approval gate (Step 7). If you find yourself waiting on "continue", that is a bug — keep the interview moving.

### Step 5: Stop at the Branch Budget or Empty Tree

- Tree empty → you have enough to draft the branch's RFC.
- Branch budget reached (Architecture 20) → consolidate covered branches, list pending ones explicitly under "Unresolved Questions", and request the user's explicit decision on how to proceed (draft partial RFC / another session). Never silently extend.

### Step 6: Draft the Architecture RFC (language-agnostic, structured)

Generate the branch's RFC using EXACTLY the fixed architecture schema (every section present; fill "N/A" or "None" when not applicable):

```markdown
# Architecture Quest: {change-name}

## Approval: pending | approved | needs-changes | rejected

## RFC

### Architecture Constraints & Decision Space

### System Boundaries & Modules

### Interfaces

### Data & Persistence

### Security / Privacy / Operational Architecture

### Scalability & Performance Envelope

### Integration Architecture

### Technology Constraints (user-confirmed only)

### Unresolved Questions (blocking for design)
```

- The RFC describes **architecture constraints, boundaries, interfaces and envelopes**, not a step-by-step implementation. Do not state a stack unless the user explicitly confirmed it as a requirement (then note it as a confirmed requirement).
- **Binding mandate**: the approved architecture RFC is the binding source of truth for `architecture-plan` — the architecture plan's titled decisions must be resolvable against it.
- **Delegation note (OpenCode):** When the artifact store is `engram`, `openspec`, or `hybrid`, the orchestrator may delegate the final RFC drafting to the `rfc-author` sub-agent after the gate approves (via `task()`) to produce the canonical artifact (`arch-rfc.md`). The interactive draft presented for user approval in this step remains the orchestrator's work; only the persistence-ready artifact is delegated.

### Step 7: The architecture RFC gate

Present the branch's RFC to the user and ask for EXPLICIT approval. Do NOT auto-approve because the tree is empty.

- **RFC gate — Architecture RFC:** `approved` → set `Approval: approved` and emit `next_recommended: rfc-author` (delegate the collected Q&A for `arch-rfc.md` persistence). `needs-changes` → re-interview ONLY the architecture branch within its REMAINING budget, re-present, re-ask. `rejected` → set `Approval: rejected`, persist, STOP (no architecture plan, no design phases).

### Step 8: Persist the Quest Artifact (RFC)

Persist per the Persistence Contract with the `## Approval:` header and the branch's full RFC schema. The `Approval:` value is the ONLY gate the routing uses to decide re-run vs skip vs proceed. **This is MANDATORY** when tied to a named change — do not skip it. If the orchestrator delegated the final RFC drafting to `rfc-author` after the gate approved (see Step 6 delegation note), persist the sub-agent's artifact output (`arch-rfc.md`); otherwise persist the branch RFC drafted in Step 6.

### Step 9: Return the Envelope

Return the structured envelope per **Section D** from `skills/_shared/sdd-phase-common.md`:

- `status`: `success` (branch RFC approved) | `partial` (interview cut early, needs revisiting) | `blocked` (rejected)
- `executive_summary`: what the branch RFC resolved and the user's approval state
- `artifacts`: the quest artifact locator (branch + `## Approval:` header)
- `branch`: `architecture`
- `approval`: `approved` | `needs-changes` | `rejected`
- `next_recommended`: gate `approved` → `rfc-author` (architecture branch); otherwise `quest` (re-run the architecture branch only) or `none`
- `risks`: any unresolved questions / risks
- `skill_resolution`: from Section A

## Rules

- **NEVER exceed the hard budget:** Architecture Quest = 20. Exhaustion stops the branch with a report.
- **NEVER ask more than one question at a time.** This is branch-following, not batching.
- **NEVER auto-approve.** The branch has its own explicit RFC gate; approval is a separate, explicit act by the user (non-goal: do not approve decisions on the user's behalf).
- **`needs-changes` reopens ONLY the architecture branch**, within its remaining budget; no other branch is touched by the rejection.
- **NEVER drag the stack into the RFC** unless the user confirms the stack choice as a requirement.
- **Start AFTER exploration and the approved product RFC, from the findings.** Do not read the codebase during the interview; facts come from the exploration findings, the approved product RFC, and the user, with single bounded environment lookups delegated to a sub-agent only when necessary.
- The **approved architecture RFC is the binding source of truth** for `architecture-plan` — not merely a recommendation.
- Ask the user directly via the host's question primitive. Do NOT delegate your interview to a sub-agent.
- Keep the interview moving: after each answer, ask the NEXT question without pausing for a "continue" confirmation. Do not end the turn waiting for the user to say "continúa"/"go on" between questions. The interview only pauses for the user's explicit go-ahead at the RFC gate (Step 7).
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