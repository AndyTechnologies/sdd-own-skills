---
name: product-quest
description: "Product question phase — the RFC pre-pass (product branch). Bounded RFC interview with the user AFTER exploration, one question at a time, hard budget 50, then an explicit product RFC gate; on approval rfc-author assembles product-rfc.md. ALWAYS runs after exploration in the default ODD workflow and in explicit SDD."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "4.1"
  delegate_only: true  # intentional: quest is orchestrator-inline; excluded from registry autocomplete by design
---

## Execution Role

Confirm your role before acting. In OpenCode, **only the orchestrator holds the interactive human channel** (the `question` tool permission); a `task()` sub-agent returns a single final result and cannot sustain a live one-question-at-a-time interview. Therefore the PRODUCT QUEST interview is always performed by whoever holds that channel.

- **If you are the orchestrator** (you loaded this skill through the `skill()` tool): you PERFORM the interview yourself. Do NOT delegate the interview to the `rfc-author` sub-agent — it cannot talk to the human in OpenCode. Proceed with the phase work below, asking the user one focused question at a time via your `question` tool.
- **If you are the `rfc-author` sub-agent**: you do NOT interview the human. You are the RFC author: you receive the user's answers (Q&A pairs) collected by the orchestrator for the product branch, assemble them into `product-rfc.md`, and present the approval gate back to the orchestrator. Do not call the Skill tool or another orchestrator command.

> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

You are responsible for the **PRODUCT QUEST** phase (the product branch of the RFC pre-pass): a bounded RFC interview with the human user about the product and domain decisions, run **after** exploration and before the proposal. In OpenCode the interviewer is the orchestrator (the only role with the `question` channel); the `rfc-author` sub-agent, when launched, is the RFC author that shapes the collected answers into `product-rfc.md`.

Your job:
1. Interview the user **one focused question at a time** to discover and pin the product and domain requirements and behavior (never invent product or domain decisions), within the **hard budget of 50**.
2. Produce a **language-agnostic, structured product RFC** that describes behavior and contracts — NOT an implementation or a stack choice.
3. Present the product RFC for **explicit user approval** at the product RFC gate. `needs-changes` reopens the product branch only, within its remaining budget.
4. Mark the **approved product RFC as the binding mandate** — the source of truth `sdd-propose` and `sdd-spec` must trace to. After the gate approves, delegate the collected Q&A to `rfc-author` for `product-rfc.md` persistence.

The product quest runs AFTER exploration: the interview starts from the change's problem statement (`$ARGUMENTS`) AND the exploration findings. Do not re-explore the codebase yourself — the explore phase already produced the findings. This is one of the two SDD phases that talk to the human (the other is the architecture quest). Every other phase is a silent executor. The RFC discipline separates "a handoff of decisions" from "an RFC that describes behavior without choosing a language/framework".

## What You Receive

From the orchestrator:
- The change/problem statement (from `$ARGUMENTS`) — the Product branch's starting point
- The **exploration summary / explore findings** — the evidence base the interview builds on (the interview consumes them; it does NOT re-explore the codebase, the explore phase already produced the findings)
- The branch being interviewed (`product` in this skill) — the orchestrator performs the product branch first, behind its own RFC gate
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- The branch's hard question budget: **Product Quest = 50** (never exceed it)

## Hard constraints

1. **Hard question budget.** Product Quest = **50**. Never exceed it; exhaustion stops the branch with a report, never silently extends.
2. **One explicit RFC gate.** The product RFC gate (before `rfc-author` runs and before any architecture quest starts). The RFC is not approved by an empty frontier — the user must explicitly approve it. Never auto-approve on the human's behalf.
3. **`needs-changes` reopens ONLY the product branch.** A gate rejection re-interviews the product branch within its REMAINING budget; no other branch is touched by this rejection.
4. **One question at a time.** Ask exactly ONE focused question; follow the answer until that branch resolves before the next. Never batch a frontier.
5. **Never invent missing decisions.** If something is unspecified, ASK — do not assume.
6. **No stack drag.** Do not pull the repo's language/framework/stack into the RFC unless the user explicitly confirms it as a requirement. Describe behavior, constraints, inputs/outputs/events, invariants, contracts.
7. **Start from the problem statement AND the exploration findings; stay out of the repo.** The explore phase already produced the findings — do not re-explore the codebase during the interview. Facts about the user's intention and domain come from the user; facts you genuinely need from the environment are looked up for you by a sub-agent (see Step 4) — you do not dig into the codebase yourself.

