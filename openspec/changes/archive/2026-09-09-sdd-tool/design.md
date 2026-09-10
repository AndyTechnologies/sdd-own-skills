# Design: sdd-tool — Go CLI (4 GAPs + incident overlay)

> Revised against council acta (binding) + arch-lint findings. Adds: asymmetric fail-open (write loud-fail), lazy per-command scanner snapshot, scrub extension to retro bodies + full token prefixes, rollback-via-real-sync, loud parse-failure + snapshot UI contract, D1 proposal reconciliation (resolved).

## Technical Approach

One Go 1.27 binary (`srv/sdd-tool/`, cobra): `worktree list|verify`, `retro lookup|persist`, `dashboard`, `bug record|resolve|list`. One cached `gentle-ai sdd-status --json` parse feeds each listing surface that needs it (facade, **lazily per command** — never for writes). Engram via subprocess only. Retro: store-first by declared mode, cross-store fallback, dedupe. Incidents: pure-Go SQLite. Dashboard: read-only Bubbletea, on-demand. `orchestrator.md` edited directly; `skills/sdd-changelog/SKILL.md` edited in place (D1). **Fail-open is asymmetric**: reads warn-and-continue, writes MUST loud-fail non-zero and never lose data silently (D2).**

## Architecture Decisions

- **D1 sdd-changelog input** — (a) overlay strip/append vs (b) direct edit `skills/sdd-changelog/SKILL.md`. (a) breaks: the skill is OURS (symlinked); `sync_dir` full-install clobbers overlay write-through → DESYNC (AC1). ⇒ **(b)** verify-report becomes the PRE-archive input (Step 2 consumes verdict/tests/no-CRITICAL); "absent archive-report → blocked" post-archive only. **Proposal reconciled (D1 resolved)**: `proposal.md` affected-areas row `overlays/skills/sdd-changelog/SKILL.md — New` is corrected to `skills/sdd-changelog/SKILL.md — Modified (direct edit)`; rollback references to "strip overlay clauses (… sdd-changelog)" are replaced by "revert the direct edit + real-sync redeploy (D4)". Executors MUST NOT create `overlays/skills/sdd-changelog/`.
- **D2 Fail-open call — ASYMMETRIC (acta D2)** — per-command class, not global:
  - **Reads stay fail-open** (`retro lookup`, `worktree list|verify`, `dashboard`, `bug list`): `command -v sdd-tool` → run → non-zero ⇒ warn "sdd-tool \<cmd> failed (fail-open)", continue pre-tool.
  - **Data-producing commands FAIL-CLOSED-loud** (`retro persist`, `bug record`, `bug resolve`): tool error ⇒ **exit non-zero with a loud, non-ignorable FAIL-OPEN marker naming the lost write** (e.g. `FAIL-OPEN: retro persist lost write to engram store — output not persisted`). NEVER convert a write failure into silent success.
  - setup.sh 5d-2 (after L1211): optional `go build -o "$SDD_OWN_DIR/bin/sdd-tool" ./srv/sdd-tool/cmd/sdd-tool`; check/dry-run/real; missing Go/build failure ⇒ warn-only.
