# Quest: sdd-mcp-worktree

## Approval: approved

## RFC

### Goals / Non-goals

**Goals**
- Hacer `setup.sh` resiliente ante fallos de red/temporales: los degrades de red ya no abortan la instalación; avisan (warning) y continúan. El 401 (token inválido) sigue siendo fatal.
- Agregar un selector interactivo de MCPs al último paso de setup.sh: el usuario elige qué runtimes configuran (default todos), toggle por espacio + Enter, pty-managed, sin TTY → todos, y `--check`/`--dry-run` nunca preguntan.
- Extender `srv/gh-mcp-server` con herramientas MCP de worktree (`git_worktree_add`, `git_worktree_list`, `git_worktree_remove`) bajo el patrón destructive_flow two-phase existente.
- Bootstrap de worktree desde la rama por defecto; remoción con safety check (sin cambios sin commitear + sin agentes activos).
- Actualizar el skill vendored `using-git-worktrees` (6c) y los tests de `run_red_checks.sh` (T09/T20 re-specced + nuevos).

**Non-goals**
- No adoptar server-git/otras implementaciones de worktree MCP existentes.
- No agregar persistencia de selección del selector entre corridas.
- No tocar wiring/opencode.sdd.json (eso es Lane B); no agregar `permission` a ningún config.
- No cambiar la mecánica de merge del sync ni las bases de Alan.

### Domain Terminology & Business Rules

- **F5 selector**: campo `selectors` fuera del block envelope (no es parte del bloque que se mergea); default TODOS; espacio = toggle; Enter = confirmar; sin TTY → todos sin preguntar; `--check`/`--dry-run` no preguntan.
- **F5 degrades**: en setup.sh líneas 306–309, 314–317, 729–732 (exit 2) → warning + instala igual; 401 (línea 401) → fatal; token existente (658–662) ya degrada.
- **F6 worktrees**: ubicación `<repo-parent>/<repo-name>-worktrees/<change-name>` (nunca /tmp); rama `sdd/<change>`; instalaciones propias por worktree (pnpm hardlinks Node, builds out-of-source); `.codegraph/` propio, jamás copiado/symlinkeado.
- **F6 tools**: `git_worktree_add/list/remove` bajo `destructive_flow` two-phase con patrón `_validate_worktree` (local_mutation.py).

### Contracts (Inputs / Outputs / Events / External)

- `setup.sh [--check|--dry-run|--skip-opencode|--skip-gentleai-sync|--registries <p...>]` — flujo existente + selector final.
- `git_worktree_add {repo_path, change_name}` → envuelto en dry-run + allow/deny; respuesta ok/err; crea worktree, rama, instala deps.
- `git_worktree_list {repo_path}` → lista worktrees del repo.
- `git_worktree_remove {repo_path, worktree, force?}` → dry-run + allow/deny; safety check: rechaza con cambios sin commitear o agentes activos.

### Invariants & Validation

- Ninguna tool worktree corre git crudo por bash; todo viaja por MCP gh-git-mcp (no-git-crudo).
- Un worktree por change; un writer por worktree; creados desde default branch.
- Fail-closed: comando mal formado → rechazado + finding + work unit bloqueado, jamás ejecutado.
- Toda mutación MCP pasa por dry-run + confirmación explícita.

### Failure Cases & Edge Cases

- Red caída durante `gentle-ai sync` / install / overlay → warning, continue (no abort).
- Token inválido (401) → fatal, stop.
- Worktree target ya existe → error claro, no duplicar.
- Worktree con cambios uncommitted o agentes activos → remove rechazado (safety check).
- Sin TTY → todos los MCPs, sin UI.
- Selector sin runtime detectado de un MCP → sin opción marcable para ese runtime.

### Security / Privacy / Performance / Operational

- PAT de GitHub nunca se commitea ni aparece en argv; solo fingerprint enmascarado (0600 en ~/.config/sdd-own/github-mcp.env).
- Operaciones destructivas siempre two-phase (dry-run + confirmación).
- Instalaciones por worktree para no contaminar el principal; builds out-of-source.

### Alternatives & Trade-offs

- **No-server-git**: evaluado en la meta-implementación; se rechaza porque no encaja con el envelope contract de este repo y no ofrece dos fases nativas con safety check en el mismo esquema.
- **Selector: persistencia vs siempre-TODOS**: elegido siempre-TODOS (decisión del usuario en quest) — simple, predecible, sin estado extra.

### Acceptance Criteria (measurable)

1. F5: simular red caída en los 3 puntos → setup termina con exit ≤1 y warning; simular 401 → exit fatal, no muta configs.
2. F5: selector con TTY → toggle por espacio + Enter; sin TTY → todos; `--check`/`--dry-run` no preguntan.
3. F6: `git_worktree_add` crea worktree en la ubicación correcta desde default branch con rama `sdd/<change>`; dry-run primero.
4. F6: `git_worktree_remove` rechaza worktree con cambios uncommitted o agentes activos.
5. F6: `git_worktree_list` lista los worktrees existentes.
6. Tests: T09/T20 re-specced; nuevos casos verde en `run_red_checks.sh`; `bash -n` exit 0 en setup.sh y srv.
7. `./sync-skills.sh --check` → cero desyncs sin cambios en bases de Alan.

### Unresolved Questions (blocking)

None
