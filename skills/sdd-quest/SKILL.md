---
name: sdd-quest
description: "SDD question phase — the RFC pre-pass with two branches and two explicit RFC gates. Run two bounded RFC interviews against the user BEFORE exploration: Product Quest (hard budget 50) → RFC gate → Architecture Quest (hard budget 20) → RFC gate. Each branch produces a language-agnostic RFC Q&A (the binding mandate) the user must explicitly approve; needs-changes reopens ONLY the affected branch within its remaining budget. After both gates approve, sdd-rfc-author assembles the dual artifacts product-rfc.md + arch-rfc.md. Trigger: orchestrator launches quest first, before sdd-explore and before sdd-propose."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "4.0"
  delegate_only: true  # intentional: quest is orchestrator-inline; excluded from registry autocomplete by design
---

## Execution Role

Confirm your role before acting. In OpenCode, **only the orchestrator holds the interactive human channel** (the `question` tool permission); a `task()` sub-agent returns a single final result and cannot sustain a live one-question-at-a-time interview. Therefore the QUEST interview is always performed by whoever holds that channel.

- **If you are the orchestrator** (you loaded this skill through the `skill()` tool, or you are running `/sdd-new` / `sdd-continue`): you PERFORM the interview yourself. Do NOT delegate the interview to the `sdd-rfc-author` sub-agent — it cannot talk to the human in OpenCode. Proceed with the phase work below, asking the user one focused question at a time via your `question` tool.
- **If you are the `sdd-rfc-author` sub-agent**: you do NOT interview the human. You are the RFC author: you receive the user's answers (Q&A pairs) collected by the orchestrator, assemble them into the structured RFC, and present the approval gate back to the orchestrator. Do not call the Skill tool or another orchestrator command.

> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

You are responsible for the **QUEST** phase (the RFC pre-pass): a bounded RFC interview with the human user, run **before** exploration and before the proposal. In OpenCode the interviewer is the orchestrator (the only role with the `question` channel); the `sdd-rfc-author` sub-agent, when launched, is the RFC author that shapes the collected answers into the structured RFC.

Your job:
1. Interview the user **one focused question at a time** to discover and pin the requirements and behavior (never invent product or domain decisions) — twice, once per branch: **Product Quest (hard budget 50)** then **Architecture Quest (hard budget 20)**.
2. Produce a **language-agnostic, structured RFC** per branch that describes behavior and contracts — NOT an implementation or a stack choice.
3. Present each branch's RFC for **explicit user approval** at its own RFC gate (gate 1: Product before the Architecture Quest; gate 2: Architecture before `sdd-rfc-author`). `needs-changes` reopens ONLY the affected branch within its remaining budget.
4. Mark the **approved RFCs as the binding mandate** — the source of truth the explore phase consumes, and that `sdd-propose` and `sdd-spec` must trace to. After BOTH gates approve, delegate the collected Q&A to `sdd-rfc-author` for dual-artifact persistence (`product-rfc.md` + `arch-rfc.md`).

The quest runs BEFORE exploration. There is NO exploration summary to base questions on: the interview starts from the change's problem statement (`$ARGUMENTS`) and the user's stated intent, not from the repository. This is the ONE SDD phase that talks to the human. Every other phase is a silent executor. The RFC discipline separates "a handoff of decisions" from "an RFC that describes behavior without choosing a language/framework".

## What You Receive

From the orchestrator:
- The change/problem statement (from `$ARGUMENTS`) — this is the Product branch's starting point; there is NO exploration summary
- The approved Product RFC Q&A (for the Architecture branch only; the architecture interview starts from the product mandate and the user's stated architecture intent, never from the repository)
- The branch being interviewed (`product` | `architecture`) — the orchestrator performs the branches sequentially, each behind its own RFC gate
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- The branch's hard question budget: **Product Quest = 50** / **Architecture Quest = 20** (never exceed the active branch's budget)

## Hard constraints

1. **Hard question budgets per branch.** Product Quest = **50**, Architecture Quest = **20**. Never exceed the ACTIVE branch's budget; exhaustion stops the branch with a report, never silently extends.
2. **Two explicit RFC gates.** Gate 1 approves the Product RFC (before the Architecture Quest starts); gate 2 approves the Architecture RFC (before `sdd-rfc-author` runs). Neither RFC is approved by an empty frontier — the user must explicitly approve each one. Never auto-approve on the human's behalf.
3. **`needs-changes` reopens ONLY the affected branch.** A gate rejection re-interviews the rejected branch within its REMAINING budget; the other branch stays untouched until its own gate.
4. **One question at a time.** Ask exactly ONE focused question; follow the answer until that branch resolves before the next. Never batch a frontier.
5. **Never invent missing decisions.** If a branch is unspecified, ASK — do not assume.
6. **No stack drag.** Do not pull the repo's language/framework/stack into either RFC unless the user explicitly confirms it as a requirement. Describe behavior, constraints, inputs/outputs/events, invariants, contracts.
7. **Run before exploration; stay out of the repo.** You are the pre-pass. Do not perform exploratory reading of the codebase during either interview. Facts about the user's intention and domain come from the user; facts you genuinely need from the environment are looked up for you by a sub-agent (see Step 4) — you do not dig into the codebase yourself.

