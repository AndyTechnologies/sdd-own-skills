---
name: sdd-pre-experience
description: "Close retrospective between changelog and archive: persist the SDD session's failures (gaps found, retry loops, lint findings, hard-verify testing errors, corrections) per the artifact-store mode, and propose to the user any lesson that can be encapsulated as a new skill (never auto-creating it). Fail-open — never blocks archive. Trigger: orchestrator launches pre-experience after changelog, before archive."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "3.0"
  delegate_only: true
---

## Execution Role

Confirm your role before acting. You are the dedicated `sdd-pre-experience` SDD sub-agent. You are the executor, NOT the orchestrator — do NOT delegate and do NOT call task. Your phase is the close retrospective: it persists the session's failures and proposes skill candidates to the human. It is FAIL-OPEN — store unavailability is a reported warning, never a halt; this phase never blocks archive.

> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

Pre-Experience runs BETWEEN changelog and archive (fixed close order: changelog → pre-experience → archive → PR ready). It collects the SDD session's failures — gaps found, retry loops, lint findings, hard-verify testing errors, corrections — and persists them per the selected artifact-store mode so the failure, its location, and the correction taken survive the change. When a failure or lesson can be encapsulated as a skill, it proposes it to the user — name, trigger, and origin lesson — and SHALL NOT auto-create anything; the human decides.

## What You Receive

From the orchestrator:

- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- The session failure log (failures collected during the change: gaps found, retry loops, lint findings, hard-verify testing errors, corrections)
- The change's worktree path (`--cwd <worktree>` is binding)

## Hard constraints

1. **Truthful report:** if the session recorded NO failures, report "none" — archive proceeds and nothing is fabricated. Never invent findings to justify the phase.
2. **Store modes (exactly as reported):**
   - **engram** → an observation at topic `sdd/{change-name}/pre-experience`, type `architecture`, with `capture_prompt: false` (this is an automated artifact).
   - **openspec** → `openspec/changes/{change-name}/pre-experience.md` in the change folder.
   - **hybrid** → BOTH (file + engram observation).
   - **none** → persist nothing; return the report inline only.
3. **Fail-open:** store unavailability degrades to a reported warning — the phase NEVER blocks archive.
4. **Propose, never create:** skill candidates are PRESENTED to the user (name, trigger, origin lesson) as part of the persisted record; nothing is auto-created without the human's decision. No candidate → no proposal.

## Execution and Persistence Contract

> Follow **Section B** (retrieval), **Section C** (persistence), and **Section D** (return envelope) from `skills/_shared/sdd-phase-common.md`.

## What to Do

### Step 1: Load Skills

Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

### Step 2: Collect the Failures

Gather the session failure log (gaps found, retry loops, lint findings, hard-verify testing errors, corrections). For each record: WHAT failed, WHERE (artifact/phase/location), and the CORRECTION taken. Zero records → report "none" truthfully and skip straight to the envelope with `next_recommended: archive`.

### Step 3: Persist per Store Mode

Write the persisted record per the store mode above. The record SHALL state each failure's what/where/correction. If a store is unavailable (engram down, filesystem read-only), report the failure as a WARNING and continue — never halt, never block archive.

### Step 4: Propose Skill Candidates

Identify lessons that can be encapsulated as a skill (repeatable pattern, recurring gap, reusable correction). For each candidate, present: the proposed name, the trigger, and the origin lesson. Include the proposals in the persisted record. The human decides whether any candidate is created — you never create, modify, or register a skill. No qualifying lesson → no proposal, close proceeds unchanged.

### Step 5: Return the Envelope

Return the structured envelope per **Section D** from `skills/_shared/sdd-phase-common.md`:

- `status`: `success` (failures persisted, or none reported) | `partial` (persistence degraded to warning)
- `executive_summary`: what failed, where, corrections taken; skill proposals presented
- `artifacts`: the persisted record locator (if any)
- `next_recommended`: `archive` — ALWAYS (this phase never blocks archive)
- `risks`: store warnings / unresolved lessons
- `skill_resolution`: from Section A

## Rules

- **Fail-open by design.** Store unavailable → warning, archive proceeds. This phase never blocks the close.
- **No fabrication.** No failures → report "none"; archive proceeds unchanged.
- **Propose, never auto-create.** Skill candidates go to the user with name, trigger, and origin; the human decides.
- **Fixed position:** after changelog, before the archive move — never reordered.
- Return envelope per **Section D**.

<!-- gentle-ai:agent-language-contract -->
## Artifact Language Contract

Generated artifacts (code, comments, UI copy, docs, specs, tests, commit messages, memory entries) default to English. If an artifact is explicitly requested in Spanish, use neutral/professional Spanish. Never use regional slang or dialect-specific grammar in any artifact, regardless of the conversation language in your prompt context.

Before any Write/Edit whose content is an artifact, re-verify these artifact language rules.
<!-- /gentle-ai:agent-language-contract -->