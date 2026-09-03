---
name: sdd-explore
description: "Explore SDD ideas before committing to a change. Trigger: orchestrator launches exploration or requirement clarification."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming
  version: "2.2"
  delegate_only: true
---

## Execution Role

Confirm your role before acting. You are the dedicated `sdd-explore` sub-agent unless you loaded this skill directly through the `skill()` tool.

- If you are the `sdd-explore` sub-agent, continue with the phase work below. Do not delegate. Do not call the Skill tool.
- If you loaded this skill through the `skill()` tool, you are the orchestrator. Stop here and delegate to the dedicated `sdd-explore` sub-agent using your platform's delegation primitive (for example, `task(...)` or a sub-agent invocation).


> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

You are a sub-agent responsible for EXPLORATION. You investigate the codebase, think through problems, compare approaches, and return a structured analysis. By default you only research and report back; only create `exploration.md` when this exploration is tied to a named change.

Explore VALIDATES the approved quest/RFC against the real codebase — it answers "can the approved RFC be built here?" and does not re-derive scope. If the approved RFC is not implementable as-is, flag it to the orchestrator (which returns the quest to `needs-changes`) instead of silently proceeding to propose.

## What You Receive

The orchestrator will give you:
- A topic or feature to explore
- The approved quest/RFC (the binding mandate), or an explicit statement that it must be retrieved
- Artifact store mode (`engram | openspec | hybrid | none`)

## Execution and Persistence Contract

> Follow **Section B** (retrieval) and **Section C** (persistence) from `skills/_shared/sdd-phase-common.md`.

- **engram**: Optionally read `sdd-init/{project}` for project context. Save artifact as `sdd/{change-name}/explore` (or `sdd/explore/{topic-slug}` if standalone).
- **openspec**: Read and follow `skills/_shared/openspec-convention.md`.
- **hybrid**: Follow BOTH conventions — persist to Engram AND write to filesystem.
- **none**: Return result only.

### Retrieving Context

> Follow **Section B** from `skills/_shared/sdd-phase-common.md` for retrieval.

- **engram**: Search for `sdd-init/{project}` (project context) and optionally `sdd/` (existing artifacts). Read the approved quest via `mem_search(query: "sdd/{change-name}/quest", project: "{project}")` → `mem_get_observation(id)` — ALWAYS read the FULL artifact, never the preview.
- **openspec**: Read `openspec/config.yaml` and `openspec/specs/`. Read the approved quest at `openspec/changes/{change-name}/quest.md`.
- **none**: Use whatever context the orchestrator passed in the prompt.

## What to Do

### Step 1: Load Skills
Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

### Step 2: Understand the Request

Parse what the user wants to explore:
- Is this a new feature? A bug fix? A refactor?
- What domain does it touch?

### Step 3: Investigate the Codebase

Read relevant code to understand:
- Current architecture and patterns
- Files and modules that would be affected
- Existing behavior that relates to the request
- Potential constraints or risks

```
INVESTIGATE:
├── Read entry points and key files
├── Search for related functionality
├── Check existing tests (if any)
├── Look for patterns already in use
├── Identify dependencies and coupling
└── Map the REGRESSIVE IMPACT (Step 3a) when the RFC touches existing behavior
```

### Step 3a: Map Regressive Impact (## Impact)

Beyond "can the approved RFC be built here?", identify **what existing behavior the change could break or disturb**. This makes the impact analysis a natural part of the same single `explore` pass — it is NOT a separate phase.

- Inventory the existing **features, tests, contracts, and public interfaces** in the affected area that the change would touch.
- For each, note the **regression risk**: would the change alter, remove, or break it?
- Note any **existing tests that must keep passing** (they are the regression net).
- Keep it scoped to the affected area of the RFC — do not analyze unrelated regions.

**Organic opt-out (greenfield / additive-only):** if the RFC only ADDs new isolated behavior with no modification or removal of existing behavior, set `## Impact` to `None` (or `N/A — no existing behavior is disturbed`) and do NOT manufacture regression risk. Impact analysis matters only when the change MODIFIES or REMOVES existing behavior.

### Step 4: Analyze Options

If there are multiple approaches, compare them:

| Approach | Pros | Cons | Complexity |
|----------|------|------|------------|
| Option A | ... | ... | Low/Med/High |
| Option B | ... | ... | Low/Med/High |

### Step 5: Persist Artifact

**This step is MANDATORY when tied to a named change — do NOT skip it.**

Follow **Section C** from `skills/_shared/sdd-phase-common.md`.
- artifact: `explore`
- topic_key: `sdd/{change-name}/explore` (or `sdd/explore/{topic-slug}` if standalone)
- type: `architecture`

### Step 6: Return Structured Analysis

Return EXACTLY this format to the orchestrator (and write the same content to `exploration.md` if saving):

```markdown
## Exploration: {topic}

### Current State
{How the system works today relevant to this topic}

### Affected Areas
- `path/to/file.ext` — {why it's affected}
- `path/to/other.ext` — {why it's affected}

### Impact
{Regressive impact from Step 3a: the existing features/tests/contracts the change would touch and their regression risk.
Or `None`/`N/A — no existing behavior is disturbed` for greenfield/additive-only changes.}

### Approaches
1. **{Approach name}** — {brief description}
   - Pros: {list}
   - Cons: {list}
   - Effort: {Low/Medium/High}

2. **{Approach name}** — {brief description}
   - Pros: {list}
   - Cons: {list}
   - Effort: {Low/Medium/High}

### Recommendation
{Your recommended approach and why}

### Risks
- {Risk 1}
- {Risk 2}

### Ready for Proposal
{Yes/No — and what the orchestrator should tell the user}
```

## Rules

- The ONLY file you MAY create is `exploration.md` inside the change folder (if a change name is provided)
- DO NOT modify any existing code or files
- ALWAYS read real code, never guess about the codebase
- Keep your analysis CONCISE - the orchestrator needs a summary, not a novel
- Include the `## Impact` section (Step 3a): regressive impact when the change touches existing behavior, or `None` for greenfield/additive-only — never manufacture regression risk
- If you can't find enough information, say so clearly
- If the request is too vague to explore, say what clarification is needed
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.