## Loop guard

- Stop the active branch when every branch of it is resolved **OR** its hard budget is spent (Product 50 / Architecture 20).
- Gate 1 `approved` → proceed to the Architecture branch; gate 2 `approved` → hand off to `sdd-rfc-author`. You never start a new question just to keep going.
- If the user asks you to stop early, STOP immediately and persist a `rejected`/`needs-changes` result for the active branch — never force a full session.

## Execution and Persistence Contract

> Follow **Section B** (retrieval), **Section C** (persistence), and **Section D** (return envelope) from `skills/_shared/sdd-phase-common.md`.

Artifact: you persist a **quest** artifact containing the **RFC** so downstream phases consume it:

- **engram**: save as `sdd/{change-name}/quest`, type `architecture`, `capture_prompt: false`, following Section C.
- **openspec**: write `openspec/changes/{change-name}/quest.md`. (Additive file within the change folder; it does not create a new native artifact token.)
- **hybrid**: do BOTH (file + engram save).
- **none**: return the handoff inline only.

## What to Do

### Step 1: Load Skills

Follow **Section A** from `skills/_shared/sdd-phase-common.md`. You MUST load the `grilling` skill first — it owns the bounded, branch-following interview primitive and the question-budget discipline (Product 50 / Architecture 20).

> **Runtime note (OpenCode):** the interviewer is the orchestrator. If you are the orchestrator and loaded this skill via `skill()`, run Steps 2–5 yourself against the user with your `question` tool. The `sdd-rfc-author` sub-agent is not used for the interview; after the user approves the RFC, the orchestrator launches it with the collected Q&A to draft the final canonical RFC, which the orchestrator persists as the binding mandate.

### Step 2: Establish the Problem Statement

You receive the change/problem statement, NOT an exploration. If the change name or problem statement is vague or ambiguous, make resolving it your **first branch**: ask the user to state the goal and desired outcome before you enumerate the decision tree. Never grill in a vacuum — but the vacuum here is filled by the user's intent, not by a prior exploration. Do NOT let any stack detail the user mentions bleed into the RFC (see Constraint #4).

### Step 3: Plan the Question Path (branch budget ≤ 50 / ≤ 20)

Before asking anything, enumerate the open decision branches **from the problem statement and user intent** (Product branch) or **from the approved product RFC and the user's architecture intent** (Architecture branch — never from a repository), rank by impact × uncertainty, and allocate questions so the running total never exceeds the ACTIVE branch's budget (Product 50 / Architecture 20). Provide your recommended answer per question (a synthesis of the problem and your domain reasoning), pending the user's correction.

- **Product branch** covers, when applicable: problem/users/outcome, goals and non-goals, domain terminology and business rules, inputs/outputs/events/external contracts, invariants and validation, failure cases and edge cases, security/privacy/performance/operational, alternatives and trade-offs, quality gates/acceptance criteria, unresolved questions.
- **Architecture branch** covers, when applicable: structural constraints and non-goals, boundaries and external dependencies, architecture decisions with alternatives and trade-offs, quality attributes (performance/security/operational), invariants, failure cases, and unresolved architecture questions.

### Step 4: Run the Interview — one question at a time

Ask exactly ONE question, wait for the answer, follow it down its branch until resolved, then ask the next. Guard: finding facts is your job, never the user's. Because you run before exploration, the primary source of facts is the **user's stated intent and domain knowledge**. During the interview you do not read the codebase yourself; if a question truly requires a fact from the environment (a repo, a tool, an API), delegate a single bounded lookup to a sub-agent and do not block the interview on it — record it as a fact for the RFC once resolved. Do not turn the interview into an exploration pass.

> **Flow discipline (CRITICAL):** the interview is a **continuous stream** driven by the agent holding the `question` channel. After the user answers a question, ask the NEXT question immediately in the same flow — do NOT pause to ask "shall I continue?", do NOT end the turn to wait for a "continúa"/"go on" prompt, and do NOT re-confirm before each new question. Keep asking one after another until the branch tree is empty or the 50-question budget is spent. The ONLY place you stop to get the user's explicit go-ahead is the RFC approval gate (Step 7). If you find yourself waiting on "continue", that is a bug — keep the interview moving.

### Step 5: Stop at the Branch Budget or Empty Tree

- Tree empty → you have enough to draft the branch's RFC.
- Branch budget reached (Product 50 / Architecture 20) → consolidate covered branches, list pending ones explicitly under "Unresolved Questions", and request the user's explicit decision on how to proceed (draft partial RFC / another session). Never silently extend.

### Step 6: Draft the Branch RFC (language-agnostic, structured)

Generate the branch's RFC using EXACTLY the fixed schema for that branch (every section present; fill "N/A" or "None" when not applicable). The **Product RFC** uses the product schema below; the **Architecture RFC** uses the architecture schema that follows it.

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

