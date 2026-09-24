# Task Doc: works-tool-rewire

> Seeded from `odd/rfcs/works-tool-rewire-product-rfc.md` (Approval: approved). Product RFC is the binding mandate.
> Plan: `approved` — architecture-plan acta integrated below (`## Architecture Plan Acta`, decisions A1–A13); binding for design and for post-apply architecture lint (axis 2 fails closed if this section is missing or unreadable).

## Objective

Rename the SDD-era helper `srv/sdd-tool` into `works-tool`, keep exactly four ODD features (`worktree list`, `worktree verify`, retro per work-unit, `incidents`), remove the dashboard TUI and every SDD-native integration, and wire the tool into the ODD flow with `setup.sh` installing it to `~/.local/bin/works-tool`. Agents must use `works-tool` (canonical path) instead of ad-hoc bash scripts.

## Scope

- In: Go module rename (`srv/sdd-tool` → `srv/works-tool`, module `works-tool`), CLI surface rename (`works-tool ... --feature <name>`), keep worktree list|verify, retro persist|lookup, incidents record|resolve|list; drop dashboard + scanner (`gentle-ai sdd-status`); retro stores Engram `odd/<feature>/retrospective` + append to `odd/tasks/<feature>.md`; incidents DB at `~/.config/sdd-own/srv/works-tool/incidents.db`; `setup.sh` 5d-2 builds/installs to `~/.local/bin/works-tool`; rewrite RED T40–T48 for the new surface; update ODD wiring (routing/prompts) to reference `works-tool` by canonical path; update CHANGELOG/docs.
- Out: dashboard TUI, `bug` subcommand (renamed to `incidents`), openspec stores (`both|openspec|engram|none` → Engram-first only), `--change` flag vocabulary, any `gentle-ai sdd-status` coupling.

## Tasks

