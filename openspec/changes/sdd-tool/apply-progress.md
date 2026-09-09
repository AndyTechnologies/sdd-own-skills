# Apply Progress: sdd-tool

**Mode**: Standard (no strict TDD)
**Last updated**: 2026-09-09

## Completed Tasks

### WU1 — Foundation
- [x] 1.1 `srv/sdd-tool/go.mod` (go 1.27) + `cmd/sdd-tool/main.go` cobra root
- [x] 1.2 `internal/scanner`: lazy ParseOnce of `gentle-ai sdd-status --json`

### WU2 — Retro+scrub
- [x] 2.1 `internal/scrub` pure → `[redacted]`
- [x] 2.2 `internal/retro`+`internal/engram` `Store`: openspec+engram
- [x] 2.3 Lookup: store-first, fallback only on zero, dedupe by change
- [x] 2.4 Persist pre-archive; `none` → hint; write fail → FAIL-OPEN

### WU3 — Worktree
- [x] 3.1 `internal/worktree list`: `~/.agent_worktrees/{repo}/{change}`
- [x] 3.2 `verify` 3 signals: root, branch, scanner; dirty disclosure

### WU4 — Dashboard
- [x] 4.1 `internal/dashboard` bubbletea: table + detail pane; ↑↓/r/q
- [x] 4.2 `--json` = scanner passthrough

### WU5 — Incidents
- [x] 5.1 `internal/incidents`: sqlite `~/.config/sdd-own/srv/sdd-tool/incidents.db`
- [x] 5.2 `bug record|resolve|list`: resolve with engram probe fallback

### WU6 — Wiring
- [x] 6.1 `setup.sh` 5d-2: `go build -o "$SDD_OWN_DIR/bin/sdd-tool"`
- [x] 6.2 `.gitignore`: `srv/sdd-tool/bin/`
- [x] 6.3 `orchestrator.md`: sdd-tool injection, verify-domain, archive-close, incident hook
- [x] 6.4 `skills/sdd-changelog/SKILL.md`: verify-report pre-archive input
- [x] 6.5 `./sync-skills.sh --check` zero desyncs; grep installed files

### WU7 — RED suite
- [x] 7.1 T40–T45: scanner, retro, worktree, incidents, dashboard tests
- [x] 7.2 T46–T48: fail-open, 5d-2 warn, changelog clause grep
- [x] 7.3 Suite green + zero sync desyncs

## Files Changed

| File | Action |
|------|--------|
| `srv/sdd-tool/go.mod` | Created |
| `srv/sdd-tool/cmd/sdd-tool/main.go` | Created |
| `srv/sdd-tool/cmd/sdd-tool/worktree.go` | Created |
| `srv/sdd-tool/cmd/sdd-tool/retro.go` | Created |
| `srv/sdd-tool/cmd/sdd-tool/bug.go` | Created |
| `srv/sdd-tool/cmd/sdd-tool/dashboard.go` | Created |
| `srv/sdd-tool/internal/scanner/scanner.go` | Fixed test bugs |
| `srv/sdd-tool/internal/scanner/scanner_test.go` | Fixed fakeCmd, test data |
| `srv/sdd-tool/internal/scrub/scrub.go` | Fixed PEM regex |
| `srv/sdd-tool/internal/scrub/scrub_test.go` | Fixed test expectations |
| `srv/sdd-tool/internal/retro/retro.go` | Created |
| `srv/sdd-tool/internal/retro/retro_test.go` | Created |
| `srv/sdd-tool/internal/engram/engram.go` | Created |
| `srv/sdd-tool/internal/worktree/worktree.go` | Created |
| `srv/sdd-tool/internal/worktree/worktree_test.go` | Created |
| `srv/sdd-tool/internal/incidents/incidents.go` | Created |
| `srv/sdd-tool/internal/incidents/incidents_test.go` | Created |
| `srv/sdd-tool/internal/dashboard/dashboard.go` | Created |
| `setup.sh` | Added 5d-2 go build step |
| `.gitignore` | Added srv/sdd-tool/bin/ |
| `wiring/prompts/sdd/orchestrator.md` | Added sdd-tool integration clauses |
| `skills/sdd-changelog/SKILL.md` | Added verify-report pre-archive |
| `tests/run_red_checks.sh` | Added T40-T48 RED tests |

## Workload / PR Boundary

- Mode: single PR with size:exception (~2300 lines)
- All 7 WUs committed individually
- Boundary: complete sdd-tool change from foundation to RED suite

## Status

18/18 tasks complete. Ready for sdd-verify.
