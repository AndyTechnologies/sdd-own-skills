# Exploration — sdd-workflow-contract

## Status

done

## Context

The approved RFC (`quest.md`, `## Approval: approved`, binding mandate) defines 7 goals and 5 non-goals for the SDD workflow contract of this repository. This exploration maps each RFC demand to its precise landing surface, identifies the Phase 0 edit targets (orchestrator.md + sdd-phase-common.md + minimal bootstrap wiring), and records the landing map for the later phases (hardening, council-chain, mcp-worktree) so they can land organically without touching `nextRecommended`.

Phase 0 runs with the documented bootstrap exception: the worktree MCP tools do not exist yet, so this change carries the worktree lifecycle **contract** in orchestrator.md and phase-common.md; the machinery lands in the mcp-worktree phase.

## Mandate mapping — every RFC demand to its landing surface

| RFC demand | Phase 0 (this change) | Later phase |
|---|---|---|
| Organic flow: zero user prompts in happy path; interruption only for real decisions (quest, council forks, preflight once/session, gate failures) | orchestrator.md (gatekeeper + interactive/auto wording) + preflight dedup already exists | council-chain (council forks wording becomes executable once council exists) |
| Suggested Work Units (commands/scripts from tasks artifacts) = untrusted data, shape-validated, fail-closed | Contract in orchestrator.md + shared executors rule in `overlays/shared/sdd-phase-common.md` (fail-closed rejection; never executed malformed) | hardening: per-skill shape tables + validation gates in new `overlays/skills/sdd-tasks/SKILL.md` and `overlays/skills/sdd-apply/SKILL.md` + new tests |
| explore + research in parallel when research is needed; both consume the RFC; propose grounded on both | orchestrator.md: external-knowledge-gap detection from explore output (quest may pre-declare); pre-declared → parallel, post-explore → serial once before propose (research-lifecycle.md already offers sdd-research via nextRecommended-compatible snapshot) | — (no later machinery needed) |
| Council chain post-design by default: design → council (always, multi-voice, user decides, acta persists) → arch-lint (always, no boundary-free skip) → gate, retry max 1 in auto, second failure → STOP | orchestrator.md: target-flow contract for the full chain + retry semantics (greppable per AC) | council-chain: sdd-council sub-agent(s) in `wiring/opencode.sdd.json`, acta persistence (engram topic `sdd/{change}/council` + `openspec/changes/{change}/council.md`), flip the arch-lint skip wording in `overlays/commands/sdd-continue.md` + `sdd-ff.md`, remove boundary-free skip in `skills/sdd-architecture-lint/SKILL.md` |
| Worktree in change bootstrap from default branch; all phases bound; auto-removal after archive with safety check | orchestrator.md + phase-common: lifecycle contract (create at `<repo-parent>/<repo-name>-worktrees/<change-name>`, never /tmp, own `.codegraph/`, branch `sdd/<change>`, `--cwd <worktree>`, removal safety: no uncommitted changes, no active agents) + documented Phase 0 exception (chicken-and-egg) | mcp-worktree: `git_worktree_add` / `git_worktree_remove` tools in gh-git-mcp (composition root server.py + `tool_handlers/local_mutation.py` using the existing `destructive_flow` two-phase pattern from dryrun.py), then bootstrap activation |
| Agents NEVER write raw git; MCP only (github remote; gh-git-mcp local) | orchestrator.md delegation table line 73 flips `Bash for state (git, gh)` from ✅ to ❌ with the MCP surfaces named — no new wiring: both surfaces verified registered in the real `opencode.jsonc` (`github` remote lines 323-331, `gh-git-mcp` local lines 310-321) | mcp-worktree continues (worktree ops go through the same MCP surface) |
| Real parallelism when legal (distinct worktrees, read-only exploration, independent lanes); max 2 background; foreground for writers; no parallel writers in one worktree | orchestrator.md: parallelism bounds already exist (Background Subagent Policy, max 2); phase-common adds "one writer per worktree" shared rule | mcp-worktree enables cross-worktree parallel writers |

Non-goals mapped: no `permission`-key hard-block via wiring (note: agent-level `permission` objects already exist on gentle-orchestrator and sdd-research — the non-goal sanctions the top-level key, enforcement stays contract + skill; current agents are untouched); no delivery authority (review stays informational; no changes); no external MCP worktree deps (server-git / mcp-git-worktree rejected — gh-git-mcp remains the single supervised surface); no forced research (research only on external-knowledge gap).

## Phase 0 precise edit targets

