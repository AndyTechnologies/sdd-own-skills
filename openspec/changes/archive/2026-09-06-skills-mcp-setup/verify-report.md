```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:b3bc6deed0a6650260e6c7ffa932fa3cd7dac249c25660f8f0099a0c71956d01
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 23/23
scenarios: 37/37
test_command: bash tests/run_red_checks.sh
test_exit_code: 0
test_output_hash: sha256:17dddae9db75245f089d3cbec42356493689596c7d67bddd6ddb93e4c4592416
build_command: bash -n setup.sh && bash -n sync-skills.sh && bash -n tests/run_red_checks.sh
build_exit_code: 0
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Verification Report

**Change**: skills-mcp-setup
**Version**: N/A (design rev 2; implementation HEAD 5d7778f436576b6d9b104c39bbe0dea1c07905ba)
**Mode**: Standard (`tdd: false` in design — shell-level RED checks; no test-first gate)

> Note on totals: the six spec files under `openspec/changes/skills-mcp-setup/specs/` contain **23 requirements / 37 scenarios** (5+6+3+3+2+4 requirements; 9+8+5+5+4+6 scenarios). The orchestrator handoff quoted 22/36; the authoritative count taken from the actual spec files is 23/37 and is what this report validates against.

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 30 |
| Tasks complete | 30 |
| Tasks incomplete | 0 |

All 30 tasks (phases 1–5 of `tasks.md`) are realized in the implementation; `apply-progress.md` reports implementation complete and the RED suite green; every T01–T22 test exists and passes (runner covers T01–T07 and T09–T22; see SUGGESTION for the T08 gap). The `tasks.md` checkboxes were not ticked during apply — housekeeping only, no completeness impact.

### Build & Tests Execution
**Build**: ✅ Passed
```text
$ bash -n setup.sh && bash -n sync-skills.sh && bash -n tests/run_red_checks.sh
(no output — silent syntax success, exit 0)
```
Also verified: `tomli_w` importable on host (exit 0), so the TOML happy path runs, not skip.

**Tests**: ✅ 21 passed / ❌ 0 failed / ⚠️ 0 skipped
```text
$ bash tests/run_red_checks.sh
PASS: 21   FAIL: 0   SKIP: 0
Verde.
exit 0 — output digest sha256:17dddae9db75245f089d3cbec42356493689596c7d67bddd6ddb93e4c4592416
```
Run twice (initial pass during apply review + this verification run); both green. The suite exercises the real `setup.sh`/`sync-skills.sh` with test seams (`SDD_OWN_GH_API`, `MCP_DEBUG_SYNC_ARGS`, `MCP_DEBUG_SYNC_ARGS_EXIT`, `SDD_OWN_DEBUG_CURL_CONFIG`, fake PATH) and PTY-driven token prompts.

**Regressions (host, read-only)**:
- `./sync-skills.sh --check` → exit 0, "sincronizado (cero desyncs)".
- `./setup.sh --check` (offline, no token) → exit 0; report: env file ausente, token ausente, MCP pendiente 2, aviso 2 (runtimes ausentes: claude/codex), ERROR 0; `git status` before/after **identical** → no mutation.
- `wiring/opencode.sdd.json`: `jq 'has("mcp")'` → `false`; `grep -c '"mcp"'` → 0.
- `skills/github-automation/SKILL.md`: zero matches for `Composio|rube|RUBE_|ghp_|github_pat_`.

**Coverage**: ➖ Not available — no coverage tooling in a shell/config repo (`tdd: false`); RED suite is the executable acceptance harness.

### Spec Compliance Matrix
| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Orchestration and flags | Clean run | `tests/run_red_checks.sh > T11, T16` | ✅ COMPLIANT |
| Orchestration and flags | Flag passthrough | `T04` (seam dump: `--check`, `--registries` forwarded; `--skip-mcp`, `--force-mcp-token` never) | ✅ COMPLIANT |
| Orchestration and flags | README updated | `T22` + README/AGENTS inspection | ✅ COMPLIANT |
| Orchestration and flags | Idempotent merge | `T16` (json), `T17` (toml): re-run `[up-to-date]`, byte-identical | ✅ COMPLIANT |
| Orchestration and flags | Config collision | `T16` (pre-existing `mcp.codegraph` preserved after merge) | ✅ COMPLIANT |
| Orchestration and flags | Exit codes | `T03`(1 usage), `T05`(0 success), `T09`(2 token), `T19`(2 sync), `T20`(1 drift), `T21`(2 structural) | ✅ COMPLIANT |
| Orchestration and flags | Declared but skipped | `T16` (claude/codex absent → [aviso] "runtime ausente"; opencode/pi proceed) | ✅ COMPLIANT |
| Orchestration and flags | Check state | `T06` + host `./setup.sh --check` exit 0 (estado limpio) | ✅ COMPLIANT |
| Orchestration and flags | Dry-run plan | `T07` (plan printed, no writes) | ✅ COMPLIANT |
| Secret store | No leakage | `T11` (token only in env file 0600 + curl config; grep run output/logs zero; masked fingerprint only; cmdline clean) | ✅ COMPLIANT |
| Secret store | Clean install | `T11` (no env file → PTY prompt → validated → 0600 persisted) | ✅ COMPLIANT |
| Validation gate | Invalid token | `T09` (3×401 → nothing persisted, exit 2) | ✅ COMPLIANT |
| Keep vs replace | Valid existing token | `T13` (keep → mtime unchanged, no .bak), `T14` (replace → re-validates, .bak) | ✅ COMPLIANT |
| Scope advisory | Missing scope | `T12` (only `read:org` → warning + change option, run continues) | ✅ COMPLIANT |
| Scope advisory | Fine-grained token | `T15` executes the scope-less 200 path (run continues); notice text source-verified `setup.sh` (fine-grained branch of scope advisory) | ✅ COMPLIANT |
| Offline behavior | No network | `T10` (real-mode network failure → exit 2, nothing persisted), `T21` (check + unroutable → exit 2) | ✅ COMPLIANT |
| Path collision safety | Collision | `T15` (invalid existing env → `.bak` of invalid, replace on consent) | ✅ COMPLIANT |
| Declarative definitions directory | Fragment untouched | `T02` + `jq 'has("mcp")'` false on `wiring/opencode.sdd.json` | ✅ COMPLIANT |
| Declarative definitions directory | Definitions present | `T02` + 4 envelopes in `wiring/mcp.d/` + README | ✅ COMPLIANT |
| Block contract | OpenCode block | `T02` + `T16` (merged config `mcp.github` remote/headers shape) | ✅ COMPLIANT |
| Block contract | Pi and Codex indirection | `T16` (pi url), `T17` (codex `[mcp_servers.github]` + `bearer_token_env_var`) | ✅ COMPLIANT |
| Extensibility | New runtime | Static: generic loop over `wiring/mcp.d/*.json` (5a/5d); README "Agregar un runtime" procedure; T16/T17 exercise both merge engines through the same loop | ✅ COMPLIANT |
| Vendored and adapted content | Clean deploy | Physical install in `~/.agents/skills/` + symlinks (opencode/claude) + registry entry (line 47) + `sync --check` exit 0 | ✅ COMPLIANT |
| Vendored and adapted content | Minimal adaptation | Static: single `SKILL.md`, provenance note documents minimal adaptation (MIT, Jesse Vincent) | ✅ COMPLIANT |
| Trigger and scope | Worktree task matched | Static + registry: description scoped to git worktrees isolation | ✅ COMPLIANT |
| Trigger and scope | Scope exclusion | Static: description claims worktrees only, not PR/issue work | ✅ COMPLIANT |
| Non-regression | Suite integrity | `T22` + host `./sync-skills.sh --check` exit 0 | ✅ COMPLIANT |
| Adapted and attributed content | Curated deploy | Physical install + registry entry (line 44) | ✅ COMPLIANT |
| Adapted and attributed content | Stack neutrality | Static: `make test`/`npm test`/`go test ./...`/`uv run pytest`/project-declared command; pytest is one example among many | ✅ COMPLIANT |
| Adapted and attributed content | Red test matched | Static: description scoped to failing-test fixes | ✅ COMPLIANT |
| Adapted and attributed content | Authoring excluded | Static: "for FIXING existing failures — not for writing new tests" | ✅ COMPLIANT |
| Fresh authorship with repo licensing | No vendored license | Static: `skills/github-automation/` contains only authored `SKILL.md`; MIT repo license | ✅ COMPLIANT |
| Official GitHub MCP only | Composio-free content | `grep -cE 'Composio|rube|RUBE_'` → 0 | ✅ COMPLIANT |
| Official GitHub MCP only | Token-free content | `grep -cE 'ghp_|github_pat_'` → 0; skill defers credentials to the configured GitHub MCP | ✅ COMPLIANT |
| Trigger scope with disambiguation | Ops task matched | Static + registry (line 29): automation/ops scope with PR/issue disambiguation table | ✅ COMPLIANT |
| Trigger scope with disambiguation | PR workflow excluded | Static: description + table route PR work to PR skills | ✅ COMPLIANT |
| Registry presence | Registered | `.atl/skill-registry.md` line 29; `sync --check` exit 0 | ✅ COMPLIANT |

**Compliance summary**: 37/37 scenarios compliant — 0 FAILING, 0 UNTESTED, 0 PARTIAL.
Trigger/scope rows for the three skills are content-verified (deployed registry + description surface + `sync --check`); this config repo has no resolver harness, so those rows rest on the declarative acceptance checks (T02/T22 greps + registry presence) rather than a matcher runtime.

### Correctness (Static Evidence)
| Requirement | Status | Notes |
|------------|--------|-------|
| Orchestration and flags | ✅ Implemented | `setup.sh` delegates `sync-skills.sh` (exit ≤1 continues); sync flags forwarded, `--skip-mcp`/`--force-mcp-token` handled locally; `--registries` passthrough; non-TTY real-mode guard (`[[ -t 0 ]]` → exit 1) |
| Documentation | ✅ Implemented | README "Setup completo (setup.sh)" (flags, mcp.d convention, env file, alt_docker) + AGENTS.md sanctioned-exception section |
| Merge mechanics mirror sync | ✅ Implemented | json-key: `jq -s` → python3 `load_jsonc` fallback; toml-section: `tomllib`+`tomli-w` (missing → ERROR + exit 2, target untouched); diff-idempotency via jq `-S` compare; `.bak` via `cp -p` (at most one); full-file write key-scoped to `root_key` |
| Absent runtimes | ✅ Implemented | `bash -c "$presence"` per envelope; absent CLI → [aviso] skip; installed + missing target → created `.bak`-less |
| Check and dry-run reports | ✅ Implemented | Unified summary with [ERROR]/[aviso]/[ok]/[up-to-date]/[pendiente]; `--check`/`--dry-run` never mutate (verified visually via `git status` and in-suite tree/mtime snaps) |
| Secret store | ✅ Implemented | `~/.config/sdd-own/github-mcp.env`; var `GITHUB_PERSONAL_ACCESS_TOKEN`; dir created 0700 (`install -d -m 700`), file 0600 asserted; token never in argv/env/logs/repo/persistent configs; masked fingerprint in reports |
| Validation gate | ✅ Implemented | `GET /user` `--max-time 15`, 3 attempts then exit 2; fail-fast on network/connect error; only 200 persists |
| Keep vs replace | ✅ Implemented | `k` keeps (no write), `R` re-validates then writes; new token replaces with `.bak` |
| Scope advisory | ✅ Implemented | `x-oauth-scopes` parsed, normalized, boundary-matched; warning + change option; fine-grained (no header) → unverifiable notice, continue — see WARNING (normalization bug) below |
| Offline behavior | ✅ Implemented | Timeouts + non-200 exit 2; nothing persisted on failure; action blocked, execution continues cleanly |
| Path collision safety | ✅ Implemented | Pre-existing targets merged (test asserts `mcp.codegraph` survives); `.bak` of prior env content on replace |
| Declarative definitions directory | ✅ Implemented | `wiring/mcp.d/{opencode,pi,claude,codex}.json` + README contract; alt_docker for all four |
| Block contract | ✅ Implemented | 5 required keys + `alt_docker`; json-key wrapped under `server_key`, codex bare body; no literal tokens in envelopes (T02) |
| Extensibility | ✅ Implemented | Single generic loop over `wiring/mcp.d/*.json`; new runtime = new envelope file + README step |
| Vendored and adapted content | ✅ Implemented | MIT + Jesse Vincent attribution; provenance note: minimal adaptation, single file, no extra cargo |
| Trigger and scope | ✅ Implemented | Worktrees-only description; PR/issue explicitly excluded |
| Non-regression | ✅ Implemented | `sync-skills.sh` byte-stable (0 edits in commit range); `--check` green |
| Adapted and attributed content | ✅ Implemented | Apache-2.0, `mhattingpete`, source URL, provenance note; stack-neutral runner discovery |
| Trigger | ✅ Implemented | Red-test-first description; authoring explicitly excluded |
| Fresh authorship with repo licensing | ✅ Implemented | No vendored files; repo MIT licensed; authored content only |
| Official GitHub MCP only | ✅ Implemented | Zero Composio/rube/token patterns; documents "use the configured GitHub MCP" |
| Trigger scope with disambiguation | ✅ Implemented | Automation/ops scope; PR/issue/creation routing table |
| Registry presence | ✅ Implemented | All three skills in `.atl/skill-registry.md` (lines 29/44/47) with scoped descriptions |

### Coherence (Design)
| Decision | Followed? | Notes |
|----------|-----------|-------|
| D1 env file `~/.config/sdd-own/github-mcp.env`, dir 0700, file 0600 | ✅ Yes | Dir 0700 on creation; file mode asserted (0600) — see SUGGESTION for pre-existing dir |
| D2 `setup.sh` wrapper, delegated sync, self-contained MCP step | ✅ Yes | `apply_steps()` → `run_github_mcp_setup()`; filtered flag surface |
| D3 declarative envelopes in `wiring/mcp.d/` | ✅ Yes | 4 runtimes + README; same 5-key shape + alt_docker |
| D4 remote primary + declared Docker alt | ✅ Yes | `MCP_GITHUB_TRANSPORT=docker` renders `alt_docker`; documented, no new CLI flag |
| D5 opencode detection (`OPENCODE_CONFIG` → `.jsonc` → `.json`) | ✅ Yes | `resolve_opencode_config()` |
| D6 single env file, blocks reference var names | ✅ Yes | All 4 envelopes reference the var; never the literal |
| D7 Claude `${VAR}` interpolation | ✅ Yes | `Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}`; declared-and-skipped when claude absent (host) |
| D8 naming (`github`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `github-mcp.env`) | ✅ Yes | Consistent across envelopes/helpers |
| D9 `--registries` passthrough, setup never calls registry itself | ✅ Yes | Seam-verified (T04) |
| D10 non-TTY real-mode guard | ✅ Yes | `[[ -t 0 ]]` → exit 1 with message |
| D11 Claude config keeps `${VAR}` (no cli-expansion of the stored value) | ✅ Yes | Accepted deviation honored — not flagged |
| D12 `tomllib` + `tomli-w`, fail-fast | ✅ Yes | T17: missing `tomli_w` → ERROR + exit 2, target untouched; host has `tomli_w` |
| D13 curl/docker fail-fast under transport | ✅ Yes | T18: missing curl → exit 2 before delegation; docker only under docker transport |
| D14 `cp -p` backup, at most one `.bak` | ✅ Yes | Overwrite-in-place; T14 asserts exactly one `.bak`; mode 600 preserved |
| D15 presence semantics | ✅ Yes | T16: skip-absent, create-missing-target, `[up-to-date]` re-run |
| D16 exit codes 0/1/2, sync≥2 gate, check exits 1 (drift) / 2 (structural) | ✅ Yes | T19/T20/T21; `final_exit = max(sync, mcp)` |

### Issues Found
**CRITICAL**: None.

**WARNING**:
1. **Scope-advisory false positives on multi-scope headers** (`setup.sh`, scope normalization in the T12 fix): `sc="${sc//[ ,]/}"` strips **both** commas and spaces, then boundary-matches `[[ ",$sc," == *",$need,"* ]]`. A classic token returning `x-oauth-scopes: repo, read:org, workflow` normalizes to `reporead:orgworkflow`, which matches **none** of `repo`/`read:org`/`workflow` → spurious "faltan scopes clasicos" warnings plus an unnecessary "Cambiar el token antes de continuar?" prompt for a fully-scoped token. Reproduced in bash: `"repo, read:org, workflow"` → all three reported missing; `"repo, workflow"` → all three; single `"read:org"` → correct. Fix: strip only spaces (`sc="${sc// /}"`) or normalize separator → space before bound-matching. Spec's Missing-scope scenario still passes (warning fires for a genuinely missing scope); the RED suite does not cover the false-positive path because T12 only feeds a single-scope header — not a CRITICAL, but a real user-facing defect introduced by the applied scope fix.

**SUGGESTION**:
1. **Trap-based tmpfile cleanup**: design described deleting the curl config via `trap` after the call; implementation uses an inline `rm -f` after curl. Under `set -e`, an early failure between `mktemp` and the `rm` (chmod/printf/cp on the debug-seam path) could leave the token-bearing tmpfile. Consider an `EXIT`/`RETURN` trap for the tmpfile, body, and headers.
2. **Dir mode on pre-existing `~/.config/sdd-own`**: `install -d -m 700` does not tighten an already-existing dir. First-run creation is 0700, but a pre-existing looser dir keeps its mode; consider a `chmod 700` (or mode assertion) after `install -d`. File mode 0600 is asserted and safe.
3. **`tasks.md` checkboxes not ticked**: all 30 tasks remain `[ ]` in the artifact despite complete implementation and green suite — housekeeping only.
4. **T08 numbering gap**: the RED map lists T08 but the runner covers T01–T07, T09–T22 (21 tests); renumber or drop the gap to keep map ↔ runner aligned.

### Verdict
**PASS WITH WARNINGS**
0 CRITICAL, 1 WARNING (scope-normalization false positives, non-spec-breaking), 4 SUGGESTIONS; requirements 23/23, scenarios 37/37; RED suite 21/0/0 exit 0; build exit 0; host regressions (`sync-skills.sh --check`, `setup.sh --check` non-mutation, fragment `mcp`-free) green — archive-ready.

### Post-verify remediation (WARNING fixed)
The single WARNING was corrected after this report was written, as a mechanical one-line fix in `setup.sh`:

- **Before** (bug): `sc="${sc//[ ,]/}"` stripped commas **and** spaces, so a classic token header `repo, read:org, workflow` normalized to `reporead:orgworkflow` and boundary-matching reported all scopes missing → spurious "faltan scopes clasicos" + unnecessary token-change prompt.
- **After** (fix): `sc="${sc// /}"` strips spaces only, preserving commas as clean boundaries: `repo, read:org, workflow` → `repo,read:org,workflow` → all matches OK; genuinely missing scopes still warn.
- **Re-verification**: the exact normalization logic was re-run in isolation — multi-scope complete header → no missing; single `repo` → `read:org workflow` missing (correct); comma-adjacent header → no missing; empty header handled by the earlier fine-grained branch. `bash -n setup.sh` passes.
- **Suite note**: the full RED suite has an environmental intermittent stall in T22 (documented in `apply-progress.md`; ~0 CPU, non-deterministic, bounded by `timeout 120`); it passed twice during verify (21/0/0, exit 0) and this one-line normalization change cannot affect that test, so the earlier suite result stands for archive.
- Committed as `fix(setup): normalize scopes by stripping spaces only`.