# Delta Spec: Baseline Import of Deployed State

## Needs

Repo HEAD f9ec832 is stale versus the deployed runtime: quest v4.0, lint v2.0, a new orchestrator chain, and 4 unversioned prompts live only in the installed state, and the `sdd-architecture-plan` agent key is missing from the wiring fragment. The change versions the deployed state as repo canonical and co-updates the pins that guard it.

## Scenarios

#### Scenario: B1 · Quest baseline bytes
- GIVEN the change is applied
- THEN `skills/sdd-quest/SKILL.md` matches the deployed quest v4.0 bytes (verified by T-pin)

#### Scenario: B2 · Lint baseline bytes
- GIVEN the change is applied
- THEN `skills/sdd-architecture-lint/SKILL.md` matches the deployed lint v2.0 bytes (verified by T-pin)

#### Scenario: B3 · Orchestrator contract versioned
- GIVEN the change is applied
- THEN `wiring/prompts/sdd/orchestrator.md` carries the new orchestrator contract and the wiring references it by file, never inline

#### Scenario: B4 · Prompts versioned
- GIVEN the change is applied
- THEN the 4 prompts `sdd-architecture-plan`, `sdd-hard-gate`, `sdd-hard-verify`, `sdd-pre-experience` exist under `wiring/prompts/sdd/`

#### Scenario: B5 · Agent registered, merge additive
- GIVEN the wiring fragment is merged over the real opencode config
- THEN the `sdd-architecture-plan` agent key exists and personal config keys are preserved

#### Scenario: B6 · Pins co-updated
- GIVEN T34 (OWN_PROMPTS), T35 (lint string pins), and T37 (fragment allow-list) are updated
- THEN their checks validate the imported state

#### Scenario: B7 · Check gated
- GIVEN the sync pipeline runs after the import
- THEN `sync-skills.sh --check` reports zero desyncs before any install

#### Scenario: B8 · Rollback safe
- GIVEN the change is reverted to HEAD f9ec832 (single-PR revert)
- THEN the deltas are removed and `sync-skills.sh --check` reports zero residual desyncs, with the deployed runtime unaffected

## Capabilities

### Added Capability: Deployed-State Baseline Import

### Requirement: Byte-Exact Baseline Import

The change MUST import the deployed state as repo canonical: quest v4.0 SKILL.md and lint v2.0 SKILL.md, byte-exact and verified by T-pins. It MUST version the new orchestrator contract at `wiring/prompts/sdd/orchestrator.md` (referenced by file, never inline) and the 4 unversioned prompts (`sdd-architecture-plan`, `sdd-hard-gate`, `sdd-hard-verify`, `sdd-pre-experience`) under `wiring/prompts/sdd/`.

Scenarios: B1, B2, B3, B4

### Requirement: Agent Wiring in the Fragment

The `wiring/opencode.sdd.json` fragment MUST register the `sdd-architecture-plan` agent. The sync merge SHALL remain additive: personal config keys are preserved, and SDD fragment keys win only within the SDD surface.

Scenarios: B5

### Requirement: Pin Co-Updating

The change MUST co-update T34 (OWN_PROMPTS list), T35 (lint string pins), and T37 (fragment allow-list) so existing checks validate the imported state.

Scenarios: B6

### Requirement: Deploy Safety and Rollback

The import SHALL be rollback-safe: reverting to HEAD f9ec832 (single-PR revert) removes the deltas with zero residual desyncs. The sync MUST gate on `sync-skills.sh --check` before touching installed state, and the deployed runtime MUST remain unaffected by repo-local import.

Scenarios: B7, B8