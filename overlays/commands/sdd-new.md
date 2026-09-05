<!-- sdd-own:cmd-sdd-new-quest:start -->
**SDD-own personalization — quest pre-pass.** The quest (RFC pre-pass) interview runs BEFORE exploration. Replace the WORKFLOW step list above with this version:

1. Run the quest (RFC pre-pass) interview yourself as the orchestrator: load the `sdd-quest` skill via your Skill tool and interview the user ONE focused question at a time with your `question` tool (you are the only role with the interactive human channel in OpenCode — a `task()` sub-agent cannot sustain the live interview). Keep asking consecutive questions without pausing for a "continue"; do not delegate the interview to the `sdd-rfc-author` sub-agent. Build the RFC and require explicit user approval (`## Approval: approved`) before continuing. After the user approves (`## Approval: approved`), delegate the collected Q&A to the `sdd-rfc-author` sub-agent (task tool) to draft the final canonical RFC for persistence as the binding mandate; then proceed to exploration.
   - If the quest returns `approved` → the RFC is the binding mandate for exploration. Proceed to step 2.
   - If `needs-changes` → re-run the interview on the affected branches until approved or rejected.
   - If `rejected` → STOP; do not explore or propose.
2. Launch sdd-explore sub-agent to investigate the codebase, consuming the approved quest/RFC as its mandate (what to validate/resolve).
3. Present the exploration summary to the user.
4. Launch sdd-propose sub-agent to create a proposal based on the approved RFC + exploration.
5. Present the proposal summary and ask the user if they want to continue with specs and design.

HARD GATE stays: do not launch quest, exploration, or proposal in the same turn when the session preflight is missing.
<!-- sdd-own:cmd-sdd-new-quest:end -->