- [x] **T1 — Rename module + folder**: `git mv srv/sdd-tool srv/works-tool`; module path `works-tool`; internal imports `works-tool/internal/...`; cobra `Use: "works-tool"`; package docs updated; `go build ./...` green after this step alone.
- [x] **T2 — Prune dashboard + scanner + bug**: delete `cmd/sdd-tool/dashboard.go`, `internal/dashboard`, `internal/scanner` (incl. tests), and `cmd/sdd-tool/bug.go`; drop bubbletea/lipgloss/bubbles deps via `go mod tidy`; cobra + modernc.org/sqlite retained; zero `gentle-ai sdd-status` references remaining.
- [x] **T3 — internal/envelope uniform contract**: new package `internal/envelope` implementing the `{ok, feature?, data|error}` JSON envelope, `error = {code, message, fail_open?}`, and the central exit-code mapping (0 ok, 1 error, 2 fail-open/warn). Every `--json` surface and every fail-open marker routes through it; shared `repoRootFromCwd()` helper (walk-up `.git` marker, filesystem-only) lives in `internal/worktree` and is reused by list/verify/retro persist.
- [x] **T4 — ODD worktree signals**: `worktree list [--json]` canonical discovery of `~/.agent_worktrees/<repo>/` (repo namespace from filesystem `.git` walk-up, no git subprocess), per-entry validation flags `repo_root_ok` + `task_doc_ok`; `worktree verify --feature <name> [--json]` with ODD binding signals: repo root (BLOCKING, expected `~/.agent_worktrees/<repo>/<feature>`), task doc `odd/tasks/<feature>.md` (BLOCKING) — never passes without the task-doc signal; branch `feat/<feature>` INFORMATIVE only (reported, not gating). Scanner signal and dirty disclosure removed; `--root` flag removed.
- [x] **T5 — Retro per work-unit (Engram + task-doc append)**: `retro persist --feature <name> --phase <phase> --body|-file [--verify-domain] [--commit-ref <ref>]`; commit ref = `git rev-parse HEAD` in the active worktree (the tool's ONLY git subprocess) or `--commit-ref` override; Engram observation topic `odd/<feature>/retrospective` (type learning) is PRIMARY, body = ordered list of signed entries `- [Retro <phase>] <commit-ref>: <summary>`; re-persist of the same key (feature, phase, ref) = in-place entry update (idempotent, never duplicate). Appends the SAME entry line to `odd/tasks/<feature>.md` under a `## Retros` section (created if missing) as the SECONDARY durable copy; missing task doc → loud FAIL-OPEN marker, exit 2, NO append (the Engram write still stands). `retro lookup [--feature <name>] [--verify-domain] [--json]` reads by key; `--mode` flag removed (drop openspec/none/composite stores). ENV NOTE (2026-09-24, verified): the standalone CLI `engram save` here is rejected by the v2 session-ownership guard (`session "manual-save-sdd-own-skills" belongs to "open-ai-skills", not "sdd-own-skills"`); the tool reports EngramWritten=false + EngramError honestly and NEVER re-orders the A6 contract — Engram primary, task-doc appendix secondary, FAIL-OPEN exit 2 only when the task-doc append fails.
- [x] **T6 — Incidents rename + path migration**: subcommand `bug` → `incidents` (`record|resolve|list`); `--change` → `--feature` (required on record); `resolve` requires `--id`; `list` gains optional `--feature` filter + `--json`; DB default path constant → `~/.config/sdd-own/srv/works-tool/incidents.db` (no data migration — new store authoritative); fallback_path string updated to the ODD task-doc appendix form; scrub + FAIL-OPEN semantics retained.
- [x] **T7 — setup.sh 5d-2 install**: 5d-2 builds `srv/works-tool` → `~/.local/bin/works-tool` honoring check/dry-run/real; real mode only: idempotent removal of stale `~/.config/sdd-own/bin/sdd-tool`; `--check`/`--dry-run` report works-tool status AND stale-removal as pending; non-blocking if Go missing; binary gitignored.
- [x] **T8 — RED rewrite**: T40–T48 group + warm-build block rewritten for `works-tool` list/verify/retro/incidents + envelope shape + FAIL-OPEN (exit 2) + stale-removal reporting; T48 extended with works-tool wiring pins; zero `sdd-tool` refs in owned surface. (Blocker from lint fixed: T48 pins + T47b assertions landed in fe88ec8; T41 hermetic engram stub in 24f9b21; suite 76 PASS / 0 FAIL.)
- [x] **T9 — ODD wiring + docs**: new full-install skill `skills/works-tool/SKILL.md` (canonical path `~/.local/bin/works-tool`, command cheat-sheet, exit-code semantics); routing extension `wiring/sdd-own-routing.md` gains the works-tool clause (verify before work-unit, retro persist on close, incidents record on failure, list discovery); CHANGELOG migration note under [Unreleased]/Changed; README/AGENTS.md references updated if present.
- [x] **T10 — Verification**: `bash -n`, `go build`/`go vet`/`go test ./...` in `srv/works-tool`, `setup.sh --check` reports `works-tool` + stale sdd-tool pending removal, RED suite 0 new failures beyond the 7 known post-sync invariants, grep zero `sdd-tool` in owned surface (CHANGELOG history/legacy docs exempt). (Series: bash -n OK; build/vet/test 78 passed / 7 pkgs; setup.sh --check reports `[pendiente] works-tool` + stale removal; RED 76 PASS / 0 FAIL incl. hermetic T41; parent spot-check re-ran build + RED at closure.)

## Authorized Scope

RFC-approved: rename, 4 features kept, dashboard/scanner/openspec/bug removed, `--feature` vocabulary, Engram+task-doc retro, `~/.local/bin/works-tool`, ODD wiring.

## Acceptance Criteria

From product RFC: `setup.sh --check` reports works-tool; RED T40–T48 cover list/verify/retro/incidents; 0 new RED failures beyond 7 post-sync invariants; ODD wiring references canonical path.

## Applicable Checks

- `tests/run_red_checks.sh` (full suite; 71 PASS baseline + 7 expected post-sync invariants)
- `cd srv/works-tool && go build ./... && go vet ./... && go test ./...`
- `bash -n` on touched shell files
- Grep guard: zero `sdd-tool` in owned surface (repo files except CHANGELOG history/legacy docs)

## Architecture Plan Acta

> Artifact name: `arch-plan.md` (integrated into this task doc; no separate acta file — decision A13). Consumes the approved RFCs (`odd/rfcs/works-tool-rewire-product-rfc.md`, `odd/rfcs/works-tool-rewire-arch-rfc.md`), the seeded task doc, and the exploration findings (verified facts). Binding for design and for post-apply architecture lint (axis 2 fails closed if this section is missing or unreadable).

### Acta — works-tool-rewire

Titled decisions A1–A13. Each carries its decision, rationale, and traceable inputs. No open decisions; no research lane was required (all decisions resolve from the RFCs + findings).

## Decision

### Decision: A1 — Module + directory rename to `works-tool`

- **Decision**: `git mv srv/sdd-tool srv/works-tool`; `go.mod` module line becomes `works-tool`; every internal import `sdd-tool/internal/...` → `works-tool/internal/...`; cobra root `Use: "works-tool"`; package doc comments updated from "sdd-tool" to "works-tool". Pure rename first (T1), so `go build ./...` stays green independently of the prune.
- **Rationale**: A clean rename preserves git history and gives a clean identity before any content surgery; it makes the prune (T2) a reviewable diff on top instead of a mixed rename+delete blob.
- **Inputs**: product-rfc Goals §Rename; arch-rfc Migration §`git mv srv/sdd-tool → srv/works-tool`; finding: current tree `srv/sdd-tool` with module `sdd-tool`, go 1.27.

### Decision: A2 — Command surface and vocabulary (`--feature`, no `bug`, no `dashboard`)

- **Decision**: Three subcommand families: `worktree` (`list`, `verify`), `retro` (`persist`, `lookup`), `incidents` (`record`, `resolve`, `list`). The `bug` family and the `dashboard` command are deleted (T2). The flag `--change` is replaced by `--feature <name>` everywhere; `--feature` is REQUIRED on `worktree verify`, `retro persist`, and `incidents record`, and is an optional FILTER on `retro lookup` and `incidents list`. `incidents resolve` requires `--id`. `retro persist` flags: `--feature`, `--phase` (default `verify`), `--body` | `--body-file`, `--verify-domain`, `--commit-ref` (override, optional). `retro lookup` flags: `--feature`, `--phase`, `--ref`, `--verify-domain`, `--json`. Incidents: `record --feature --summary [--kind]`, `resolve --id [--engram-id]`, `list [--feature] [--json]`.
- **Rationale**: The RFCs pin the exact vocabulary; the ODD flow is feature-scoped (task doc `odd/tasks/<feature>.md`), so `--feature` is the invariant-required flag; lookup/list keep feature optional to allow cross-feature reads.
- **Inputs**: product-rfc Contracts §all four surface contracts + Invariants; arch-rfc Interfaces §contracts; finding: current `bug.go`/`dashboard.go` command files.

### Decision: A3 — Uniform JSON envelope and exit-code contract

- **Decision**: New package `internal/envelope` (the arch RFC's "output envelope") owns the single serialization contract:
  - Success: `{"ok": true, "feature": "<name>", "data": <payload>}` (`feature` omitted when not scoped; `data` may be `[]` — clean empty surfaces are honest results, never errors).
  - Failure: `{"ok": false, "feature": "<name>", "error": {"code": "<code>", "message": "<msg>", "fail_open": true|false}}`.
  - Exit codes, central mapping: `0` = ok, `1` = error (hard failure, `fail_open: false`), `2` = fail-open/warn (write failed loudly but the tool continues to exist; `fail_open: true`). Read-side warn-and-continue (e.g. Engram CLI absent on lookup, unusable DB on list) still exits `0` with the warning on stderr and honest (possibly empty) `data` — agents get valid output, never a fabricated surface.
  - Human (non-`--json`) mode keeps the same exit codes; the literal marker token `FAIL-OPEN` is preserved on write failures.
- **Rationale**: The RFC mandates one shared envelope invariant with stable exit codes so agents branch deterministically; centralizing it (instead of per-command `json.NewEncoder` + `os.Exit` sprinkled across cmd files) removes the current copy/paste duplication and makes the contract grep-able/pinnable in RED.
- **Inputs**: arch-rfc Modules §output envelope + Data §Uniform envelope invariant + Interfaces §exit codes; finding: per-command ad-hoc JSON/exit handling in `cmd/sdd-tool/*.go`.

### Decision: A4 — `worktree list` as ODD-directory enumeration (no scanner, no git subprocess)

- **Decision**: `works-tool worktree list [--json]` enumerates the entries of `~/.agent_worktrees/<repo>/` where `<repo>` is derived filesystem-only: walk up from cwd to the nearest ancestor containing a `.git` marker (file or directory); repo name = basename of that ancestor; degenerate results fall back to `"repo"`. This replaces `RepoNameFromGitRoot` (git subprocess) with a deterministic, no-git helper `repoRootFromCwd()` shared with verify and retro persist. Each entry is reported with per-entry validation flags: `repo_root_ok` (entry dir contains a worktree `.git` file whose `gitdir:` line resolves under `<repo>/.git/worktrees/`) and `task_doc_ok` (`odd/tasks/<feature>.md` exists at the entry root). Entries failing validation are still listed (absent/invalid data is reported, never fabricated or hidden). Output entries: `{name, path, branch, repo_root_ok, task_doc_ok}`; branch is read from the entry's own gitdir HEAD (`ref: refs/heads/<branch>`), informative.
- **Rationale**: The RFCs declare list the canonical discovery surface, NOT a `git worktree list` passthrough, and restrict git use to commit-ref resolution only; a directory-enumeration + existence-check implementation is deterministic, cheap, and honors both constraints.
- **Inputs**: product-rfc Contracts §`worktree list`, arch-rfc Interfaces §list + External Dependencies §git-only-for-commit-ref; finding: current list driven by scanner snapshot + `RepoNameFromGitRoot`.

### Decision: A5 — `worktree verify` ODD binding signals

- **Decision**: `works-tool worktree verify --feature <name> [--json]` emits exactly the ODD binding signals:
  - **Root (BLOCKING)**: the filesystem walk-up root of cwd equals the convention worktree root `~/.agent_worktrees/<repo>/<feature>` (normalized). Failed → signal fails and verify fails.
  - **Task doc (BLOCKING)**: `odd/tasks/<feature>.md` exists at the verified root. Failed → signal fails and verify fails. Verify NEVER passes without this signal.
  - **Branch (INFORMATIVE)**: current branch read from the worktree gitdir HEAD, expected `feat/<feature>`; mismatch is REPORTED, never gates.
  - The scanner signal (signal 3) and the dirty-state disclosure (`git status --porcelain`) are REMOVED: dirty was a scanner-era overlay and `git status` is a git subprocess outside the commit-ref-only allowance. The `--root` flag is removed (expected root is the deterministic convention path).
- **Rationale**: The arch RFC defines the binding signals as root + task doc BLOCKING, branch INFORMATIVE, contrasting them with the 3 scanner-era signals; the git-only-for-commit-ref constraint makes `git status`/`git rev-parse` probes unviable, and the filesystem walk-up root is their deterministic replacement.
- **Inputs**: arch-rfc Interfaces §verify + Architecture Alternatives §ODD binding signals + External Dependencies §git constraint; finding: current verify signals (root, branch, scanner, dirty).

### Decision: A6 — Retro Engram-only with per-work-unit key and shared entry line

- **Decision**: `retro persist` writes exactly two places:
  1. **Engram** (primary): observation topic `odd/<feature>/retrospective`, type `learning`, body = an ordered list of signed entries `- [Retro <phase>] <commit-ref>: <summary>` (one per work-unit). Re-persist of the same key `(feature, phase, ref)` updates that entry IN PLACE (idempotent, never a duplicate) — read-modify-write: search topic, replace entry by key, re-save.
  2. **Task-doc appendix** (secondary): the SAME entry line appended under a `## Retros` section in `odd/tasks/<feature>.md` (section created if missing; entry deduplicated by line identity). Missing task doc → loud FAIL-OPEN marker, exit 2, NO append; the Engram write still stands.
  - Commit ref: `git rev-parse HEAD` in the active worktree (the tool's ONLY git subprocess), overridable with `--commit-ref`; if neither yields a ref → FAIL-OPEN marker, exit 2, never a fabricated ref.
  - `retro lookup [--feature <name>] [--phase <phase>] [--ref <ref>] [--verify-domain] [--json]` reads the Engram observation and filters entries by the key components; `--verify-domain` retains its extraction of Verification Gaps / Verify-Phase Incidents.
  - The `--mode` flag and the `both|openspec|engram|none` store hierarchy (compositeStore, openspecStore, noneStore) are deleted.
- **Rationale**: The RFC pins the Engram topic `odd/<feature>/retrospective`, content signed with the work-unit ref and phase, per-work-unit dedupe key `(feature, phase, ref)`, and the task-doc `## Retros` appendix in the exact line format; a single shared line format for both stores keeps P03 (single source of truth) while giving idempotent updates.
- **Inputs**: arch-rfc Data §Engram retro identity + Interfaces §retro contracts + Failure Isolation §missing task doc; product-rfc Contracts §retro; finding: current retro.go multi-mode stores + `sdd/{change}/retrospective` topic.

### Decision: A7 — Incidents rename + DB path migration (no data migration)

- **Decision**: `bug` → `incidents` (`record|resolve|list`); default DB path constant changes from `~/.config/sdd-own/srv/sdd-tool/incidents.db` to `~/.config/sdd-own/srv/works-tool/incidents.db`; no data migration — any pre-existing database is left untouched and the new store is authoritative. `record` requires `--feature`; `resolve` requires `--id` (keeps `--engram-id` binding); `list` gains optional `--feature` filter + `--json`. Scrub + FAIL-OPEN + fallback_path semantics retained, with the fallback_path string updated to the ODD task-doc appendix (`odd/tasks/<feature>/retrospective` appendix; Engram observation when `. --engram-id` verified).
- **Rationale**: The product RFC renames the surface and pins the new DB path; the arch RFC migration section states no pre-existing state migration — the new store is authoritative going forward.
- **Inputs**: product-rfc Contracts §incidents + Security/Privacy §DB path; arch-rfc Migration §no state migration; finding: incidents.go default path + bug.go command surface.

### Decision: A8 — `setup.sh` 5d-2 rewire to `~/.local/bin/works-tool`

- **Decision**: Step 5d-2 becomes "build works-tool": `WORKS_TOOL_SRC="$REPO/srv/works-tool"`, `WORKS_TOOL_BIN="$HOME/.local/bin/works-tool"` (ensure `~/.local/bin` exists in real mode), `go build -C "$WORKS_TOOL_SRC" -o "$WORKS_TOOL_BIN" ./cmd/works-tool/` honoring check/dry-run/real. Real mode only: after a successful build, idempotently `rm -f "$ENV_DIR/bin/sdd-tool"` (stale binary at `~/.config/sdd-own/bin/sdd-tool`); `--check`/`--dry-run` report works-tool status AND the stale-removal as `[pendiente]`. Missing Go or build failure → non-blocking warning (unchanged behavior). The old `$ENV_DIR/bin/sdd-tool` target, `SDD_TOOL_*` names, and the `./cmd/sdd-tool/` build path are removed.
- **Rationale**: The RFCs pin the canonical install path `~/.local/bin/works-tool` and the idempotent stale removal with honest check/dry-run reporting; keeping real-mode-only removal prevents any surprise mutation under `--check`.
- **Inputs**: arch-rfc Deployment §5d-2 + Migration §stale removal; product-rfc Goals §`~/.local/bin/works-tool`; finding: setup.sh lines 1266–1298.

### Decision: A9 — `.gitignore` coverage swap

- **Decision**: Replace the `# Go build output (sdd-tool)` + `srv/sdd-tool/bin/` entries with `# Go build output (works-tool)` + `srv/works-tool/bin/` (lines ~12–13). No other ignore change.
- **Rationale**: The renamed module's build output must stay ignored; the old path no longer exists and the grep guard requires zero `sdd-tool` in owned surface.
- **Inputs**: arch-rfc Deployment §gitignore; finding: `.gitignore` lines 12–13.

### Decision: A10 — RED suite rewrite shape (T40–T48)

- **Decision**: The warm-build block (top of `tests/run_red_checks.sh`) builds `srv/works-tool` → `works-tool` binary, and the T40–T48 group is rewritten as follows (zero `sdd-tool` refs in the owned surface; fixture sandboxes unchanged in mechanics):
  - **T40** — one-parse surface: `--help` exits 0 and prints `worktree`, `retro`, `incidents`; asserts `dashboard` and `bug` are ABSENT.
  - **T41** — retro Engram-only dedupe: re-persist of the same key updates in place (unit-level: body keeps a single entry line); sandbox without Engram CLI → persist exits 2 with `FAIL-OPEN` hint; lookup warns-and-continues (exit 0, empty result, no panic).
  - **T42** — topic retrievability: engram title filter matches `odd/*/retrospective` prefix (unit tests on `internal/engram` filter + `odd/` topic).
  - **T42b** — worktree list empty: no `~/.agent_worktrees` → clean empty output, exit 0; with an entry missing task doc → listed with `task_doc_ok: false`.
  - **T43** — verify signals: on a non-convention checkout, root signal fails (BLOCKING) and verify exits non-zero; with a stub task doc present the root/task-doc signals drive the verdict; branch is informative-only (mismatched branch never fails the gate).
  - **T44** — incidents lifecycle: `record --feature test-x` → `list` shows it → `resolve --id` resolves it; `--feature` filter on list.
  - **T45** — `--json` envelope shape: `retro lookup --json` / `incidents list --json` emit `{"ok":true,"data":[...]}`; a forced write failure (unusable DB) emits `{"ok":false,"error":{"fail_open":true}}` with exit 2.
  - **T46** — read fail-open: absent Engram CLI / empty surfaces never panic; warns-and-continues with exit 0.
  - **T47** — write FAIL-OPEN: unusable incidents DB path (regular file where the dir must be) → exit 2 + `FAIL-OPEN` marker under `~/.config/sdd-own/srv/works-tool/`.
  - **T47b** — setup 5d-2 warn: missing Go → non-blocking warning; `--check` reports works-tool pending AND stale `sdd-tool` removal pending (stub sdd-tool binary present in sandbox). Sandbox stub binary path updated to `~/.local/bin/works-tool`.
  - **T48** — wiring pins (extended): keeps the 2-prompts + poda assertions; adds: `skills/works-tool/SKILL.md` exists; routing extension `wiring/sdd-own-routing.md` references `~/.local/bin/works-tool`; zero `sdd-tool` refs in owned wiring.
- **Rationale**: The acceptance criteria pin the T40–T48 coverage (list/verify/retro/incidents, FAIL-OPEN, zero sdd-tool refs); the rewrite keeps test IDs and sandbox mechanics stable while reshaping assertions to the new contract.
- **Inputs**: product-rfc Acceptance Criteria; arch-rfc Migration §RED rewrite; finding: current warm-build block and T40–T48 bodies.

### Decision: A11 — ODD wiring insertion points

- **Decision**: Wire `works-tool` via exactly three owned surfaces (there are zero `sdd-tool` refs in deployed `opencode.jsonc` or owned wiring today — wiring is ADDITIVE, nothing to migrate):
  1. **Routing extension** `wiring/sdd-own-routing.md` (deployed via sync Paso 3b into the orchestrator's inline prompt): add a works-tool clause — discover worktrees via `works-tool worktree list --json`, verify before each work-unit via `works-tool worktree verify --feature <name>`, `retro persist --feature <name> --phase <phase> --body-file <report>` when closing a work-unit, `incidents record --feature <name> --summary "<msg>"` on failures, always via the canonical path `~/.local/bin/works-tool`.
  2. **A dedicated full-install skill** `skills/works-tool/SKILL.md` (new own skill, full-install mechanics via the existing sync loop): sub-agents load it before using the tool; it documents the canonical path, the four surfaces, the envelope + exit-code semantics, FAIL-OPEN reading, and the `--feature` vocabulary.
  3. **Task-doc protocol language**: the ODD change task docs' Verification/close flow references the canonical path (this change's own task doc is the first instance).
- **Rationale**: The arch RFC mandates a dedicated `works-tool` SKILL.md and orchestrator-protocol wiring via the canonical path; the routing block is the repo's only owned hook into the orchestrator prompt, and the skill is the only owned surface sub-agents load.
- **Inputs**: arch-rfc External Integrations §skill + orchestrator wiring; finding: 0 `sdd-tool` hits in deployed config and owned wiring; `wiring/sdd-own-routing.md` is the routing-extension seam.

### Decision: A12 — Migration order and verification gate

- **Decision**: Fixed execution order for apply: **T1 (rename)** → **T2 (prune + tidy)** → **T3 (envelope)** → **T4 (worktree signals)** → **T5 (retro)** → **T6 (incidents)** → **T7 (setup.sh)** → **T8 (RED)** → **T9 (wiring + docs)** → **T10 (verification)**, each step leaving the module buildable (`go build ./...` must pass after T1 and after every subsequent step that touches Go). T8 runs only after T4–T7 are implemented (it tests their surfaces); T9's routing/skill references the final name and path, so it lands after the binary surface is stable. The final verification gate is T10: full RED suite + go vet/test + setup.sh --check + grep guard.
- **Rationale**: A rename-first order keeps history reviewable; building the envelope before the command rework prevents per-command rework; RED last avoids churn while surfaces settle — the seeded task plan's T1–T9 intents all survive, reordered and extended with T3/T10 as genuine additions.
- **Inputs**: arch-rfc Migration §order of operations (mv → tidy → RED → setup → docs); finding: task seed T1–T9 ordering.

### Decision: A13 — No separate acta file

- **Decision**: The plan acta is integrated INTO `odd/tasks/works-tool-rewire.md` under this `## Architecture Plan Acta` section; no separate `arch-plan.md` file is created anywhere. The canonical artifact name remains `arch-plan.md` for lint/axis-2 resolution purposes, resolved to this section.
- **Rationale**: The phase contract mandates task-doc integration (decision 3 of the plan contract): the task doc is the binding contract for design and apply, and the lint reads the acta from it (fail-closed when missing).
- **Inputs**: phase contract §Execution and Persistence Contract (task doc always; no separate acta file); architecture-lint SKILL.md §axis 2 acta locator.

## Principios no verificables

Checklist applied to this change, resolved by path from `skills/_shared/architecture-principles.md` (single source; no copies inline). State enum: `applicable | direction-evidence | n-a-justified`.

| ID | State (exactly one) | Evidence or justification (MANDATORY) |
| P01 | applicable | Dependency direction stays inward: `cmd/works-tool` imports `internal/*`; internal packages are a flat peer set (envelope shared leaf); nothing in `internal/*` imports `cmd`; `internal/worktree` no longer imports `internal/scanner` (scanner removed). Commands stay thin cobra wrappers over internal packages. |
| P02 | applicable | Explicit pinned contracts: envelope schema `{ok, feature?, data\|error}` + `error={code,message,fail_open?}` (A3), exit codes 0/1/2 central mapping, command+flag contracts in the task doc (A2), shared retro entry-line format, `--feature` vocabulary — all grep-able and RED-pinned (T40–T48). |
| P03 | applicable | Single source of truth: one module `works-tool`, one DB path constant, one canonical binary path `~/.local/bin/works-tool` shared by setup.sh/wiring/skill/task docs, one `repoRootFromCwd()` helper (A4/A5), one envelope package (A3), principles catalog consumed by path (this table holds no copies). |
| P04 | applicable | Minimal change: diff bounded to rename + 4 retained features; the prune deletes dashboard/scanner/bug/openspec modes instead of adding; no speculative generality (single Engram retro store replaces a 4-mode hierarchy; one envelope package replaces per-command ad-hoc JSON). |
| P05 | applicable | Fail-closed gates: `--feature`/`--id` required (A2); verify never passes without the BLOCKING task-doc signal (A5); missing task doc → FAIL-OPEN marker with exit 2, no append (A6); acta missing/unreadable → lint axis 2 fails closed (A13 note). |
| P06 | applicable | Testability/fixture coverage: RED T40–T48 rewritten as deterministic fixtures per surface (list entries, verify signals, retro dedupe, incidents lifecycle, envelope shape, FAIL-OPEN) (A10); go unit tests retained for scrub/engram/incidents and added for the envelope + topic filter; sandbox mechanics unchanged. |
| P07 | applicable | Separation of concerns: one tool concern per package+command family — `internal/worktree` (list/verify), `internal/retro` (persist/lookup), `internal/incidents` (record/resolve/list), `internal/envelope` (serialization/exit codes), `internal/scrub` (privacy); the plan/lint phases keep their own responsibilities (this acta vs. axis 3). |
| P08 | applicable | Cheap deterministic verification envelope: list/verify are directory enumeration + existence checks (no git subprocess, A4/A5); retro persists via one Engram observation read-modify-write + one task-doc append; the RED suite runs the fixture surfaces within its time budget. |
| P09 | applicable | Stable identity: exit codes 0/1/2, envelope keys `ok/feature/data/error/code/message/fail_open`, key `(feature, phase, ref)`, entry line `- [Retro <phase>] <commit-ref>: <summary>`, flag `--feature`, topic `odd/<feature>/retrospective` — all frozen and RED-pinned in both directions. |
| P10 | applicable | Deterministic execution, no hidden state: re-persisting the same retro key is an in-place idempotent update (A6); setup.sh stale-removal is idempotent and real-mode-only (A8); list/verify depend only on filesystem state; no new global mutable state; re-runs produce byte-stable output. |
| A01 | n-a-justified | Single local CLI binary with no services, no deployments, no scale topology — the distributed-monolith failure mode cannot manifest in this change's scope. |
| A02 | n-a-justified | No service split anywhere in the change; internal packages are in-process library boundaries, not independently deployable units — premature-microservice risk does not apply. |
| A03 | n-a-justified | The only database (incidents SQLite) is written by exactly one component (the `incidents` command's repository); Engram is reached via its own CLI subprocess (never direct DB writes); no other component reads the incidents DB — no shared-DB integration exists. |
| A04 | applicable | The change REMOVES abstraction rather than adding it: the 4-mode retro store hierarchy and the scanner facade are deleted; the only new package (`internal/envelope`) is RFC-mandated and consumed by every `--json` surface (not speculative single-use generality). |
| A05 | applicable | No mutable global state introduced: stores are constructed per command invocation; the scanner's process-lifetime cached snapshot (the prior hidden state) is deleted with the scanner; envelope construction is pure. |
| A06 | applicable | CLI-only, no server, no polling; subprocess calls are bounded (one `git rev-parse HEAD` per retro persist inside the commit-ref-only allowance; Engram CLI per retro op); no synchronous dependency chains are added. |
| A07 | applicable | No god object: the command files stay thin wrappers; logic lives per concern in `internal/worktree`, `internal/retro`, `internal/incidents`, `internal/envelope`, `internal/scrub`; the dashboard module (a candidate god module) is removed. |
| A08 | applicable | Flat internal package set with one import direction (`cmd` → `internal`); the prior worktree↔scanner coupling is cut (scanner deleted, worktree now self-contained); no module depends on many others; `go vet`/imports check in T10 catches tangles. |
| A09 | applicable | Framework use is bounded: cobra retained ONLY at the `cmd` boundary per the arch RFC; bubbletea/bubbles/lipgloss (the TUI framework stack) are dropped; no internal package imports cobra; domain logic is framework-free. |
| A10 | applicable | Shared write-once layers instead of copy/paste: every command routes serialization + fail-open markers through `internal/envelope` (replacing per-file `json.NewEncoder`/`os.Exit` duplication); scrub remains the single shared privacy function; the retro entry-line format is defined once and reused by both stores. |
| A11 | n-a-justified | Each command is a direct handler → one store call (cobra RunE → envelope → single internal package); no handler chains exist — the composite-store fallback chain (the only chain) is deleted in A6. |

## Verification of Record

- Route per task: writer delegated for 2+ non-trivial files (mandatory trigger); assessment via parent per Delegated Verification Gate.
- Commits: work-unit commits on a feature branch (conventional, no push unless asked).
- Deliveries: delivery_strategy `ask-on-risk` → user chose chain_strategy `feature-branch-chain` (2026-09-23): feature branch accumulates integration; PRs target the previous PR branch; only the tracker merges to main. Slice boundaries to be recorded per work-unit commit.
- Plan: `approved` — architecture-plan acta integrated into this task doc (artifact `arch-plan.md`, decisions A1–A13); plan phase gate passed; ready for apply (T1–T10).
- Slice boundaries (2026-09-24): user chose 3-PR chain (`feature-branch-chain`), real line counts vs origin/main @ 7dbabb7 exceeded estimates (quest ~2900 incl. `37314bc` unpushed, core ~4800, wiring ~1170) → size-exception-worthy slices reported in each PR, one honest slicing pass only, per `chained-pr`.
  - PR #10 (tracker, draft/no-merge): `feat/works-tool-rewire` @ 779382c → `main`.
  - PR #11 (quest): `feat/odd-workflow-refactor` @ 6478acf → `main` (includes `37314bc` drop-sdd-prefix, child of `6478acf`, not yet on origin).
  - PR #12 (core): `feat/works-tool-core` @ 978bb8d → `feat/odd-workflow-refactor` (slice 6478acf..978bb8d).
  - PR #13 (wiring): `feat/works-tool-rewire` @ 779382c → `feat/works-tool-core` (slice 978bb8d..779382c).

## Retros
