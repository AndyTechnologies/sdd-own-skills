# Proposal: sdd-tool — Go CLI (4 GAPs + incident overlay)

## Intent

One Go CLI fixes 4 SDD gaps: store-aware retro persistence, prior-context injection (incl. verify-domain), worktree re-entry, on-demand dashboard; plus incident overlay bound to fix observations. Hard rules: fail-open; Engram subprocess-only; never mutates routing/ledger.

## Scope

### In Scope
- `srv/sdd-tool/`: cobra CLI; shared scanner (`gentle-ai sdd-status --json`); retro lookup/persist (both-store, dedupe, precis ≤15 lines); worktree `list|verify`; dashboard (on-demand, `--json`); `bug record|resolve|list`.
- `setup.sh` step 5d-2: optional `go build`, check/dry-run/real, fail-open warning.
- Orchestrator: 4 fail-open overlay clauses (injection, retro persist, worktree verify, incidents) + changelog hook reorder.
- sdd-changelog direct edit (verify-report pre-archive input; council D1). RED checks T40+. `.gitignore` entry.

### Out of Scope
No pkg-manager/CGO/deps, polling, chained changes, web dashboard, routing/ledger mutation, auto-clean worktrees.

## Capabilities

> New caps → full specs; modified → delta spec.

### New Capabilities
- `sdd-tool-cli`: cobra root, shared scanner, `--json`, fail-open rules.
- `sdd-tool-retro`: store-first lookup, cross-store fallback, dedupe, precis; openspec file pre-archive + engram topic (learning).
- `sdd-tool-worktree`: `verify` = 3 signals + dirty disclosure; never auto-clears.
- `sdd-tool-dashboard`: table + detail pane, on-demand, `--json` = scanner.
- `sdd-tool-incidents`: `bug record|resolve|list`; scrubbed; resolve binds engram obs id; `fallback_path` when Engram off.

### Modified Capabilities
- `workflow-contract`: 4 overlay clauses + changelog hook reorder.

## Approach

- One binary, one cached scanner parse.
- **Persist order**: changelog pre-archive, verify-report input; honors fixed `verify → changelog → retro persist → archive`; CHANGELOG.md outside `openspec/` keeps readback clean.
- **Engram discovery**: save topic `sdd/{change}/retrospective` type `learning`, title carries the key (`search` matches title/content only).
- **Store decoupling**: declared retro mode (`both`, tool input) never derived from `sdd-status.artifactStore` (`openspec` here).
- Retro file pre-archive (travels via `git mv`). Phases: explore/propose/design/council-lens/verify, archive close, worktree rule 5, support hooks.

## Affected Areas

| Area | Impact | What |
|------|--------|------|
| `srv/sdd-tool/` | New | Go CLI project |
| `setup.sh` | Modified | Step 5d-2 optional Go build |
| `wiring/prompts/sdd/orchestrator.md` | Modified | 4 overlay clauses |
| `skills/sdd-changelog/SKILL.md` | Modified | verify-report pre-archive input (direct edit; council D1 — NOT an overlay) |
| `tests/run_red_checks.sh` | Modified | RED checks T40+ |
| `.gitignore` | Modified | Binary entry (precedent `.venv/`) |

## Risks

| Risk | Likel. | Mitigation |
|------|--------|------------|
| Changelog input contract broken by reorder | Med | verify-report input overlay; RED check |
| `artifactStore` conflation misroutes lookup | Med | Decoupled; never derived |
| Engram retro undiscoverable | Low | Title carries topic key (AC3) |
| Archive readback non-empty | Med | Retro file pre-archive-launch |
| 800-line budget exceeded | Med | size:exception at tasks |
| No live worktrees today | Low | Branch fails → "no worktree" disclosure |

## Rollback Plan

Strip orchestrator clauses; revert the sdd-changelog direct edit + real-mode `./sync-skills.sh` redeploy (council D4 — `--check` only reports DESYNC, cannot fix); remove 5d-2; delete `srv/sdd-tool/`; revert `.gitignore`. Tool absent → fail-open. `sync-skills.sh --check` zero-desync after redeploy.

## Dependencies

Go 1.27; gentle-ai 2.7.0; engram 1.20.0; bubbletea/lipgloss/cobra/modernc sqlite.

## Success Criteria

- [ ] `sync-skills.sh --check` zero desyncs (AC1)
- [ ] RED: both-store dedupe + cross-store fallback (AC2)
- [ ] Retro retrievable: archive file + engram topic (AC3)
- [ ] Worktree verify: 3 signals + clean/dirty (AC4)
- [ ] Bug flow record→resolve→retro; Engram-off → fallback_path (AC5)
- [ ] Dashboard `--json` = scanner (AC6)
- [ ] Overlay clauses present, fail-open visible (AC7)
- [ ] Executors pass with tool absent AND present (AC8)