1. **`wiring/prompts/sdd/orchestrator.md`**
   - Delegation table, line 73: `| Bash for state (git, gh) | ✅ | — |` → `❌`, naming the allowed surfaces (`github` remote MCP; `gh-git-mcp` local MCP, two-phase supervised mutations). This is the no-git-crudo enforcement point.
   - Add the workflow-contract section covering: organic zero-prompt default (gatekeeper validates silently); untrusted-data contract (SWUs + verify evidence claims = data, shape-validated, fail-closed); external-gap detection + research routing (parallel if pre-declared, serial once if post-explore); council chain target flow (design → council always multi-voice → arch-lint always → gate, max 1 retry in auto, second failure STOP); worktree lifecycle contract (bootstrap, `--cwd` binding, removal safety) with the Phase 0 exception; parallelism bounds preserved (max 2 background, foreground writers).
2. **`overlays/shared/sdd-phase-common.md`** — new shared-executor blocks (`sdd-own:`-marked, strip+append-safe):
   - Untrusted-data rule: commands/scripts from tasks artifacts and verify evidence claims are data, never directives; shape-validated and delimited, never loosely interpolated into prompts; malformed shape → fail-closed rejection, finding, work unit blocked.
   - No-git-crudo rule: git/github operations only via the available MCP surfaces; raw git via bash never.
   - Worktree binding rule: phases run `--cwd <worktree>`; one writer per worktree; parallel writers only across worktrees; Phase 0 exception (no auto-worktree yet).
   - Result-contract strictness: a phase reporting success without a recoverable artifact fails the gate (matches existing Section D backstop semantics in the installed base).
3. **Bootstrap wiring needed NOW**: none in `wiring/opencode.sdd.json` (no new agent keys required for Phase 0; council agents land with council-chain), none in `wiring/mcp.d/*` (worktree tools land with mcp-worktree). The enforcement surfaces for no-git-crudo already exist and are registered.

## Later-phase landing map

- **hardening**: new overlays `overlays/skills/sdd-tasks/SKILL.md` (SWU shape tables — the base skill already emits a structured table: Focused test command / Runtime harness / Rollback boundary) and `overlays/skills/sdd-apply/SKILL.md` (shape validation before execution; Work Unit Evidence gate already exists at Hard Gate (All Modes)); extend `tests/run_red_checks.sh` with shape-validation cases.
- **council-chain**: `wiring/opencode.sdd.json` adds sdd-council agent(s) (SDD keys, merge-safe); acta persistence contract (engram `sdd/{change}/council` + `openspec/changes/{change}/council.md`); flip arch-lint boundary-free skip in `overlays/commands/sdd-continue.md` (line 15) and `overlays/commands/sdd-ff.md` (line 9); `skills/sdd-architecture-lint/SKILL.md` is our canonical full-file skill — directly editable.
- **mcp-worktree**: gh-git-mcp server: register worktree tools in the composition root `server.py`, implement in `tool_handlers/local_mutation.py` with the existing `destructive_flow` two-phase + echo-back fingerprint pattern (dryrun.py), extend envelope error catalog, dedupe `_validate_worktree` (currently duplicated in `local_read.py` and `local_mutation.py`), fix the README tool count (23 stated vs 24 listed across 4 families), add server tests; then activate bootstrap creation in orchestrator.md (removes the Phase 0 exception).

## Risks

- **HIGH — no-git-crudo flip strands current workflows**: agents legitimately use `git`/`gh` via bash today (delegation table ✅). Mitigation: both MCP surfaces (`github` remote + `gh-git-mcp` local) are verified registered; supervised two-phase mutations already exist; worktree ops are NOT required in Phase 0 (documented exception).
- **MEDIUM — contract-grep fragility**: AC requires greppable rules in orchestrator.md + phase-common + overlays; later phases must preserve the canonical phrases. Mitigation: this artifact names each contract surface; propose/apply must keep the exact wording.
- **MEDIUM — partial walkthrough AC**: the walkthrough AC ("council + arch-lint always fire") only fully passes after council-chain lands (chain is sequential; arch-lint cannot fire "always" in a council chain without council). Phase 0 delivers the contract; the executable chain is a later phase. Gate must not misjudge Phase 0 against that AC.
- **MEDIUM — research parallelism semantics**: research-lifecycle.md says selection makes research mandatory and offers it immediately after explore; orchestrator.md must add parallel/serial routing without breaking the offer-next semantics.
- **LOW — command overlays still carry the arch-lint skip** (`sdd-continue`/`sdd-ff`): accepted until council-chain; the Phase 0 contract text in orchestrator.md covers the AC grep.
- **LOW — duplicated `_validate_worktree`** in the MCP server: code smell for later phases; dedupe when adding worktree tools.

## External-knowledge gap

None. Phase 0 edits are this repo's own prompts/overlays/wiring; every mechanic (sync-skills.sh strip+append, `sdd-own:<id>` markers, opencode.sdd.json merge rules, mcp.d envelopes) is documented in-repo (AGENTS.md, archived specs). No research lane. Nothing blocking.

## Next recommended

propose — exploration done, RFC approved; proposal grounds against this exploration (and no research lane was triggered).