The **Architecture RFC** uses this schema (structural, still language-agnostic — no stack unless the user confirmed it as a requirement):

```markdown
# Quest (Architecture): {change-name}

## Approval: pending | approved | needs-changes | rejected

## RFC (Architecture)

### Constraints & Non-goals

### Boundaries & External Dependencies

### Architecture Decisions (with Alternatives & Trade-offs)

### Quality Attributes (Performance / Security / Operational)

### Invariants & Validation

### Failure Cases & Edge Cases

### Acceptance Criteria (structural, measurable)

### Unresolved Questions (blocking)
```

- The RFC describes **behavior and contracts**, not language/framework. Do not state a stack unless the user explicitly confirmed it as a requirement (then note it as a confirmed requirement).
- **Binding mandate**: the approved RFCs are the mandate the `explore` phase consumes (what to validate/resolve), and the binding source of truth for `sdd-propose` AND `sdd-spec` — not just "recommended scope".
- **Delegation note (OpenCode):** When the artifact store is `engram`, `openspec`, or `hybrid`, the orchestrator may delegate the final RFC drafting to the `sdd-rfc-author` sub-agent after BOTH gates approve (via `task()`) to produce the canonical dual artifacts. The interactive drafts presented for user approval in this step remain the orchestrator's work; only the persistence-ready artifacts are delegated.

### Step 7: Two explicit RFC gates

Present the branch's RFC to the user and ask for EXPLICIT approval at its gate. Do NOT auto-approve because the tree is empty.

- **RFC gate 1 — Product RFC:** `approved` → set `Approval: approved` and emit `next_recommended: architecture-quest` (the Architecture branch starts next). `needs-changes` → re-interview ONLY the product branch within its REMAINING budget, re-present, re-ask. `rejected` → set `Approval: rejected`, persist, STOP (no explore, no Architecture Quest).
- **RFC gate 2 — Architecture RFC:** `approved` → set `Approval: approved` and emit `next_recommended: rfc-author` (delegate the collected Q&A for dual-artifact persistence). `needs-changes` → re-interview ONLY the architecture branch within its REMAINING budget, re-present, re-ask. `rejected` → set `Approval: rejected`, persist, STOP.

### Step 8: Persist the Quest Artifact (RFC)

Persist per the Persistence Contract with the `## Approval:` header, the branch name (`product` | `architecture`), and the branch's full RFC schema. The `Approval:` value is the ONLY gate `sdd-continue` uses to decide re-run vs skip vs proceed, gate by gate. **This is MANDATORY** when tied to a named change — do not skip it. If the orchestrator delegated the final RFC drafting to `sdd-rfc-author` after BOTH gates approved (see Step 6 delegation note), persist the sub-agent's dual-artifact output (`product-rfc.md` + `arch-rfc.md`); otherwise persist the branch RFC drafted in Step 6.

### Step 9: Return the Envelope

Return the structured envelope per **Section D** from `skills/_shared/sdd-phase-common.md`:

- `status`: `success` (branch RFC approved) | `partial` (interview cut early, needs revisiting) | `blocked` (rejected)
- `executive_summary`: what the branch RFC resolved and the user's approval state
- `artifacts`: the quest artifact locator (branch + `## Approval:` header)
- `branch`: `product` | `architecture`
- `approval`: `approved` | `needs-changes` | `rejected`
- `next_recommended`: gate 1 `approved` → `architecture-quest`; gate 2 `approved` → `rfc-author`; otherwise `quest` (re-run the affected branch only) or `none`
- `risks`: any unresolved questions / risks
- `skill_resolution`: from Section A

## Rules

- **NEVER exceed the active branch's hard budget:** Product Quest = 50, Architecture Quest = 20. Exhaustion stops that branch with a report.
- **NEVER ask more than one question at a time.** This is branch-following, not batching.
- **NEVER auto-approve.** Each branch has its own explicit RFC gate; approval is a separate, explicit act by the user (non-goal: do not approve decisions on the user's behalf).
- **`needs-changes` reopens ONLY the affected branch**, within its remaining budget; the other branch is never touched by the rejection.
- **NEVER drag the stack into either RFC** unless the user confirms the stack choice as a requirement.
- **Run BEFORE exploration.** Do not read the codebase during the interviews; facts come from the user, with single bounded environment lookups delegated to a sub-agent only when necessary.
- The **approved RFCs are the binding mandate for explore and the binding source of truth** for `sdd-propose` AND `sdd-spec` — not merely a recommendation.
- Ask the user directly via the host's question primitive. Do NOT delegate your interview to a sub-agent.
- Keep the interview moving: after each answer, ask the NEXT question without pausing for a "continue" confirmation. Do not end the turn waiting for the user to say "continúa"/"go on" between questions. The interviews only pause for the user's explicit go-ahead at the two RFC gates (Step 7).
- If the user stops early, STOP and persist `rejected` or `needs-changes` for the active branch — never force a full session.
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
