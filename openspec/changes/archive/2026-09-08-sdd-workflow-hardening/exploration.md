# Exploration: sdd-workflow-hardening

## Current State

The Phase 0 contract text (approved and archived at `openspec/changes/archive/2026-09-07-sdd-workflow-contract/`) is **landed in the working tree but not yet committed** (`git status` shows `M wiring/prompts/sdd/orchestrator.md`, `M overlays/shared/sdd-phase-common.md`). Its surfaces today:

- `wiring/prompts/sdd/orchestrator.md` (repo-owned canonical, not Alan-managed) carries `### SDD Workflow Contract` rule 2 "Untrusted-data fail-closed" (line ~478), rule 3 "External-knowledge-gap research routing" (~480), the `### Research and Pre-Proposal Gate (MANDATORY)` section (~358), `### Organic Support Phase Hooks` with the research hook (~371), and the `SDD Edit-Authority Consent Relay` (~48-50).
- `overlays/shared/sdd-phase-common.md` carries the `shared-untrusted-data` block (lines 22-30, appended to `~/.agents/skills/_shared/sdd-phase-common.md` `[ok]`), plus `shared-no-git-crudo`, `shared-worktree-binding`, `shared-result-contract-strictness`, `shared-language-domain-contract`, `shared-quest-explore-contract`.
- The executor skills `sdd-tasks` (Alan base v2.0), `sdd-apply` (v3.0), `sdd-verify` (v3.0) are **real dirs** in `~/.agents/skills/` with **NO `sdd-own:` blocks yet** (verified: only sdd-design/explore/onboard/propose/spec have blocks). Enforcement is therefore **contract text only** — nothing yet operationalizes the shape requirements inside the phase skills.

Concrete enforcement gap (F1): the Phase 0 tasks artifact (`archive/.../tasks.md` lines 12-15) shows the current SWU emission format — a markdown table with "Focused test command / Runtime harness / Rollback boundary" columns holding **free-form single-line commands**. That is exactly the untrusted-data gap: no explicit start/finish/verification/rollback tokens, no machine-checkable shape. `sdd-apply` executes those commands (its "Hard Gate (All Modes): Work Unit Evidence" requires focused test command + result, runtime harness + result, rollback boundary — line 149-161) without any shape validation step, and `sdd-verify` consumes the resulting evidence claims (apply-progress) without delimited-shape validation.

## Affected Areas

