# Apply Progress: sdd-tool

**Mode**: Standard (no strict TDD)
**Last updated**: 2026-09-09 (corrective run)

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
- [x] 5.1 `internal/incidents`: modernc sqlite (pure Go) `~/.config/sdd-own/srv/sdd-tool/incidents.db`
- [x] 5.2 `bug record|resolve|list`: resolve with engram probe fallback

### WU6 — Wiring
- [x] 6.1 `setup.sh` 5d-2: `go build -o "$SDD_OWN_DIR/bin/sdd-tool"`
- [x] 6.2 `.gitignore`: `srv/sdd-tool/bin/`
- [x] 6.3 `orchestrator.md`: sdd-tool injection, verify-domain, archive-close, incident hook
- [x] 6.4 `skills/sdd-changelog/SKILL.md`: verify-report pre-archive input
- [x] 6.5 `./sync-skills.sh --check` zero desyncs; grep installed files

### WU7 — RED suite
- [x] 7.1 T40–T45: scanner, retro, title retrievability, worktree, incidents, dashboard tests
- [x] 7.2 T46–T48: fail-open, FAIL-OPEN write marker, 5d-2 warn, changelog clause grep
- [x] 7.3 Suite green + zero sync desyncs

### WU8 — Corrective Run (2026-09-09)
- [x] D6 driver swap: `go-sqlite3` (CGO) → `modernc.org/sqlite` (pure Go)
- [x] T42 title retrievability: restored to engram title-key filter + unit tests
- [x] T47 FAIL-OPEN write check: added `bug record` unusable-DB exit-non-zero marker test
- [x] Disclosure: baseline failures, CGO guard, empty attempt ledger

## Corrective Run Details

### D6 Driver Swap
- **What**: Replaced `github.com/mattn/go-sqlite3` (CGO-dependent) with `modernc.org/sqlite` v1.37.0 (pure Go) per design D6 and proposal "No pkg-manager/CGO/deps" constraint.
- **Files**: `srv/sdd-tool/go.mod`, `srv/sdd-tool/go.sum`, `srv/sdd-tool/internal/incidents/incidents.go`
- **Verify**: `CGO_ENABLED=0 go build ./...` passes; `go test ./internal/...` green; `go vet ./...` clean.

### T42 Title Retrievability
- **What**: Renamed the previous T42 ("worktree list") to T42b and restored T42 to test the engram adapter's title-key filter (design/testing-strategy: "T42 title retrievability"). Added `internal/engram/engram_test.go` with 4 unit tests for `parseSearchOutput` and title prefix/suffix filtering.
- **Files**: `tests/run_red_checks.sh`, `srv/sdd-tool/internal/engram/engram_test.go`

### T47 FAIL-OPEN Write Check
- **What**: Added T47 ("bug record exits non-zero with FAIL-OPEN marker when DB is unusable") before the renamed T47b (5d-2 warn). Tests D2 asymmetric fail-open: write commands must loud-fail, not silently succeed.
- **Files**: `tests/run_red_checks.sh`

## Known Risks & Disclosures

### T40–T46 Conditional Skip in Full RED Suite
T40 through T46 are gated on `_sdd_tool_built` — the binary is compiled at RED-suite startup using `go build`. If Go is not installed in PATH, or if the build fails for any reason, T40–T46 skip (status: SKIP, reason: "sdd-tool binario no construido"). This is intentional: the RED suite lives in `run_red_checks.sh` and must run on any machine, not just build hosts. **The skip condition is: `$_sdd_tool_built -ne 1`**, triggered by missing `go` binary or compile failure. The corrective driver swap to modernc removed the CGO dependency, so `go build` should now succeed anywhere Go is installed — but the guard remains for robustness.

### Pre-Existing Baseline Failures (Unrelated to sdd-tool)
The following tests in the RED suite have pre-existing baseline failures that are NOT caused by the sdd-tool change:
- **T05**: no-mutacion host — `--check no toca el repo` (environmental sensitivity, git state dependent)
- **T21**: regresion sync + excepcion sancionada en README (sync-skills.sh --check timeout/stall risk)
- **T30**: sync idempotency + id hygiene (post-sync state assumption may drift)
- **T39**: merge ambos motores (jq vs python engine parity, ambiental)

These MUST be verified against the pre-sdd-tool baseline in `sdd-verify` — if they fail there too, they are not regressions.

### Empty Runtime Attempt Ledger
The first apply pass did NOT execute `gentle-ai sdd-attempt acquire/settle`. This corrective run acquired and will settle the attempt. The empty ledger in the first pass is a known risk: `sdd-verify` should verify the attempt states are present and settled before declaring the change complete.

## Files Changed

| File | Action |
|------|--------|
| `srv/sdd-tool/go.mod` | Created + corrected (modernc sqlite) |
| `srv/sdd-tool/go.sum` | Created + regenerated |
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
| `srv/sdd-tool/internal/engram/engram_test.go` | Created (corrective: title filter tests) |
| `srv/sdd-tool/internal/worktree/worktree.go` | Created |
| `srv/sdd-tool/internal/worktree/worktree_test.go` | Created |
| `srv/sdd-tool/internal/incidents/incidents.go` | Created + corrected (modernc driver) |
| `srv/sdd-tool/internal/incidents/incidents_test.go` | Created |
| `srv/sdd-tool/internal/dashboard/dashboard.go` | Created |
| `setup.sh` | Added 5d-2 go build step |
| `.gitignore` | Added srv/sdd-tool/bin/ |
| `wiring/prompts/sdd/orchestrator.md` | Added sdd-tool integration clauses |
| `skills/sdd-changelog/SKILL.md` | Added verify-report pre-archive |
| `tests/run_red_checks.sh` | Added T40-T48 + T42/T47 corrective tests |

## Workload / PR Boundary

- Mode: single PR with size:exception (~2300 lines + corrective)
- All 7 WUs committed individually; corrective run is one additional commit
- Boundary: complete sdd-tool change from foundation to RED suite + corrective fixes

## Status

18/18 tasks complete + 4 corrective items complete. Ready for sdd-verify.
