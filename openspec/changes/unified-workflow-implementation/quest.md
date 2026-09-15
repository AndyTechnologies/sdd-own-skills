# Quest: unified-workflow-implementation

## Approval: approved

## RFC

> Language-agnostic behavior and contracts. No stack is stated unless the user confirmed it as a requirement (none did).
> The approved RFC is the **binding mandate** for `explore` (what to validate/resolve) and the binding source of truth for `sdd-propose` and `sdd-spec`.

### Section 1 — Product

#### Goals / Non-goals

**Goals**
- Implement the complete SDD flow of the provided diagram (`docs/diagrams/sdd-workflow-unified.html`) in this repository: request → preflight (with worktree confirmation) → init → worktree + PR draft → quest → RFCs authored by a sub-agent → single gate → explore → propose → spec → design → tasks → apply TDD → verify → hard gate → archive → changelog + retro + PR ready.
- Produce exactly one `quest.md` containing the three RFC sections (product, architecture, general), authored by the `sdd-rfc-author` sub-agent, approved through a single human gate.
- Every phase runs inside the confirmed worktree; openspec artifacts live inside the worktree and travel with the PR.
- A draft PR exists from the start on branch `sdd/{change-name}`, with incremental commits per work unit.
- Close sequence: archive → automatic changelog (post-archive, as today) → retro persisted via `sdd-tool` (as today) → PR marked ready; **merge is ALWAYS human**.

**Non-goals**
- No per-RFC human gates — the three RFC sections are approved together in one gate, never three.
- No work in the main repository once the worktree is confirmed.
- No automatic PR merge (human always merges).
- No format contracts living inside the orchestrator; the RFC format lives inside the RFC author's own prompt/skill.
- No mid-phase path lookups (canonical paths are pre-resolved at session start).
- Explore is not skipped: it runs after the quest gate and before propose.

#### Domain Terminology & Business Rules

- **Quest**: the RFC pre-pass producing `quest.md` with three RFC sections.
- **RFC**: a language-agnostic statement of behavior and contracts, authored by `sdd-rfc-author` from the collected Q&A — never an implementation or stack choice.
- **Gate (quest)**: the single human approval point on the consolidated quest summary. ✅ approves the whole quest; ❌ re-opens only the affected RFC section (Q5/Q27).
- **Worktree**: the per-change execution root for all phases (this change: `/home/andy/.agent_worktrees/sdd-own-skills/unified-workflow-implementation`, branch `sdd/unified-workflow-implementation`). Confirmed per session during preflight; reused for the same change; conflicts are asked (Q7/Q33/Q34).
- **Hard gate**: the ALWAYS-on quality gate before archive: native attempt ledger (`sdd-attempt`) + adversarial verifier with fresh eyes (specs vs code) (Q15/Q32).
- **Return edge**: on phase failure, control returns to the origin phase; max 2 correction rounds, then a report to the human (Q16/Q19).
- **Preflight**: 4 decision groups + the per-session worktree confirmation as a 5th group, asked together (Q33).
- **Council**: optional post-design review (3 lenses + acta); when triggered it runs the FULL council (Q11/Q28).
- **Arch-lint**: mandatory post-design validation — axis 1: requirements/scope; axis 2: acta, only if a council ran (Q31).
- **Task forecast**: the basis for trigger thresholds (>10 files, >400 lines, or critical paths `wiring/`, `skills/`, `prompts/`), with fallback to design (Q12/Q29/Q30).

#### Contracts (Inputs / Outputs / Events / External)

- **Input**: user request to implement the unified SDD workflow; the diagram `docs/diagrams/sdd-workflow-unified.html` is the reference sequence.
- **Event — preflight**: per session, the orchestrator asks the 4 decision groups plus worktree confirmation (5th group) in one pass (Q33).
- **Event — quest gate**: orchestrator presents the consolidated quest summary; the human approves (✅ all) or rejects (❌ affected section re-opens) (Q5/Q27).
- **Output — quest**: one `quest.md` with 3 RFC sections at `openspec/changes/{change-name}/quest.md`, plus the engram mirror (Q4).
- **Event — PR**: draft PR created at the start on branch `sdd/{change-name}` with incremental commits (Q8).
- **Event — close**: archive → automatic changelog (post-archive, as today) → retro persisted via `sdd-tool` → PR listed as ready; merge remains human-only (Q17/Q38/Q39).
- **External**: all openspec artifacts live inside the worktree and travel with the PR (Q20/Q37).

#### Invariants & Validation

