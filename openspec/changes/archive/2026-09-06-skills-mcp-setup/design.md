# Design: skills-mcp-setup

Change: `skills-mcp-setup` · Phase: design · Hybrid store (OpenSpec + Engram)

Revision: **2 — architecture-lint remediation F1–F9 integrated (2026-09-05)**. F1–F3 mandatory fixes applied; F4–F7 and F9 integrated as accepted design decisions; F8 recorded as an accepted deviation below.

## Technical Approach

Three curated/reauthored skills land in `skills/` (deployed by the existing sync step 1), and a new `setup.sh` wrapper turns the repo into a definitive setup: it **delegates** steps 0–4 to `sync-skills.sh` (unchanged), then runs a self-contained **MCP step** that validates a GitHub PAT (`GET /user`, ≤3 tries, keep-vs-replace), persists it to a 0600 env file outside the repo, and additively merges per-runtime GitHub MCP blocks from declarative definitions in `wiring/mcp.d/` into OpenCode (`opencode.jsonc`, jsonc wins), Pi (global `~/.pi/agent/mcp.json`), and — declared-but-skipped while absent — Claude Code and Codex. Transport is the official remote server `https://api.githubcopilot.com/mcp/` (PAT Bearer); Docker `ghcr.io/github/github-mcp-server` is declared as an alternative. All merges mirror `sync-skills.sh` mechanics (jq `-s` → python3 fallback, `.bak` once, exit 0/1/2, idempotent, `--check`/`--dry-run` never mutate); `wiring/opencode.sdd.json` never gains `mcp`.

## Architecture Decisions

