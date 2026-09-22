---
name: architecture-quest
description: "Architecture question phase — the RFC pre-pass (architecture branch). Bounded RFC interview AFTER exploration AND the approved product RFC, one question at a time, hard budget 20, then rfc-author assembles arch-rfc.md and an explicit architecture RFC gate is presented on the assembled artifact; on approval the architecture RFC binds the change task doc odd/tasks/<feature>.md and downstream phases. Runs when the request involves product/feature work or needs architectural decisions, or the user explicitly requests architecture work."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "4.2"
  delegate_only: true  # intentional: quest is orchestrator-inline; excluded from registry autocomplete by design
---

## Execution Role

Confirm your role before acting. In OpenCode, **only the orchestrator holds the interactive human channel** (the `question` tool permission); a `task()` sub-agent returns a single final result and cannot sustain a live one-question-at-a-time interview. Therefore the ARCHITECTURE QUEST interview is always performed by whoever holds that channel.

- **If you are the orchestrator** (you loaded this skill through the `skill()` tool): you PERFORM the interview yourself. Do NOT delegate the interview to the `rfc-author` sub-agent — it cannot talk to the human in OpenCode. Proceed with the phase work below, asking the user one focused question at a time via your `question` tool.
- **If you are the `rfc-author` sub-agent**: you do NOT interview the human. You are the RFC author: you receive the user's answers (Q&A pairs) collected by the orchestrator for the architecture branch, assemble them into `arch-rfc.md`, and return the assembled RFC back to the orchestrator for the approval gate. Do not call the Skill tool or another orchestrator command.

> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

You are responsible for the **ARCHITECTURE QUEST** phase (the architecture branch of the RFC pre-pass): a bounded RFC interview with the human user about the architecture and technical design decisions, run **after** exploration AND the **approved product RFC**. It does NOT run for mechanical or documentation-only changes (the orchestrator skips both quests at its discretion). In OpenCode the interviewer is the orchestrator (the only role with the `question` channel); the `rfc-author` sub-agent, when launched, is the RFC author that shapes the collected answers into `arch-rfc.md`.

Your job:
1. Interview the user **one focused question at a time** to discover and pin the architecture, structure, and technical context decisions (never invent architecture decisions), within the **hard budget of 20**.
2. Hand the collected Q&A to `rfc-author` so it assembles a **language-agnostic, structured architecture RFC** that describes structure and contracts — NOT an implementation or a premature stack choice.
3. Present the assembled architecture RFC for **explicit user approval** at the architecture RFC gate. `needs-changes` reopens the architecture branch only, within its remaining budget.
4. Mark the **approved architecture RFC as binding** — the architecture source of truth the change's task doc (`odd/tasks/<feature>.md`) and downstream phases (architecture-plan, apply, lint) must trace to.

The architecture quest runs on top of the **approved product RFC**: the interview starts from the product RFC's goals/contracts plus the change's problem statement and the exploration findings. Do not re-explore the codebase yourself — exploration and the product quest already produced the inputs. This is one of the two quest phases that talk to the human (the other is the product quest). Every other phase is a silent executor. The RFC discipline separates "a handoff of decisions" from "an RFC that describes structure without choosing a language/framework".

## What You Receive

From the orchestrator:
- The change/problem statement (from `$ARGUMENTS`) — the Architecture branch's starting point
- The **approved Product RFC** (`product-rfc.md`) — REQUIRED input; the architecture interview builds on its goals and contracts
- The **exploration summary / explore findings** — the evidence base the interview builds on (the interview consumes them; it does NOT re-explore the codebase)
- The branch being interviewed (`architecture` in this skill) — the orchestrator performs the architecture branch behind its own RFC gate, only when architectural decisions are in play or the user explicitly requests architecture work
- Change name
- The branch's hard question budget: **Architecture Quest = 20** (never exceed it)

## Hard constraints

1. **Hard question budget.** Architecture Quest = **20**. Never exceed it; exhaustion stops the branch with a report, never silently extends.
2. **Approved Product RFC precondition.** The architecture branch interviews ONLY after the product RFC is approved. If the product RFC is missing or not yet approved, **STOP and report `blocked`** — do not interview the architecture branch first.
3. **One explicit RFC gate, post-assembly.** The architecture RFC gate is presented ONCE, on the RFC that `rfc-author` assembled from the collected Q&A. The RFC is not approved by an empty frontier — the user must explicitly approve it. Never auto-approve on the human's behalf.
4. **`needs-changes` reopens ONLY the architecture branch.** A gate rejection re-interviews the architecture branch within its REMAINING budget; no other branch is touched by this rejection.
5. **One question at a time.** Ask exactly ONE focused question; follow the answer until that branch resolves before the next. Never batch a frontier.
6. **Never invent missing decisions.** If something is unspecified, ASK — do not assume.
7. **No stack drag.** Do not pull the repo's language/framework/stack into the RFC unless the user explicitly confirms it as a requirement. Describe structure, boundaries, contracts, and invariants — not an implementation.
8. **Start from the product RFC + problem statement + exploration findings; stay out of the repo.** Do not re-explore the codebase during the interview. Facts about the user's architectural intention come from the user; facts you genuinely need from the environment are looked up for you by a sub-agent (see Step 4) — you do not dig into the codebase yourself.