- **D3 Engram contract** — exact shapes in Interfaces. ⇒ persist via `save` (title = topic key; no CLI capture-prompt flag ⇒ `false` by construction); lookup via `search`; bind probe via `timeline <id>`.
- **D4 Scanner caching — LAZY per command (F6, council-arch lens)** — one cached `Scanner.Snapshot` per run, but built ONLY when a listing surface requires it (`retro lookup`, `worktree list|verify`, `dashboard --json`, `bug list`); NOT in `PersistentPreRunE` for all commands. `bug record`/`retro persist` never invoke or wait on the sdd-status parse. Invalidation = process lifetime (no daemon/cache file); dashboard `r` = explicit re-parse, not polling. **Parse failure ⇒ exit non-zero loudly, never fabricate empty worktree/dashboard surfaces** (acta D5).
- **D5 Store selection** — `artifactStore` coupling vs declared input. ⇒ `Store` interface (`Lookup`/`Persist`), `openspecStore` + `engramStore`; mode = input, NEVER `sdd-status.artifactStore`; `both` ⇒ openspec primary, engram fallback only on zero results; dedupe by change.
- **D6 Incidents** — direct DB vs repository. ⇒ `Repository` over `incidents.db` (modernc sqlite, `~/.config/sdd-own/srv/sdd-tool/incidents.db`, `--db` override); **scrub = ONE shared pure function** applied uniformly to incident summaries AND retro bodies (acta D3); resolve binds direct obs id.
- **D7 Dashboard** — polling vs on-demand. ⇒ Bubbletea table + detail pane; ↑↓/Enter/r/q; no timers; `--json` = scanner passthrough; keyboard-operable, help line, no motion. **UI help line documents that the snapshot is process-lifetime and `r` re-parses once per keypress** (acta D5); never fabricates empty surfaces on parse failure.
- **D8 Retro timing** — post- vs pre-archive. ⇒ pre-archive `openspec/changes/{change}/retrospective.md`; travels via `git mv`; `diff -r` readback clean.

Patterns: **Facade** (scanner), **Repository** (incidents), **Adapter** (engram), **Strategy** (`Store` pair). Avoided: Singleton, God Gateway, Shared Database.

## Data Flow

```
orchestrator → sdd-tool <sub> ──(listing surface?)──► lazy scanner.ParseOnce (1× per command)
  → handlers → openspecStore | engramStore | incidents.db
  → stdout (--json|text)
  Reads  (retro lookup, worktree list|verify, dashboard, bug list):  exit 0|1 — fail-open warn+continue
  Writes (retro persist, bug record, bug resolve): exit 0 on success;
          exit non-zero + loud FAIL-OPEN marker naming the lost write on tool failure
  Parse failure (sdd-status JSON unreadable/half-written): exit non-zero loudly; never fabricate empty surfaces
Never mutates routing/ledger
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `srv/sdd-tool/{go.mod,cmd/sdd-tool/main.go}` | Create | Module `sdd-tool`, cobra root |
| `srv/sdd-tool/internal/{scanner,retro,worktree,incidents,dashboard,engram}/` | Create | Facade; store-first retro; signals; repo+scrub; TUI; adapter |
| `setup.sh` | Modify | 5d-2: optional build, fail-open (D2) |
| `wiring/prompts/sdd/orchestrator.md` | Modify | Direct edit: 4 fail-open clauses (injection ~L595, retro ~L360/archive-close, rule 5 ~L495, incidents hook) + changelog pre-archive |
| `skills/sdd-changelog/SKILL.md` | Modify | Pre-archive verify-report input (D1) |
| `tests/run_red_checks.sh` | Modify | T40+ (see Testing) |
| `.gitignore` | Modify | `srv/sdd-tool/bin/` |

## Interfaces / Contracts

```
sdd-tool
├── worktree list [--json] | verify [--change C] [--json]
├── retro lookup [--change C] [--mode both|openspec|engram|none] [--verify-domain] [--json]
├── retro persist C --mode M --phase P [--body MD|--body-file F]
├── dashboard [--json]
└── bug record C --summary S --kind blocker|test_failure|transport|other
    ├── bug resolve ID [--engram-id OBS]  └── bug list [--json]
```

**Engram (exact)**: `engram save "sdd/{change}/retrospective" <body> --type learning --project <repo> --scope project --topic "sdd/{change}/retrospective"` → parse `#<id>` from stdout; absent ⇒ error (never fabricate). `engram search "retrospective" --project <repo> --scope project --limit 20` → filter titles `sdd/*/retrospective`, newest 5 deduped. `engram timeline <obs-id>` exit 0 ⇒ id exists; Engram off ⇒ `fallback_path` (= `openspec/changes/{change}/retrospective.md`).

**`retrospective.md`**: frontmatter (`change`,`phase`,`store-mode`) + 4 sections: `What Worked` / `What Didn't` / `Verification Gaps` / `Verify-Phase Incidents`; `--verify-domain` extracts the last two. Resolved incidents feed `Verify-Phase Incidents`.

