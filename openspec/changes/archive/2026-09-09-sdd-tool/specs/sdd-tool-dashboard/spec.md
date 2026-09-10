# sdd-tool-dashboard Specification

## Purpose

On-demand Bubbletea TUI: a change table with a detail pane for the selected change. Refreshes only on demand (no polling). `--json` output is consistent with the shared scanner. The dashboard is a human window — it replaces nothing and never mutates routing or ledger state.

## Requirements

### Requirement: Table and detail pane

The dashboard SHALL render a table of changes from the shared scanner (`gentle-ai sdd-status --json`) and SHALL show a detail pane for the selected change (status, nextRecommended, blockedReasons, artifact paths).

#### Scenario: Table with detail pane rendered

- GIVEN scanner data for at least one change
- WHEN the dashboard launches
- THEN the table lists changes and the detail pane shows the selected change's state

### Requirement: On-demand refresh only

The dashboard SHALL refresh only when the user requests it; SHALL NOT poll. An idle dashboard SHALL make no repeated scanner invocations.

#### Scenario: Idle dashboard makes no calls

- GIVEN the dashboard is open and idle
- WHEN 60 seconds pass with no input
- THEN no additional scanner invocation occurs

#### Scenario: Manual refresh pulls new state

- GIVEN the user presses the refresh key
- WHEN the refresh runs
- THEN the scanner is invoked once and the table/detail pane update

### Requirement: JSON output matches the scanner

With `--json`, the dashboard SHALL emit the same data as the shared scanner parse (same schema `gentle-ai.sdd-status` v2), so script consumers get identical fields.

#### Scenario: JSON output equals scanner output

- GIVEN a change set
- WHEN `sdd-tool dashboard --json` and `gentle-ai sdd-status --json` both run
- THEN the listing fields match

### Requirement: Read-only window

The dashboard SHALL NOT mutate `nextRecommended`, `blockedReasons`, or the attempt ledger.

#### Scenario: Ledger untouched after dashboard

- GIVEN a dashboard session runs
- WHEN `gentle-ai sdd-status --json` is read afterward
- THEN routing and ledger state are unchanged