## Loop guard

- Stop when every branch of the product decision tree is resolved **OR** the hard budget is spent (50).
- Gate `approved` → hand off to `rfc-author` (product branch only). You never start a new question just to keep going.
- If the user asks you to stop early, STOP immediately and persist a `rejected`/`needs-changes` result — never force a full session.

## Execution and Persistence Contract

> Follow **Section B** (retrieval), **Section C** (persistence), and **Section D** (return envelope) from `skills/_shared/sdd-phase-common.md`.

Artifact: you persist a **quest artifact** containing the **product RFC** so downstream phases consume it:

- **engram**: save as `sdd/{change-name}/quest-product`, type `architecture`, `capture_prompt: false`, following Section C.
- **openspec**: write `openspec/changes/{change-name}/quest-product.md`. (Additive file within the change folder; it does not create a new native artifact token.)
- **hybrid**: do BOTH (file + engram save).
- **none**: return the handoff inline only.

## What to Do

### Step 1: Load Skills

Follow **Section A** from `skills/_shared/sdd-phase-common.md`. You MUST load the `grilling` skill first — it owns the bounded, branch-following interview primitive and the question-budget discipline (Product 50).

> **Runtime note (OpenCode):** the interviewer is the orchestrator. If you are the orchestrator and loaded this skill via `skill()`, run Steps 2–5 yourself against the user with your `question` tool. The `rfc-author` sub-agent is not used for the interview; after the user approves the RFC, the orchestrator launches it with the collected Q&A to draft the final canonical RFC, which the orchestrator persists as the binding mandate.

### Step 2: Establish the Problem Statement

You receive the change/problem statement AND the exploration findings. If the change name or problem statement is vague or ambiguous, make resolving it your **first branch**: ask the user to state the goal and desired outcome before you enumerate the decision tree. Never grill in a vacuum — the exploration findings and the user's intent fill it. Do NOT let any stack detail the user mentions bleed into the RFC (see Constraint #4).

### Step 3: Plan the Question Path (branch budget ≤ 50)

Before asking anything, enumerate the open decision branches **from the problem statement, the user intent, AND the exploration findings**, rank by impact × uncertainty, and allocate questions so the running total never exceeds the branch's budget (50). Provide your recommended answer per question (a synthesis of the problem and your domain reasoning), pending the user's correction.

The **Product branch** covers, when applicable: problem/users/outcome, goals and non-goals, domain terminology and business rules, inputs/outputs/events/external contracts, invariants and validation, failure cases and edge cases, security/privacy/performance/operational, alternatives and trade-offs, quality gates/acceptance criteria, unresolved questions.

### Step 4: Run the Interview — one question at a time

Ask exactly ONE question, wait for the answer, follow it down its branch until resolved, then ask the next. Guard: finding facts is your job, never the user's. The primary sources of facts are the **exploration findings** and the **user's stated intent and domain knowledge**. During the interview you do not read the codebase yourself; if a question truly requires a fact from the environment (a repo, a tool, an API), delegate a single bounded lookup to a sub-agent and do not block the interview on it — record it as a fact for the RFC once resolved. Do not turn the interview into an exploration pass.

> **Flow discipline (CRITICAL):** the interview is a **continuous stream** driven by the agent holding the `question` channel. After the user answers a question, ask the NEXT question immediately in the same flow — do NOT pause to ask "shall I continue?", do NOT end the turn to wait for a "continúa"/"go on" prompt, and do NOT re-confirm before each new question. Keep asking one after another until the branch tree is empty or the 50-question budget is spent. The ONLY place you stop to get the user's explicit go-ahead is the RFC approval gate (Step 7). If you find yourself waiting on "continue", that is a bug — keep the interview moving.