- `overlays/skills/sdd-tasks/SKILL.md` — **NEW overlay file** (append-only, `sdd-own` marked) → sync target `~/.agents/skills/sdd-tasks/SKILL.md`. Switches SWU emission from prose columns to explicit closed-domain tokens + machine-checkable shape. Deadlines: Run que el archivo no existe en el repo (`skills/sdd-tasks/` is NOT in our tree; it is Alan's). The repo-side canonical source for OUR content is the overlay, not a `skills/` copy.
- `overlays/skills/sdd-apply/SKILL.md` — **NEW overlay file** → target `~/.agents/skills/sdd-apply/SKILL.md`. F1: shape-validation gate before executing any suggested command; fail-closed rejection. F3: config-protection + `blocked(edit_authority_missing)` alignment.
- `overlays/skills/sdd-verify/SKILL.md` — **NEW overlay file** → target `~/.agents/skills/sdd-verify/SKILL.md`. F1: evidence claims delimited + shape-validated, fail-closed duro (`not-verifiable` + block until apply corrects). F3: config-protection alignment.
- `wiring/prompts/sdd/orchestrator.md` — **F2: NO change required** (verified below). **F4: ONE additive hook clause required** (post-verify RDD, section mapping below). Read-only reference for pin wording otherwise.
- `overlays/shared/sdd-phase-common.md` — **NO change required**: `shared-untrusted-data` is the binding text skills align to; F1 does not reauthor it. F3's consent relay is orchestrator-owned (Edit-Authority Consent Relay); do not duplicate it in phase-common.
- `tests/run_red_checks.sh` — extend after T27 (line ~508) with Grupo 7 (T28+) contract/shape checks; update the coverage header map (lines 8-18).
- `overlays/commands/sdd-continue.md` — optional alignment only (see F2 verdict; recommend NOT touching).

## Impact

This change MODIFIES existing behavior (enforcement), so regressive impact applies:

- **Alan bases stay untouched** — overlay strip+append must remain byte-identical to Alan's base after strip. New ids must be globally unique (sync-skills.sh line ~721 dup check) and well-formed (start/end balance). Existing ids in use: `shared-*` (5), `sdd-explore-quest-validate`, `sdd-propose-quest-binding`, `sdd-spec-rfc-binding`, `sdd-onboard-quest-phase`, `design-domain-skills`, `cmd-sdd-*` (3).
- **`./sync-skills.sh --check` must stay clean** (AC) — new overlays install with `[aplicado]` on first real sync, `[up-to-date]` on re-run (idempotent). Host regression tests T05/T21 must keep passing.
- **Existing RED checks T01-T27 must keep passing** — they are the regression net; the new Grupo 7 must not disturb the sandbox/fake-API machinery.
- **Old-shape tasks artifacts fail closed at apply** — any in-flight change with a Phase-0-style prose SWU table (like the archived one) will now be rejected until tasks.md is regenerated in the new shape. This is the intended fail-closed semantics, but it is a real behavioral break for in-flight changes.
- **No executable surface changes** — prompt/overlay text only (same scope decision as Phase 0): no shell/process boundary, no permissions wiring (`permission` key untouched), no MCP registration.
- **F4: post-verify review preflight now actually runs** — once this change lands and RDD is ON, the 4R preflight fires after each verify PASS (consent relayed always). Behavior change for the user's workflow: reviews will ask instead of only running when requested by hand.

## Approaches

1. **Three new skill overlays + test extension (recommended)** — one overlay file per executor skill (tasks/apply/verify), each with 1-2 uniquely-id'd `sdd-own` blocks; F1 and F3 as separate ids per skill for atomic re-sync; tests T28+ as grep/shape probes.
   - Pros: matches the established overlay pattern of the other 5 executor overlays; per-skill files keep strip+append targets clear; separate F1/F3 ids allow independent evolution; sync mechanics unchanged.
   - Cons: 3 new overlay files + 2 new overlay blocks to maintain; wording must stay aligned with the shared block (risk of drift if rephrased).
   - Effort: Medium

2. **Single shared overlay block per concern in phase-common** — put F1 shape + F3 protection in `overlays/shared/sdd-phase-common.md` (new `shared-*` ids) instead of per-skill overlays.
   - Pros: one place to maintain; applies to every phase automatically.
   - Cons: contradicts the RFC's "overlays tasks/apply/verify" placement (quest F1: "overlays tasks/apply/verify + phase-common"; F3: "overlays apply/verify"); phase-common would duplicate the orchestrator's consent relay; blurs per-skill anchors (tasks emits, apply validates, verify consumes — different duties).
   - Effort: Low (writing), but wrong placement → rejected.

3. **Permissions-wiring enforcement** — add `permission` rules so apply/verify mechanically cannot edit configs.
   - Pros: strongest enforcement.
   - Cons: explicitly out of scope (non-goal: "no changes to permissions wiring... Phase 0 precedent"); would require editing the personal opencode config merge — against golden rule 2.
   - Effort: High + violates contract.

## Recommendation

**Approach 1.** Exact target files and ids:

| # | Overlay file (repo canonical) | Sync target (installed) | Block id | Concern |
|---|---|---|---|---|
| 1 | `overlays/skills/sdd-tasks/SKILL.md` (NEW) | `~/.agents/skills/sdd-tasks/SKILL.md` | `sdd-own:sdd-tasks-swu-shape` | F1 emission |
| 2 | `overlays/skills/sdd-apply/SKILL.md` (NEW) | `~/.agents/skills/sdd-apply/SKILL.md` | `sdd-own:sdd-apply-swu-validate` | F1 consumption |
| 3 | `overlays/skills/sdd-apply/SKILL.md` (same file) | same | `sdd-own:sdd-apply-edit-authority` | F3 apply |
| 4 | `overlays/skills/sdd-verify/SKILL.md` (NEW) | `~/.agents/skills/sdd-verify/SKILL.md` | `sdd-own:sdd-verify-evidence-shape` | F1 verify (fail-closed duro) |
| 5 | `overlays/skills/sdd-verify/SKILL.md` (same file) | same | `sdd-own:sdd-verify-edit-authority` | F3 verify |

Anchors (Alan base line numbers, exact; overlay appends at end and must reference the section it extends, same pattern as `sdd-explore-quest-validate`):

- **tasks block** extends: `### Suggested Work Units` table (base L97-102), "Task Writing Rules" (L129-142), Rules "Work-unit evidence" (L258-259). Must mandate, per work unit, a **delimited command block carrying the four explicit tokens `start` / `finish` / `verification` / `rollback`** (each a single shell command or explicit `N/A` + reason), a machine-checkable shape (mechanically verifiable before use), and NEVER free-form prose. Keep the canonical pins verbatim from the shared block: explicit tokens (start/finish/verification/rollback), machine-checkable shape, never free-form prose.
- **apply F1 block** extends: Step 2a workload decision (L80-102) + "Hard Gate (All Modes): Work Unit Evidence" (L149-161). Must mandate: shape-validate EVERY suggested command **before executing**; a malformed command (missing tokens, free-form prose) is NEVER executed and is rejected `fail-closed` (rejection + finding + blocked work unit); malformed commands are never approximated, paraphrased, or grouped. Reuse the shared-block pins `fail-closed`, untrusted DATA.
- **apply F3 block** extends: Status and Workspace Guard / `allowedEditRoots` (L55-63) + Section D return. Must mandate: apply NEVER edits config files outside the authorized edit roots without explicit consent (unprotected surfaces named: `wiring/opencode.sdd.json`, personal runtime configs); a `blocked(edit_authority_missing)` status relays the consent envelope losslessly with its two exits (fix tasks.md to stay inside authorized roots, or grant edit authority for the change); without a grant nothing is edited. Pin: `blocked(edit_authority_missing)`.
- **verify F1 block** extends: Hard Rules (L34-57) + Execution Steps (L75-85) + Decision Gates (L59-73). Must mandate fail-closed duro per the USER DECISION: evidence claims are delimited and shape-validated; malformed SWU evidence (apply-progress Work Unit Evidence lacking the required structure) is **discarded**, THAT work unit is reported `not-verifiable`, and verify **blocks until apply corrects it** — no degrade-and-continue, no tolerant interpretation, phase result never built on untrusted claims. Pins: delimited evidence, `not-verifiable`, block until apply corrects.
- **verify F3 block** extends: the report-write scope. Verify never edits config files outside the authorized edit roots without explicit consent; its only write target is the change's own `verify-report` (change artifact path / topic), and `blocked(edit_authority_missing)` applies the same two-exit relay.

Tests (Grupo 7, insert after T27 line ~508, before `stop_fake_api` line 510):

- **T28 — contract pins on repo canonical files** (deterministic, host-side, no sandbox): grep `wiring/prompts/sdd/orchestrator.md` + `overlays/shared/sdd-phase-common.md` + the 3 new overlay files for the quest's canonical pins: `fail-closed`, untrusted DATA, explicit tokens (start/finish/verification/rollback), delimited evidence, `not-verifiable`, `blocked(edit_authority_missing)`, one lossless grouped prompt, research `done` before propose, parallel-on-predeclare / serial-once-post-explore / no-gap-no-research.
- **T29 — synthetic SWU shape probe**: a small shell/`awk` probe that extracts the tasks overlay's mandated token list and asserts `start`/`finish`/`verification`/`rollback` are all present, and that the apply overlay's validation text contains the fail-closed rejection chain (malformed → never executed → rejection + finding + blocked work unit), verifying the shape can be mechanically checked (AC: "shape probe on a synthetic tasks artifact").
- **T30 — sync idempotency + id hygiene** (extends the T21 pattern): `./sync-skills.sh --check` after the overlays land reports zero desyncs; ids are unique across all overlay files (mirror of the sync dup check).
- **T31 — F4 hook pins on orchestrator.md** (host-side, deterministic): grep `wiring/prompts/sdd/orchestrator.md` for post-verify + RDD ON → preflight command shape (`review status --cwd <repo> --contract gentle-ai.review-integration/v2 --agent opencode --next-transition`), consent relayed losslessly, "never skips human authorization", decline → pipeline continues. Insert after T30.

**F2 verdict — NO orchestrator change needed beyond Phase 0.** Verified against the RFC point by point:

- Pre-declared gap → explore + research in parallel, both consuming the approved RFC: orchestrator rule 3 (line ~480) ✅.
- Post-explore gap → research serial exactly once before propose, reusing explore context: rule 3 ✅.
- No gap → no forced research (offer-next preserved): rule 3 + Research and Pre-Proposal Gate ("Offer `sdd-research` immediately after `sdd-explore`; selection makes completion mandatory") ✅.
- Propose gated on research `done` (or unselected) + decisions confirmed + evidence valid + store ready: Gate section (line ~358) ✅.
- Orchestrator owns discovery, never delegates the quest interview, never infers consent; unresolved automatic choices → one lossless grouped prompt with exact tokens, pending state persisted, STOP: Gate section + Organic hook 1 (line ~364) + Lossless Blocking Prompts ✅.
- The `sdd-continue` overlay (`cmd-sdd-continue-quest-support`) says research "runs BEFORE propose" and is triggered by "the explore/proposal gap" — it does not name the parallel-predeclare case, but the contract itself declares "this contract is the authority, and when a command conflicts, this section wins", and there is no conflict (merely less precision). **Recommendation: leave it unchanged** — touching it adds churn with zero AC value; the greppable pins all live in orchestrator.md.

## F4 — Post-verify RDD hook (added to scope by user decision, RFC re-approved)

**Concern**: the current orchestrator contract carries the COMPLETE Review Execution Contract (§Review Execution Contract, L103-204) and the RDD switch (§Receipt-driven development is user-owned, L663-673), but has NO "when": nothing ever invokes the preflight, so 4R only runs when the user asks by hand. Upstream contract (Alan's `sdd-apply.md` L161) makes the review lifecycle a PARENT-owned offer after independent verify — the executor never launches it.

**Mapping (verified live anchors)**:

- `wiring/prompts/sdd/orchestrator.md` — **NEW hook clause** between `### Automatic Mode Gatekeeper` (L377-403) and `### Native Runtime Attempt Authority` (L405). Hook text (mandate F4 + user decisions):
  - Trigger: after the gatekeeper PASSES `sdd-verify` AND RDD global ON → run the selectorless preflight `gentle-ai review status --cwd <repo> --contract gentle-ai.review-integration/v2 --agent opencode --next-transition`.
  - If START returns consent/v3 → relay it as a Lossless Blocking Prompt, **in interactive AND auto modes alike** — the review never skips human authorization; do NOT auto-accept in auto.
  - Consent **declined** → run the decline invocation candidate-scoped (never a kill switch), re-enter through STATUS, and the SDD pipeline CONTINUES to normal archive; delivery follows ordinary repository policy.
  - Consent granted → follow the existing Review Execution Contract (freeze → collect → 4R parallel via OpenCode Concurrent Reviewer Group → bounded correction → acknowledge burns authority). The hook does NOT alter that machinery — it merely triggers it.
  - No candidate / RDD OFF / review unavailable → informational no-op; never a pipeline block; never a fabricated approval.
- `tests/run_red_checks.sh` — extend **Grupo 7** with **T31**: grep the hook pins in `wiring/prompts/sdd/orchestrator.md` (post-verify + RDD ON → preflight command shape, consent relayed losslessly, "never skips human authorization", decline → pipeline continues). Insert after T30 (after the sync idempotency check), same host-side pattern.
- **NO change** to the Review Execution Contract sections (L103-204) themselves or to `gentle-ai review mode` switch semantics (L663-673) — verified by construction: the hook is additive, placed outside both.

**Non-goals (F4)**: no change to Native RAR lens planning/admission/closure; no review-gated archive (decline continues); no change to the 4R lens set, correction budget, or acknowledge burn.

**F2 verdict stands unchanged** (no orchestrator change for research routing); F4 introduces the ONLY orchestrator.md edit this change makes.

## Risks

- **Wording drift** between the new overlays and the `shared-untrusted-data` block / orchestrator rule 2 would break the "skills align exactly, no divergence" invariant. Mitigate by copying the canonical pins verbatim and grepping T28.
- **Old-shape in-flight tasks** get blocked at apply (intended fail-closed, but a surprise for any change mid-pipeline). Mitigate: orchestration should regenerate tasks.md before continuing an existing change; document in the proposal.
- **Sync errors on first real run** if an id collides or a marker is unbalanced — T30 + `--check` before deploy catch this; ids above are verified unique.
- **Alan base drift**: if `gentle-ai sync` updates the sdd-tasks/apply/verify bases (versions 2.0/3.0 today), the appended overlays still apply (append-only contract), but line anchors shift — the overlays must reference sections by heading, not line numbers.
- **No executable enforcement** — shape validation lives in prompt text; a non-conforming executor could bypass it. Accepted per the approved scope (skills/overlay enforcement, Phase 0 precedent; permissions wiring is a non-goal).
- **F4 review now auto-offers** — after verify, the 4R preflight fires when RDD is ON and consent is always relayed; this adds an interaction point per completed change. Accepted per the user decision (review never skips human authorization); decline keeps the pipeline moving.

## Ready for Proposal

Yes. The re-approved RFC (F1+F2+F3+F4) is implementable on this codebase: 3 new overlay files with 5 unique `sdd-own` ids on Alan's untouched bases, ONE additive orchestrator.md hook clause (post-verify RDD, §between gatekeeper and runtime-attempt sections), test Grupo 7 (T28-T31). Tell the user: scope F1+F2+F3+F4 is fully mappable to the existing overlay/sync mechanics; the only behavioral break to be aware of is that existing prose-shaped tasks artifacts will fail closed at apply until regenerated, and that after verify the 4R preflight will now actually run when RDD is ON (with consent relayed always).