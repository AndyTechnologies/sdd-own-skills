# Exploration: unified-workflow-implementation

> Phase artifact — consumed by `sdd-propose` alongside the binding quest RFC (`quest.md`, `Approval: approved`).
> Status: READY FOR PROPOSAL.

## Current State

The repo ships a gentle-ai SDD pipeline controlled from `wiring/prompts/sdd/orchestrator.md` (721 lines, full-install prompt) plus prompt-defined sub-agents (`sdd-rfc-author.md`, `sdd-council.md`), a wiring fragment (`wiring/opencode.sdd.json`), exclusive skills (`skills/sdd-quest`, `grilling`, etc.), overlay blocks appended to Alan's base skills (`overlays/skills/*`, `overlays/commands/*`, `overlays/shared/*`), a deployment script (`sync-skills.sh`, `OWN_PROMPTS=(orchestrator.md sdd-rfc-author.md sdd-council.md)`), a Go CLI (`srv/sdd-tool`, subcommands: dashboard, engram, incidents, retro, scanner, scrub, worktree), an MCP server (`srv/gh-mcp-server`), and a RED regression harness (`tests/run_red_checks.sh`, 48 checks T01–T48).

The current pipeline order is: request → preflight (4 groups) → init (silent if present) → quest → explore → propose → spec → design → council (ALWAYS) → arch-lint (ALWAYS, acta mandatory) → tasks → apply (TDD) → verify → F4/RDD hook (only when RDD ON) → archive (with changelog PRE-archive en la archive-close chain) → PR ready. Worktree lifecycle v2 exists (`.sdd-agent-lock`, supervised `git_worktree_add/remove`, `--cwd <worktree>` binding), but NO PR is drafted at change start and NO hard gate runs before archive.

The approved quest RFC (`openspec/changes/unified-workflow-implementation/quest.md`, 39 decisions + Q40) redefines the flow: request → preflight (5 groups, worktree confirmation) → init → worktree + PR draft → quest → **3 RFCs (product/architecture/general) by `sdd-rfc-author`** → single gate → explore → propose → spec → design → arch-lint → **council (OPTIONAL, threshold-driven)** → tasks → apply TDD → verify → **hard gate (ALWAYS)** → archive → changelog + retro + PR ready. Merge ALWAYS human. The binding RFC already uses the NEW 3-section schema — the current `sdd-quest` skill and `sdd-rfc-author` prompt use a flat 9-slot schema and are therefore BEHIND the approved reality.

## Impact

The change MODIFIES existing pinned behavior (not greenfield). Concretely:

| # | Quest mandate | Current behavior (conflicting) | Pinned by |
|---|---------------|-------------------------------|-----------|
| 1 | Council OPTIONAL (threshold-driven: >10 files, >400 lines, critical paths — wiring/, skills/, prompts/ — evaluated on task forecast, fallback design) | Council ALWAYS after design; arch-lint acta mandatory | orchestrator.md (rule 4, hooks #3, council-chain target flow), sdd-council.md, overlays/commands/sdd-continue.md (SUPPORT-CONDITIONAL), sdd-ff.md, workflow-contract spec, RED T32, T35 |
| 2 | Changelog POST-archive ("as today") | Archive-close fixed persist order: verify → changelog PRE-archive → retro → archive | overlays sdd-tool-integration (orchestrator.md embedded block), sdd-changelog SKILL.md (input = verify-report pre-archive; absent archive-report → blocked), RED T48, workflow-contract spec |
| 3 | Axis 2 only if a council ran (Q31: axis 1 always, axis 2 acta verification title-by-title only when acta exists) | Arch-lint axis 2 ALWAYS, acta MANDATORY, fail-closed if missing | sdd-architecture-lint SKILL.md, RED T35, spec scenarios |
| 4 | Preflight 5th group: worktree confirmation per session | 4 preflight groups | orchestrator.md preflight section |
| 5 | Draft PR from start on `sdd/{change}` + incremental commits per work unit + mark-ready at close | No PR lifecycle at all | (new behavior) |
| 6 | Bootstrap pre-resolutions at session start (sdd-tool canonical path `$HOME/.config/sdd-own/bin/sdd-tool`, sdd-rfc-author prompt path, skills) | Ad-hoc resolution; recent seek "sdd-tool not found in PATH" evidence | orchestrator.md sections; setup.sh 5d-2 builds to `$ENV_DIR/bin` wait |
| 7 | Hard gate ALWAYS pre-archive: native sdd-attempt ledger + adversarial fresh-eyes verifier (specs vs code) | F4 post-verify RDD hook only when RDD ON; no adversarial verifier | — (new; design fork: which agent executes) |
| 8 | Return edge ≤2 rounds to origin phase, then human report | Gatekeeper re-runs once then stops | orchestrator.md gatekeeper/rule text, diagram hv→fix_loop→apply |
| 9 | Quest schema: 3 sections (product/architecture/general) × 9 slots; needs-changes relaunch = affected branch only, ≤50 budget, pass existing quest.md path | Flat 9-slot single RFC; relaunch details unspecified | sdd-quest SKILL.md, sdd-rfc-author.md |

Affected files (grouped, non-exhaustive):

- `wiring/prompts/sdd/orchestrator.md` — flow contract restate (single authoritative section), preflight 5 groups, bootstrap section (Q40), PR-draft-from-start section, hard gate section, council-optional rule, changelog post-archive in sdd-tool-integration block, return edge, handoff paths ("locations never contents").
- `wiring/prompts/sdd/sdd-rfc-author.md` — 3-section schema (product/architecture/general), one author affects 3 sections in one pass, needs-changes relaunch with new Q&A + existing quest.md path.
- `wiring/prompts/sdd/sdd-council.md` — ALWAYS → OPTIONAL trigger language (machinery stays).
- `wiring/opencode.sdd.json` — possibly a hard-gate verifier agent (new) OR reuse of existing `jd-*`/`review-*` allow-list entries; `subagent_depth: 2` (R1) stays.
- `skills/sdd-quest/SKILL.md` — Step 6 schema → 3-section; gate `## Approval:` stays.
- `skills/sdd-changelog/SKILL.md` — input flips verify-report (pre-archive) → archive-report (post-archive).
- `skills/sdd-architecture-lint/SKILL.md` — axis 2 conditional (skip when no council; fail-closed only when council ran but acta unreadable).
- `skills/sdd-council/SKILL.md` (installed copy + repo source if present) — trigger language.
- `overlays/commands/sdd-new.md`, `sdd-continue.md`, `sdd-ff.md` — gateway order, worktree+PR draft, council optional, PR-ready close.
- `tests/run_red_checks.sh` — rewrite T32/T35/T48 greps; add T49+ pins (bootstrap pre-resolve, quest 3-section schema, PR-draft-from-start, hard gate, preflight 5th group, threshold triggers).
- `openspec/specs/workflow-contract/spec.md` — MODIFIED requirements (council-chain target flow, archive-close order, arch-lint axis 2) + ADDED (hard gate, bootstrap, PR lifecycle, preflight 5th group, thresholds, quest schema).
- `docs/diagrams/sdd-workflow-unified.html` (+ `.visual-check.json`, JSON IR) — untracked in main repo; this change must ADD them to the PR (reference + deliverable evidence).
- `README.md` — diagram reference (currently embeds `sdd-flow.*`; the unified diagram replaces it as the flow reference).

## Approaches

1. **Contract-first, minimal-touch (recommended)** — Restate the flow contract ONCE as a single authoritative "Flow Contract" section in the orchestrator (mirroring quest §3), then make targeted deltas everywhere else: flip council to optional, flip changelog to post-archive, conditionalize axis 2, add 5th preflight group, add worktree+PR + hard-gate hooks that reference the contract. Rewrite only T32/T35/T48 greps; add T49+ for new pins. Spec deltas as MODIFIED/ADDED requirements.
   - Pros: single source of truth; smallest diff surface; T31/F4 byte-stability preserved; contradictions (the two existing changelog timings) eliminated structurally, not patched.
   - Cons: orchestrator section still grows (~+80–120 lines); discipline needed to avoid re-embedding contract fragments in overlays.
   - Effort: Medium.

2. **Wholesale rewrite of the SDD Workflow block** — Rewrite the orchestrator SDD Workflow section from scratch to the quest flow; sync all skills/prompts in one pass; rewrite RED T32/T35/T48 + new checks.
   - Pros: cleanest end-state text; no legacy vestiges.
   - Cons: largest diff; high risk to T31 byte-stable F4 pins and council hooks; harder review; the F4/RDD interplay (must stay byte-stable) makes partial rewrite unavoidable anyway.
   - Effort: High.

3. **Hook-only (no contract restate)** — Keep current section structure; bolt on the new phases as hooks (worktree+PR hook, hard-gate hook, bootstrap section) without reordering main text; minimal spec delta.
   - Pros: smallest orchestrator diff.
   - Cons: repeats the existing contradiction failure mode (two changelog timings already disagree today); contract fragments stay distributed; new RED pins harder to write against scattered text.
   - Effort: Low-Medium (but highest ongoing debt).

## Recommendation

**Approach 1 (contract-first, minimal-touch).** The quest's Section 3 already IS the flow contract — mirror it once in the orchestrator and reference it from every changed skill/overlay. This structurally kills the changelog timing contradiction (quest §3 is binding: archive → changelog → retro → PR-ready) and keeps the F4/RDD byte-stable pins untouched. Sequence the implementation as:

1. Flip intimate deltas first (council optional + axis 2 conditional; changelog post-archive; preflight 5th group).
2. Additive sections (bootstrap Q40, worktree+PR draft, hard gate, return edge, quest 3-section schema in sdd-quest + sdd-rfc-author).
3. Rewrite T32/T35/T48; add T49+ pins; update workflow-contract spec (MODIFIED + ADDED requirements).
4. Add `docs/diagrams/sdd-workflow-unified.*` to the change (they are untracked in main and must ship with the PR).

Design forks to resolve in propose/design (quest does not decide):

- **Council ↔ arch-lint sequencing**: quest §3 lists arch-lint then council; Q31 makes axis 2 depend on the acta. Recommended reading (matches the validated diagram): design → arch-lint (axis 1) → council (if triggered, post-arch-lint) → arch-lint axis 2 on the acta → tasks. Confirm in proposal.
- **Hard-gate verifier executor**: (a) new wiring sub-agent (e.g. `sdd-hard-gate`), (b) reuse existing `jd-*`/`review-*` allow-list entries with adversarial framing, (c) native `gentle-ai sdd-verify-validate` ledger + orchestrator-side fresh-eyes re-read of specs vs code. Each has different wiring/`OWN_PROMPTS` implications.
- **Council trigger basis**: council fires BEFORE tasks exist, so its threshold evaluation uses the design (fallback) unless the implementer moves the forecast computation earlier (adversarial to current pipeline). Recommend: document fallback-to-design as the binding reading.
- **PR tools**: PR lifecycle uses `gh-git-mcp`/github MCP (local supervised two-phase) — no raw `git`/`gh` bash (no-git-crudo rule). Setup.sh 5d provisions the MCP; preflight group 5 must verify `gh-git-mcp` availability before the change starts PAST phase 0.

## Risks

- HIGH — Council flip touches the most pinned text (T32/T35, spec scenarios, three overlays, two skills); any missed pin FAILS the RED suite. Mitigate: contract-first restate, one flip at a time, run `tests/run_red_checks.sh` after each.
- HIGH — Changelog timing flip contradicts the PREVIOUS archived change (`sdd-tool`, 2026-09-09) which introduced pre-archive ordering; T48 + workflow-contract "Archive-close fixed persist order" + sdd-changelog SKILL.md must all flip together or verification deadlocks.
- MEDIUM — `sdd-phase-common.md` is NOT in the repo (lives in `~/.config/sdd-own/skills/_shared/` and `~/.agents/skills/_shared/`); if the change touches language-domain-contract/quest-explore-contract overlay blocks, it edits `overlays/shared/sdd-phase-common.md` (which strips+appends onto the installed base). Verify sync wiring before touching.
- MEDIUM — F4 post-verify RDD hook text must stay byte-stable (T31); the hard gate must be ADDED around it, not replace it.
- MEDIUM — `sdd-workflow-unified.html` + `.visual-check.json` are untracked in main and absent from the worktree branch; forgetting to add them silently drops deliverable evidence.
- LOW — sdd-rfc-author is prompt-defined (not a skill; recent seek confirms it is missing from `~/.agents/skills`); wiring references it via `wiring/prompts/sdd/sdd-rfc-author.md` — ensure `OWN_PROMPTS` deployment + symlinks remain intact (`T34`).
- LOW — Diagram/README: current README embeds `sdd-flow.*` as "the flow"; unified diagram replaces it as reference; keep both or update pointer explicitly.

## Ready for Proposal

Yes — for orchestrator to tell the user: the exploration is complete, the change is NOT greenfield (it flips two previously archived behaviors: council-always→optional and pre-archive→post-archive changelog, plus the flat→3-section RFC schema), and the proposal phase must fix the four design forks above (council/arch-lint sequencing, hard-gate executor, council trigger fallback basis, PR toolchain availability check).