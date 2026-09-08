# Apply Progress: sdd-mcp-worktree

Status: **in-progress** · Apply session (lane-c-apply-4-units) · Runtime token: `sha256:feb8608537f7f3437a8ddfba722933cd793c0d377222e3b80df6c8798ab29d39` (UNSETTLED — orchestrator settles)

## Context

- Baseline `./sync-skills.sh --check` (pre-apply): **EXIT=0, "sincronizado (cero desyncs)"** — deployed `~/.config/sdd-own` copies match repo canonicals, including the uncommitted `sdd-workflow-contract` edits (orchestrator.md prompts + sdd-phase-common overlay markers). Recorded as the pre-change byte-identical reference for the 6c additive-only gate.
- Plan: 6 phases / 4 work-unit commits (per tasks.md).
- Golden rules applied: no-git-crudo on the workspace repo (raw git only inside throwaway /tmp fixtures and inside run_red_checks.sh's own sandbox behavior); never edit Alan base files directly; `wiring/opencode.sdd.json` untouched; no commit/push; `.atl/` local.
- Read source: envelope.py, executor.py, server.py, dryrun.py, all 4 existing handler files, pyproject.toml; sync-skills.sh (984 lines); design.md, council.md, tasks.md, 3 specs.

## Decisions / Deviations (documented)

1. **Deploy gate for Phases 4.3/5.2/6.3**: `--check` byte-compares repo canonicals (`wiring/prompts/sdd/*.md`, `skills/*/`) against `~/.config/sdd-own/`. Overlay interiors are structural-only (marker presence), so the `sdd-phase-common.md` flip never desyncs. The orchestrator.md + using-git-worktrees/SKILL.md edits WILL desync unless deployed. The change's own acceptance criteria demand 0 desyncs → the end-state requires a deploy. Resolution: run the **minimal deploy** `./sync-skills.sh --skip-gentleai-sync --skip-opencode` after U4/U5 repo edits (no gentle-ai base reset, no personal-config merge), then plain `./sync-skills.sh --check` for the acceptance gate. Recorded in final report.
2. **Selector 5g placement (design contradiction)**: D-F5-3 says "after 5e (merge), before 5f"; but merge-mechanics skip must happen INSIDE the merge loop, which runs at 5e. A selector running after the loop cannot inform it → selector step executes BEFORE the merge loop (after 5d); the permission-deploy step follows the loop and respects `SELECTED_RUNTIMES`. Documented as a deviation from D-F5-3 ordering (same gate, consistent with D-F5-4).
3. **Server tests**: no pytest infra. Deep behavior proof (add→list→remove + deny matrix) = throwaway python driver in `/tmp/opencode` against repo source via `uv run --directory srv/gh-mcp-server python` with temp git fixtures (disposable, not workspace repo state). Durable RED surface for the change = new grep/bash blocks in `tests/run_red_checks.sh` (U3), per design File Changes.
4. **`.codegraph` init is best-effort**: only the `.sdd-agent-lock` write is a hard requirement after worktree creation; if `codegraph` binary is missing the tool skips init and reports it (minor deviation, reported).
5. **Server-owned artifacts vs. dirty detection (implementation fix, smoke-driven)**: `git_worktree_add` leaves `.codegraph/` + `.sdd-agent-lock` untracked in the worktree → `git status --porcelain` reports them, which would make EVERY worktree permanently "dirty" and block removal. Fix: the dirty check (pre-check + dry-run recompute) ignores exactly those two porcelain entries (`?? .codegraph/`, `?? .sdd-agent-lock`); everything else (user modified/untracked) stays dirty. `execute` pre-removes the server-owned artifacts (`shutil.rmtree(.codegraph)`, `remove_lock()`) BEFORE `git worktree remove`, so git's own clean check (rc=128 on untracked/modified) remains the fail-closed backstop against dry-run→confirm drift. Verified by git ground-truth test (untracked file blocks remove; clean remove rc=0).
6. **Smoke driver protocol note**: phase 2 of ANY two-phase tool requires `dry_run: false` explicitly; the tool-level default is `dry_run: true`, so a confirm call without it short-circuits into the plan (this also applies to the pre-existing tools — the existing per-tool skill/tests already pass `dry_run:false`).

## Work Units

### Unit 1 — F6 server + catalog (DONE)

- [x] 1.1 `envelope.py` docstring: closed catalog 12 types (`auth_required, repo_not_found, network_error, not_found, not_a_repo, dirty_worktree, not_safe, commit_failed, invalid_parameter, worktree_exists, active_agents, owned_by_other`); `confirm_required` is an `ok()` summary marker, never `err()`. Spec side already satisfied (gh-git-mcp-server spec L84-97 lists the full closed set + confirm_required note).
- [x] 1.2 `worktree_mutation.py`: safe-slug + canonical derivation pure helpers; `git_worktree_add` / `git_worktree_remove` via `destructive_flow`; pre-checks outside the flow (dirty / live-pid / owner); dirty detection ignores server-owned artifacts (decision 5).
- [x] 1.3 `git_worktree_list` in `local_read.py` (4 → 5 tools) — parses `git worktree list --porcelain` blocks into `worktrees` list.
- [x] 1.4 register `worktree_mutation` in `tool_handlers/__init__.py` (4 → 5 families, 26 tools total).
- [x] 1.5 Verify: `py_compile` clean; smoke driver `/tmp/opencode/smoke_worktree_driver.py` **32/32 PASS** (add dry→confirm→create+branch+lock+codegraph; exists; list; remove denies: live-pid→active_agents, foreign owner→owned_by_other, dirty→dirty_worktree, echo drift→confirm_required not executed; remove happy path with stale lock; not_found absent; invalid_parameter traversal/empty; not_a_repo; cross-repo structurally impossible). Codegraph binary present → init ran (asserted).

### Unit 2 — E1 echo-contract (DONE)

- [x] 2.1 `dryrun.py` `ECHO_PROTOCOL` now reads `confirmed_data=EXACT <display_data object>` — the single source shared by all 7 two-phase tool descriptions (2 local_mutation + 3 remote_mutation + 2 worktree_mutation). Grep proof: 7 `description=` blocks reference `ECHO_PROTOCOL`; `confirmed_data=EXACT` present in dryrun.py L67.
- [x] 2.2 `confirm_required` markers in `destructive_flow` already name the missing field (`confirmed_data`) via `ok()` at L268/L275; fingerprint gate unweakened — `effect.data["safe"] is not True` → `err("not_safe")` at L257-262 stays; `effect.data.get("error")` → invalid_parameter L246-247 stays. Verified no `err()` with confirm_required anywhere in source (only docstring mentions).
- [x] 2.3 RED self-check: 7 descriptions echo `confirmed_data` (via ECHO_PROTOCOL); `confirm_required` is an `ok()` marker, never `err()`. `py_compile dryrun.py` → clean.

### Unit 3 — F5 setup.sh + C2 + envelopes (DONE)

- [x] 3.1 `degrade()` red-fallback (network_degraded=1, exit 0) applied to `prompt_new_token` network branch, real mode, and `--check` (T09/T20 re-spec'd); 401 branch unchanged (aviso + 3 intentos → exit 2).
- [x] 3.2 4 envelopes (`wiring/mcp.d/*.json`) with `"selectors": ["opencode","pi","claude","codex"]` + `"permission_roots": ["~/agent_worktrees/**"]` (verified present, pre-existing diff).
- [x] 3.3 `select_runtimes()` (L649): union por envelopes → filtro presencia → restriccion `selectors` → auto-ALL sin TTY/no-real → interactivo (espacio toggle / flechas / Enter); `SELECTED_RUNTIMES` nunca persistido; merge loop (L1218) + permission deploy (L1268) skipean runtimes deseleccionados (`[skip] <rt>: no seleccionado en el selector`).
- [x] 3.4 `deploy_permission_roots()` (L746): opencode `permission.external_directory` glob; claude `permissions.additionalDirectories` + `allow` tool-specs; pi `sandbox.allowWrite` + `permission.external_directory`; codex `sandbox_mode=workspace-write` + `sandbox_workspace_write.writable_roots` TOML; idempotente (`up-to-date` sin reescritura) + gate MCP_MODE.
- [x] 3.5 Pasos renumerados: 5e selector → 5f merges → 5g permisos → 5h env snippet (desvio D-F5-3 documentado en Decisions 2).
- [x] 3.6 **Suite RED completa: 25/25 PASS, 0 FAIL, 0 SKIP, SUITE_EXIT=0** (T09/T20 degradacion, T23 permisos C2 idempotentes, T24 selector --check, T25 selector pty).
- [x] 3.7 Bugs corregidos durante validacion (todos U3):
  - a. **Selector: espacio = Enter (toggle muerto)** — `read -rsn1` divide por IFS: un espacio unico → cero palabras → `key=""` → case `""` → break inmediato. Comportamiento general de bash (verificado empiricamente, no es del pty). Fix: `IFS= read -rsn1 key` + `IFS= read -rsn2 seq`.
  - b. **codex `deploy_permission_roots` crasheaba setup.sh** — `tomli_w.dump(conf, open("w"))` escribe bytes a un fd de texto → TypeError; con `set -euo pipefail` el capture `st="$(...)"` fallido abortaba el script (exit 1) dejando `config.toml` TRUNCADO. Fix: `f.write(tomli_w.dumps(conf))` (string-first, crash-safe) + `|| st="runtime-error"` en ambos captures.
  - c. **T15 assertion pre-existente rota** — el test buscaba `opencode.jsonc.bak` (sin timestamp) pero la implementacion (HEAD) usa `opencode.jsonc.bak.<ts>`; fix del assertion a glob.
- [x] 3.8 `bash -n` limpio en setup.sh y tests/run_red_checks.sh.

### Unit 4 — Lockstep convention flip (DONE)

- [x] 4.1 `wiring/prompts/sdd/orchestrator.md` clause 5: path flip `<repo-parent>/<repo-name>-worktrees/<change-name>` → `~/.agent_worktrees/<repo-name>/<change-name>` (HOME-relative, `Path.home()`); Phase 0 exception re-scoped (auto-worktree only absent while gh-git-mcp tooling is not yet provisioned — fresh bootstrap); creation/removal named as MCP tools (`git_worktree_add`/`git_worktree_remove`), raw `git worktree` via bash explicitly forbidden (no-git-crudo).
- [x] 4.2 `overlays/shared/sdd-phase-common.md` `shared-worktree-binding` block: same flip + bullet de herramientas MCP supervisadas (dentro de los markers `sdd-own:shared-worktree-binding:start/end`).
- [x] 4.3 `./sync-skills.sh --check` → 0 desyncs (resuelto junto a 5.2 con el deploy mínimo tras U4/U5, Decision 1: EXIT=0 "cero desyncs").
- **Hallazgo (out-of-scope)**: `skills/_shared/codegraph.md` L19 sigue enseñando la convención vieja (`<repo-parent>/<repo-name>-worktrees/<worktree-name>`) — NO está en File Changes del design (seto cerrado) → no editado. Un agente que la siga crearía worktrees fuera de los raíces C2 concedidos (`~/agent_worktrees/**`). Documentado para el reporte final (follow-up: flip en un cambio futuro o decisión del usuario).

### Unit 5 — Skill 6c append (DONE)

- [x] 5.1 `skills/using-git-worktrees/SKILL.md`: sección `## 6c — MCP-Native Worktree Lifecycle (lockstep convention)` APPENDED tras Provenance (fin de archivo; todo el contenido previo byte-idéntico — no se tocó frontmatter ni secciones anteriores). Cubre: convención `~/.agent_worktrees/<basename(repo_path)>/<change-name>` (HOME-relative, `Path.home()`), branch `sdd/<change>`, deps por-worktree (pnpm hardlinks / out-of-source builds), `.codegraph/` propio nunca copiado/symlinkeado, safety checks de remoción (clean + sin agentes vivos + owner), 3 herramientas MCP (`git_worktree_add`/`list`/`remove`), y el invariante no-git-crudo (nunca `git worktree` raw via bash).
- [x] 5.2 RED: deploy mínimo `./sync-skills.sh --skip-gentleai-sync --skip-opencode` → EXIT=0, "Actualizados: 2" (skill 6c + overlay sdd-phase-common), 0 errores. Luego `./sync-skills.sh --check` → EXIT=0, "sincronizado (cero desyncs)" (junto a 4.3, Decision 1).

### Phase 6 — Verification (DONE)

- [x] 6.1 Bloques RED mandados por el design ("new worktree test blocks + E1 doc-contract check") añadidos a `tests/run_red_checks.sh`:
  - **T26 "worktree MCP contrato"**: familia `register_worktree_mutation` registrada en `tool_handlers/__init__.py`; `git_worktree_add`/`git_worktree_remove` en worktree_mutation.py; `git_worktree_list` en local_read.py; `Path.home()` (resolución HOME-relative); `destructive_flow` (two-phase); catálogo cerrado de 12 err types presente en envelope.py.
  - **T27 "E1 doc-contract"**: exactamente **7** descripciones de tools dos-fases citan `+ ECHO_PROTOCOL` (2 local_mutation + 3 remote_mutation + 2 worktree_mutation); `confirm_required` NUNCA como err type (`err("confirm_required")` → 0 hits; el único hit del primer intento era la docstring de dryrun.py que documenta el propio contrato — regex afinado a calls reales); marker presente en dryrun.py.
- [x] 6.2 Sintaxis: `bash -n` setup.sh + sync-skills.sh + tests/run_red_checks.sh → 0; `py_compile` de todo `srv/gh-mcp-server/src/*.py` + `tool_handlers/*.py` → 0.
- [x] 6.3 Sync gate: deploy mínimo `./sync-skills.sh --skip-gentleai-sync --skip-opencode` → EXIT=0 (2 actualizados, 0 errores; base de Alan intacta — strip+append de bloques `sdd-own` únicamente). `./sync-skills.sh --check` → **EXIT=0, "sincronizado (cero desyncs)"** (cierra 4.3 + 5.2).
- [x] 6.4 Contratos (greps de superficie durables): 12 err types + `invalid_parameter` (T26); `confirm_required` no-err (T27); **26 tools / 5 familias** verificadas por nombre (`17 gh_* + 9 git_*`); convención VIEJA `<repo-name>-worktrees/<` → **0 ocurrencias** en archivos del change (los 7 hits de `worktrees/<` eran la convención NUEVA `~/.agent_worktrees/` en docs del server — falso positivo); no-git-crudo preservado (6c: "never raw `git worktree`").
- [x] 6.5 RED final: **27/27 PASS, 0 FAIL, 0 SKIP, SUITE_EXIT=0** (`/tmp/opencode/red_checks_final.log`). Nota operacional: 2 runs intermedios fallaron con **"Disk quota exceeded"** — /tmp (tmpfs 7.7G) saturado por 168 sandboxes `sdd-red.*` (~81M c/u) de runs previos; limpieza → 1% de uso → suite verde. No es defecto del change.
- [x] 6.6 Footprint: `git diff --stat` → **16 archivos modificados, 648 inserciones, 83 borrados** (gross 731 / net 565) + 3 untracked openspec + 1 untracked server (worktree_mutation.py). Runtime token: **NO settleado por el agente** (ver Status — el token listado es el de la sesión original; el agente de continuación operó con otro token de sesión).

### Estado final del apply

- RED suite: **27/27 verde** (T01–T27; bloques por unidad U1–U5; el cambio de este apply añadió U4/U5/6c + T26/T27).
- Sync: **0 desyncs** post-deploy; base de Alan sin tocar; opencode.json personal intacto (`--skip-opencode`); sin commits ni pushes (no-git-crudo).
- Hallazgo abierto: `skills/_shared/codegraph.md` L19 convención vieja (out-of-scope, no editado) — follow-up propuesto.
- Token: UNSETTLED → lo resuelve el orquestador. Apply completo.