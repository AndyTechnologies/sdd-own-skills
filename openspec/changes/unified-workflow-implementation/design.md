# Design: Unified Workflow Implementation

## Technical Approach

Contract-first, minimal-touch (explore #1): restate quest §3 ONCE as a single authoritative `### Unified Flow Contract` section in `wiring/prompts/sdd/orchestrator.md`, then make surgical deltas that reference it (council optional, changelog post-archive, axis 2 conditional, preflight canonical 3 groups + separate worktree/gh-git-mcp confirm, PR lifecycle, hard gate, bootstrap, return edge, 3-section quest schema). Compatibility with gentle-ai 2.9.0: the runtime-managed OpenCode plugin fixes the canonical preflight to exactly 3 groups (labels/order/400-line policy) and injects the `SDD Session Preflight` block itself; the worktree confirmation and `gh-git-mcp` availability check MUST be asked separately, never as extra canonical groups. Archive delta sync SHALL use native `gentle-ai sdd-archive-compose` (deterministic), not manual merging. Rewrite RED T32/T35/T48, append T49+; sync canonical `workflow-contract` spec at archive; ship the unified diagram with the PR. This structurally eliminates the existing changelog-timing contradiction (Organic Hooks item 4 says post-archive; the `sdd-tool-integration` block says pre-archive).

## Architecture Decisions

| # | Decision | Options | Tradeoff | Decision |
|---|---|---|---|---|
| D1 | Flow Contract restate | (a) restate §3 once; (b) wholesale rewrite; (c) hooks-only | (a) smallest diff, single source of truth; (b) high risk to F4/T31; (c) repeats scattered-contract debt | (a) — new `### Unified Flow Contract` after `SDD Session Preflight`; every delta references it |
| D2 | Council chain (fork 1, resolved) | arch-lint before vs after council | Quest §3 + Q31: axis 1 gates design before council tokens are spent | design → arch-lint axis 1 (ALWAYS) → council (OPTIONAL: >10 files, >400 lines, or critical paths `wiring/`/`skills/`/`prompts/` — evaluated on task forecast, fallback **design binding**) → axis 2 (only if council ran) → gate; auto max 1 retry then STOP |
| D3 | Hard-gate executor (fork 2, resolved) | (a) new prompt-defined `sdd-hard-gate`; (b) reuse `jd-*`/`review-*`; (c) ledger + orchestrator self-read | (a) matches `sdd-rfc-author`/`sdd-council` pattern, true fresh-eyes; (b) blurs RDD/4R contracts and budgets; (c) not adversarial | (a) — `wiring/prompts/sdd/sdd-hard-gate.md` in `OWN_PROMPTS`, agent registered in `wiring/opencode.sdd.json`, orchestrator allow-list; ADDED around F4 (T31 byte-stable); native `sdd-attempt` acquire→settle ledger |
| D4 | Changelog flip | pre→post-archive | T48 + SKILL.md + spec must flip together or verify deadlocks | archive → changelog (archive-report input; absent → blocked) → retro (`sdd-tool`) → PR ready; flip T48 + `sdd-changelog` SKILL.md + sdd-tool-integration block in one unit |
| D5 | PR lifecycle | MCP-only vs raw git/gh | no-git-crudo pinned; two-phase supervised | Draft PR on `sdd/{change}` at start via `gh-git-mcp`/`github` MCP only; incremental commits per work unit; mark-ready at close; merge ALWAYS human; >400 lines → ask-on-risk (existing Review Workload Guard) |
| D6 | Bootstrap (Q40) | pre-resolve vs on-demand | zero mid-phase lookups vs upfront cost | New mandatory section: `sdd-tool` → `$HOME/.config/sdd-own/bin/sdd-tool`/PATH; `sdd-rfc-author` prompt path; skills cache. Mid-phase `command not found` = contract violation; `sdd-rfc-author` NEVER a skill search |
| D7 | Axis 2 conditional | one invocation both axes vs explicit axis param | Sequence needs axis 1 pre-council | `sdd-architecture-lint` gains launch params `axis: 1|2` + optional acta locator; axis 1 ALWAYS post-design; axis 2 only post-council; fail-closed iff council ran + acta unreadable; no council → skip, never boundary-skip |
| D8 | Quest schema | flat 9-slot vs 3×9 | Approved quest already 3-section; skills/prompt behind | `sdd-rfc-author` + `sdd-quest` Step 6 → product/architecture/general × 9 slots, one author one pass; needs-changes = affected branch only (≤50) + existing `quest.md` path |

## Data Flow

```
request → preflight(canonical 3 groups; runtime block) + worktree/gh-git-mcp confirm (separate) → init(silent) → worktree + PR draft
→ quest(sdd-rfc-author, 3 RFCs) → single gate → explore ←quest path
→ propose → spec ←proposal → design ←proposal+spec
→ arch-lint axis1 (ALWAYS) → council (OPTIONAL, thresholds) → axis2 (acta)
→ tasks(forecast) → apply RED→GREEN, commit/unit → verify → hard gate(sdd-attempt+verifier)
→ archive → changelog(archive-report) → retro(sdd-tool) → PR ready; merge = human
        └────────── all phases --cwd <worktree> ──────────┘
```

Handoffs pass paths, never contents (sole exception: inline Q&A to `sdd-rfc-author`).

## File Changes

| File | Action | Description |
|---|---|---|
| `wiring/prompts/sdd/orchestrator.md` | Modify | Unified Flow Contract restate; preflight canonical 3 groups (runtime block) + separate worktree/gh-git-mcp confirm; bootstrap (Q40); PR lifecycle; hard-gate section (ADDED, F4/T31 untouched); rule 4 council-optional; hooks item 3 chain; sdd-tool-integration archive-close flip (post-archive changelog + PR ready); archive retro via `sdd-archive-compose`; return edge ≤2; handoff-by-path |
| `wiring/prompts/sdd/sdd-rfc-author.md` | Modify | 3-section schema; needs-changes relaunch (new Q&A + existing quest.md path) |
| `wiring/prompts/sdd/sdd-council.md` | Modify | ALWAYS → OPTIONAL threshold trigger language (machinery unchanged) |
| `wiring/prompts/sdd/sdd-hard-gate.md` | Create | Adversarial verifier prompt (our exclusive, prompt-defined): specs-vs-code fresh eyes, native `sdd-attempt`, return edge ≤2, STOP-report on 3rd |
| `wiring/opencode.sdd.json` | Modify | Register `sdd-hard-gate` (hidden subagent, `{file:…}` prompt, `permission: {}`); orchestrator allow; no `mcp` key, no `__managed_by` (T33 convention); `subagent_depth: 2` unchanged |
| `skills/sdd-quest/SKILL.md` | Modify | Step 6 schema → 3 sections × 9 slots |
| `skills/sdd-council/SKILL.md` | Modify | Trigger ALWAYS→OPTIONAL (frontmatter + invariants) |
| `skills/sdd-architecture-lint/SKILL.md` | Modify | Axis param; axis 2 conditional; fail-closed only when council ran + acta unreadable |
| `skills/sdd-changelog/SKILL.md` | Modify | Input → archive-report (post-archive; absent → blocked); drop verify-report input |
| `overlays/commands/sdd-continue.md` | Modify | SUPPORT-CONDITIONAL: council OPTIONAL thresholds; axis 1 always + axis 2 conditional; gateway order + PR draft |
| `overlays/commands/sdd-ff.md` | Modify | Item 6: arch-lint axis 1 → council OPTIONAL → axis 2 conditional |
| `overlays/commands/sdd-new.md` | Modify | Gateway: preflight canonical 3 groups (runtime block) → worktree/gh-git-mcp confirm (separate) → init → worktree + PR draft → quest |
| `sync-skills.sh` | Modify | `OWN_PROMPTS` += `sdd-hard-gate.md` (idempotent, T34 pattern) |
| `tests/run_red_checks.sh` | Modify | Rewrite T32/T35/T48 pins; append T49+ (bootstrap, quest 3-section, PR draft + merge-human, hard gate, preflight canonical 3 groups + separate worktree confirm, thresholds, return edge); T31 must stay green |
| `docs/diagrams/sdd-workflow-unified.{html,visual-check.json}` | Create (copy from main repo) | Untracked deliverable evidence, travels with PR |
| `README.md` | Modify | Unified diagram replaces `sdd-flow.*` as flow reference |

Our exclusive assets vs Alan's base: `sdd-hard-gate`, `sdd-council`, `sdd-architecture-lint`, `sdd-changelog`, `sdd-quest` are ours (repo `skills/`, overlay blocks, `OWN_PROMPTS`); overlay edits stay inside unique `sdd-own:<id>` markers (strip/append idempotent — T30).

## Interfaces / Contracts

`wiring/prompts/sdd/sdd-hard-gate.md` launch contract:

```text
input:  change, store, paths (spec, design, tasks, verify-report, apply-progress)
ledger: gentle-ai sdd-attempt acquire|settle (native, per Runtime Attempt Authority)
check:  every spec requirement/scenario has code evidence; no invented behavior
output: verdict pass | return-edge (≤2) | stop-report; artifact sdd/{change}/hard-gate
```

Arch-lint launch params: `axis: 1` (no acta) post-design; `axis: 2` (acta required) post-council.

## Testing Strategy

| Layer | What | How |
|---|---|---|
| RED | T32 council OPTIONAL chain; T35 axis 2 conditional; T48 changelog POST-archive | Rewrite greps in `tests/run_red_checks.sh` |
| RED | T49 bootstrap pre-resolve; T50 quest 3×9 schema; T51 PR draft + merge human + gh-git-mcp check; T52 hard gate (agent + OWN_PROMPTS + sdd-attempt + F4 stable); T53 preflight canonical 3 groups only (runtime block, no 4th/5th canonical group) + separate worktree confirm + thresholds + return edge. Explicit pins: council lens allow-lists intact + orchestrator allow-list includes `sdd-council` | Append pins, existing harness pattern |
| E2E | `./tests/run_red_checks.sh` green; `./sync-skills.sh --check` 0 desyncs | T30/T39 guard; T31 F4 byte-stability re-ran |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no executable-doc boundary; prompts are installed, never executed | — | — |
| Git repository selection | Applicable — worktree + branch `sdd/{change}` binding via MCP | Binding-signal mismatch → blocking prompt/fail-closed; never silent takeover | T51 + existing lifecycle pins |
| Commit state | Applicable — incremental commits per work unit | Two-phase supervised commit only; denied → return edge | T51 |
| Push state | Applicable — draft PR from start | `gh-git-mcp` availability checked in the separate preflight confirm; unavailable → no progression past phase 0 | T51, preflight-canonicity pin |
| PR commands | Applicable — draft-from-start, mark-ready, merge human | MCP surfaces only (no-git-crudo); merge guard human-only | T51 |

## Migration / Rollout

Apply order: repo edits → `./sync-skills.sh --skip-gentleai-sync` (deploy prompts, OWN_PROMPTS, wiring) → `--check` 0 desyncs → RED green. Rollback: revert branch (PR unmerged → nothing ships); overlay strip/append idempotent; revert orchestrator.md + `OWN_PROMPTS`; re-verify `--check`. No data migration; no feature flags (council thresholds evaluated at runtime per forecast/design).

## Open Questions

- [ ] None blocking. (Non-blocking runtime: council on/off fires per forecast/design evaluation; PR ask-on-risk per line count.)