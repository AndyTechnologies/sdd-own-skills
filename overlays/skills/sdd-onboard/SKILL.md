<!-- sdd-own:sdd-onboard-quest-phase:start -->
**SDD-own personalization — quest pre-pass.** The personalized pipeline runs the quest (RFC pre-pass) BEFORE exploration. Apply the following to the phased flow above.

## Purpose

The cycle runs from **quest** to archive, not from exploration.

## Phase 2 — Quest / RFC pre-pass (narrated) — inserted BEFORE exploration

Interview the user one focused question at a time (following the `sdd-quest` skill) to build a language-agnostic RFC:

```
"Step 1: Quest — Before we explore anything, I'll interview you one question
 at a time to pin down WHAT we're really solving, in neutral terms."
```

Build the RFC from their answers, then require their explicit approval before proceeding:

```
"Here's the RFC I drafted from your answers. Please review it — approve it
 to make it the binding mandate for everything that follows, or I'll adjust."
```

Only if the user gives explicit approval (`## Approval: approved`) do you continue. The approved RFC is the binding mandate for exploration.

## Exploration happens AFTER the approved RFC

When narrating exploration, the step numbers shift by one and exploration VALIDATES the approved RFC:

```
"Step 2: Explore — Given the approved RFC, let me check the real code to see
 whether it can be built here. Before we commit, we investigate.
 Let me look at the relevant code..."
```

Run `sdd-explore` behavior inline — validate the approved RFC against the chosen area, understand current state, identify what needs to change. Explain your findings to the user in plain language. If the RFC can't be built as-is, flag it to the orchestrator (returning the quest to `needs-changes`) rather than proceeding silently.

## Subsequent phases shift by one step

Propose → Step 3, Specs → Step 4, Design → Step 5, Tasks → Step 6, Apply → Step 7, Verify → Step 8, Archive → Step 9; the final summary becomes Phase 11. Ask before continuing past the proposal phase (Step 3 / Phase 4).

## Summary additions

- **Artifacts created**: add `quest.md / RFC — the approved mandate`.
- **The SDD cycle in one line**: `quest → explore → propose → spec → design → tasks → apply → verify → archive`.
- **Format rules list**: also follow `sdd-quest`.
<!-- sdd-own:sdd-onboard-quest-phase:end -->