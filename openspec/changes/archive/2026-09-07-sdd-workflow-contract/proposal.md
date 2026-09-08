# Proposal: sdd-workflow-contract

## Intent

This repo's orchestrator prompt and shared phase-common overlay lack enforceable workflow-contract rules for: no-raw-git, untrusted-data handling, worktree lifecycle, council-chain routing, and research parallelism. These contracts are prerequisites for later phases (hardening, council-chain, mcp-worktree) to land organically. Without them, the acceptance criteria from the approved RFC remain ungreetable and the pipeline has no structural guardrails.

## Scope

### In Scope

- Flip orchestrator.md line 73 delegation table: `Bash for state (git, gh)` from ✅ → ❌, naming allowed MCP surfaces (remote `github`, local `gh-git-mcp` two-phase supervised mutations)
- Add workflow-contract section to orchestrator.md covering: organic zero-prompt default, untrusted-data contract (SWUs + verify evidence claims), external-gap detection + research routing (parallel if pre-declared, serial once if post-explore), council-chain target flow (design → council always → arch-lint always → gate, max 1 retry in auto, second failure STOP), worktree lifecycle contract with Phase 0 exception, parallelism bounds (max 2 background, foreground writers)
- Four new `sdd-own`-marked shared-executor blocks in `overlays/shared/sdd-phase-common.md`: untrusted-data rule, no-git-crudo rule, worktree-binding rule, result-contract-strictness rule

### Out of Scope

- No `wiring/opencode.sdd.json` agent changes (council agents land with council-chain)
- No `wiring/mcp.d/*` changes (worktree tools land with mcp-worktree)
- No worktree MCP tool implementation (mcp-worktree phase)
- No command-overlay flips for arch-lint skip (council-chain phase)
- No skill overlays for sdd-tasks or sdd-apply (hardening phase)

## Capabilities

### New Capabilities

None — this is a prompt/overlay infrastructure change enforcing behavioral contracts, not a new product capability.

### Modified Capabilities

None — no existing spec-level behavior changes; the contracts are new enforcement layers atop existing orchestrator mechanics.

## Approach

Single-section orchestrator.md addition + one phase-common overlay file with four idempotent `sdd-own`-marked blocks. The overlay uses the existing strip+append mechanics of `sync-skills.sh` (each block carries a unique `sdd-own:<id>` marker). The orchestrator.md edit flips one table cell (line 73) and appends a new `### SDD Workflow Contract` section after the existing "Automatic Mode Gatekeeper" section (~line 400). Concrete file/line targets verified against the current installed base during exploration.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `wiring/prompts/sdd/orchestrator.md` | Modified | Line 73 flip (✅→❌); new workflow-contract section appended |
| `overlays/shared/sdd-phase-common.md` | Modified | Four new `sdd-own`-marked blocks (untrusted-data, no-git-crudo, worktree-binding, result-contract-strictness) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| no-git-crudo flip strands current workflows (agents use git/gh via bash today) | HIGH | Both MCP surfaces verified registered; supervised two-phase mutations exist; worktree ops NOT required in Phase 0 (documented exception) |
| Contract-grep fragility (AC requires greppable rules) | MEDIUM | This artifact names each contract surface; apply must keep exact canonical wording |
| Partial walkthrough AC (council + arch-lint always fire only after council-chain) | MEDIUM | Phase 0 delivers contract text; executable chain is later phase; gate must not misjudge Phase 0 against that AC |
| Research parallelism semantics (breaking offer-next semantics) | MEDIUM | Routing text references research-lifecycle.md existing semantics; no new state machine |
| Command overlays still carry arch-lint skip | LOW | Accepted until council-chain; Phase 0 contract text covers AC grep |
| Duplicated `_validate_worktree` in MCP server | LOW | Code smell deferred to mcp-worktree dedup |

## Rollback Plan

1. Revert orchestrator.md line 73 from ❌ → ✅ (one cell in the delegation table)
2. Remove the `### SDD Workflow Contract` section from orchestrator.md (single contiguous block)
3. Strip the four `sdd-own`-marked blocks from `overlays/shared/sdd-phase-common.md` using marker IDs (idempotent strip)
4. Run `./sync-skills.sh --check` to confirm zero desyncs after rollback

## Dependencies

- Approved RFC (`quest.md`) — consumed as binding mandate (already `## Approval: approved`)
- Exploration (`exploration.md`) — consumed as technical grounding
- No new external dependencies; all edit targets are in-repo prompts/overlays

## Success Criteria

- [ ] `wiring/prompts/sdd/orchestrator.md` line 73 reads ❌ with MCP surfaces named
- [ ] New workflow-contract section present in orchestrator.md with all 6 contract clauses (organic, untrusted-data, research-routing, council-chain, worktree-lifecycle, parallelism)
- [ ] Four `sdd-own`-marked blocks in `overlays/shared/sdd-phase-common.md` (untrusted-data, no-git-crudo, worktree-binding, result-contract-strictness)
- [ ] `./sync-skills.sh --check` reports zero desyncs
- [ ] `grep`-verifiable: "no-git-crudo", "untrusted-data", "fail-closed", "worktree binding" present in installed overlays
- [ ] Single apply batch (all edits fit within the review budget)
