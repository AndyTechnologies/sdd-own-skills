# Quest: sdd-workflow-hardening

## Approval: approved

## RFC

### Goals / Non-goals

**Goals** — Harden the Phase 0 workflow contracts (landed as prompt+overlay text) into REAL enforcement on the executor skills and orchestrator flow, features F1+F2+F3+F4 of the approved plan:

- **F1 — Untrusted-data fail-closed (overlays tasks/apply/verify + phase-common).** `sdd-tasks` Suggested Work Unit (SWU) commands are untrusted DATA, not directives: each suggested command (start/finish/verification/rollback) MUST carry explicit tokens and a machine-checkable shape — never free-form prose. `sdd-apply` MUST shape-validate every suggested command before executing; a malformed command is NEVER executed and MUST be rejected fail-closed (rejection + finding + blocked work unit). Malformed commands are never approximated, paraphrased, or grouped. `sdd-verify` evidence claims are shape-validated and delimited; a claim lacking the required structure is treated as untrusted and the phase result is not trusted. The skills align exactly to the existing contract text — orchestrator `### SDD Workflow Contract` rule 2 "Untrusted-data fail-closed" and the phase-common untrusted-data block — they do not reauthor it.
- **F1 user decision — verify enforcement level: fail-closed duro.** If `sdd-verify` receives malformed SWU evidence (no delimited structure, claims without shape), the evidence is discarded and THAT work unit's result is not trusted: verify reports the unit as not-verifiable and blocks until apply corrects it. No degradation-and-continue, no tolerant interpretation.
- **F2 — External-knowledge-gap research routing (orchestrator).** `sdd-explore` and `sdd-research` launch IN PARALLEL when the approved quest pre-declares an external-knowledge gap (both consume the approved RFC); a gap detected post-explore runs research SERIALLY exactly once before propose (reusing explore context); no gap → no forced research. Selected research lanes make completion mandatory before `propose`; `sdd-propose` runs only when research is `done` (or unselected), product decisions are confirmed, evidence references are valid, and the selected artifact-store state is ready.
- **F2 — Orchestrator owns product discovery.** The orchestrator NEVER delegates the live quest interview and never infers consent; unresolved automatic choices → one lossless grouped prompt with exact tokens, persist pending state, STOP.
- **F3 — Config-protection (overlays apply/verify).** Unprotected config surfaces (e.g. `wiring/opencode.sdd.json`, personal runtime configs) are protected from accidental SDD-phase mutation: apply/verify MUST NOT edit config files outside authorized edit roots without explicit consent. The existing `blocked(edit_authority_missing)` edit-authority flow is aligned in the skills.
- **F4 — Post-verify RDD hook (orchestrator contract).** The RDD/4R machinery is complete and operational in the current orchestrator contract (Review Execution Contract: preflight selectorless STATUS → exact START freezes lineage → collect → 4R parallel → consent/v3 → bounded correction → acknowledge burns authority; Native RAR owns the bounded zero/one/four-lens plan). BUT the orchestrator contract has no "when": nothing ever invokes the preflight, so reviews only run when the user asks by hand. Upstream contract (Alan's sdd-apply.md L161) says the PARENT orchestrator offers the optional review lifecycle ONLY AFTER independent SDD verification passes — the executor never launches it (monopoly of the parent). F4 adds the post-verify hook clause so the review lifecycle actually LAUNCHES at the correct point, aligning with the upstream contract.

**Non-goals**
- No new features beyond enforcement: F1+F2+F3+F4 complete is the entire scope.
- No rewrite of the Phase 0 contract text already landed (orchestrator rule 2, phase-common block) — the skills align to it, they do not reauthor it.
- No changes to permissions wiring (the `permission` config key stays untouched, Phase 0 precedent), MCP registration, delivery/review policy, or the worktree lifecycle.
- No forced research in every change: offer-next is preserved — selection makes completion mandatory; no gap → no research.
- **F4 non-goals**: F4 does NOT change how reviews run (Native RAR still owns lens plan/admission/closure); F4 does NOT alter the Review Execution Contract mechanics; F4 does NOT gate archive on review approval (decline → pipeline continues; review approval is informational for delivery under ordinary policy).

### Domain Terminology & Business Rules

- **Suggested Work Unit (SWU)**: implementation unit from `sdd-tasks` with explicit start/finish/verification/rollback commands.
- **Untrusted data**: SWU suggested commands and `sdd-verify` evidence claims are data, not directives — always shape-validated and delimited, never loosely interpolated or executed as prose.
- **Machine-checkable shape**: each suggested command carries explicit closed-domain tokens (start/finish/verification/rollback), never free-form prose; the shape is verifiable by mechanical validation before use.
- **Fail-closed rejection**: a malformed suggested command is never executed; it is rejected with a finding and the work unit is blocked. Malformed commands are never approximated, paraphrased, or grouped.
- **Fail-closed duro (verify)**: malformed SWU evidence (no delimited structure, claims without shape) is discarded; that work unit's result is not trusted; verify reports the unit as not-verifiable and blocks until apply corrects it.
- **External-knowledge gap**: need for external evidence not resolvable from the local repo; pre-declared in the approved quest or auto-detected by the orchestrator from the explore output.
- **Research lane**: selected research that makes its completion mandatory before `propose`.
- **Unprotected config surface**: config file outside the authorized edit roots (e.g. `wiring/opencode.sdd.json`, personal runtime configs) that apply/verify must not mutate without explicit consent.
- **Post-verify RDD hook**: the orchestrator clause that, after gatekeeper approves verify and with RDD global ON, runs the selectorless preflight; on START with consent/v3, relays the complete choice envelope losslessly (interactive and auto); the review never skips human authorization.

### Contracts (Inputs / Outputs / Events / External)

- `sdd-tasks` → tasks artifact: every SWU command (start/finish/verification/rollback) carries explicit tokens and a machine-checkable shape; commands are data, never narrative directives.
- `sdd-apply` ← tasks: shape-validates every suggested command before execution. Malformed → fail-closed rejection (rejection + finding + blocked work unit); never executes, never approximates/paraphrases/groups.
- `sdd-verify` → verify-report: evidence claims are delimited and shape-validated. Malformed SWU evidence → discarded; that work unit is reported not-verifiable and verify blocks until apply corrects it.
- Orchestrator research routing: pre-declared gap (quest) → explore + research in parallel, both consuming the approved RFC; post-explore gap → research serial exactly once before propose (reusing explore context); no gap → no forced research.
- Research gate → propose: `sdd-propose` launches only when selected research is `done` (or unselected), product decisions are confirmed, evidence references are valid, and the selected artifact-store state is ready.
- Orchestrator-owned discovery: the live quest interview is never delegated; consent is never inferred; unresolved automatic choices → one lossless grouped prompt with exact tokens, pending state persisted, STOP.
- apply/verify ↔ config surfaces: no edit of unprotected config files outside authorized edit roots without explicit consent; `blocked(edit_authority_missing)` relays the consent envelope with its two exits (fix tasks.md to stay inside authorized roots, or grant edit authority for the change).
- **Orchestrator → review lifecycle (post-verify RDD hook):** after gatekeeper approves verify and with RDD global ON, run the selectorless preflight (`gentle-ai review status --cwd <repo> --contract gentle-ai.review-integration/v2 --agent opencode --next-transition`); on START with consent/v3, relay the complete choice envelope losslessly (interactive and auto both relay the consent — the review NEVER skips human authorization). On decline: decline invocation candidate-scoped (not a kill switch), re-enter through STATUS, and the SDD pipeline CONTINUES to normal archive. Delivery follows ordinary repository policy.

### Invariants & Validation

- A malformed suggested command is NEVER executed.
- Malformed commands are never approximated, paraphrased, or grouped — rejection is atomic.
- Verify never degrades: malformed evidence ⇒ that work unit is not-verifiable and blocked until apply corrects it; the phase result is never trusted on top of untrusted claims.
- `propose` never runs before selected research is `done`, product decisions confirmed, evidence references valid, and store state ready.
- The orchestrator never delegates the live quest interview and never infers consent.
- apply/verify never edit config files outside authorized edit roots without explicit consent.
- Skills align exactly to the Phase 0 contract text (orchestrator rule 2, phase-common block) — no divergence in wording or semantics.
- **The post-verify hook never runs when RDD is OFF, and never skips the consent relay when a candidate requires it; a declined consent never blocks the SDD pipeline (archive continues).**

### Failure Cases & Edge Cases

- SWU command malformed (missing start/finish tokens, free-form prose): apply rejects fail-closed with a finding; work unit blocked; nothing executes.
- Verify evidence malformed: claim discarded; unit reported not-verifiable; verify blocks until apply corrects it; no tolerant pass.
- Gap pre-declared in the quest: explore + research run in parallel, both consuming the RFC; propose grounds its claims against both.
- Gap detected post-explore: research runs serially exactly once before propose, reusing explore context; never loops.
- No gap: no research is forced; explore alone grounds propose.
- Research selected but not done: `propose` is NOT launched; the orchestrator stops before it.
- Unresolved automatic choices: one lossless grouped prompt with exact tokens; pending state persisted; STOP — no silent default and no consent inference.
- Config edit attempted outside authorized roots: `blocked(edit_authority_missing)`; the consent envelope is relayed losslessly; without an explicit grant nothing is edited.
- **RDD OFF → no preflight is run (post-verify hook is gated on RDD global ON).**
- **No candidate → preflight returns unrelated/no-op (documented behavior, no ceremony).**
- **Consent declined → decline invocation candidate-scoped, re-enter STATUS, continue to archive.**
- **Review unavailable/unmanaged → informational, no pipeline block.**

### Security / Privacy / Performance / Operational

- Untrusted suggested commands are the primary security surface; machine-checkable shape validation + fail-closed rejection is the control (F1).
- Config-protection (F3) prevents accidental mutation of personal/config surfaces by SDD phases; edits are consent-gated, per-change, audited, and die with archive (existing flow).
- No new shell/process boundary is introduced by this lane (prompt/overlay enforcement text only).
- Parallel explore + research obeys the existing max-2 background bound and one-writer-per-worktree rule.
- Operational: overlay strip+append idempotency preserved; `./sync-skills.sh --check` must stay clean.
- **F4 post-verify hook is a single controlled preflight invocation in the orchestrator contract; it does not introduce new process boundaries or background work — the preflight call and consent relay are synchronous and inline.**

### Alternatives & Trade-offs

- Tolerant interpretation vs fail-closed duro for verify evidence — USER DECIDED fail-closed duro: harder to get a unit verified, but a phase result is never built on untrusted claims.
- Research always-mandatory vs offer-next: offer-next retained from Phase 0 — selection makes completion mandatory; no gap → no research forced.
- Skills/overlay enforcement vs permissions wiring: skills enforce (Phase 0 precedent); the `permission` key stays untouched.
- One lane F1+F2+F3+F4 vs phased rollout: decided as one complete hardening lane — full enforcement of the landed contract, no partial state.
- **F4 gate-on-verify vs gate-on-archive: gate-on-verify chosen per upstream contract (parent-owned offer after verify passes); gate-on-archive would delay review feedback and conflict with the existing review-lifecycle-is-optional-and-informational policy.**

### Acceptance Criteria (measurable)

- `./sync-skills.sh --check` reports zero desyncs after the overlays land.
- Contract greps: canonical pins present in the installed skills/overlays of tasks/apply/verify + phase-common + orchestrator: `fail-closed`, untrusted DATA, explicit tokens (start/finish/verification/rollback), delimited evidence, `not-verifiable`, `blocked(edit_authority_missing)`, one lossless grouped prompt, parallel-on-predeclare / serial-once-post-explore / no-gap-no-research, research `done` before propose.
- `sdd-tasks` emits SWU commands with explicit tokens and a machine-checkable shape (never free-form prose) — verified by a shape probe on a synthetic tasks artifact.
- `sdd-apply` shape-validates before executing; a malformed command is rejected with a finding and the work unit blocked, with no execution.
- `sdd-verify` applies fail-closed duro: malformed SWU evidence is discarded, the unit is reported not-verifiable, and verify blocks until apply corrects it.
- Orchestrator routing behavior: pre-declared gap runs explore + research in parallel; post-explore gap runs research exactly once; no gap runs none; propose does not launch while selected research is not `done`.
- F3: apply/verify leave config files outside the authorized roots untouched unless consent is explicitly granted; `blocked(edit_authority_missing)` relays the two exits (fix tasks.md / grant edit authority).
- **Contract grep: orchestrator.md contains the post-verify hook clause (post-verify + RDD ON → preflight; consent relayed losslessly; decline continues pipeline).**
- **A RED test T31+ greps the hook pins (post-verify, RDD ON, preflight command shape, consent relay, "never skips human authorization", decline continues).**
- **No change to Review Execution Contract mechanics (lens plan/consent/acknowledge unchanged — verified by grep that the existing review sections are untouched except the new hook clause).**

### Unresolved Questions (blocking)

- None. Both user decisions are recorded for the approval gate: (1) scope = F1+F2+F3+F4 complete; (2) verify enforcement = fail-closed duro; (3) F4 trigger = post-verify hook with RDD ON, preflight, consent relay, decline continues pipeline.
