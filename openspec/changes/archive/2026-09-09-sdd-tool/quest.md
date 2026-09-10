# Quest: sdd-tool

## Approval: approved

## RFC

### Goals / Non-goals

**Goals**
- Deliver ONE change shipping `sdd-tool`, a Go CLI covering four GAPs of the SDD flow: retrospective persistence (store-aware), prior-context injection, worktree re-entry, and an on-demand dashboard.
- Wire a bug/incident overlay (`sdd-tool bug record/resolve/list`) recording orchestrator-observed failures (blocker, failing test run, transport failure) with privacy-scrubbed summaries, bound on resolution to the direct Engram observation id of the fix.
- Add thin orchestrator-contract overlay clauses (prior-context injection, retro persist, worktree verify, incident recording) that always fail open.
- Store-aware behavior: hybrid artifact store (openspec + engram) with store-first lookup and cross-store fallback, deduped by change name.
- Single change, single PR, auto execution mode; review budget 800 lines (size:exception forecast at tasks time).
- Confirmed requirements (user explicitly stated): Go 1.27, Bubbletea + lipgloss, cobra, modernc sqlite (pure-Go, no CGO). `setup.sh` step 5d-2 adds an optional Go build with a fail-open warning only.

**Non-goals**
- No package-manager logic, no system dependencies, no CGO.
- No polling; the dashboard refreshes only on demand.
- No split into chained changes; tool + overlay ship as one change in one PR.
- The tool never decides: it never routes, never mutates `nextRecommended`/`blockedReasons` or the attempt ledger, and never auto-clears a dirty worktree — the human decides.
- The dashboard is a human window; it replaces nothing in the existing flow.

### Domain Terminology & Business Rules

**Terminology**
- **GAP**: one of the four covered gaps (retro persistence, prior-context injection, worktree re-entry, dashboard).
- **Store**: a retrospective backend — `openspec` (file in the change folder) or `engram` (memory observation). Configured mode is `both` (hybrid); `none` means inline hint only.
- **Retro precis**: capped digest of prior retrospectives (3–5 entries, ≤15 lines each).
- **Prior-context injection**: retrospective context retrieved at phase start; `verify` receives ONLY verify-domain content (`verification_gaps` + verify-phase incidents from prior changes).
- **Worktree verify**: three binding signals (below) plus dirty-state disclosure.
- **Incident**: an orchestrator-observed failure recorded via `bug record`; resolution binds the fix's direct Engram observation id (`bug resolve --engram-id <obs-id>`), or `fallback_path` when Engram is off.

**Business rules**
- Execution mode `auto`; artifact store `both`; PR strategy `single-pr`; review budget 800 lines.
- Injection phases: explore, propose, design, council lenses, AND verify (verify-domain content only).
- Retro lookup: store-first on the declared store; fallback to the other store ONLY on zero domain results; dedupe by change name.
- Persist at archive close, pre-archive, in fixed order: verify → changelog → retro persist → archive.
- Store-aware retro persist: openspec file travels to the archive folder; engram saves topic `sdd/{change}/retrospective`, type `learning`, `capture_prompt: false`; `both` does both; `none` emits an inline hint only.
- Bug resolve binds the DIRECT engram observation id from the fix's existing mem_save; the Engram-off path uses `fallback_path`.
- Hard rules: the tool NEVER writes `~/.engram/engram.db` (subprocess `engram search/save` only); NEVER mutates routing/ledger state (`nextRecommended`, `blockedReasons`, attempt ledger); always fails open; ONE shared scanner drives all listing surfaces.

### Contracts (Inputs / Outputs / Events / External)

**Inputs**
- `change-name`, declared store mode, phase name.
- Subcommands: `worktree list|verify`, `bug record|resolve|list`, dashboard invocation, retro lookup/precis request; `--json` flag for script surfaces.
- `bug resolve --engram-id <obs-id>` binding; `fallback_path` when Engram is off.

**Outputs**
- Retro precis: 3–5 retros, ≤15 lines each, deduped by change name.
- Retro persist: openspec file (travels to archive folder) and/or engram observation (topic `sdd/{change}/retrospective`, type `learning`, `capture_prompt: false`); inline hint in `none` mode.
- Worktree: `list`; `verify` returning the 3 binding signals plus clean/dirty disclosure (never a decision).
- Dashboard: change table + detail pane, on-demand refresh, `--json` output consistent with the shared scanner.
- Bug incidents: privacy-scrubbed summaries; resolvable to a direct engram observation id.

