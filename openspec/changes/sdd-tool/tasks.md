# Tasks: sdd-tool

## Review Workload Forecast

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

Estimated 2300–2900 lines; single PR (RFC non-goal); size:exception pre-accepted — secure before apply.

### Work Units (test ≡ `go test ./srv/sdd-tool/internal/<pkg>/...`; `→` start/finish)

- **WU1**: absent → `--help` 6 subs. test `scanner`; run `sdd-tool --help`; revert `srv/sdd-tool/{go.mod,cmd,internal/scanner}`.
- **WU2**: WU1 → lookup+persist. test `retro,engram,scrub`; run sandbox persist+lookup; revert `internal/{retro,engram,scrub}`.
- **WU3**: WU2 → signals+dirty. test `worktree`; run `verify` on `main`; revert `internal/worktree`.
- **WU4**: WU3 → TUI+json. test `dashboard`; run `--json`≡status; revert `internal/dashboard`+wiring.
- **WU5**: WU4 → lifecycle+fallback. test `incidents`; run record→resolve→lookup; revert `internal/incidents`+db.
- **WU6**: WU5 → wiring live. test `bash -n setup.sh`+`sync --check`; run grep (6.5); revert 4 files+REAL sync.
- **WU7**: WU6 → T40–T48 green. test `./tests/run_red_checks.sh`; run `add_bin` stubs; revert block.

## Phase 1: Foundation

- [x] 1.1 `srv/sdd-tool/go.mod` (go 1.27) + `cmd/sdd-tool/main.go` cobra root: `worktree list|verify`, `retro lookup|persist`, `dashboard`, `bug record|resolve|list`; `--json` script surfaces
- [x] 1.2 `internal/scanner`: lazy ParseOnce of `gentle-ai sdd-status --json`; listing surfaces only, never writes; parse fail → non-zero loud, no empty surfaces

## Phase 2: Retro+scrub

- [x] 2.1 `internal/scrub` pure → `[redacted]`: `ghp_|gho_|ghu_|ghs_|ghe_|github_pat_`+20, PEM, `token|secret|api[_-]?key|password`, abs paths
- [x] 2.2 `internal/retro`+`internal/engram` `Store`: openspec+engram, subprocess-only (`save`/`search`, never `~/.engram/engram.db`); topic-key title `sdd/{change}/retrospective`
- [x] 2.3 Lookup: declared mode (never `artifactStore`), store-first, fallback only on zero, dedupe by change; precis 3–5 of ≤15 lines; zero → empty exit 0
- [x] 2.4 Persist pre-archive (frontmatter+4 sections); `--verify-domain` → gaps+incidents; `none` → hint; write fail → non-zero + loud FAIL-OPEN marker

## Phase 3: Worktree

- [x] 3.1 `internal/worktree list`: `~/.agent_worktrees/{repo}/{change}` + branch
- [x] 3.2 `verify` 3 signals: root (`git rev-parse --show-toplevel`), branch `sdd/{change}`, scanner JSON; failing signal named; dirty disclosure ignoring `.codegraph/`, `.sdd-agent-lock`; never auto-clear; threat `main`

## Phase 4: Dashboard

- [x] 4.1 `internal/dashboard` bubbletea: table + detail pane (status/next/blocked); ↑↓/Enter/r/q; help: snapshot process-lifetime, `r` re-parses once
- [x] 4.2 `--json` = scanner passthrough; no polling; ledger untouched

## Phase 5: Incidents

- [x] 5.1 `internal/incidents`: modernc sqlite `~/.config/sdd-own/srv/sdd-tool/incidents.db` (+`--db`), design schema; shared Scrub
- [x] 5.2 `bug record|resolve|list`: resolve binds obs id via `engram timeline` probe; Engram off → `fallback_path`, never fabricate; resolved → retro verify-phase

## Phase 6: Wiring (rollout `./sync-skills.sh` real + `./setup.sh`)

- [ ] 6.1 `setup.sh` 5d-2 (post-L1211): `go build -o "$SDD_OWN_DIR/bin/sdd-tool"`; check/dry-run/real; no Go/build → warn only
- [ ] 6.2 `.gitignore`: `srv/sdd-tool/bin/`
- [ ] 6.3 `wiring/prompts/sdd/orchestrator.md`: injection (explore/propose/design/council-lens; verify → verify-domain only); archive-close verify→changelog→retro persist→archive + changelog pre-archive+verify-report; rule 5 + incident hook — all fail-open
- [ ] 6.4 `skills/sdd-changelog/SKILL.md` direct edit (never `overlays/skills/sdd-changelog/`): verify-report = pre-archive input; "absent archive-report → blocked" post-archive only
- [ ] 6.5 Gate: `./sync-skills.sh --check` zero desyncs; grep installed `~/.config/sdd-own/{prompts/sdd/orchestrator.md,skills/sdd-changelog/SKILL.md}` (read-only)

## Phase 7: RED suite T40+ in `tests/run_red_checks.sh`

- [ ] 7.1 T40 one-parse; T41 fallback+dedupe; T42 title retrievability; T43 signals+dirty; T44 record→resolve→retro+Engram-off; T45 `--json`≡scanner
- [ ] 7.2 T46 read fail-open (absent+failing stub); T47 write loud FAIL-OPEN + 5d-2 warn; T48 changelog clause grep
- [ ] 7.3 Suite green + zero sync desyncs