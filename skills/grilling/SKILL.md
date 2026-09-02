---
name: grilling
description: "Grill the user with one focused question at a time about a plan, decision, or idea, within a hard 50-question budget. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases. User-invoked only — never invoked by a model automatically."
disable-model-invocation: true
---

# Grilling — Bounded Interview Primitive

Interview the user to reach shared understanding, mapped as a **decision tree**: every decision branches into the decisions that hang off it. The interview is **bounded** (hard 50-question budget) and **branch-following**: you ask exactly ONE focused question at a time and follow each answer until its branch is resolved before moving on.

## Hard constraints (non-negotiable)

1. **Hard question budget = 50.** You MUST NOT ask more than 50 questions in one grilling session.
2. **One question at a time.** Ask exactly ONE focused question, wait for the answer, follow it until that decision branch resolves, THEN ask the next question. Never batch multiple frontier questions into one prompt.
3. **Plan before you ask.** Spend the first step designing the question path so the highest-impact decisions come first and the budget is never wasted on trivia.
4. **User-invoked only.** Never trigger yourself into a grilling loop; only act when the human starts the grilling.

## Step 1 — Design the question path (before asking anything)

Build the decision tree, then budget the path across it:

1. Enumerate every decision branch you can see in the plan/design.
2. Rank branches by **impact × uncertainty**: the branches that most change scope, architecture, or effort — and that you cannot infer — come first.
3. Assign each branch a question count. **Sum must be ≤ 50.** If the tree needs more than 50 questions, consolidate: merge related decisions into single questions, and drop or defer the lowest-impact branches.
4. Respect dependency ordering: a question whose answer depends on another question still open belongs LATER in the path, never ahead of its prerequisite.
5. Finding **facts** is your job, never the user's. When a question needs a fact from the environment (filesystem, tools), dispatch a sub-agent to find it; don't ask the user for anything you could look up. Don't block on it — a running exploration is an unsettled prerequisite only for the questions downstream of it.
6. **Do not drag the stack/language/framework into the interview unless the user confirms it as a requirement.** Frame questions around behavior, inputs, outputs, events, invariants, and domain contracts — not around "which framework" or "which language". If a stack decision genuinely matters, treat it as a decision the user must confirm, never one you assume or pull in from the repo.

## Step 2 — Run the interview, one question at a time

Walk the tree branch by branch. The **current question** is the highest-priority unresolved branch whose prerequisites are all settled. Ask exactly ONE question:

```
❓ **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Then STOP and wait for the user's answer. Follow that answer down its branch — if it opens sub-decisions, resolve them next, still one at a time, before returning to the rest of the tree. Recompute the priority of remaining branches after every answer.

Never ask two questions in the same turn. Never advance to a new branch until the current one is resolved. Watch the budget: allocate so future questions stay within the **remaining** budget. Once you reach 50 questions asked, **stop asking. Do not exceed the budget.**

## Step 3 — Consolidate and hand off

The session reaches shared understanding when:
- every branch is resolved, **OR**
- you have used all 50 questions (budget exhausted).

If the budget is exhausted before the tree is empty:
1. **Consolidate** what you covered into a clear shared-understanding summary.
2. **List the pending/uncovered branches** explicitly as follow-ups, so nothing is silently assumed.
3. Present the consolidated summary **and any unresolved questions that block implementation** to the user, and ask explicit acceptance before proceeding.

**Do not act on the plan until the user explicitly approves it.** A confirmed frontier is not the same as user approval — approval is a separate, explicit act by the human. If you hit the budget and the user wants to continue, that is a NEW grilling session with a fresh 50-question budget — never a silent extension of the current one.
