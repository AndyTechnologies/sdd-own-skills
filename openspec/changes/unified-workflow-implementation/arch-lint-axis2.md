# Architecture Lint — Axis 2: Council Acta Verification

**Change**: unified-workflow-implementation
**Phase**: post-council (axis 2 only — axis 1 confirmed PASS in prior pass `arch-lint.md`)
**Artifact store**: both (openspec + engram)
**Date**: 2026-09-13
**Council round**: 1 (all 3 lenses converge; no fork)

## Axis 2 — Acta Decision Verification (D1–D8, title-by-title)

| # | Acta Decision | Design Coverage | Verdict |
|---|---|---|---|
| D1 | Flow Contract restated once as a single Unified Flow Contract | D1(a) in Architecture Decisions table: "restate §3 once; new `### Unified Flow Contract` after `SDD Session Preflight`" — matches acta binding exactly. Orchestrator.md File Changes row confirms "Unified Flow Contract restate". | ✅ Incorporated |
| D2 | Council chain: arch-lint axis 1 ALWAYS, council OPTIONAL by threshold, axis 2 conditional | D2 in Architecture Decisions table: "design → arch-lint axis 1 (ALWAYS) → council (OPTIONAL: >10 files, >400 lines, or critical paths) → axis 2 (only if council ran) → gate; auto max 1 retry then STOP." Data Flow diagram confirms the same sequence. sdd-council SKILL.md row + T35 row cover the trigger language change. | ✅ Incorporated |
| D3 | Prompt-defined `sdd-hard-gate` executor, additive around F4, native sdd-attempt ledger | D3(a) in Architecture Decisions table: "new `sdd-hard-gate.md` in OWN_PROMPTS, agent registered in `wiring/opencode.sdd.json`, orchestrator allow-list; ADDED around F4 (T31 byte-stable); native `sdd-attempt` acquire→settle." Interfaces section defines the full launch contract (input/ledger/check/output with pass/return-edge≤2/stop-report). File Changes: `sdd-hard-gate.md` Create + `opencode.sdd.json` Modify rows. | ✅ Incorporated |
| D4 | Changelog flip to post-archive as one atomic unit | D4 in Architecture Decisions table: "archive → changelog (archive-report input; absent → blocked) → retro → PR ready; flip T48 + `sdd-changelog` SKILL.md + sdd-tool-integration block in one unit." sdd-changelog SKILL.md row confirms "Input → archive-report (post-archive; absent → blocked)." | ✅ Incorporated |
| D5 | PR lifecycle via gh-git-mcp two-phase, human merge only | D5 in Architecture Decisions table: "Draft PR on `sdd/{change}` at start via `gh-git-mcp`/`github` MCP only; incremental commits per work unit; mark-ready at close; merge ALWAYS human; >400 lines → ask-on-risk." Threat Matrix covers commit/push/PR states with binding-signal mismatch → blocking. T51 pins cover PR draft + merge-human + gh-git-mcp check. | ✅ Incorporated |
| D6 | Bootstrap pre-resolve (Q40) | D6 in Architecture Decisions table: "New mandatory section: `sdd-tool` canonical path + PATH; `sdd-rfc-author` prompt path; skills cache. Mid-phase `command not found` = contract violation; `sdd-rfc-author` NEVER a skill search." Orchestrator.md File Changes row confirms "bootstrap (Q40)". T49 bootstrap pin covers this. | ✅ Incorporated |
| D7 | Arch-lint axis param, axis 2 conditional | D7 in Architecture Decisions table: "`sdd-architecture-lint` gains launch params `axis: 1\|2` + optional acta locator; axis 1 ALWAYS post-design; axis 2 only post-council; fail-closed iff council ran + acta unreadable; no council → skip, never boundary-skip." SKILL.md row confirms "Axis param; axis 2 conditional; fail-closed only when council ran + acta unreadable." T35 covers this. | ✅ Incorporated |
| D8 | Quest schema 3 sections × 9 slots | D8 in Architecture Decisions table: "`sdd-rfc-author` + `sdd-quest` Step 6 → product/architecture/general × 9 slots, one author one pass; needs-changes = affected branch only (≤50) + existing `quest.md` path." `sdd-rfc-author.md` row confirms "3-section schema; needs-changes relaunch." `sdd-quest` SKILL.md row confirms "Step 6 → 3 sections × 9 slots." T50 covers this. | ✅ Incorporated |

## Convergence Consistency

The acta's convergence verdict ("convergence — design as written D1–D8") is consistent with the design's option choices:

- **D1**: acta binds (a) → design option (a) selected ✅
- **D2**: acta binds design-as-written → design D2 matches chain description ✅
- **D3**: acta binds (a) → design option (a) selected; fork resolved ✅
- **D4**: acta binds design-as-written → design D4 matches flip sequence ✅
- **D5**: acta binds design-as-written → design D5 matches lifecycle ✅
- **D6**: acta binds design-as-written → design D6 matches bootstrap ✅
- **D7**: acta binds design-as-written → design D7 matches axis params ✅
- **D8**: acta binds design-as-written → design D8 matches 3×9 schema ✅

No `fork` acta verdict requires a `## Selected Option` (the acta converged, no fork was left open). All eight decisions match.

## Council Risk Pins (compatible, not design amendments)

The council-risk lens proposed 5 hardening pins. All are **compatible** with the design as written and do not amend the decisions:

1. **D2 threshold evaluation sequencing** — runtime observation, mitigated by fallback (design binding) and axis 1 ALWAYS. Design's own Open Questions note "council on/off fires per forecast/design evaluation." No design amendment needed.
2. **D4 T48 single point of failure** — task-time hardening: T48 must grep ALL THREE flip surfaces + workflow-contract delta. Design already says "flip T48 + sdd-changelog SKILL.md + sdd-tool-integration block in ONE unit" and adds workflow-contract delta. Pin is consistent, not a design change.
3. **D3/T31 mechanism** — T31 must byte-compare the F4 marker block (not fixed offsets). Design says "ADDED around F4 with T31 byte-stable (implement as strictly appended after F4's terminal marker)." Consistent.
4. **Rollout ordering** — RED repo-file pins before `sync-skills.sh` deployment. Design's Migration section names "repo edits → `--skip-gentleai-sync` → `--check` 0 desyncs → RED green." Task-time concern, not a design amendment.
5. **Runtime threshold testability** — council: required override bounds worst case. Design's Threat Matrix + T53 pin cover the static layer; runtime behavior is inherently outside RED scope. Compatible observation.

## Findings

**None.** All 8 acta decisions are fully incorporated in the design with no contradictions, no partial incorporations, and no missing decisions.

## Verdict

**Axis 2: PASS** — all 8 acta decisions (D1–D8) verified title-by-title against design.md. Each decision is fully incorporated (same option, same tradeoffs, same file targets). Convergence verdict consistent. Council risk pins are compatible task-time hardening notes, not design amendments. No findings.

**Overall**: Axis 1 PASS (prior pass) + Axis 2 PASS (this pass) → design is ready for task freeze.
