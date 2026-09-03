---
description: Continue the next SDD phase in the dependency chain
agent: gentle-orchestrator
---

Follow the SDD orchestrator workflow to continue the active change.

HARD GATE:
SDD Session Preflight must already be complete for this session. It must include execution mode, artifact store, chained PR strategy, and review budget. If missing, ask the exact orchestrator preflight prompt and STOP. Do not launch the next phase in the same turn.

WORKFLOW:

1. If the `gentle-ai` binary is available, run `gentle-ai sdd-continue [change] --cwd <repo>` and treat its dispatcher/status output as authoritative — but only when the session artifact store is `openspec` or `hybrid`. When the session artifact store is `engram`, do NOT invoke the native dispatcher at all — it cannot see the change (it reads only `openspec/changes/`); resolve status entirely from Engram (`mem_search` + `mem_get_observation` on the change's topic keys) using the manual status schema in `~/.config/opencode/skills/_shared/sdd-status-contract.md` (the same schema used when the binary is unavailable). The dispatcher is authoritative only for `openspec`/`hybrid`. If unavailable, resolve the active change using the status contract. If `$ARGUMENTS` is missing and more than one active change exists, ask the user to choose and STOP. Do not guess.
2. Produce or consume structured status before acting: schemaName, planningHome/changeRoot, artifactPaths/contextFiles, task progress, dependency states, next recommended action, blocked reasons, and actionContext.
3. Check which artifacts already exist for the active change (quest, proposal, specs, design, tasks, changelog)
4. Determine the next phase needed based on the dependency graph:
   quest → explore → propose → [spec ∥ design] → tasks → apply → verify → archive
   QUEST CONDITIONAL: the quest (RFC pre-pass) runs before exploration and is decided by its `## Approval:` header.
   - If a quest artifact exists with `## Approval: approved` → SKIP the quest; the approved RFC is the mandate. Proceed to `explore` if no exploration exists yet, else continue down the graph from the proposal onward.
   - If `## Approval: needs-changes` → re-run the quest: the ORCHESTRATOR re-opens the interview on the affected branches via its `question` tool (still ≤50 budget).
   - If `## Approval: rejected` → do NOT explore or propose; report to the user and stop.
   - If no quest artifact exists → the ORCHESTRATOR runs the quest interview itself: load the `sdd-quest` skill via its Skill tool and interview the user one question at a time with its `question` tool. Do NOT delegate the interview to the `sdd-rfc-author` sub-agent. After the user approves (`## Approval: approved`), delegate the collected Q&A to the `sdd-rfc-author` sub-agent (task tool) to draft the final canonical RFC for persistence as the binding mandate.
   The quest never runs 2+ times when already `approved`. Detection matches the exact header casing `## Approval:` used at persistence.
   SUPPORT-CONDITIONAL: the support phases (research, architecture-lint, changelog) are OPT-IN organic phases that the ORCHESTRATOR routes by inspecting artifact/change state in this step. They are NOT part of the `nextRecommended` token set and NEVER alter it — they join the pipeline at a hook point (like the quest) and are detected by artifact presence/state, not by a status token.
   - `sdd-research` → runs BEFORE `propose` when the change requires external/auditable evidence (same rule as the README: it is a support flow, not a canonical pipeline phase). Trigger: orchestrator decides based on the explore/proposal gap for evidence.
   - `sdd-architecture-lint` → runs AFTER `design` is `done` when the change touches architecture boundaries (new layers, ports/adapters, dependency injection, module boundaries, external access). It is a second, independent eye on the design — never self-audit. Trigger: orchestrator decides based on the design's scope; if the change is local and boundary-free, register `N/A` and skip (mirrors the quest skip when already approved).
   - `sdd-changelog` → runs AUTOMATICALLY AFTER `archive` completes, producing the release narrative and SemVer classification. Trigger: an archive-report artifact exists for the change AND the change has not yet emitted a `changelog`. Detection is by artifact state, exactly like the quest's `## Approval:` — when the pipeline reaches the end, the epilogue runs. If the change has no consumer-facing behavior (per spec + archive), the sub-agent returns the organic no-release opt-out ("no consumer-facing change") and persistence is skipped.
5. Launch the appropriate sub-agent(s) for the next phase only if authoritative status says the dependency is ready. Route only by `nextRecommended` and dependency states; never infer from free text. If `blockedReasons` is non-empty, do not proceed to apply, archive, or terminal work. If `nextRecommended` is `verify`, verification/remediation may run only to refresh evidence; if `nextRecommended` is `resolve-blockers`, report `blockedReasons` and stop; if `nextRecommended` is a planning token (`explore`, `propose`, `spec`, `design`, or `tasks`), launch the corresponding planning phase.
   For SUPPORT phases selected in step 4 (research, architecture-lint, changelog), delegate to their dedicated sub-agents with the exact skill paths in the launch prompt (`## Skills to load before work`). The changelog is delegated automatically after archive; the architecture-lint and research are delegated when their trigger in step 4 fires. Never run a support phase inline — it inflates orchestration context.
6. Present the result and ask the user to proceed

CONTEXT:

- Working directory: before doing anything else, run `git rev-parse --show-toplevel 2>/dev/null || pwd` with your bash tool and use the returned path as the authoritative workspace. In OpenCode Desktop (Electron) the parse-time interpolation resolves to the app data directory, not the project.
- Current project: the `basename` of the detected workspace above.
- Change name: $ARGUMENTS
- Execution mode: ask/cache per orchestrator
- Artifact store mode: ask/cache per orchestrator; do not hardcode Engram
- Delivery strategy: ask/cache per orchestrator
- Review budget: ask/cache per orchestrator

ENGRAM NOTE:
To check which artifacts exist in engram/hybrid, search: mem_search(query: "sdd/$ARGUMENTS/", project: "{project}") to list all artifacts for this change.
Sub-agents handle persistence automatically using the selected artifact store.

Read the orchestrator instructions to coordinate this workflow. Do NOT execute phase work inline — delegate to sub-agents.

STATUS CONTRACT:

Prefer `gentle-ai sdd-continue [change] --cwd <repo>` when available — but only when the session artifact store is `openspec` or `hybrid`; when the store is `engram`, do NOT invoke the binary and resolve status from Engram using the manual status schema. Otherwise read the installed shared status contract from this agent's skills directory and follow it. Use `~/.config/opencode/skills/_shared/sdd-status-contract.md` for OpenCode, `~/.config/kilo/skills/_shared/sdd-status-contract.md` for Kilo Code, `~/.qwen/skills/_shared/sdd-status-contract.md` for Qwen, or the equivalent configured skills directory for the current adapter. Do not use a workspace-relative `skills/_shared/...` path. Carry `actionContext` and allowed edit roots into any sub-agent launch. If status reports `workspace-planning` with no allowed edit roots, do not launch apply/verify/archive work that would infer repo-local ownership.