**Events**
- Archive-close hook: verify → changelog → retro persist → archive.
- Phase-start injection for explore, propose, design, council lenses, and verify.
- Incident lifecycle: `record` (observed failure) → `resolve` (binds fix observation) → surfaced in the retro incident list.

**External interfaces**
- `git rev-parse --show-toplevel` and `git branch --show-current`; `gentle-ai sdd-status --json`.
- Engram via subprocess (`engram search/save`) only — never direct DB access.
- `setup.sh` step 5d-2: optional Go build with fail-open warning.

### Invariants & Validation

- Worktree `verify` passes ONLY when all three binding signals hold: (1) `git rev-parse --show-toplevel` equals the expected repo root; (2) `git branch --show-current` equals `sdd/<change>`; (3) `gentle-ai sdd-status --json` parses successfully. Dirty state is disclosed; the human decides — the tool never auto-clears.
- Verify-phase injection contains ONLY verify-domain content (`verification_gaps` and verify-phase incidents).
- Precis cap: 3–5 retros, ≤15 lines each; dedupe by change name.
- Persist order at archive close is fixed: verify → changelog → retro persist → archive.
- The tool never writes `~/.engram/engram.db`; never mutates `nextRecommended`/`blockedReasons`/attempt ledger; always fails open.
- Privacy scrubbing is mandatory on every incident summary.

### Failure Cases & Edge Cases

- Engram unavailable → `bug resolve` uses `fallback_path`; retro persists to the available store or inline hint (`none` mode).
- Declared store returns zero domain results → fallback to the other store; still zero → empty precis, no failure.
- Tool absent or errored → executors behave exactly as before (fail-open); the build step warns, never blocks.
- Worktree signals fail to parse → verify fails cleanly and reports which signal broke; dirty state is always disclosed for human decision.
- Retro persist interrupted between changelog and archive → the fixed order guarantees changelog and retro are complete before archive runs.
- Duplicate retros across stores → deduped by change name in lookup.

### Security / Privacy / Performance / Operational

- Incident summaries are privacy-scrubbed; no raw logs, secrets, or local paths stored in memory or ledgers.
- No direct writes to `~/.engram/engram.db`; Engram is accessed via subprocess only.
- No new credentials or tokens; the setup step never touches token configuration.
- Pure-Go stack (no CGO, no system deps) keeps the build portable and dependency-free.
- No polling; on-demand dashboard refresh bounds idle load.
- Fail-open posture: any tool failure degrades to current behavior, never blocks the SDD flow.
- Review budget 800 lines; a size:exception may be required at the tasks forecast.

### Alternatives & Trade-offs

- Single change vs. chained changes → single chosen; the overlay stays thin, one PR, one review.
- Store-first with fallback vs. always dual-write → fallback only on zero domain results, deduped, avoiding noisy cross-store merges.
- Subprocess-only Engram access vs. direct DB writes → subprocess protects Engram's DB from tool bugs.
- TUI dashboard vs. web dashboard → TUI is a human window replacing nothing; `--json` keeps scriptability.
- On-demand refresh vs. polling → no polling; lower load, human-driven cadence.
- Disclosure-only worktree handling vs. auto-clean → the human decides; the tool never auto-mutates state.

### Acceptance Criteria (measurable)

1. `./sync-skills.sh --check` reports zero desyncs after wiring.
2. Retro lookup covered by a RED check: both-store dedupe + cross-store fallback on zero results.
3. Retro persist retrievable on both sides: openspec file present in the archive folder + engram topic `sdd/{change}/retrospective` (type `learning`, `capture_prompt: false`).
4. Worktree `verify` classifies clean vs. dirty and enforces the 3 binding signals; failing signals are reported explicitly.
5. Bug flow: `record` → `resolve --engram-id <obs-id>` → incident appears in the retro incident list; the Engram-off path lands in `fallback_path`.
6. Dashboard renders the change table + detail pane; `--json` output matches the shared scanner output.
7. Orchestrator overlay clauses are present (injection, retro persist, worktree verify, incident recording) with visible fail-open behavior.
8. Executors pass BOTH with the tool absent (fail-open) and present.

### Unresolved Questions (blocking)

None.