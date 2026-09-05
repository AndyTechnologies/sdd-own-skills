<!-- sdd-own:cmd-sdd-ff-quest-support:start -->
**SDD-own personalization — quest + support phases in fast-forward.** Replace the "Planning phases:" list of the WORKFLOW above with this version:

1. Run the quest (RFC pre-pass) first when needed — same rule as `/sdd-continue` QUEST-CONDITIONAL: load the `sdd-quest` skill via your Skill tool and interview the user one focused question at a time with your `question` tool (≤50 budget); the `sdd-rfc-author` sub-agent only drafts the canonical RFC from collected Q&A after `## Approval: approved`. Skip if a quest artifact already exists with `## Approval: approved`; re-open affected branches on `needs-changes`; STOP on `rejected`.
2. sdd-explore — investigate the codebase consuming the approved RFC as its mandate (skip only if an exploration already exists).
3. sdd-propose — create the proposal from the approved RFC + exploration.
4. sdd-spec — write specifications.
5. sdd-design — create technical design.
6. sdd-architecture-lint — independently review the design when it touches architecture boundaries (new layers, ports/adapters, dependency injection, module boundaries, external access); register `N/A` and skip for local boundary-free changes.
7. sdd-tasks — break down into implementation tasks.

The quest and the lint are SUPPORT hooks: they never join `nextRecommended` and never alter it; detection is by artifact presence/state, exactly as in `/sdd-continue`. Delegate phase and support work only to dedicated sub-agents (never run support phases inline). In `interactive` mode, pause after each phase and ask before the next; in `auto` mode, run the fast-forward back-to-back with the organic hooks applied.
<!-- sdd-own:cmd-sdd-ff-quest-support:end -->