- One quest, one gate: the 3 RFC sections are approved together, never as 3 gates (Q5).
- The approved `quest.md` is the binding mandate for explore, propose, and spec.
- RFCs are ALWAYS authored by sub-agents; the orchestrator never carries the RFC format contracts (Q2/Q21).
- Work never runs in the main repository once the worktree is confirmed.
- Handoffs carry locations (paths), never artifact contents — except the inline Q&A handed to the RFC author (Q24/Q26).
- Apply follows strict TDD: RED→GREEN per work unit, one commit per unit (Q14).

#### Failure Cases & Edge Cases

- Phase failure → return edge to the origin phase, max 2 correction rounds; a 3rd failure → report to the human (Q16/Q19).
- Gate rejection (❌) → re-opens only the affected RFC section (Q5); needs-changes → targeted re-interview on the affected branch + relaunch `sdd-rfc-author` with the new Q&A and the existing `quest.md` path (Q36).
- Worktree conflict → ask the human; same-change worktree → reuse (Q7/Q34).
- PR risk (>400 lines) → ask-on-risk human gate (Q18).
- `command not found` for `sdd-tool` mid-phase → forbidden; canonical paths are pre-resolved at session start (Q40).

#### Security / Privacy / Performance / Operational

- **Operational**: all phases run with `--cwd <worktree>` (Q20/Q37).
- **Quality**: hard gate always active before archive — native ledger (`sdd-attempt`) + adversarial verifier with fresh eyes (Q15/Q32).
- **Cost control**: council and related activities trigger from the task forecast (fallback: design), not by default (Q11/Q12/Q28/Q29/Q30).
- **Pre-retro**: behaves as `sdd-tool` does today (retro lookup) (Q6).

#### Alternatives & Trade-offs

- Council optional vs mandatory today: lower overhead; when triggered it runs the full council and corrects design findings in max 2 rounds (Q11/Q12/Q28).
- Single quest gate vs per-RFC gates: fewer human interruptions, risk concentrated in one approval point (Q5).
- RFCs authored by sub-agent vs by orchestrator: clean separation (lean orchestrator) at the cost of handoff ceremony (Q2/Q21).
- Bootstrap path pre-resolution vs on-demand lookup: upfront cost, zero mid-phase failures (Q40).

#### Acceptance Criteria (measurable)

- `quest.md` exists at `openspec/changes/unified-workflow-implementation/quest.md` with exactly 3 RFC sections, each carrying the full quest schema, and `Approval: approved`.
- The quest gate was explicitly approved by the human before explore started.
- The full flow (request → preflight → … → PR ready) runs with zero mid-phase path lookups and zero `command not found` failures for `sdd-tool`.
- All phases execute with `--cwd <worktree>`; no artifacts are written to the main repository once the worktree is confirmed.
- The PR exists as draft from the start on `sdd/unified-workflow-implementation` with incremental commits; merge stays human-only.
- The hard gate (native ledger + adversarial verifier) always runs before archive; arch-lint always runs post-design.

#### Unresolved Questions (blocking)

- **None.** All interview branches were resolved (39 interview questions + the Q40 operational batch).
- Non-blocking runtime determinations (resolved by the pipeline at their phases): council on/off per forecast thresholds; PR ask-on-risk decision per line count.

---

### Section 2 — Architecture

#### Goals / Non-goals

**Goals**
- **Wiring contract**: orchestrator orchestrates only — it interviews, passes locations, and marks approval; `sdd-rfc-author` (a sub-agent) writes the RFCs (Q2/Q21).
- **Handoff discipline**: every phase hands off locations (paths), never artifact contents — the sole exception is the inline Q&A handed to the RFC author (Q24/Q25/Q26).
- **Bootstrap**: pre-resolve canonical paths (tools, sub-agent prompts, skills) at session start; zero lookups in the middle of phases (Q40).
- **Persistence**: hybrid — one `quest.md` (openspec, native source of truth) + engram mirror for recovery (Q4).

**Non-goals**
- No RFC format contracts inside the orchestrator; the format lives inside the author's prompt/skill (Q22).
- No skill-directory lookup for `sdd-rfc-author` at runtime (it is a prompt-defined sub-agent, not a `~/.agents/skills` skill) (Q40).
- No content passing in handoffs.

#### Domain Terminology & Business Rules

