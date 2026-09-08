```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:56ca175ff643448ab69fbc040d8665e350a75c4317b54d425736baa4614a0235
verdict: pass
blockers: 0
critical_findings: 0
requirements: 10/10
scenarios: 26/26
test_command: bash tests/run_red_checks.sh
test_exit_code: 0
test_output_hash: sha256:2069c853d1b4e6b4697f2c561daf36c854da2308083232af46506b5ffac26444
build_command: bash -n setup.sh sync-skills.sh tests/run_red_checks.sh + python3 -m py_compile srv/gh-mcp-server/src/*.py tool_handlers/*.py
build_exit_code: 0
build_output_hash: sha256:0450545874ec3cb0e3717232889bab044bedb2112c9a7c0b0505583de2660d2d
```

# Verify Report — sdd-mcp-worktree

- **status**: `success` (no CRITICAL findings; 2 WARNING follow-ups, none blocking)
- **objective**: `lane-c-verify` — independent re-proof of apply claims for change `sdd-mcp-worktree`
- **iteration count**: 1 (claims re-proven at runtime, not re-verified from apply's evidence)
- **token**: `sha256:56ca175ff643448ab69fbc040d8665e350a75c4317b54d425736baa4614a0235` — **NOT settled by this phase; orchestrator settles**. `max_attempts=1`, `max_changed_lines=100`.
- **verification date**: 2026-09-07
- **method notes**: strict TDD not active (config repo, no test runner). Verification surface = RED suite (independent run) + syntax gates + sync gate + contract greps + runtime probes (F6 driver 45 scenarios; existing-token network degrade; dry-run selector plan) + footprint/drift audit via `gh-git-mcp` surface only.

---

## Executive summary

| Domain | Result | Evidence |
|---|---|---|
| `srv/gh-mcp-server` (F6) — worktree MCP tools + surface | **VERIFIED** | RED T26/T27 green; 26 tools / 5 families (17 `gh_*` + 9 `git_*`); `envelope.py` 12-type closed catalog, `confirm_required` = `ok()` summary marker (never `err()`, 0 hits); ECHO_PROTOCOL in exactly 7 tool descriptions; independent runtime driver 45/45 PASS (`/tmp/opencode/verify_f6_driver.py`) covering name/location/branch/dry-run/confirm/exists/dirty/live-owner/stale-cleanup/echo-gate/slug-validation/C3 cross-repo boundary |
| `setup.sh` (F5) — token degrade, exit mapping, runtime selector, permission roots | **VERIFIED** | RED suite 27/27 PASS exit 0 (T06–T25 cover F5: gates, flags, ACL, selector interactive/pty/non-interactive, skip mechanics); 401 fatal preserved (T08, `[ERROR] token no validado tras 3 intentos` + exit 2 at L327); `degrade()` L295–299 / call sites L319+L1148; existing-token network degrade runtime probe 4/4 (`[aviso]` + env preserved, not rewritten); dry-run selector plan runtime probe exit 0 + HOME snapshot byte-identical |
| Sync + skill 6c — lockstep `~/.agent_worktrees/` flip, additive extension | **VERIFIED** | `./sync-skills.sh --check` exit 0 "sincronizado (cero desyncs)"; new convention at orchestrator.md L484, sdd-phase-common.md overlay, 3× setup.sh, 4× wiring/mcp.d/*.json, 5× worktree_mutation.py; old `<repo-name>-worktrees/<` convention 0 hits in changed files; 6c appended after Provenance (additive-only, base sections untouched); skill spec non-regression scenario (byte-identical pre-change base + zero desyncs) green |
| Drift / scope | **VERIFIED** (2 warnings) | Footprint exactly as claimed: 16 files, 648+/83-; `wiring/opencode.sdd.json` untouched; no Alan base edits; no commits (no-git-crudo respected). No invented requirements (every change maps to spec/design/council C1/C2/C3/E1). Dropped design mitigation → W1. Out-of-scope stale guidance → W2 |

**Status per domain**: `srv/gh-mcp-server` VERIFIED · `github-mcp-setup` VERIFIED · `git-worktrees-skill` VERIFIED. Overall: **success** with 2 WARNING follow-ups (both non-blocking, doc/guidance only).

---

## Findings

### CRITICAL
None.

### WARNING

#### W1 — Dropped design mitigation: README exit-semantics note (doc-only)
- **class**: design-mitigation gap · **causality**: design risk table (design.md L138) declared "T09/T20 exit flip breaks downstream consumers of old exit-2 contract → README exit-semantics note updated same change"; the change did not touch `README.md` (git status: unmodified).
- **evidence**: `README.md` L166 still reads "`2` = fallo estructural (sync falló, **o red/API inalcanzable**)" — the old contract. Under the new D-F5-2 mapping, network failure at token validation degrades (`[aviso]` + exit 0; `degrade()` L295–299, call sites L319/L1148; T09/T20 green; runtime probe exit 0). No code path exits 2 on API-unreachable during token validation anymore.
- **impact**: documentation only — users/CI reading the README would expect exit 2 on network failure. No behavior drift.
- **recommendation**: update README L166 in a small follow-up change ("red/API inalcanzable" → `[aviso]` + exit 0; exit 2 = structural/sync failure only).

#### W2 — Out-of-scope stale worktree-location guidance (follow-up, not a change)
- **class**: out-of-scope drift (apply-documented Hallazgo) · **causality**: the change flipped the SDD worktree convention to `~/.agent_worktrees/` (HOME-relative, never `/tmp`), but two guidance surfaces outside the design File Changes still teach the old `<repo-parent>/<repo-name>-worktrees/<worktree-name>` convention.
- **evidence** (grep, repo + deployed):
  - `skills/_shared/codegraph.md` L19 (repo canonical) and deployed `~/.agents/skills/_shared/codegraph.md` L19 — old convention.
  - `~/.config/opencode/AGENTS.md` L8 (global opencode guidance) — old convention `<repo-parent>/<repo-name>-worktrees/<worktree-name>`.
  - Clean: workspace-repo `AGENTS.md` (no match), installed `~/.config/sdd-own/prompts/sdd/orchestrator.md` L484 (already flipped).
- **impact**: mixed guidance for CodeGraph-dependent worktrees; sync `--check` stays green because these files are not part of the change's overlay surface.
- **recommendation**: one follow-up change updating `skills/_shared/codegraph.md` L19 (and, if in the user's stewardship, the global `~/.config/opencode/AGENTS.md` block). Do NOT edit globals directly from this repo — `skills/_shared/codegraph.md` is the repo-side source, deployed only-if-missing.

### Informational notes
- **N1** — `skills/using-git-worktrees/SKILL.md` L101 (vendored base "Sandbox fallback: `git worktree add ...`") is **pre-change base content**, protected by the spec non-regression clause ("Existing content preceding section 6c SHALL NOT be modified or removed"). The no-raw-git-worktree rule binds the 6c extension, which is clean ("never raw `git worktree` via bash — no-git-crudo invariant", L184). The 6c surface is MCP-only.
- **N2** — `tests/helpers/pty_run.py` extended (+36: scan-all prompt matcher, occurrence counting, `read -rs` ECHO race wait) as test-harness infrastructure for the selector PTY tests (T23–T25). Test-only; the design's File Changes listed `run_red_checks.sh` but not this helper; classified as supporting infrastructure, not deviation.
- **N3** — step ordering: design D-F5-3 said selector "after 5e before 5f"; implementation runs 5e selector → 5f merges → 5g permisos (setup.sh L1213/L1218/L1268). Documented in apply Decision 2; consistent with D-F5-4 skip mechanics (`SELECTED_RUNTIMES` must exist before the merge loop). Verified in code.
- **N4** — the "Existing token network degrade unchanged" spec scenario (github-mcp-setup) has no dedicated RED test; behavior code-verified (setup.sh L758–761 area, `[aviso] ... se conserva el env file sin reescribir` L1076) and runtime-probed 4/4 (exit 0, `[aviso]` emitted, env token preserved, env mtime unchanged).
- **N5** — interpretation note on skill spec scenario "no raw `git worktree` commands appear in the instructions": the requirement text scopes the rule to the extension ("The extension SHALL ... NEVER instruct raw `git worktree`"); under that binding the scenario passes. A full-file reading would collide with the equally-binding non-modification clause; the delta-scoped reading is the consistent one.

---

## Verification evidence (independent)

| Check | Result | Artifact |
|---|---|---|
| RED suite (full, freshly seeded sandbox) | **27/27 PASS, 0 FAIL, 0 SKIP, exit 0** | `/tmp/opencode/verify_red_suite.log` (matches apply's `/tmp/opencode/red_checks_final.log`) |
| Syntax gates | `bash -n` 3 files OK; `python3 -m py_compile` all server files OK | — |
| Sync gate | `./sync-skills.sh --check` exit 0, "sincronizado (cero desyncs)" | `/tmp/opencode/verify_sync_check.log` |
| Runtime F6 scenarios (in-process FastMCP client, HOME redirected to temp, fixture repos in /tmp) | **45/45 PASS, exit 0** | `/tmp/opencode/verify_f6_driver.py` (re-runnable: `uv run --directory srv/gh-mcp-server python /tmp/opencode/verify_f6_driver.py`) |
| Existing-token network degrade probe | **4/4 PASS** | `/tmp/opencode/verify_existing_token_net_probe.sh` |
| Dry-run selector plan probe | exit 0 + HOME snapshot byte-identical | — |
| Footprint audit (`gh-git-mcp` surface) | 16 files modified, 648+/83-, untracked = worktree_mutation.py + openspec dirs; `wiring/opencode.sdd.json` untouched | — |

**Contract greps (all independent)**: 12 err-types closed catalog · `err("confirm_required")` 0 hits · ECHO_PROTOCOL 7 citations · 26 tools/5 families (register_worktree_mutation wired) · old convention 0 hits in changed files · new convention present in orchestrator/phase-common/skill/setup/mcp.d · `~/.agent_worktrees` absent in real HOME (nothing disturbed).

---

## Artifacts

- `openspec/changes/sdd-mcp-worktree/verify-report.md` — this report (canonical, persisted)
- Mirrored to Engram under topic `sdd/sdd-mcp-worktree/verify-report` (project `sdd-own-skills`)
- `/tmp/opencode/verify_red_suite.log` — RED suite output (independent run)
- `/tmp/opencode/verify_sync_check.log` — sync gate output
- `/tmp/opencode/verify_f6_driver.py` — independent runtime F6 driver (45 scenarios)
- `/tmp/opencode/verify_existing_token_net_probe.sh` — existing-token network degrade probe
- `/tmp/opencode/red_checks_final.log` — apply's RED log (cross-checked, matches)

## Next recommended

1. **Orchestrator decision point**: mark change READY (verify passed; W1 + W2 are follow-up candidates, not blockers). Token `sha256:56ca175ff643448ab69fbc040d8665e350a75c4317b54d425736baa4614a0235` is for the orchestrator to settle.
2. **Follow-up change (recommended, non-blocking)**: update `README.md` L166 exit semantics (W1) + `skills/_shared/codegraph.md` L19 and global `~/.config/opencode/AGENTS.md` L8 convention (W2).
3. After merge, normal post-merge continuity: type/ATM enrichment, archive.

## Risks

- **Low (accepted, documented)**: W1 doc staleness until the follow-up lands; W2 mixed guidance for CodeGraph worktrees until updated.
- **None blocking**: no CRITICAL findings; all spec scenarios carry passing covering checks (RED or runtime probe) or are code-verified non-regression.

## Skill resolution

- Contract read from canonical location `~/.agents/skills/sdd-verify/SKILL.md` (injected repo path `skills/sdd-verify/SKILL.md` does not exist in the workspace; `~/.config/opencode/skills/sdd-verify/` symlinks to the same canonical). `sdd-phase-common.md` read from `~/.agents/skills/_shared/`.
- No skill actions required this phase; no changes to `wiring/opencode.sdd.json` (untouched, verified).