# sdd-tool-incidents Specification

## Purpose

Bug/incident overlay recording orchestrator-observed failures (`bug record|resolve|list`) with privacy-scrubbed summaries. Resolution binds the fix's DIRECT Engram observation id (`bug resolve --engram-id <obs-id>`); when Engram is off, resolution lands in `fallback_path`. Resolved incidents surface in the retro incident list.

## Requirements

### Requirement: Record incidents with privacy scrubbing

`bug record` SHALL record orchestrator-observed failures (blocker, failing test run, transport failure). Every summary SHALL be privacy-scrubbed: no raw logs, secrets, or local paths stored in memory or ledgers.

#### Scenario: Record a failure

- GIVEN the orchestrator observes a failing test run
- WHEN `bug record` runs with a description and change name
- THEN the incident is recorded for the change

#### Scenario: Secrets and paths scrubbed

- GIVEN a description containing a token and a local path
- WHEN `bug record` stores the summary
- THEN the stored summary contains neither the token nor the path

### Requirement: Resolve binds the direct fix observation

`bug resolve --engram-id <obs-id>` SHALL bind resolution to the DIRECT observation id of the fix's existing `mem_save` — not to a derived or topic-level record. The bound id SHALL be verifiable via `engram get-observation`/search.

#### Scenario: Resolve binds the fix observation

- GIVEN fix work saved a memory observation with a known id
- WHEN `bug resolve --engram-id <obs-id>` runs for the incident
- THEN the incident is resolved and bound to that exact id

### Requirement: Engram-off fallback path

When Engram is unavailable, `bug resolve` SHALL record resolution with the incident's `fallback_path` and SHALL NOT fabricate an engram id.

#### Scenario: Engram off lands in fallback_path

- GIVEN Engram is unavailable and the incident carries a `fallback_path`
- WHEN `bug resolve` runs
- THEN resolution is recorded against the `fallback_path` and no engram id is claimed

### Requirement: List and retro surfacing

`bug list` SHALL list recorded incidents with their resolution state. Resolved incidents SHALL appear in the retro incident list (verify-phase incidents) used by prior-context injection.

#### Scenario: Incident appears in the retro incident list

- GIVEN a recorded incident resolved with a bound engram id
- WHEN the retro precis for the change is built
- THEN the incident appears in the verify-phase incident list

### Requirement: Subprocess-only Engram access

`bug record|resolve|list` SHALL access Engram via the `engram` subprocess only and SHALL NOT write `~/.engram/engram.db`.

#### Scenario: No direct Engram DB write

- GIVEN a full incident lifecycle runs
- WHEN the Engram DB mtime is observed
- THEN no direct write occurred from the tool; only subprocess calls ran