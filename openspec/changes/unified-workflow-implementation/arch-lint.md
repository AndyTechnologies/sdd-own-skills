# Architecture Lint: unified-workflow-implementation

**Phase**: post-design (pre-council, pre-tasks) · **Pass**: axis 1 only
**Artifact store**: both (openspec + engram) · **Date**: 2026-09-13

## Axis 2 — Council acta verification

**N/A in this pass.** No council has run for this change (council is OPTIONAL, threshold-driven, per the delta spec's new conditional contract; no `council.md` exists under `openspec/changes/unified-workflow-implementation/`). Per the delta requirement *Arch-lint axis 2 (acta verification)*, when no council ran, axis 2 is skipped and axis 1 gates alone. This pass is itself the first exercise of the new conditional flow: axis 1 only, no acta, no fail-closed.

## Axis 1 — Requirements/scope coverage (6 MODIFIED + 8 ADDED)

### MODIFIED requirements

| # | Requirement | Design coverage | Verdict |
|---|---|---|---|
| M1 | Council-chain target flow (design → arch-lint axis 1 ALWAYS → council OPTIONAL thresholds → axis 2 conditional → gate; max 1 auto retry then STOP; convergence no-interrupt; forks → user) | D2 chain + Data Flow + rule 4 rewrite: thresholds (>10 files, >400 lines, critical paths `wiring/`/`skills/`/`prompts/`) on task forecast, fallback design binding; auto max 1 retry then STOP. Matches spec scenario set. | ✅ Conforms |
| M2 | Arch-lint axis 2 (title-by-title acta verification; conditional on council ran; fail-closed iff council ran + acta unreadable; axis 1 unchanged ALWAYS) | D7 launch params `axis: 1\|2` + optional acta locator; axis 1 ALWAYS, axis 2 only post-council; fail-closed iff council ran + acta unreadable; "no council → skip, never boundary-skip". SKILL.md row + T35 rewrite. | ✅ Conforms |
| M3 | Command overlay council chain (sdd-continue SUPPORT-CONDITIONAL, sdd-ff item 6: axis 1 always → council OPTIONAL → axis 2 conditional; no always-council language) | Both overlay rows + sdd-new gateway row name the conditional chain and drop the always language. | ✅ Conforms |
| M4 | Archive-close fixed persist order (archive → changelog POST-archive w/ archive-report → retro sdd-tool → PR ready; merge human) | D4 + sdd-tool-integration flip row + `sdd-changelog` input → archive-report (absent → blocked). Also resolves the verified existing contradiction (orchestrator.md line 375 post-archive vs lines 701-704 pre-archive + verify-report). | ✅ Conforms |
| M5 | Orchestrator rule 4 + organic hooks item 3 rewrite; F4/T31 byte-stable; hard gate ADDED around F4, never replacing | Rule-4 row + hooks item 3 row + "hard-gate section (ADDED, F4/T31 untouched)" + T31 must stay green in RED row. Verified current text (line 493 rule 4 council-ALWAYS, line 373 hooks item 3 acta-mandatory) — the rewrite targets exactly these. | ✅ Conforms |
| M6 | RED checks T32+ (rewrite T32/T35/T48, append T49+: bootstrap, quest 3×9, PR draft, hard gate, preflight 5th, thresholds, return edge; allow-lists; OWN_PROMPTS; no mcp key; T30 0 desyncs) | RED row (rewrite T32/T35/T48; append T49+ list matching the spec's pin set) + Testing Strategy T49-T53 enumeration + OWN_PROMPTS row (T34 pattern). Verified current T31/T32/T35/T48 pins exist in `tests/run_red_checks.sh`. | ✅ Conforms (2 INFO nits — see findings) |

### ADDED requirements

| # | Requirement | Design coverage | Verdict |
|---|---|---|---|
| A1 | Hard gate pre-archive (native `sdd-attempt` ledger + adversarial verifier fresh eyes spec-vs-code; return edge ≤2 then STOP-report; additive around F4/T31) | D3 (a) `sdd-hard-gate` prompt-defined sub-agent, `sdd-attempt` acquire→settle ledger; Interface launch contract (input/ledger/check/output pass\|return-edge≤2\|stop-report; artifact `sdd/{change}/hard-gate`). Resolves proposal fork 2. | ✅ Conforms |
| A2 | Bootstrap canonical paths (Q40): `sdd-tool` → `$HOME/.config/sdd-own/bin/sdd-tool`/PATH; `sdd-rfc-author` prompt path; skills; command-not-found = contract violation; never a skill search | D6 new mandatory section + orchestrator row "bootstrap (Q40)" with exact paths and violation semantics + "NEVER a skill search". | ✅ Conforms |
| A3 | PR lifecycle (draft from start on `sdd/{change}` via MCP only, no-git-crudo; incremental commits; mark-ready at close; merge human; >400 lines → ask-on-risk) | D5 MCP-only + Threat Matrix (commit/push/PR rows) + T51 pins + Review Workload Guard reference. | ✅ Conforms |
| A4 | Preflight 5th group (worktree confirmation, one pass; reuse same change; conflict asks; no main-repo work post-confirmation; init silent) | Data Flow "preflight(4 groups + worktree confirm) → init(silent)" + sdd-new gateway row + orchestrator row. | ✅ Conforms |
| A5 | gh-git-mcp availability check (pre-phase-0; unavailable → no PR/worktree lifecycle past phase 0) | Orchestrator row + Threat Matrix push-state row + T51. | ✅ Conforms |
| A6 | Quest 3-section schema + single gate (3×9 slots; one author one pass; `## Approval: approved`; ❌ re-opens affected section only; engram mirror `capture_prompt: false`; needs-changes affected branch ≤50 + existing quest path) | D8 + `sdd-rfc-author` row (3-section schema, needs-changes relaunch) + `sdd-quest` SKILL.md row (Step 6 → 3×9). | ✅ Conforms |
| A7 | Return edge (bounded correction, max 2, 3rd → human report, never loop; applies to gate rejection, arch-lint/council, hard gate, apply/verify) | orchestrator row "return edge ≤2" + D2/D3 + hard-gate interface output. | ✅ Conforms |
| A8 | Handoff by path (locations never contents; explore←quest path; propose←quest+explore; spec←proposal; design←proposal+spec; sole exception inline Q&A; no format contracts in orchestrator) | Data Flow path arrows + "Handoffs pass paths, never contents (sole exception: inline Q&A to `sdd-rfc-author`)" + D8 format lives in author prompt. | ✅ Conforms (1 INFO nit — propose inputs not drawn) |

### Boundary review — clean/hexagonal consistency of the orchestration contract

| Concern | Verdict | Rationale |
|---|---|---|
| Layer dependencies (inward) | ✅ Conforms | Orchestrator stays a pure shell: locations in, approvals out, zero format contracts (D8, quest §3 invariants). Sub-agents (`sdd-rfc-author`, `sdd-hard-gate`, council machinery) are prompt-defined behind the orchestrator's allow-list; no layer reaches outward. |
| Ports & adapters | ✅ Conforms | Git/GitHub state behind MCP surfaces only (D5, no-git-crudo); gh-git-mcp availability is an adapter-presence gate before phase 0 (A5); `sdd-tool` behind canonical-path bootstrap (A2). External concerns never leak into the contract core. |
| Dependency injection | ✅ Conforms | Bootstrap pre-resolves canonical paths at session start (composition root, A2/D6); handoffs inject locations, never contents (A8); sub-agents read their inputs from the backend. |
| Domain isolation | ✅ Conforms | The quest/RFC format contract lives inside the author's prompt/skill, never in the orchestrator (D8, quest §2 non-goals). F4/T31 consent machinery stays byte-stable — the hard gate is ADDED around it, not replacing it (M5). |
| External access | ✅ Conforms | Worktree binding `--cwd <worktree>` (shared contract); no main-repo work once confirmed (A4); worktree lifecycle via supervised MCP tools, not raw git. |

## Findings

| Severity | Detail | File |
|---|---|---|
| INFO | M6 RED rewrite: spec requires "lens allow-lists intact" and "orchestrator allow-list includes sdd-council" among the new pins; the design's T49-T53 enumeration and T32 rewrite cover this implicitly (allow-list lives in T32's domain), but the pins are not named. Make the council allow-lists pin explicit in the RED row to avoid a T32 rewrite that misses the lens allow-lists. | design.md File Changes / Testing Strategy |
| INFO | New `sdd-hard-gate` agent row in `wiring/opencode.sdd.json` states "no `mcp` key" but not the repo-wide no-`__managed_by` convention (T33 pins it for council agents; spec M1 repeats "no `__managed_by`"). Add "no `__managed_by`" explicitly for the new agent (T34/T33-style pin). | design.md File Changes (wiring/opencode.sdd.json row) |
| INFO | Sequencing: the installed `skills/sdd-architecture-lint/SKILL.md` still carries legacy "acta MANDATORY / axis 2 ALWAYS / N/A solo trivial" text; this run exercises the NEW conditional contract at the orchestrator's direction. The design updates the skill + T35 in this change, so any OTHER in-flight change running arch-lint before this change syncs reads stale text. Apply-order awareness only; not a design defect. | design.md (skills/sdd-architecture-lint/SKILL.md row) |
| INFO | Data Flow draws `→ propose →` without the quest+explore path inputs the spec (A8) names; the "Handoffs pass paths" line covers it. Cosmetic, no correction needed. | design.md Data Flow |

## Risks

- **This change triggers its own council threshold.** File Changes lists 17 files touching critical paths (`wiring/`, `skills/`, `prompts/`, `tests/`) — the task forecast is absent, so the fallback (design, binding) already exceeds >10 files. Per D2, the council SHOULD fire next; axis 2 then becomes mandatory with the acta. Consistent with the new flow, but this change is the first exercise of it (see finding 3 for the stale-skill exposure).
- **Changelog flip is 3-file atomic** (D4): T48 + `sdd-changelog` SKILL.md + sdd-tool-integration block must land in one work unit or verify deadlocks. Design names this; keep it as a single unit in tasks.
- None structural: no dependency-direction inversion, no external concern in the core, no scope over-reach beyond the proposal's in-scope list (the `sdd-hard-gate` executor is the proposal's declared pending fork, resolved as (a)).

## Verdict

**Axis 1: PASS** — all 6 MODIFIED + 8 ADDED requirements covered, no omissions, no scope over-reach; orchestration contract consistent with clean/hexagonal principles (4 INFO observations, none blocking).
**Axis 2: N/A this pass** (no council ran — conditional contract).