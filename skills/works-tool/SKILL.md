---
name: works-tool
description: "ODD work-unit helper binary (canonical ~/.local/bin/works-tool): verify a worktree against the task-doc convention BEFORE starting work on an ODD change, persist phase retrospectives to Engram + task-doc on change close, record/list orchestrator-observed incidents, and discover retros/incidents by feature. Trigger: works-tool, worktree verify, retro persist, incidents record, ODD work-unit lifecycle."
license: MIT
metadata:
  author: andy
  version: "1.0"
---

## Execution Role

`works-tool` is the CLI the orchestrator uses around ODD work units. It is
built by `setup.sh` step 5d-2 to `~/.local/bin/works-tool` (never rebuild it
by hand; `go build ./...` inside `srv/works-tool/` is for the module only).

## Command Cheat-Sheet

- `works-tool worktree verify --feature <feature>` — 3 signals (Root / Task
  doc / Branch). Root and task-doc are BLOCKING; branch is informative.
  Exit 1 when the gate fails. Run BEFORE starting any work unit.
- `works-tool worktree list [--json]` — enumerate worktrees (entry JSON has
  `repo_root_ok`, `task_doc_ok`). Empty is honest ("No worktrees found.").
- `works-tool retro persist <phase> <feature> --body <line> [--commit-ref <ref>]`
  — append one retro line. Engram primary (topic `odd/<feature>/retrospective`,
  deduped by change) + task-doc `## Retros` appendix secondary. Missing/unresolvable
  commit ref or a lost appendix → FAIL-OPEN exit 2 with the marker. Run on change close.
- `works-tool retro lookup --feature <feature> [--json]` — read the ledger;
  absent store → warn-and-continue (exit 0).
- `works-tool incidents record --feature <feature> --summary <text> [--kind blocker|test_failure|transport|other]`
  — record a failure that blocked a unit. Write failure → FAIL-OPEN exit 2.
- `works-tool incidents resolve --id <n>` / `works-tool incidents list [--feature <feature>] [--json]`
  — lifecycle + discovery.

## Exit Codes

0 = ok (including honest empty reads) · 1 = hard error (invalid args, missing
feature, gate failed) · 2 = FAIL-OPEN: a write was lost or the task-doc
appendix is unavailable — the output contains a `FAIL-OPEN:` marker. `--json`
emits `{"ok":true,...}` / `{"ok":false,"error":{...}}` envelopes; retro lookup
emits the Precis shape `{"count":N,"retros":[...]}`.

## Memory Contract

Retros persist to Engram with label `odd/<feature>/retrospective`; the task
doc carries the `## Retros` appendix as secondary. Incidents live in the
local incidents DB (`~/.config/sdd-own/srv/works-tool`). Never invent a
persisted outcome: a FAIL-OPEN marker means the write is NOT confirmed.