## Loop guard

- Stop when every branch of the architecture decision tree is resolved **OR** the hard budget is spent (20).
- Tree empty or budget spent → hand the collected Q&A to `rfc-author` for assembly; the RFC gate follows on the assembled artifact.
- If the user asks you to stop early, STOP immediately and persist a `rejected`/`needs-changes` result — never force a full session.

## Execution and Persistence Contract

> Follow **Section B** (retrieval), **Section C** (persistence), and **Section D** (return envelope) from `skills/_shared/sdd-phase-common.md`.

Artifact: you persist a **quest artifact** containing the **architecture RFC** so downstream phases consume it (ODD-pure persistence — no sdd-era artifact branches):

- **File (always)**: write `odd/rfcs/<change-name>-arch-rfc.md` — the canonical RFC artifact, `## Approval:` header included.
- **engram (always)**: save as `odd/<change-name>/arch-rfc`, type `architecture`, `capture_prompt: false`, following Section C.
- **none**: if no backend is writable, return the handoff inline only and report it.

## What to Do

### Step 1: Load Skills

Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

The interview mechanics are INLINE in this skill — no external interview skill is loaded. The bounded, branch-following interview primitive is:

- ask **exactly ONE focused question** at a time (never a batch),
- follow the answer down its branch until resolved, then ask the next,
- provide a **recommended answer** with each question (a synthesis of the product RFC + your domain reasoning), pending the user's correction,
- keep a running question count against the branch budget (**Architecture Quest = 20**; exhaustion stops the branch with a report, never silently extends),
- stop-and-wait after each question: one question per turn, answer received, next question — the interview only pauses for the user's explicit go-ahead at the RFC gate (Step 7).

> **Runtime note (OpenCode):** the interviewer is the orchestrator. If you are the orchestrator and loaded this skill via `skill()`, run Steps 2–5 yourself against the user with your `question` tool. When the interview resolves, launch the `rfc-author` sub-agent with the collected Q&A (Step 6), then present the assembled RFC at the gate (Step 7).

### Step 2: Verify the Product RFC Precondition

Confirm the **product RFC exists AND is approved**. If the product RFC is missing or not yet approved, **STOP and report `blocked`** — the architecture branch never interviews ahead of the product branch. That report is the phase result; the orchestrator re-runs the product branch first.

### Step 3: Establish the Problem Statement

You receive the change/problem statement, the approved product RFC, AND the exploration findings. If the architecture intent is still vague, make resolving it your **first branch** (within the 20 budget). Never interview in a vacuum — the approved product RFC and the user's intent fill it. Do NOT let any stack detail the user mentions bleed into the RFC (see Constraint #7).

### Step 4: Plan the Question Path (branch budget ≤ 20)

Before asking anything, enumerate the open decision branches **from the problem statement, the approved product RFC, the user intent, AND the exploration findings**, rank by impact × uncertainty, and allocate questions so the running total never exceeds the branch's budget (20). Provide your recommended answer per question (a synthesis of the product RFC and your domain reasoning), pending the user's correction.

The **Architecture branch** covers, when applicable: system decomposition and boundaries, modules/structure and responsibilities, data/schema and its invariants, interfaces/contracts between boundaries, external integrations and dependencies, deployment/configuration aspects, security/privacy/performance implications of the structure, failure isolation and recoverability, architecture alternatives and trade-offs, migration/compatibility concerns, unresolved questions.

### Step 5: Run the Interview — one question at a time

Ask exactly ONE question, wait for the answer, follow it down its branch until resolved, then ask the next. Guard: finding facts is your job, never the user's. The primary sources of facts are the **exploration findings, the approved product RFC**, and the **user's stated architectural intent and domain knowledge**. During the interview you do not read the codebase yourself; if a question truly requires a fact from the environment (a repo, a tool, an API), delegate a single bounded lookup to a sub-agent and do not block the interview on it — record it as a fact for the RFC once resolved. Do not turn the interview into an exploration pass.

> **Flow discipline (CRITICAL):** the interview is a **continuous stream** driven by the agent holding the `question` channel. After the user answers a question, ask the NEXT question immediately in the same flow — do NOT pause to ask "shall I continue?", do NOT end the turn to wait for a "continúa"/"go on" prompt, and do NOT re-confirm before each new question. Keep asking one after another until the branch tree is empty or the 20-question budget is spent. The ONLY place you stop to get the user's explicit go-ahead is the RFC approval gate (Step 7). If you find yourself waiting on "continue", that is a bug — keep the interview moving.

### Step 6: Stop at the Branch Budget or Empty Tree