- **Handoff**: Q&A inline + destination path; the agent is referenced by name, never by an explicit skill path (Q21/Q23).
- **`sdd-rfc-author`**: a SUB-AGENT defined by prompt at `wiring/prompts/sdd/sdd-rfc-author.md` (installed at `~/.config/sdd-own/prompts/sdd/sdd-rfc-author.md`), NOT a skill under `~/.agents/skills`. The runtime launches it by `subagent_type` with the prompt loaded; the orchestrator must not search for a "skill" of that name (Q40).
- **`sdd-tool`**: invoked by its canonical path `$HOME/.config/sdd-own/bin/sdd-tool` (or the PATH must include it); the orchestrator contract declares it explicitly — a `command not found` mid-phase is a contract violation, not an error case (Q40).
- **One author writes the 3 sections**: a single `sdd-rfc-author` produces product, architecture, and general in one pass (Q2/Q21).
- **Explore** receives the `quest.md` PATH, never its content (Q9/Q24).
- **Propose**: `sdd-propose` (sub-agent) writes `proposal.md`, receiving paths (quest + explore), and returns its location (Q10/Q25).
- **Spec/design**: path-based handoffs — spec receives the proposal path; design receives proposal + spec paths (Q26).

#### Contracts (Inputs / Outputs / Events / External)

- **Quest input to the author**: Q&A pairs + change/problem statement + change name + artifact store mode + destination path (per the `sdd-rfc-author` contract).
- **Quest output**: `quest.md` at `openspec/changes/{change-name}/quest.md` with the `## Approval:` header — the ONLY gate `sdd-continue` reads to decide re-run vs skip vs proceed.
- **Enram mirror**: topic `sdd/{change-name}/quest`, type `architecture`, `capture_prompt: false` (Q4).
- **Handoff — explore**: receives the approved `quest.md` path after the gate, before propose (Q9/Q24).
- **Handoff — propose**: receives quest + explore paths; writes `proposal.md`; returns the location (Q10/Q25).
- **Handoff — spec/design**: path-based (proposal → spec; proposal + spec → design) (Q26).
- **Event — quest gate**: orchestrator presents the summary; human approves → orchestrator marks `Approval` (or relaunches `sdd-rfc-author` with `needs-changes`) (Q27).
- **Event — council (if triggered)**: full council (3 lenses + acta) evaluating the EXISTING design; corrects findings in max 2 rounds (Q11/Q12/Q28/Q30).
- **Event — arch-lint**: ALWAYS mandatory post-design; axis 1 (requirements/scope) always; axis 2 (acta) only if a council ran (Q31).
- **Event — hard gate**: ALWAYS before archive — native ledger (`sdd-attempt`) + adversarial verifier, fresh eyes, specs vs code (Q15/Q32).
- **External**: worktree from `sdd-init`/preflight; all openspec artifacts inside the worktree travel with the PR (Q20/Q37).

#### Invariants & Validation

- All phases run with `--cwd <worktree>`; openspec artifacts live inside the worktree (Q20/Q37).
- Handoffs pass locations, never contents (except the inline Q&A to the RFC author).
- RFCs are always written by sub-agents; a single author writes the 3 sections; the format never contaminates the orchestrator (Q2/Q21/Q22).
- Work never runs in the main repository once the worktree is confirmed.
- Init is silent, as today: run `sdd-init` only if the context is missing (Q35).
- Preflight asks the 4 decision groups + the worktree confirmation together (Q33).
- Worktree: reuse when the change is the same; ask when there is a conflict (Q7/Q34).
- The interview runs under the hard 50-question budget; it is never exceeded silently (loop guard).

#### Failure Cases & Edge Cases

- **needs-changes**: targeted re-interview on the affected branch only; relaunch `sdd-rfc-author` with the new Q&A and the path of the existing `quest.md` (Q36).
- Phase failure: return edge to the origin phase, max 2 rounds; then a report to the human (Q16/Q19).
- Council findings: the council corrects the existing design, max 2 rounds (Q12/Q30).
- Missing canonical path (e.g. `sdd-tool`) mid-phase: prohibited by the bootstrap contract — paths are pre-resolved at session start (Q40).

#### Security / Privacy / Performance / Operational

- **Bootstrap (Q40, mandatory)**: the new orchestrator contract pre-resolves at session start the canonical paths of tools (`sdd-tool` → `$HOME/.config/sdd-own/bin/sdd-tool` or PATH), sub-agent prompts (`sdd-rfc-author` → `wiring/prompts/sdd/sdd-rfc-author.md` / `~/.config/sdd-own/prompts/sdd/sdd-rfc-author.md`), and skills. The flow NEVER wastes time looking them up mid-phase.
- **Trigger thresholds**: evaluated on the task forecast (fallback: design) — >10 files, >400 lines, or critical paths (`wiring/`, `skills/`, `prompts/`) (Q12/Q13/Q29/Q30).
- **Hard gate ledger**: native `sdd-attempt`; adversarial verification with fresh eyes (Q15/Q32).
- **Pre-retro**: unchanged from today (`sdd-tool` retro lookup) (Q6).