| # | Decision | Options considered | Tradeoff | Decision |
|---|---|---|---|---|
| D1 | Env file path | `~/.config/sdd-own/github-mcp.env` vs `~/.config/github-mcp.env` vs `~/.local/share/github-mcp.env` | Spec-mandated path; `sdd-own` namespace avoids collision with runtime config dirs; XDG-consistent; single obvious discovery point | **`~/.config/sdd-own/github-mcp.env`** (dir 0700, file 0600, var `GITHUB_PERSONAL_ACCESS_TOKEN`); shell alias `GITHUB_PAT` reserved, not used |
| D2 | Set-up architecture | Extend `sync-skills.sh` with MCP step vs new `setup.sh` wrapper | Extending sync violates "sync internals: reuse only" (proposal) and risks AC 8; wrapper keeps sync byte-stable and adds a dedicated entry point | **`setup.sh` wrapper**: delegates sync via subprocess with filtered flags; MCP helpers are a self-contained copy of sync's merge pattern (jq `-s` + python3 `load_jsonc`/`deep_merge`, `.bak`, diff-idempotency) — *reused mechanics, not reused file* |
| D3 | MCP definitions format | Neutral DSL + renderer per runtime vs native-shape fragments in `wiring/mcp.d/` | Neutral DSL needs a schema, parser, and N renderers (spec scenario "new runtime → no restructuring" worse); native fragments render trivially and each already references the env var by name (opencode `{env:...}`, pi `bearerTokenEnv`, codex `bearer_token_env_var`, claude `${...}`) | **`wiring/mcp.d/<runtime>.json` envelopes**: `{runtime, target_mode, target, merge, root_key, server_key, presence, block, alt_docker}`; block is the exact native fragment, token-free, wrapped per F6 (json-key) or bare (toml-section) |
| D4 | Transport | Remote hosted (official, zero local deps, PAT Bearer everywhere) vs Docker (offline, `--env-file`) vs release binary | Remote: consistent across all 4 targets, no daemon; Docker: extra pull, per-runtime daemon, but offline-capable. RFC non-goal = PAT-only, remote satisfies it | **Remote primary**; Docker alternative **declared** in every envelope (`alt_docker`) and rendered when `MCP_GITHUB_TRANSPORT=docker` env override is set (documented, no new CLI flag — flag surface stays per spec) |
| D5 | OpenCode target | `opencode.jsonc` vs `opencode.json` vs both | Both exist on this machine; opencode merges `config.json` → `opencode.json` → `opencode.jsonc`; `.jsonc` wins (source-confirmed). Merge must land where the authoritative bytes live | **Detect `OPENCODE_CONFIG` → `opencode.jsonc` → `opencode.json`** (sync's exact order); merge touches ONLY the `mcp` key |
| D6 | Secret indirection | One env file, per-runtime env-var reference vs per-runtime env files vs literal tokens | RFC invariant: blocks never hold literals; no cross-runtime `envFile` feature exists; runtimes read process env | **Single 0600 env file; every block references the var name**. README documents exporting it to the shell profile (runtime processes inherit); setup.sh exports it for its own subprocesses only |
| D7 | Claude block auth syntax | Literal header (violates invariant) vs `${VAR}` interpolation | Claude Code substitutes `${VAR}`/`${VAR:-default}` in `url`/`headers`/`env` of `mcpServers` (verified); `claude mcp add -e` would persist the literal value into config — forbidden | **`headers: {"Authorization": "Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}"}`**; declared-but-skipped (`command -v claude` gate) |
| D8 | Skill naming | Keep upstream names vs rename (`git-worktrees`) | Upstream name preserves provenance and resolver familiarity; description carries the trigger scope, not the name | **Keep `using-git-worktrees`, `test-fixing`; `github-automation`** (name was free, ecosystem-recognized) |
| D9 | Registry sync | `gentle-ai skill-registry refresh --force` via setup's own call vs pass `--registries` through | sync step 4 already owns refresh with its report/exit semantics; setup reusing it avoids a second refresh path | **Pass `--registries <proyecto...>` through to sync**; setup never calls `skill-registry` itself |
| D10 | Non-interactive behavior | Fail vs read token from env var | Reading from env invites leakage into shell history/environments; spec has no non-interactive token input | **`[[ -t 0 ]]` guard**: real mode + no TTY + token needed → exit 1 "run interactively or pre-seed the env file"; `--check`/`--dry-run` never prompt |
| D11 | Claude auth syntax (F8 — ACCEPTED DEVIATION) | Keep spec's `-e` vs keep `${VAR}` (D7) | `claude mcp add -e` persists the literal token into `~/.claude.json`, violating the spec's own no-literal invariant (mcp-definitions); `${VAR}` keeps config token-free, Claude Code substitutes at runtime (externally verified) | **DEVIATION ACCEPTED by orchestrator**: Claude uses `headers: {"Authorization": "Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}"}` (static-JSON env indirection). The mcp-definitions "Claude `-e`" line is superseded; tasks/verify MUST honor `${VAR}` as the Claude contract |
| D12 | Codex TOML merge (F3) | python3 `tomllib`+`tomli-w` vs manual bounded string rewrite vs extra PyPI lib (`toml`) | `tomllib` is stdlib (parse) and `tomli-w` a declared dependency; manual rewrite risks quoting/escaping bugs; extra PyPI lib is unneeded | **python3 `tomllib` (parse) + `tomli-w` (write)**; `tomli-w` missing → `[ERROR]` + exit 2 BEFORE any write; re-merge diff-identical → `[up-to-date]` (decision taken now; latent while codex is declared-but-skipped) |
| D13 | Hard deps fail-fast (F4) | Startup check vs fail at first use | curl is required for token validation; docker only for the `alt_docker` variant; mirror sync's "requiere jq o python3" guard style | **Fail-fast usage guard**: missing `curl` → `[ERROR]` + exit 2 before delegation; missing `docker` → same, only when `MCP_GITHUB_TRANSPORT=docker` |
| D14 | Env-file rotation hygiene (F5) | `cp` vs `cp -p`; keep `.bak` forever vs delete stale | `cp` re-derives mode from umask; stale `.bak` files accumulate expired secret copies | `.bak` via `cp -p` (preserves 0600); after a successful rotation DELETE the stale previous `.bak` — at most one backup retained |
| D15 | Presence semantics (F2) | `command -v` vs `test -f` config vs hybrid | `test -f ~/.pi/agent/mcp.json` conflates "runtime installed" with "config exists" and silently skips installed-but-unconfigured runtimes; config detection is opencode's only meaningful gate | `presence` = **runtime installed**: `command -v <runtime>` for pi/claude/codex; opencode = config detection (`OPENCODE_CONFIG` → `.jsonc` → `.json`, target_mode). Evaluated `bash -c "$presence"` over the repo-fixed string (trust boundary). Target-existence: installed + missing target json/toml → CREATE (`.bak`-less); CLI absent → SKIP (spec "Absent runtimes" + quest edge case) |
| D16 | `--check` exit + real-mode gate (F9) | Run MCP despite sync exit 2 vs gate; network failure = drift vs structural | Sync exit 2 means apply failed — proceeding to MCP reuses broken state; unreachable API is structural, invalid token is drift | Real mode: MCP step runs ONLY if sync exit ≤ 1 (sync 2 → skip MCP, propagate 2). `--check`: env-file token non-200 → drift (exit 1); network failure blocking validation → structural (exit 2); missing token → clean state (exit 0) |

> **F8 — Accepted deviation (formal)**: the mcp-definitions spec's "Claude `-e`" indirection line is superseded by D11 (`${VAR}` static-JSON indirection). Accepted by the orchestrator: `-e` persists the literal token into config, which violates the no-literal invariant the spec itself declares. Tasks and verify MUST track `${VAR}` as the Claude contract, not `-e`.

## Data Flow

```
setup.sh <flags>
  │  parse flags (unknown → usage, exit 1; --check ∧ --dry-run → exit 1)
  │  build SYNC_FLAGS (subset sync understands; never --skip-mcp/--force-mcp-token)
  ▼
[Step 0] sync-skills.sh $SYNC_FLAGS  ──►  its steps 0–4 + report; exit code captured (0/1/2)
  │      sync exit ≥ 2 → MCP step SKIPPED, propagate exit 2 (F9 gate)
  │
[Step 5] MCP step (skipped if --skip-mcp; plan-only in --check/--dry-run)
  │
  ├─ 5a runtime detection  ──►  for each wiring/mcp.d/*.json envelope:
  │      presence = runtime installed (pi/claude/codex: `command -v <runtime>` · opencode:
  │      config detection OPENCODE_CONFIG → .jsonc → .json), evaluated `bash -c "$presence"`
  │      over the repo-fixed string (trust boundary; never user input)
  │      CLI absent → "declared, skipped" notice (never fails the run)
  │      installed + target json/toml missing → CREATE target (`.bak`-less; quest edge case)
  │
  ├─ 5b token gate (REAL mode only)  ──►  env file exists?
  │      ├─ no  → prompt (read -s, no echo), validate GET /user, ≤3 tries
  │      ├─ yes + valid + no --force → ask keep/replace; keep → no rewrite
  │      └─ yes + invalid / --force → prompt; backup env file (.bak) → write on 200
  │      validate: export token from env file for this subprocess only; curl -sS --max-time 15
  │        -o body -D headers -K <tmpfile> https://api.github.com/user   ← token NEVER in argv (F1)
  │        tmpfile: umask 0622 (→ 0600), line `header = "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}"`;
  │        curl expands ${VAR} from the environment INSIDE the config file; tmpfile deleted in a
  │        trap after the call; no -v/--trace ever
  │      ├─ 200 → parse x-oauth-scopes (classic): warn missing repo/read:org/workflow
  │      │        + "change token before continuing? [y/N]"; no header → fine-grained:
  │      │        "scopes unverifiable" notice, continue
  │      ├─ non-200 → re-prompt (≤3), nothing persisted
  │      └─ curl failure/timeout → clear network failure, nothing persisted
  │
  ├─ 5c persist (only on 200)  ──►  install -d -m 700 ~/.config/sdd-own
  │      tmp file + mv, chmod 600, verify mode; token never in argv/logs/output
  │      (report shows masked fingerprint only, e.g. ghp_••••1234)
  │      rotation: env-file .bak via cp -p (preserves 0600); on success delete the stale
  │      previous .bak — at most one backup retained (F5)
  │
  └─ 5d per-runtime merge (--check/--dry-run: report only)
         render block from envelope (primary, or alt_docker if MCP_GITHUB_TRANSPORT=docker)
         json-key merge (opencode `mcp.github`, pi/claude `mcpServers.github`):
           jq -s '.[0] * {KEY: (.[0].KEY // {}) * .[1]}'  → python3 deep_merge fallback
           .bak once · diff-identical → [up-to-date] (idempotent) · else write
         toml-section merge (codex `[mcp_servers.github]`): python3 tomllib (parse)
           + tomli-w (write; fail-fast `[ERROR]`+exit 2 if missing); diff-identical → [up-to-date] (F3)
  │
  ▼
Final report (sync-style markers [ok]/[DESYNC]/[FALTA]/[pendiente]/[actualizado]/[up-to-date]/[ERROR]/[aviso])
+ "Resumen:" mirroring sync: skills, MCP per-runtime install/update/skip, token status
Exit: 0 success · 1 usage/check-desync · 2 apply failure (max of sync and MCP step exits)
```

## Contracts

### `wiring/mcp.d/<runtime>.json` envelope

```jsonc
{
  "runtime": "opencode",                      // unique id; file name matches
  "target_mode": "opencode-config",           // "opencode-config" | "path"
  "target": "~/.pi/agent/mcp.json",           // used when target_mode = "path"
  "merge": "json-key",                        // "json-key" | "toml-section"
  "root_key": "mcp",                          // "mcp" | "mcpServers" | "mcp_servers"
  "server_key": "github",                     // json-key: wrapper key inside block · toml: names the section
  "presence": "command -v pi", // runtime-installed predicate (pi/claude/codex); "" = always;
                               // opencode: config detection (target_mode "opencode-config");
                               // evaluated via `bash -c "$presence"` over the repo-fixed string
  "block": { /* json-key: WRAPPED {<server_key>: body}, e.g. {"github": {...}} · toml-section: bare body */ },
  "alt_docker": { /* optional local docker variant; same wrapping contract as block */ }
}
```

**Block wrapping (F6)**: for `merge: "json-key"`, the stored `block` INCLUDES the `server_key` wrapper (`{"github": {...}}`) and the merge is `target[root_key] * block` (deep merge); for `merge: "toml-section"`, `block` is the bare section body and `server_key` names the section (`[mcp_servers.<server_key>]`). Applies to `alt_docker` identically. One wrapping rule — no ambiguity.

### Per-runtime primary blocks (token-free by construction; json-key rows shown wrapped per F6)

| Runtime | Target / key | Block |
|---|---|---|
| OpenCode | detected config (`OPENCODE_CONFIG` → `.jsonc` → `.json`) / `mcp` | `{"github": {"type":"remote","url":"https://api.githubcopilot.com/mcp/","headers":{"Authorization":"Bearer {env:GITHUB_PERSONAL_ACCESS_TOKEN}"},"oauth":false}}` |
| Pi | `~/.pi/agent/mcp.json` / `mcpServers` | `{"github": {"url":"https://api.githubcopilot.com/mcp/","bearerTokenEnv":"GITHUB_PERSONAL_ACCESS_TOKEN"}}` (adapter env-var indirection) |
| Claude | `~/.claude.json` / `mcpServers` | `{"github": {"type":"http","url":"https://api.githubcopilot.com/mcp/","headers":{"Authorization":"Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}"}}}` |
| Codex | `~/.codex/config.toml` / `[mcp_servers.github]` — `server_key` names the section | bare body: `url = "https://api.githubcopilot.com/mcp/"` + `bearer_token_env_var = "GITHUB_PERSONAL_ACCESS_TOKEN"` |

`alt_docker` (all runtimes): `docker run --rm -i --env-file ~/.config/sdd-own/github-mcp.env ghcr.io/github/github-mcp-server` — rendered when `MCP_GITHUB_TRANSPORT=docker`; documented in README.

### Env file (`~/.config/sdd-own/github-mcp.env`, 0600)

```bash
# GitHub MCP token — written by setup.sh (mode 0600). Rotate in the GitHub UI; do not commit.
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_...
```

### setup.sh flags and exits

| Flag | Effect |
|---|---|
| `--check` | Sync check (delegated with `--check`) + MCP state report (configured-or-absent, token valid/invalid/missing; validates only if env file exists) — no writes, no prompt. Exit 0 = consistent state (absent MCP + missing token is a valid clean state), 1 = drift (incl. env-file token non-200), 2 = structural errors (incl. network failure blocking validation — F9) |
| `--dry-run` | Sync dry-run + MCP plan incl. the would-be prompt — no writes, **no network validation** |
| `--skip-gentleai-sync` / `--skip-opencode` / `--registries <p...>` | Forwarded verbatim to `sync-skills.sh` |
| `--skip-mcp` | Skips the MCP step only; sync still runs |
| `--force-mcp-token` | Forces re-prompt + re-validation even with a valid existing token (existing env file backed up first) |

`--check` ∧ `--dry-run` mutually exclusive (enforced before delegation). Real mode: the MCP step runs ONLY when sync exits ≤ 1; sync exit 2 → MCP step skipped, exit 2 (F9). Exit: `max(sync_exit, mcp_exit)` mapped to 0/1/2 mirroring sync.

## File Changes

| File | Action | Description |
|---|---|---|
| `setup.sh` | Create (executable) | Wrapper: flag parsing/filtering, sync delegation, token gate, env-file persistence, per-runtime merge, sync-style report/exit |
| `wiring/mcp.d/opencode.json` | Create | Envelope + remote block (D5 detection) |
| `wiring/mcp.d/claude.json` | Create | Envelope + `${VAR}` block (D7), absent-runtime ready |
| `wiring/mcp.d/pi.json` | Create | Envelope + `bearerTokenEnv` block, global target |
| `wiring/mcp.d/codex.json` | Create | Envelope + TOML section block |
| `wiring/mcp.d/README.md` | Create | Declarative contract: envelope schema, add-a-runtime steps, docker variant |
| `skills/using-git-worktrees/SKILL.md` | Create | Vendored from `obra/superpowers` (MIT, Jesse Vincent); single file, frontmatter per suite, minimal adaptation |
| `skills/test-fixing/SKILL.md` | Create | Adapted from `mhattingpete/claude-skills-marketplace` (Apache-2.0); pytest/uv → stack-neutral (pytest as example only) |
| `skills/github-automation/SKILL.md` | Create | Fresh reauthoring (no upstream file), Compo-sio-family skeleton only as inspiration; official github-mcp-server tools; automation/ops scope |
| `README.md` | Modify | New "Definitive setup" + "MCPs" sections, skills table rows, wiring tree, Estructura, Licencia provenance; documents the sanctioned exception — setup.sh is the one allowed writer of the opencode config `mcp` key outside the sync pipeline (F7; mirrors the AGENTS.md section) |
| `AGENTS.md` | Modify | New section documenting `setup.sh` as the **sanctioned exception** writer of the opencode `mcp` key + `wiring/mcp.d/` convention; golden rules untouched |

## github-automation structure (reauthored)

Frontmatter `name: github-automation`; description scopes to automation/ops and explicitly disambiguates from `github-pr`/`branch-pr`/`chained-pr`/`issue-creation` (they own PR/issue creation). Sections: **Prerequisites** (GitHub MCP via setup.sh; official server; zero tokens) → **Tool surface** (`github_*` families: browse repo, issues, branches, commits, pulls (merge/review/status — not create), actions/workflows, code search, repos; toolsets/readonly gating) → **Automation workflows** (repo ops · issue triage ops · PR ops · branch/commit ops · actions ops · code-search ops, each with task→tool mapping) → **Pitfalls** (rate limits, scopes `repo`/`read:org`/`workflow`, context-window via toolset limiting) → **Quick reference**. Zero matches for `Composio|rube|RUBE_|ghp_|github_pat_` (RED-checked).

## Testing Strategy

No test runner in this config repo (`tdd: false`); planned **shell-level RED checks** (carried into tasks as RED steps):

| Layer | What | How |
|---|---|---|
| Syntax | `setup.sh`, `sync-skills.sh` | `bash -n` both (verify phase extends `build_command`) |
| Idempotency | Double real run | Second run reports `[up-to-date]`; configs byte-identical; `mcp.github` key count == 1 (jq) |
| Non-mutation | `--check`, `--dry-run` | Snapshot file tree + mtimes before/after → identical; no prompt in non-TTY |
| Token gate | Invalid token | `SDD_OWN_GH_API` test seam → local fake returning 401: 3 prompts, nothing persisted, exit 2 |
| Secret hygiene | Leak check | Fake token `ghp_REDTEST123`; grep full run output/logs → zero matches; env file mode == 600 |
| Keep/replace | Valid existing | Preset env file + fake 200: keep → file mtime unchanged; replace → `.bak` created |
| Scopes | Classic without `repo` | Fake 200 + `x-oauth-scopes: read:org` → warning + change option, run continues |
| Collision | Invalid existing file | Replace path backs up `.bak` before overwrite (explicit consent = the prompt) |
| Regressions | Suite | `./sync-skills.sh --check` still exits 0 (AC 8) after full setup run |
| Token argv hygiene (F1) | Child curl argv | Fake token via `SDD_OWN_GH_API` seam: child curl `/proc/<pid>/cmdline` contains no token; config-file dump (seam) holds only the `${GITHUB_PERSONAL_ACCESS_TOKEN}` literal; curl config tmpfile mode 0600 and deleted via trap after the call |
| Presence semantics (F2) | Absent CLI vs installed + missing target | `bash -c "$presence"` over repo strings: absent `command -v` → skip; installed + missing target json/toml → target created `.bak`-less; re-run reports `[up-to-date]` |
| TOML merge (F3) | Fake `config.toml` | `tomllib` parse + `tomli-w` write → `[mcp_servers.github]` correct; re-run `[up-to-date]`; `tomli-w` absent → `[ERROR]` + exit 2, target untouched |
| Hard deps (F4) | PATH without curl / docker | Missing curl → fail-fast exit 2 before delegation; missing docker only under `MCP_GITHUB_TRANSPORT=docker` |
| Env rotation (F5) | Replace valid token | `.bak` mode == 600 (`cp -p`); stale previous `.bak` removed after success |
| Wrap contract (F6) | Envelope shapes | json-key blocks ship wrapped under `server_key`; codex block is bare body; RED-check done by inspecting the 4 envelope files |
| Exit gates (F9) | sync exit 2 / 401 / no network | Fake sync exit 2 → MCP skipped, exit 2; `--check` + fake 401 → exit 1 (drift); `--check` + unroutable API → exit 2 (structural) |
| README exception (F7) | README grep | README mentions the sanctioned exception and links `wiring/mcp.d/` |

## Threat Matrix

| Boundary | Min adversarial cases | Applicability | Design response | Planned RED tests |
|---|---|---|---|---|
| Documentation-like paths | executable Markdown/`README.sh` | **N/A** — no doc-as-code execution introduced; skills are data, executed by hosts | — | — |
| Git repository selection | `git -C`, relative/absolute | **N/A** — setup.sh resolves `SCRIPT_DIR` and repo-relative paths only; never runs `git` | — | — |
| Commit state | staged, `commit -a`, empty index | **N/A** — no commit operations | — | — |
| Push state | tracking branch, refspec | **N/A** — no push operations | — | — |
| PR commands | `--head`, env prefix | **N/A** — no PR operations (github-automation skill instructs MCP tools, doesn't shell out) | — | — |
| Subprocess composition | setup.sh → sync-skills.sh; `bash -c "$presence"`; python3 tomllib/tomli-w | **Applicable** | Only the sync-understood flag subset is forwarded (`--check/--dry-run/--skip-gentleai-sync/--skip-opencode/--registries`); setup-only flags (`--skip-mcp`, `--force-mcp-token`) never reach sync; sync exit captured and propagated (exit ≥ 2 gates the MCP step, F9); delegation via `"$SCRIPT_DIR/sync-skills.sh"`, never PATH lookup; presence strings are repo-fixed (never user input); tomli-w missing → fail-fast | Unknown-flag → exit 1 before delegation; forwarded argv contains no setup-only flag (unit-inspect with `MCP_DEBUG_SYNC_ARGS` seam); tomli-w absent → `[ERROR]` exit 2 without touching the target |
| Secret handling in argv/logs/output | token in argv, `curl -v`, echoed prompt, config literals | **Applicable** | `read -rs` prompt; validation via `curl -K` config file (umask 0622 → 0600; `header = "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}"` — curl expands `${VAR}` from env INSIDE the file so argv stays clean; tmpfile removed in a trap); no `-v`/`--trace`; responses trimmed to status + `x-oauth-scopes`; masked fingerprint only in reports; env-file write `umask 077` + `chmod 600` + mode verify; rotation `.bak` via `cp -p` (0600) and stale `.bak` deleted (F5); blocks reference env var names only | `ghp_REDTEST123` grep across full run output/logs/tmp → zero matches; child curl `/proc/<pid>/cmdline` (or `SDD_OWN_GH_API` config dump) contains no token (F1); curl config tmpfile mode 0600 and deleted; config diffs contain no token |
| Remote validation call | non-200, timeout, DNS failure | **Applicable** | `curl --max-time 15 -K <tmpfile>` (config-file auth, argv clean — F1); 200 → persist; non-200 → re-prompt ≤3, nothing persisted; curl error/empty → clear "no network" failure, nothing persists (`--check`: structural exit 2 — F9); fine-grained (no `x-oauth-scopes`) → "unverifiable" + continue | Fake 401 → no env file (`--check`: exit 1 drift); fake timeout (unroutable `SDD_OWN_GH_API`) → no env file + clear failure (`--check`: exit 2 structural); absence/`github_pat_` → notice path |

Applicable rows are design requirements and MUST propagate to tasks with their RED tests unchanged; `N/A` rows require no task.

## Integration with sync (reuse vs not)

- **Reuse**: config detection order (`OPENCODE_CONFIG` → `.jsonc` → `.json`); jq `-s` deep-merge + python3 `load_jsonc`/`deep_merge` fallback pattern; `.bak`-once semantics; byte-diff idempotency; exit 0/1/2; report markers (`[ok]`, `[DESYNC]`, `[FALTA]`, `[pendiente]`, `[actualizado]`, `[up-to-date]`, `[ERROR]`, `[aviso]`); `--registries` delegation.
- **Not reused / untouched**: overlay strip+append (MCP blocks are JSON keys, not `sdd-own` markers); `sync-skills.sh` itself (zero edits); `wiring/opencode.sdd.json` (never gains `mcp`); repo `.pi/mcp.json` (gentle-ai state; Pi targets the global config).

## Migration / Rollout

No migration required (greenfield additions). Rollout: one real `setup.sh` run. Rollback: restore `.bak` (or delete `mcp`/`mcpServers` keys), delete `~/.config/sdd-own/github-mcp.env`, delete the three `skills/` dirs; SDD fragment untouched; `./sync-skills.sh --check` unaffected.

## Risks

| Risk | Mitigation |
|---|---|
| Live configs (`opencode.jsonc`, `~/.pi/agent/mcp.json`) | Additive `mcp`-key-only merges, `.bak` once, idempotent diff, `--check`/`--dry-run` non-mutating |
| jsonc comment loss on python3 fallback re-serialization | Same behavior as existing sync merge (no new risk class); `.bak` preserves the original; first choice is jq when the target parses |
| claude/codex absent | Declared-but-skipped gates; definitions ready for later installs |
| Token must reach runtime process env | Env file exported in shell profile (README documents exact line); blocks reference var names so a missing export fails loudly at runtime, not silently |
| `github-automation` trigger overlap | Scoped description + explicit disambiguation in body; POST-creation tools fenced out |
| Fine-grained scopes unverifiable | Notice path, never blocks (RFC non-goal) |
| codex toml merge deps | `tomli-w` missing → fail-fast `[ERROR]` + exit 2 before writes (declared dependency; `tomllib` is py3.11+ stdlib) |

## Open Questions

None blocking. Apply-time note (not a task blocker): Pi adapter may require `lifecycle`/`directTools` keys on the pi-mcp-adapter 2.32.1 schema for the URL server entry — verify against the installed adapter at apply and add only the minimal keys needed; the block contract above is the default.

## Idempotency guarantees (config rule) / skill provenance (config rule)

- **Idempotency**: every write path — env file, json-key merge, toml-section sync — converges to fixed bytes and re-runs report `[up-to-date]`; `.bak` written only when the target first diverges; `--check`/`--dry-run` provably non-mutating.
- **Provenance**: `using-git-worktrees` and `test-fixing` are ours-but-vendored (MIT / Apache-2.0 attribution preserved, distinct from Alan's base skills which sync installs); `github-automation` is fully ours (fresh authorship, repo MIT), no upstream license file.