<!-- sdd-own:sdd-explore-quest-validate:start -->
**SDD-own personalization — quest flow + regressive impact.** This block extends the sections above; where it restates a line, it is the authoritative version for the personalized pipeline.

## Purpose — quest validation

Explore VALIDATES the approved quest/RFC against the real codebase — it answers "can the approved RFC be built here?" and does not re-derive scope. If the approved RFC is not implementable as-is, flag it to the orchestrator (which returns the quest to `needs-changes`) instead of silently proceeding to propose.

## What You Receive — additional required input

- The approved quest/RFC (the binding mandate), or an explicit statement that it must be retrieved

## Retrieval additions (Section B)

- **engram**: also read the approved quest: `mem_search(query: "sdd/{change-name}/quest", project: "{project}")` → `mem_get_observation(id)` — ALWAYS read the FULL artifact, never the preview.
- **openspec**: also read the approved quest at `openspec/changes/{change-name}/quest.md`.

## Step 3a: Map Regressive Impact (## Impact)

Beyond "can the approved RFC be built here?", identify **what existing behavior the change could break or disturb**. This makes the impact analysis a natural part of the same single `explore` pass — it is NOT a separate phase.

- Inventory the existing **features, tests, contracts, and public interfaces** in the affected area that the change would touch.
- For each, note the **regression risk**: would the change alter, remove, or break it?
- Note any **existing tests that must keep passing** (they are the regression net).
- Keep it scoped to the affected area of the RFC — do not analyze unrelated regions.

**Organic opt-out (greenfield / additive-only):** if the RFC only ADDs new isolated behavior with no modification or removal of existing behavior, set `## Impact` to `None` (or `N/A — no existing behavior is disturbed`) and do NOT manufacture regression risk. Impact analysis matters only when the change MODIFIES or REMOVES existing behavior.

## Exploration template — add after "Affected Areas"

### Impact

{Regressive impact from Step 3a: the existing features/tests/contracts the change would touch and their regression risk.
Or `None`/`N/A — no existing behavior is disturbed` for greenfield/additive-only changes.}

## Guidelines addition

- Include the `## Impact` section (Step 3a): regressive impact when the change touches existing behavior, or `None` for greenfield/additive-only — never manufacture regression risk
<!-- sdd-own:sdd-explore-quest-validate:end -->