### Step 5: Stop at the Branch Budget or Empty Tree

- Tree empty → you have enough to draft the branch's RFC.
- Branch budget reached (Product 50) → consolidate covered branches, list pending ones explicitly under "Unresolved Questions", and request the user's explicit decision on how to proceed (draft partial RFC / another session). Never silently extend.

### Step 6: Draft the Product RFC (language-agnostic, structured)

Generate the branch's RFC using EXACTLY the fixed product schema (every section present; fill "N/A" or "None" when not applicable):

```markdown
# Product Quest: {change-name}

## Approval: pending | approved | needs-changes | rejected

## RFC

### Goals / Non-goals

### Users & Outcome

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
- **Binding mandate**: the approved product RFC is the binding source of truth for `sdd-propose` AND `sdd-spec` — not just "recommended scope".
- **Delegation note (OpenCode):** When the artifact store is `engram`, `openspec`, or `hybrid`, the orchestrator may delegate the final RFC drafting to the `rfc-author` sub-agent after the gate approves (via `task()`) to produce the canonical artifact (`product-rfc.md`). The interactive draft presented for user approval in this step remains the orchestrator's work; only the persistence-ready artifact is delegated.

### Step 7: The product RFC gate

Present the branch's RFC to the user and ask for EXPLICIT approval. Do NOT auto-approve because the tree is empty.

- **RFC gate — Product RFC:** `approved` → set `Approval: approved` and emit `next_recommended: rfc-author` (delegate the collected Q&A for `product-rfc.md` persistence). `needs-changes` → re-interview ONLY the product branch within its REMAINING budget, re-present, re-ask. `rejected` → set `Approval: rejected`, persist, STOP (no propose, no design phases).

### Step 8: Persist the Quest Artifact (RFC)

Persist per the Persistence Contract with the `## Approval:` header and the branch's full RFC schema. The `Approval:` value is the ONLY gate the routing uses to decide re-run vs skip vs proceed. **This is MANDATORY** when tied to a named change — do not skip it. If the orchestrator delegated the final RFC drafting to `rfc-author` after the gate approved (see Step 6 delegation note), persist the sub-agent's artifact output (`product-rfc.md`); otherwise persist the branch RFC drafted in Step 6.

### Step 9: Return the Envelope

Return the structured envelope per **Section D** from `skills/_shared/sdd-phase-common.md`:

- `status`: `success` (branch RFC approved) | `partial` (interview cut early, needs revisiting) | `blocked` (rejected)
- `executive_summary`: what the branch RFC resolved and the user's approval state
- `artifacts`: the quest artifact locator (branch + `## Approval:` header)
- `branch`: `product`
- `approval`: `approved` | `needs-changes` | `rejected`
- `next_recommended`: gate `approved` → `rfc-author` (product branch); otherwise `quest` (re-run the product branch only) or `none`
- `risks`: any unresolved questions / risks
- `skill_resolution`: from Section A

## Rules

- **NEVER exceed the hard budget:** Product Quest = 50. Exhaustion stops the branch with a report.
- **NEVER ask more than one question at a time.** This is branch-following, not batching.
- **NEVER auto-approve.** The branch has its own explicit RFC gate; approval is a separate, explicit act by the user (non-goal: do not approve decisions on the user's behalf).
- **`needs-changes` reopens ONLY the product branch**, within its remaining budget; no other branch is touched by the rejection.
- **NEVER drag the stack into the RFC** unless the user confirms the stack choice as a requirement.
- **Start AFTER exploration, from the findings.** Do not read the codebase during the interview; facts come from the exploration findings and the user, with single bounded environment lookups delegated to a sub-agent only when necessary.
- The **approved product RFC is the binding source of truth** for `sdd-propose` AND `sdd-spec` — not merely a recommendation.
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