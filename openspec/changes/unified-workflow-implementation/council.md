# Council Acta: unified-workflow-implementation

## Round
1

## Lens Verdicts

### sdd-council-arch
- Viable option: design as written (D1–D8)
- Verdict: converge on design as written (D1–D8)
- Concerns: None. Minimal-touch by intent; each D1–D8 decision is the smallest correction addressing its structural debt. Dependency direction is clean (orchestrator owns the chain; sub-agents are prompt-defined and receive paths, never contents). The only hard boundary introduced (`sdd-hard-gate`) follows the established prompt-defined pattern and creates no new coupling. Applied clarifications confirmed: no `__managed_by` key in `wiring/opencode.sdd.json` (T33 convention, design File Changes line 42) and council lens allow-lists pinned in T49+ (design Testing Strategy line 75).
- skill_resolution: paths-injected

### sdd-council-product
- Viable option: design as written (D1–D8)
- Verdict: converge on design as written (D1–D8)
- Concerns: Two minor, non-blocking:
  1. Council trigger thresholds are evaluated on the task forecast — a prediction; a mis-forecast under thresholds could skip council. Mitigated by axis 1 ALWAYS + design-binding fallback (D2/D7), recorded as an observation, not a defect.
  2. The `workflow-contract` spec delta sync is delegated to the archive phase (design Technical Approach) without being listed in File Changes — recommend an explicit pin/note at tasks time so it is not missed at archive.
  - Skill resolution: paths-injected

### sdd-council-risk
- Viable option: design as written (D1–D8) with risk pins (explicitly not a dissent)
- Verdict: propose — converge on the design with recorded hardening pins
- Concerns (ranked; each compatible with the design's own language and decisions):
  1. **D2 threshold evaluation sequencing** (the only inadequate-as-written mitigation): the data flow sequences council BEFORE tasks(forecast), yet thresholds are "evaluated on task forecast"; the design's own Open Questions permit "forecast/design evaluation". Tasks MUST evaluate the trigger on the scope estimate available at the council decision point; when the estimate is unavailable or uncertain, prefer running the council (never silently skip a council the critical-path flags demand) and support an explicit `council: required` opt-in override. Note: the design's stated fallback remains "design binding" — the default-flip guard is a task-phase recommendation, not a design amendment.
  2. **D4 T48 single point of failure**: T48 must grep ALL THREE flip surfaces (orchestrator `sdd-tool-integration` block, `sdd-changelog` SKILL.md, installed prompt post `--check`) plus the `workflow-contract` delta, or a partial flip can pass RED. Archive-report must be the terminal artifact of archive (written atomically at completion) so changelog "absent → blocked" is fail-loud, never silent corruption.
  3. **D3/T31 mechanism**: "ADDED around F4" must be implemented as strictly appended AFTER F4's terminal marker; T31 must byte-compare the F4 marker-delimited block, not fixed file offsets (an append would shift offsets and false-positive a naive pin). JSON wiring changes are T52's surface, not T31's.
  4. **Rollout ordering**: run the RED repo-file pins BEFORE `./sync-skills.sh` deploys to installed state, so a mid-sequence RED failure never leaves the production prompt set mutated-but-unvalidated; the designed final gate (RED green + `--check` 0 desyncs) stays as-is. `sync-skills.sh` self-modification is bounded by T30/T34 idempotency and the post-run `--check`.
  5. **Minor**: runtime threshold evaluation (no feature flags) is only partially pin-testable (T53 greps trigger language, not runtime behavior); the `council: required` override plus the critical-path trigger bound the worst case.
- skill_resolution: paths-injected

## Convergence
convergence

## Decision
### Decision: D1 — Flow Contract restated once as a single Unified Flow Contract
Bind the change to design D1(a): restate quest §3 ONCE as a single authoritative new `### Unified Flow Contract` section in `wiring/prompts/sdd/orchestrator.md` (after `SDD Session Preflight`); every delta in this change references it; F4/T31 stays byte-stable.

### Decision: D2 — Council chain: arch-lint axis 1 ALWAYS, council OPTIONAL by threshold, axis 2 conditional
Bind the change to design D2: post-design sequence is design → arch-lint axis 1 (ALWAYS) → council (OPTIONAL: >10 files, >400 lines, or critical paths `wiring/`/`skills/`/`prompts/` — evaluated on the task forecast, fallback design binding) → axis 2 (only if council ran) → hard gate; auto max 1 retry then STOP. Council machinery unchanged; trigger language only.

### Decision: D3 — Prompt-defined `sdd-hard-gate` executor, additive around F4, native sdd-attempt ledger
Bind the change to design D3(a): new `wiring/prompts/sdd/sdd-hard-gate.md` (OWN_PROMPTS, `{file:…}` prompt), agent registered in `wiring/opencode.sdd.json` (no `mcp` key, no `__managed_by` per T33 convention; `subagent_depth: 2` unchanged), orchestrator allow-list; ADDED around F4 with T31 byte-stable (implement as strictly appended after F4's terminal marker, byte-compared on the F4 marker block); adversarial verifier via native `sdd-attempt` acquire→settle; return edge ≤2, STOP-report on 3rd.

### Decision: D4 — Changelog flip to post-archive as one atomic unit
Bind the change to design D4: archive → changelog (archive-report input; absent → blocked) → retro (`sdd-tool`) → PR ready. Flip T48 + `sdd-changelog` SKILL.md + sdd-tool-integration block in ONE unit; T48 rewritten to pin changelog POST-archive (all three flip surfaces + workflow-contract delta).

### Decision: D5 — PR lifecycle via gh-git-mcp two-phase, human merge only
Bind the change to design D5: draft PR on `sdd/{change}` at start via `gh-git-mcp`/`github` MCP only (no-git-crudo pinned); incremental commits per work unit; mark-ready at close; merge ALWAYS human; >400 lines → ask-on-risk (existing Review Workload Guard); MCP availability checked in preflight 5th group — unavailable → no progression past phase 0; binding-signal mismatch → blocking prompt/fail-closed, never silent takeover.

### Decision: D6 — Bootstrap pre-resolve (Q40)
Bind the change to design D6: new mandatory bootstrap section resolving `sdd-tool` canonical path + PATH, `sdd-rfc-author` prompt path, and skills cache before any phase execution; zero mid-phase lookups — mid-phase `command not found` is a contract violation; `sdd-rfc-author` is NEVER a skill search.

### Decision: D7 — Arch-lint axis param, axis 2 conditional
Bind the change to design D7: `sdd-architecture-lint` gains launch params `axis: 1|2` + optional acta locator; axis 1 ALWAYS post-design (no acta); axis 2 only post-council (acta required); fail-closed iff council ran + acta unreadable; no council → skip, never boundary-skip.

### Decision: D8 — Quest schema 3 sections × 9 slots
Bind the change to design D8: `sdd-rfc-author` + `sdd-quest` Step 6 → product/architecture/general × 9 slots, one author one pass; needs-changes relaunch = affected branch only (≤50) + existing `quest.md` path.