#### Alternatives & Trade-offs

- Sub-agent-authored RFC vs orchestrator-authored: isolation of format contracts vs added handoff ceremony (Q2/Q21/Q22).
- Path-based handoffs vs content-based: lean orchestrator; sub-agents read their dependencies from the backend (Q24/Q25/Q26).
- Hybrid persistence (openspec native + engram mirror) vs single store: team-shareable files + cross-session recovery at higher token cost (Q4).
- Council optional vs always-on: cost control vs coverage; when triggered it runs complete (Q11/Q28).

#### Acceptance Criteria (measurable)

- `quest.md` contains the `## Approval: approved` header and the 3 RFC sections, each with the full quest schema (9 slots).
- The engram mirror exists at topic `sdd/unified-workflow-implementation/quest` with `capture_prompt: false`.
- The orchestrator bootstrap resolves `sdd-tool`, the `sdd-rfc-author` prompt, and the skills paths BEFORE any phase runs.
- No handoff in the flow passes artifact content instead of a path — except the quest Q&A handoff.
- `Approval: approved` is the exact gate `sdd-continue` reads to skip re-running quest.

#### Unresolved Questions (blocking)

- **None.** All wiring branches resolved (39 interview questions + Q40 batch).

---

### Section 3 — General (Synthesis)

#### Goals / Non-goals

**Goals**
- A fully wired unified SDD pipeline in this repository realizing the diagram, with quest as the binding pre-pass and every downstream phase traceable to the approved `quest.md`.
- Single quest gate; hard gate ALWAYS on before archive; merge ALWAYS human.
- Orchestrator stays a pure orchestrator: locations in, approvals out, zero format contracts.

**Non-goals**
- No automatic merges; no RFC authoring by the orchestrator; no mid-phase discovery of tool/sub-agent paths.

#### Domain Terminology & Business Rules

- **Binding mandate**: the approved quest is the mandate the explore phase consumes and the binding source of truth for `sdd-propose` AND `sdd-spec` — not a recommendation (invariant).
- **Orchestrator rule**: it only orchestrates — passes locations, never contents (the sole exception is the inline Q&A to the RFC author) (invariant).
- **Gate rule**: one human gate per quest (the 3 RFC sections together), never 3 gates (Q5, invariant).
- **Worktree rule**: once confirmed, work never runs in the main repository (invariant).
- **RFC authoring rule**: RFCs are ALWAYS written by sub-agents; the format lives inside the author's prompt/skill (Q2/Q21/Q22, invariant).

#### Contracts (Inputs / Outputs / Events / External)

- **Flow contract** (Q1, as user-confirmed): request → preflight (4 groups + worktree confirmation) → init (silent if present) → worktree + PR draft → quest (RFCs by sub-agent) → single gate → explore (receives quest path) → propose (writes `proposal.md`) → spec → design → arch-lint (mandatory) → council (optional, threshold-driven) → tasks (forecast) → apply TDD (RED→GREEN per unit, commit per unit) → verify → hard gate (native ledger + adversarial) → archive → changelog (automatic, post-archive) → retro (`sdd-tool`, as today) → PR ready; human merge (Q8/Q14/Q17/Q31/Q32/Q38/Q39).
- **External**: draft PR on `sdd/{change}` from the start; changelog post-archive as today; all artifacts inside the worktree travel with the PR (Q8/Q17/Q20/Q37).
- **Handoff contract**: all phases hand off paths, never contents; RFC format stays inside the author's prompt/skill (Q22/Q23/Q26).

#### Invariants & Validation

- The approved quest is the binding mandate for explore, propose, and spec.
- The orchestrator only orchestrates: passes locations, never contents (except the inline Q&A to the RFC author).
- One human gate per quest (the 3 RFCs together), not 3 gates.
- Work never runs in the main repository once the worktree is confirmed.
- RFCs always written by sub-agents; the format never contaminates the orchestrator.

#### Failure Cases & Edge Cases

- Any phase failure returns to the origin phase; max 2 rounds; then a report to the human (Q16/Q19).
- Gate ❌ re-opens only the affected section; needs-changes re-interviews the affected branch using the existing `quest.md` path (Q5/Q36).
- Threshold-driven events (council, PR ask-on-risk) fire from the task forecast (fallback: design) at their respective phases (Q18/Q29/Q30).

#### Security / Privacy / Performance / Operational