**Scrub (ONE shared pure function `Scrub(string) string`, used identically by incident summaries AND retro `--body`/`--body-file`) → `[redacted]`**:
- GitHub token prefixes: `(ghp_|gho_|ghu_|ghs_|ghe_|github_pat_)[A-Za-z0-9]{20,}`
- PEM blocks (`-----BEGIN ... PRIVATE KEY-----`)
- `(token|secret|api[_-]?key|password)\s*[:=]\s*\S+`
- absolute paths (`/[\w./-]+` long-form; repo-local paths matched by isolation rule)

The scrub is shared so a retro body persisted to Engram long-lived memory is scrubbed with the same contract as incident summaries (retro bodies MUST NOT carry unscubbed secrets into openspec or engram).

```sql
CREATE TABLE incidents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  change_name TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN
    ('blocker','test_failure','transport','other')),
  summary TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open'
    CHECK(status IN ('open','resolved')),
  fallback_path TEXT, resolved_engram_id INTEGER, resolved_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')));
```

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Unit | scrub, precis cap/dedupe, id parse | `go test ./internal/...` |
| Integration | fallback+dedupe, signals, bug lifecycle, JSON parity | real binary in sandbox: T40 one-parse, T41 store-first fallback+dedupe, T42 title retrievability, T43 3 signals+dirty (ignore `.codegraph/`, `.sdd-agent-lock`), T44 record→resolve→retro + Engram-off fallback, T45 `--json` ≡ scanner |
| Orchestrator | fail-open absent + failing stub, 5d-2 warn, changelog pre-archive | T46–T48: `add_bin` stubs + prompt-text grep (verify-report clause in installed changelog SKILL) |

## Threat Matrix

| Boundary | Applicability | Response / RED |
|---|---|---|
| Doc-like paths | N/A — no executable-doc handling | — |
| Git repo selection | **Applicable** — read-only `git -C` probes only, convention-derived paths, never user argv | signals named on failure; RED: foreign root / `main` branch |
| Commit / Push / PR | N/A — tool never stages, commits, pushes, or runs PR automation | — |

## Migration / Rollout

No migration (greenfield). Rollout: `./sync-skills.sh` real (AC1) + `./setup.sh`.

**Rollback (acta D4)**: git revert of `srv/sdd-tool/`, `setup.sh`, orchestrator clauses, changelog edit, `.gitignore`; delete binary + `incidents.db`; tool absent ⇒ fail-open. **Reverting the `skills/sdd-changelog/SKILL.md` direct edit additionally requires `./sync-skills.sh` in REAL mode to propagate the reverted canonical to `~/.config/sdd-own/skills/sdd-changelog/`** — `--check` alone only REPORTS DESYNC (sync-skills.sh L372); it cannot fix. The rollback gate is a `./sync-skills.sh --check` reporting zero desyncs AFTER the real sync, proving AC1 holds.

## Open Questions

None — D1 maintainer change is resolved above (direct edit + proposal reconciled as the binding decision).

## Learned (applied decisions)

- **Fail-open is command-class asymmetric**: reads warn-and-continue to keep executors identical pre-tool, but `retro persist`/`bug record`/`bug resolve` MUST loud-fail non-zero naming the lost write — a write failure that degrades like a read failure IS silent data loss.
- **Scanner parse is lazy, not eager**: mutating commands (`bug record`, `retro persist`) never pay for or are perturbed by an sdd-status parse they do not need; parse failure exits loudly and never fabricates empty worktree/dashboard surfaces.
- **Scrub is ONE shared pure function** across incident summaries and retro bodies — retro bodies persist to Engram long-lived memory, so an unscubbed body is a durable secret leak; regex now covers `ghe_` (enterprise) and `github_pat_`.
- **The sdd-changelog direct-edit rollback is incomplete without a REAL `./sync-skills.sh`** — `--check` reports DESYNC but cannot fix; rollback must run the real sync then gate on a zero-desync check.