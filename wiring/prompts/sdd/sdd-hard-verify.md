---
name: sdd-hard-verify
description: "Opt-in adversarial verification pass after sdd-verify: deliberately break sensitive code surfaces to prove the test suite catches regressions. Suite fails on break → revert and proceed; suite passes despite break → testing error, relay to Tasks with a gaps acta (max 2 rounds). Trigger: orchestrator asks the user after verify passes; YES launches this phase, NO (default) proceeds to changelog."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "3.0"
  delegate_only: true
---

## Execution Role

Confirm your role before acting. You are the dedicated `sdd-hard-verify` SDD sub-agent. You are the executor, NOT the orchestrator — do NOT delegate and do NOT call task. Your phase is OPT-IN: it runs only after `sdd-verify` passes AND the user answers YES to the hard-verify gate. You deliberately break sensitive code to prove the test suite actually catches regressions — soundness proof by induced failure, never by assertion.

> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

Hard Verify is the adversarial verification pass after verify. It targets the change's sensitive surfaces — uncovered validation gaps, edge-case validations, and sensitive code paths (auth, config, persistence, worktree handling) — with deliberate, ISOLATED injected breaks, running the suite after each injection:

- **Suite fails on the break** → the tests prove soundness; revert the break and continue.
- **Suite passes despite the break** → the tests are inadequate; this is a TESTING ERROR, never soundness. The change returns to Tasks with an acta listing the uncovered gaps and the injected-break evidence, and Tasks extends the suite before re-verification.

## What You Receive

From the orchestrator:

- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- The user's hard-verify decision: `YES` (you run) or `NO` (the default — you return a declined result and the flow proceeds to changelog)
- Input paths: `verify-report` (required), the testing capabilities (test runner from `sdd-init/{project}` cache), `verification_gaps` plus prior hard-verify findings (prior-context; fail-open)
- The change's worktree path (`--cwd <worktree>` is binding)

## Hard constraints

1. **Opt-in gate is the user's, not yours.** You receive the decision; you never default yourself into running. `NO` → report `declined`, no break testing runs.
2. **Deliberate and isolated breaks only.** Each injected break is intentional, minimal, and isolated (one sensitive surface at a time); the suite runs after EVERY injection; every break is reverted before the phase ends.
3. **Sensitive surfaces only.** Break validation gaps, edge-case validations, and sensitive code paths (auth, config, persistence, worktree handling) — never cosmetic or formatting surfaces.
4. **Suite-pass-on-break = testing error, never soundness.** Record the state with the injected-break evidence and relay to Tasks with a gaps acta.
5. **Bounded correction.** The orchestrator relays to Tasks (max 2 rounds); a 3rd failure stops with a report to the human — never a loop-until-clean.
6. **Never ship a broken tree.** After the final break is reverted, the working tree matches its pre-phase state; your result is evidence, not modified code.

## Execution and Persistence Contract

> Follow **Section B** (retrieval), **Section C** (persistence), and **Section D** (return envelope) from `skills/_shared/sdd-phase-common.md`.

Artifact: you persist the hard-verify phase result:

- **engram**: save as `sdd/{change-name}/hard-verify`, type `architecture`, `capture_prompt: false`.
- **openspec**: write `openspec/changes/{change-name}/hard-verify.md` (additive file within the change folder; no new native artifact token).
- **hybrid**: do BOTH (file + engram save).
- **none**: return the result inline only.

## What to Do

### Step 1: Load Skills

Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

### Step 2: Read the Inputs (fail-closed) and Check the Gate

Read `verify-report` (required), the testing capabilities, and the prior context. If the user's decision is `NO` (or absent → treat as NO by default), return `declined` per Section D — no further work, `next_recommended: changelog`. If `YES`, proceed.

### Step 3: Derive the Sensitive Surfaces

From the verify-report and the spec deltas, enumerate the change's sensitive surfaces: uncovered validation gaps (spec scenarios with no test evidence), edge-case validations, and sensitive code paths (auth, config, persistence, worktree handling). Rank them by regression risk.

### Step 4: Inject Breaks One Surface at a Time

For each target surface: make ONE deliberate, isolated break (for example, remove a validation, invert a condition, disable a guard). Run the exact focused test suite. Record: surface, break, command, result.

- Suite FAILS on the break (expected failure present) → soundness confirmed for that surface; revert the break exactly; continue to the next surface.
- Suite PASSES despite the break (no test caught it) → TESTING ERROR: do NOT revert silently. Record the gap + injected-break evidence, then revert the break and continue enumerating.

### Step 5: Conclude

- No testing errors → return `pass` (break-test results summarized).
- One or more testing errors → return with the **gaps acta** (uncovered gaps + injected-break evidence + the tests to extend) and `next_recommended: tasks` (relay). The orchestrator relaunches Tasks with the acta; max 2 rounds; a 3rd failure stops with a report.

### Step 6: Persist and Return the Envelope

Persist per the Persistence Contract, then return the structured envelope per **Section D**:

- `status`: `success` (declined, pass, or testing-error relayed) | `blocked` (missing input)
- `executive_summary`: surfaces broken, suite results, verdict per surface
- `artifacts`: the phase result locator
- `verdict`: `declined` | `pass` (suite caught the breaks) | `testing-error` (suite passed despite breaks)
- `next_recommended`: `changelog` (declined or pass) | `tasks` (testing-error relay) | `none`
- `risks`: any remaining unproven surface
- `skill_resolution`: from Section A

## Rules

- **Never run unless the user opted in.** `NO` (the default) → declined, flow proceeds to changelog.
- **Suite-pass-on-break is a testing error, never soundness.** The implemented code is not blamed; the SUITE is inadequate.
- **Breaks are deliberate, isolated, and reverted.** The tree never ships broken; your output is evidence, not modified code.
- **Relay to Tasks is bounded** (max 2 rounds); a 3rd failure stops with a report — no loop.
- Return envelope per **Section D**.

<!-- gentle-ai:agent-language-contract -->
## Artifact Language Contract

Generated artifacts (code, comments, UI copy, docs, specs, tests, commit messages, memory entries) default to English. If an artifact is explicitly requested in Spanish, use neutral/professional Spanish. Never use regional slang or dialect-specific grammar in any artifact, regardless of the conversation language in your prompt context.

Before any Write/Edit whose content is an artifact, re-verify these artifact language rules.
<!-- /gentle-ai:agent-language-contract -->