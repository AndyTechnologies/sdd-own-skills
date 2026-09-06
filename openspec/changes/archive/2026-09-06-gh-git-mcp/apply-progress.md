# apply-progress — gh-git-mcp

Change: **gh-git-mcp** — local FastMCP server (gh_*/git_*) sobre gh + git CLIs.
Status: **completed (22/22 tasks)** — despliegue del wiring/skill pendiente de autorización explícita (regla AGENTS.md: no sync real sin pedido).
Método: inicio por subagente sdd-apply + continuación directa del orquestador tras 2 abortos por corte de internet (verificación de lo ya escrito + cierre de tareas restantes).

## Tareas completadas (tasks.md, 5 fases)

### Fase 1 — Foundation
- [x] Scaffold `srv/gh-mcp-server/` (pyproject.toml `fastmcp>=2`, requires-python >=3.12, .python-version, README.md)
- [x] `src/envelope.py` — Envelope `{ok, data, summary, error}` tipado
- [x] `src/executor.py` — SubprocessRunner (único llamador de subprocess.run) + ExecutorProto (Protocol port DI) + SubprocessError
- [x] `src/gh_auth.py` — core service require_auth (per-call `gh auth status --exit-code`)

### Fase 2 — Core
- [x] `src/dryrun.py` — DryRunResult + `fp()` (SHA-256 sorted-JSON) + classifiers puros (mergeability, merged, safe_to_rerun) + `destructive_flow()` Template Method con echo-back
- [x] `src/tool_handlers/remote_read.py` — 14 tools gh_*
- [x] `src/tool_handlers/remote_mutation.py` — 3 tools destructivas (gh_merge_pull_request, gh_rerun_workflow, gh_delete_branch) con dry-run+confirm
- [x] `src/tool_handlers/local_read.py` — 4 tools git_* (git_status, git_diff, git_log, git_branch)
- [x] `src/tool_handlers/local_mutation.py` — 2 tools (git_commit = add -A + commit secuencial, git_delete_branch)

### Fase 3 — Transport
- [x] `src/server.py` — composition root (SubprocessRunner + register_all + safety net de excepciones inesperadas → invalid_parameter)
- [x] Corrección propia del orquestador: safety net del primer draft era código muerto (patch posterior a register_all). Reescrito limpio: wrapper ANTES de register_all, restore del decorator original después.

### Fase 4 — Wiring + Skill
- [x] `wiring/mcp.d/opencode.json` — multi-entry: block = `github` (remote, presence primaria server_key) + `gh-git-mcp` (local, uv run --directory <abspath> python src/server.py, token-free)
- [x] `wiring/mcp.d/README.md` — contrato multi-entry documentado (aditivo por servidor; server_key solo presencia; alt_docker solo github)
- [x] `skills/github-automation/SKILL.md` — dual surface: runtime selection (own gh_*/git_* default; oficial solo GHEC), tabla de equivalencias honesta (mapped / partial→report-only), pitfalls 403 + echo-back, quick reference dual

### Fase 5 — Verify smoke hooks
- [x] tools/list → **23 tools** (14+3+4+2), NINGUNA env de token
- [x] git_status real → envelope tipado ok
- [x] destructive_flow con executor falso: dry-run no muta; echo erróneo → confirm_required sin ejecutar; echo exacto → ejecuta una vez
- [x] require_auth: fail → auth_required envelope; ok → None
- [x] `bash -n sync-skills.sh` OK; `./sync-skills.sh --check` y `./setup.sh --check` coherentes (SIN desyncs no intencionales; ver estado abajo)

## Correcciones post-verify (ronda 1)

El verify delegado encontró 1 CRITICAL + 4 WARNING + 4 SUGGESTION. Aplicadas todas:

- [x] **CRITICAL A9 — fail-closed gate en `destructive_flow`** (dryrun.py): efecto con `data["safe"]` distinto de `True` NUNCA ejecuta, ni con echo matcheado → `err("not_safe", ...)`; además `error` en el dry-run → `invalid_parameter` antes de mutar.
- [x] **WARNING 2 — `classify_mergeability` con enums string de gh** (GraphQL `MergeableState`): `MERGEABLE`→safe, `CONFLICTING`→no-safe, cualquier otro string (`UNKNOWN`/`DRAFT`)→`safe: None` (fail-closed). A3b/A3c pasan.
- [x] **WARNING 3 — trampa del echo-back**: el fingerprint ahora cubre el objeto completo recibido (`{dry_run: True, **data}`), no el data pelado → "echo the exact object you received" funciona verbatim. A8 pasa con contrato corregido.
- [x] **WARNING 4 — SubprocessError → envelope `network_error`** (server.py safety net): ya no re-lanza; clasifica typed. Contrato "failure envelope" cumplido.
- [x] **WARNING 5 — guard `git_delete_branch` invertido**: reemplazado `git branch --merged <b>` (siempre True) por `git merge-base --is-ancestor <b> HEAD` (exit 0 = merged). Verificado en scratch repo: unmerged→safe:False, merged→safe:True.
- [x] **SUGGESTION 6 — `git_commit` fallido** ahora devuelve `err("commit_failed", ..., hint="index remains staged…")` en vez de ok:true.
- [x] **SUGGESTION 8 — skill Quick Reference "Failed CI"**: columna oficial corregida a `github_list_workflow_runs → github_get_workflow_run → github_download_workflow_run_logs`.
- [x] **SUGGESTION 9 — skill runtime-selection**: re-evaluación a mitad de tarea documentada (fallback a la superficie que funcione ante 403).
- [x] SUGGESTION 7 (spec wording de `gh_search_code` cross-repo) — nota aceptada, sin cambio de código (el diseño lo documenta como cross-repo).

Re-smoke: **11/11 checks PASS** (suite del verifier ajustada al contrato de echo completo). Header YAML del verify-report anterior (requirements 9/11, scenarios 22/25) queda obsoleto; el re-verify formal actualiza el report.

## Estado de despliegue (pendiente de autorización — NO ejecutado)

El repo fuente está completo. Falta desplegar a los destinos instalados; NO se corre solo por regla del repo:
- `./sync-skills.sh` (paso real) — instala el skill github-automation dual-surface en ~/.agents/skills (+ symlinks)
- `./setup.sh` (paso real) — mergea el fragmento multi-entry en opencode.jsonc (agrega gh-git-mcp; github queda igual)

Confirmación del estado: `--check` reportó 1 actualizado (skill) + 1 MCP pendiente (gh-git-mcp), 0 errores.

## Riesgos / observaciones

- **No commiteado**: todos los cambios del change están en working tree (srv/, openspec/, .gitignore, wiring/, skills/) junto con trabajo preexistente NO del change (setup.sh, tests/helpers/pty_run.py, tests/run_red_checks.sh — fix UX previo). El commit es decisión del usuario.
- **Path absoluto** en wiring/mcp.d/opencode.json (`/home/andy/Proyectos/sdd-own-skills/srv/gh-mcp-server`) — máquina-específico; es la convención actual del envelope opencode (block ya usaba rutas del sistema).
- **gh 2.98**: no `gh pr merge --dry-run`; branch delete vía `gh api -X DELETE .../git/refs/heads/`; dry-runs computados (mergeability/compare/runs).
- **git_commit** deja staged index si falla el commit — documentado (diseño §especificado).
- Sin test runner (repo de config, strict_tdd false); build_command `bash -n sync-skills.sh`.

## Artefactos

- Planificación: openspec/changes/gh-git-mcp/{quest,exploration,proposal,design,architecture-lint,tasks}.md + specs/
- Código: srv/gh-mcp-server/ (14 archivos)
- Wiring: wiring/mcp.d/opencode.json, wiring/mcp.d/README.md
- Skill: skills/github-automation/SKILL.md
- Este progress: openspec/changes/gh-git-mcp/apply-progress.md + Engram `sdd/gh-git-mcp/apply-progress`

## Next recommended

- `verify` — smoke real del servidor desplegado tras sync+setup (o verify de códigos ya validados como paso previo), luego archive.