- Tree empty → you have enough to hand the Q&A to `rfc-author` for assembly.
- Branch budget reached (Architecture 20) → consolidate covered branches, list pending ones explicitly under "Unresolved Questions", and request the user's explicit decision on how to proceed (draft partial RFC / another session). Never silently extend.

### Step 7: Hand the Q&A to rfc-author for Assembly

Delegate the collected Q&A for the architecture branch to the `rfc-author` sub-agent (via the orchestrator's `task()` primitive). It assembles the canonical `arch-rfc.md` using the fixed architecture schema below and returns it to the orchestrator. You do NOT draft the final RFC yourself; you present the assembled artifact at the gate.

**The fixed architecture schema** (what rfc-author fills, and what you present):

```markdown
# Architecture Quest: {change-name}

## Approval: pending | approved | needs-changes | rejected

## RFC

### System Decomposition & Boundaries

### Modules / Structure & Responsibilities

### Data & Invariants

### Interfaces & Contracts

### External Integrations & Dependencies

### Deployment & Configuration

### Security / Privacy / Performance Implications

### Failure Isolation & Recoverability

### Architecture Alternatives & Trade-offs

### Migration / Compatibility

### Unresolved Questions (blocking)
```

- The RFC describes **structure and contracts**, not language/framework. No stack unless the user explicitly confirmed it as a requirement (then note it as a confirmed requirement).
- **Binding mandate**: the approved architecture RFC is the binding architecture source of truth for the change's task doc (`odd/tasks/<feature>.md`) and downstream phases (architecture-plan, apply, lint) — not just "recommended scope".

### Step 8: The architecture RFC gate (on the assembled artifact)

Present the assembled `arch-rfc.md` to the user and ask for EXPLICIT approval. The gate runs on the artifact rfc-author produced (post-assembly, decision 5). Do NOT auto-approve because the tree is empty.

- **RFC gate — Architecture RFC:** `approved` → set `Approval: approved`, persist the artifact; the RFC then binds the task doc and downstream phases. `needs-changes` → re-interview ONLY the architecture branch within its REMAINING budget, re-assemble via rfc-author, re-present, re-ask. `rejected` → set `Approval: rejected`, persist, STOP (no downstream phases consume the architecture RFC).

### Step 9: Persist the Quest Artifact

Persist per the Persistence Contract with the `## Approval:` header and the branch's full RFC schema. The `Approval:` value is the ONLY gate the routing uses to decide re-run vs skip vs proceed. **This is MANDATORY** when tied to a named change — do not skip it.

- Persist `odd/rfcs/<change-name>-arch-rfc.md` + engram `odd/<change-name>/arch-rfc`.

### Step 10: Return the Envelope

Return the structured envelope per **Section D** from `skills/_shared/sdd-phase-common.md`:

- `status`: `success` (branch RFC approved) | `partial` (interview cut early, needs revisiting) | `blocked` (product RFC missing/not approved, or rejected)
- `executive_summary`: what the branch RFC resolved and the user's approval state
- `artifacts`: the quest artifact locator (branch + `## Approval:` header)
- `branch`: `architecture`
- `approval`: `approved` | `needs-changes` | `rejected`
- `next_recommended`: gate `approved` → `architecture-plan` only when the change is substantial/large and needs deeper planning (the plan consumes the approved RFCs + exploration findings + the task doc and integrates its acta INTO the task doc); otherwise `apply`/native flow (the RFCs bind the task doc directly). Otherwise `quest` (re-run the architecture branch only) or `none`
- `risks`: any unresolved questions / risks
- `skill_resolution`: from Section A

## Rules

- **NEVER exceed the hard budget:** Architecture Quest = 20. Exhaustion stops the branch with a report.
- **NEVER ask more than one question at a time.** This is branch-following, not batching.
- **NEVER auto-approve.** The branch has its own explicit RFC gate on the assembled artifact; approval is a separate, explicit act by the user (non-goal: do not approve decisions on the user's behalf).
- **`needs-changes` reopens ONLY the architecture branch**, within its remaining budget; no other branch is touched by the rejection.
- **NEVER drag the stack into the RFC** unless the user confirms the stack choice as a requirement.
- **STOP and report `blocked`** when the product RFC is missing or not yet approved — never interview the architecture branch ahead of the product branch.
- **Start AFTER exploration, on top of the approved product RFC, from the findings.** Do not read the codebase during the interview; facts come from the exploration findings, the approved product RFC, and the user, with single bounded environment lookups delegated to a sub-agent only when necessary.
- The **approved architecture RFC is the binding architecture source of truth** for the change's task doc (`odd/tasks/<feature>.md`) and every downstream phase — not merely a recommendation.
- Ask the user directly via the host's question primitive. Do NOT delegate your interview to a sub-agent.
- Keep the interview moving: after each answer, ask the NEXT question without pausing for a "continue" confirmation. Do not end the turn waiting for the user to say "continúa"/"go on" between questions. The interview only pauses for the user's explicit go-ahead at the RFC gate (Step 8).
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