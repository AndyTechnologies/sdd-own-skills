---
description: Start a new SDD change — runs the quest (RFC pre-pass), then exploration, then creates a proposal
agent: gentle-orchestrator
---

Follow the SDD orchestrator workflow for starting a new change named "$ARGUMENTS".

HARD GATE:
SDD Session Preflight must already be complete for this session. It must include execution mode, artifact store, chained PR strategy, and review budget. If missing, ask the exact orchestrator preflight prompt and STOP. Do not launch quest, exploration, or proposal in the same turn.

WORKFLOW:

1. Launch sdd-quest sub-agent FIRST to run the RFC interview (the pre-pass) against the user. It produces the RFC and requires explicit user approval (`## Approval: approved`) before continuing.
   - If the quest returns `approved` → the RFC is the binding mandate for exploration. Proceed to step 2.
   - If `needs-changes` → re-run quest until approved or rejected.
   - If `rejected` → STOP; do not explore or propose.
2. Launch sdd-explore sub-agent to investigate the codebase, consuming the approved quest/RFC as its mandate (what to validate/resolve).
3. Present the exploration summary to the user.
4. Launch sdd-propose sub-agent to create a proposal based on the approved RFC + exploration.
5. Present the proposal summary and ask the user if they want to continue with specs and design.

CONTEXT:

- Working directory: before doing anything else, run `git rev-parse --show-toplevel 2>/dev/null || pwd` with your bash tool and use the returned path as the authoritative workspace. In OpenCode Desktop (Electron) the parse-time interpolation resolves to the app data directory, not the project.
- Current project: the `basename` of the detected workspace above.
- Change name: $ARGUMENTS
- Execution mode: ask/cache per orchestrator
- Artifact store mode: ask/cache per orchestrator; do not hardcode Engram
- Delivery strategy: ask/cache per orchestrator
- Review budget: ask/cache per orchestrator

ENGRAM NOTE:
Sub-agents handle persistence automatically using the selected artifact store. In engram/hybrid, each phase saves with topic_key "sdd/$ARGUMENTS/{type}".

Read the orchestrator instructions to coordinate this workflow. Do NOT execute phase work inline — delegate to sub-agents.