- Canonical-path bootstrap at session start (tools + sub-agent prompts + skills); zero mid-phase lookups (Q40).
- Hard gate ALWAYS: native ledger + adversarial verifier (Q15/Q32).
- All phases `--cwd <worktree>`; artifacts inside the worktree (Q20/Q37).
- Human gates total exactly 3: (1) worktree confirmation per session, (2) quest gate, (3) PR ask-on-risk (>400 lines) — plus the always-human merge (Q18).

#### Alternatives & Trade-offs

- Quest as a hard binding pre-pass (vs optional clarification): higher upfront interview cost, dramatically fewer mid-flight surprises downstream (Q1/Q5).
- Sub-agent RFC authoring (vs orchestrator-inline): clean separation of concerns at the price of one extra handoff (Q2/Q21).
- Single gate (vs per-section gates): the human slows down once, not three times (Q5).

#### Acceptance Criteria (measurable)

- `quest.md` exists at the canonical path with `Approval: approved` and the 3-section × full-schema structure.
- The flow's wiring pre-resolves canonical paths at session start and never passes artifact contents in handoffs.
- Explore, propose, and spec can trace their mandate to the approved `quest.md`.
- The flow completes with exactly 3 human gates + human merge.
- The hard gate (ledger + adversarial verifier) and arch-lint run unconditionally at their mandated points.

#### Unresolved Questions (blocking)

- **None blocking.** Non-blocking runtime determinations resolved by the pipeline at the phase: council on/off and the PR ask-on-risk gate fire per the evaluated thresholds.

---

## Interview Coverage (traceability — Q&A mapped to contracts)

| Q | Decision | Contract location |
|---|----------|-------------------|
| Q1 | Scope: full flow | Product Goals; General flow contract |
| Q2/Q21 | RFCs always by sub-agent; one author for 3 sections; format inside author's prompt; handoff = Q&A inline + path, agent by name | Architecture contracts/invariants |
| Q3 | Format: full quest schema ×3 | Whole document structure |
| Q4 | Single quest.md (3 sections) + engram mirror | Architecture persistence contract |
| Q5 | Single gate on quest.md (✅ all / ❌ affected section) | Product + General gate rule |
| Q6 | Pre-retros as today (retro lookup) | Product ~ sdd-tool |
| Q7 | Worktree confirmation per session; reuse same change; ask on conflict | Product + Architecture |
| Q8 | Draft PR from start on sdd/{change}, incremental commits | Product contracts |
| Q9 | Explore after gate, before propose; receives quest.md path | Architecture handoffs |
| Q10/Q25 | sdd-propose writes proposal.md, receives paths, returns location | Architecture handoffs |
| Q11/Q28 | Council optional; full council + acta when active | Product + Architecture events |
| Q12/Q13/Q29/Q30 | Thresholds on task forecast (fallback design): >10 files, >400 lines, critical paths | Product + Architecture |
| Q14 | Work units RED→GREEN, commit per unit, strict TDD | Product invariants; General flow |
| Q15/Q32 | Hard gate ALWAYS: native ledger + adversarial verifier | Product + Architecture |
| Q16/Q19 | Fix loop: return edge to origin phase, max 2, then human report | Product + General failures |
| Q17/Q38/Q39 | Close: archive → changelog auto → retro → PR ready; merge human | Product contracts |
| Q18 | 3 human gates: worktree, quest, PR risk | Product + General operational |
| Q20/Q37 | All phases --cwd worktree; artifacts inside worktree | Product + Architecture |
| Q22 | RFC format inside sub-agent prompt/skill | Architecture terminology |
| Q23 | Handoff: Q&A inline + path, skill by name | Architecture terminology |
| Q24 | explore receives quest.md path, never content | Architecture handoffs |
| Q26 | Paths in all handoffs (spec ← proposal; design ← proposal+spec) | Architecture handoffs |
| Q27 | Gate: orchestrator presents summary, marks Approval / relaunches with needs-changes | Architecture event |
| Q31 | Arch-lint ALWAYS post-design; axis 1 always, axis 2 if council | Architecture events |
| Q33 | Preflight: 4 groups + worktree confirmation (5th) | Product + Architecture |
| Q34 | Worktree reuse same change; ask on conflict | Product + Architecture |
| Q35 | Init guard silent; run sdd-init only if missing | Architecture invariants |
| Q36 | needs-changes: targeted re-interview + relaunch with new Q&A + existing quest.md path | Product + Architecture failures |
| Q40 | Bootstrap: pre-resolve canonical paths (sdd-tool path, sdd-rfc-author prompt, skills); zero mid-phase lookups; sdd-rfc-author is a prompt-defined sub-agent, not a skill | Architecture Operational (mandatory) |

## Envelope

- status: success
- approval: approved
- next_recommended: explore