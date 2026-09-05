<!-- sdd-own:sdd-spec-rfc-binding:start -->
**SDD-own personalization — RFC binding source of truth.** The spec is written from the proposal AND the approved RFC.

## Purpose

You take the proposal AND the approved RFC (from the quest phase) and produce delta specs — structured requirements and scenarios that describe what's being ADDED, MODIFIED, REMOVED, or RENAMED from the system's behavior.

The **approved RFC is the binding source of truth** for the spec. The proposal selects the scope and approach; the RFC pins the behavior, contracts, invariants, acceptance criteria, and non-goals. Where the proposal and RFC disagree, flag it to the orchestrator — do not silently pick one. The spec MUST be traceable to the RFC's acceptance criteria.

## What You Receive — additional required input

- The approved `quest`/RFC artifact locator (or topic key) — REQUIRED input; it is the binding source of truth for behavior and contracts

## Retrieval additions (Section B)

- **engram**: read `sdd/{change-name}/quest` (the approved RFC — required binding input) in addition to the proposal.

## New pre-step before "Step 3: Read Existing Specs"

Read the approved quest/RFC artifact (`sdd/{change-name}/quest` in engram, or `quest.md` in openspec). This is the **binding source of truth** for behavior and contracts. From it, extract:

- **Goals / Non-goals** — scope guardrails; the spec must not exceed the goals or fill in the non-goals.
- **Contracts** — inputs/outputs/events/external that become requirement subjects.
- **Invariants & Validation** — become MUST/SHALL requirements with their edge-case scenarios.
- **Failure Cases & Edge Cases** — become explicit scenarios.
- **Acceptance Criteria (measurable)** — each becomes a verifiable requirement or scenario; the spec must be traceable to them.
- **Unresolved Questions (blocking)** — must be resolved or flagged before the spec is complete; do not silently assume an answer.

Do NOT pull in a stack/language/framework the RFC never confirmed. If the RFC is not marked `Approval: approved`, STOP and report to the orchestrator — you must not write a spec from an unapproved RFC.
<!-- sdd-own:sdd-spec-rfc-binding:end -->