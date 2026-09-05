<!-- sdd-own:shared-language-domain-contract:start -->
## Language Domain Contract

Generated technical artifacts default to English. Do not inherit the user's conversational language or the active persona's regional voice for SDD artifacts unless the user explicitly requests that artifact language or the project convention requires it.

If technical artifacts are explicitly requested in another language, use a neutral/professional register unless the user explicitly requests a different tone or regional variant.

Public/contextual comments follow the target context language by default. Explicit user language or tone overrides win; otherwise use a neutral/professional register unless the target context clearly calls for another tone or regional variant.
<!-- sdd-own:shared-language-domain-contract:end -->

<!-- sdd-own:shared-quest-explore-contract:start -->
### Quest↔Explore contract (quest runs BEFORE explore)

The quest (RFC pre-pass) is the first SDD phase and runs before exploration. Its output is the `quest`/RFC artifact with an `## Approval:` gate.

- **The approved quest/RFC is the mandate for `sdd-explore`.** The explore phase consumes `sdd/{change}/quest` (engram) or `openspec/changes/{change}/quest.md` (openspec) and validates/resolves the RFC's behavior, contracts, invariants, and acceptance criteria against the real codebase. Explore answers "can the approved RFC be built here?" — it does not re-derive scope.
- **Explore must read the FULL quest artifact via `mem_get_observation`**, never a search preview (same rule as Section B).
- **If explore discovers that the approved RFC is not implementable as-is** (a stated goal/contract/invariant conflicts with existing code, a non-goal is already satisfied, an acceptance criterion is infeasible), it must NOT silently proceed to propose. It flags the conflict to the orchestrator, which returns the quest to `needs-changes` — re-opening the interview on only the affected branches (preserving the remaining 50-question budget). An RFC approved before explore is never frozen against later contradictory findings.
- **The proposal is built from BOTH the approved RFC and the exploration.** `sdd-propose` and `sdd-spec` consume the quest as binding source of truth, with the exploration supplying technical grounding.
<!-- sdd-own:shared-quest-explore-contract:end -->