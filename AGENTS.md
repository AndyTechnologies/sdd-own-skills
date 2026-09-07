# AGENTS.md — Guía para agentes de código

Este repositorio es la **fuente canónica** de la personalización SDD del usuario sobre **gentle-ai** (binario de Gentleman-Programming, v2.6.0). El flujo es: gentle-ai instala sus skills/commands/prompts originales y este repo se adhiere con **bloques gestionados** — skills exclusivas nuestras (full install) + overlays de bloques `sdd-own` anexados al final de los archivos de Alan. Las originales de Alan se respetan SIEMPRE: nunca se pisán, nunca se editan.

## Reglas de oro

1. **Nunca edites los globales directamente.** `~/.agents/skills/*`, `~/.config/opencode/skills/*`, `~/.config/opencode/commands/*` y `~/.config/opencode/prompts/sdd/*` son resultados del sync: bases de Alan (instaladas por `gentle-ai sync`) + lo que despliega este repo. **Lo NUESTRO (skills exclusivas, bootstrap `_shared`, prompts) vive como copias físicas originales en `~/.config/sdd-own/`** (`skills/<skill>`, `skills/_shared/`, `prompts/sdd/`) y los directorios de agentes (`~/.agents/skills/`, `~/.config/opencode/skills/`, `~/.claude/skills/`, prompts de Claude) son SYMLINKS a esas copias: editar el original en `~/.config/sdd-own/` se propaga a todos lados sin replicación. **Excepción `_shared`**: `~/.agents/skills/_shared/` es un directorio REAL compartido (base de Alan + copia solo-si-falta de lo nuestro) y `~/.config/opencode/skills/_shared` / `~/.claude/skills/_shared` symlinkean a ese directorio compartido, no a sdd-own. Las skills de Alan se quedan como directorios reales en `~/.agents/skills/` (los overlays les anexan bloques `sdd-own`). Edita la fuente canónica (`skills/<skill>/SKILL.md`, `overlays/**`, `wiring/prompts/sdd/*.md`) y corre `./sync-skills.sh`.
2. **Nunca edites `~/.config/opencode/opencode.json` ni `~/.config/opencode/opencode.jsonc` directo.** Es config personal (providers, mcp, permisos, modelos). Los agentes SDD se gestionan desde `wiring/opencode.sdd.json`; el sync los mergea sobre el config real sin tocar lo personal.
3. **Las originales de Alan se respetan SIEMPRE.** Un archivo overlay solo puede: (1) quitar bloques `<!-- sdd-own:<id>:start --> … <!-- sdd-own:<id>:end -->` propios (strip, idempotente) y (2) anexar contenido al final (append). NUNCA sobrescribe líneas del archivo base de Alan. Los bootstrap de `skills/_shared/` se instalan SOLO SI FALTA el target; jamás se pisa un archivo ya instalado.
4. **El contrato del orquestador vive en `wiring/prompts/sdd/orchestrator.md`**, no inline en el JSON. Se edita en el repo y se sincroniza; el fragmento lo referencia con `{file:./prompts/sdd/orchestrator.md}`.
5. **No corras `./sync-skills.sh` sin flags en máquinas productivas.** Usa `--check` (verificar) o `--dry-run` (ensayo) salvo que se te pida aplicar explícitamente. El paso 0 (`gentle-ai sync`) corre solo en modo real; se omite con `--skip-gentleai-sync` si ya corrió hace poco.
6. **`.atl/` es local** (contiene rutas absolutas del sistema) y está gitignoreado; no lo commitees. Su refresh se hace con `./sync-skills.sh --registries <proyecto...>`.
7. **No hagas commits ni pushes sin que se te pidan.** Git no forma parte del flujo de sync.

## Cómo funciona la sincronización

- **Paso 0 — gentle-ai sync**: ejecuta `gentle-ai sync` (instala/resetea las bases de Alan). Solo en modo real; omisible con `--skip-gentleai-sync`; si el binario no existe, avisa y sigue.
- **Paso 1 — install de lo nuevo en `~/.config/sdd-own/`** (el canónico de TODO lo nuestro):
  - `skills/<skill>/` (exclusivas) → **copias físicas ORIGINALES** en `~/.config/sdd-own/skills/<skill>/`; symlinks en `~/.agents/skills/<skill>/` (`../../.config/sdd-own/skills/<skill>`), `~/.config/opencode/skills/<skill>/` (`../../../.config/sdd-own/skills/<skill>`) y `~/.claude/skills/<skill>/` (`../../.config/sdd-own/skills/<skill>`).
  - `skills/_shared/` (nuestra exclusiva `codegraph.md` + 8 bootstrap **idénticos** a los de Alan) → `~/.config/sdd-own/skills/_shared/` **SOLO SI FALTA** (never overwrite). `~/.agents/skills/_shared` es un directorio REAL compartido: ahí vive la base de Alan (instalada por `gentle-ai sync`) y se copian nuestros 9 archivos SOLO SI FALTA; `~/.config/opencode/skills/_shared` y `~/.claude/skills/_shared` son symlinks al directorio compartido (no a sdd-own), para que los agentes vean también la base de Alan.
  - `wiring/prompts/sdd/{orchestrator.md,sdd-rfc-author.md}` → **originales** en `~/.config/sdd-own/prompts/sdd/` + symlinks por archivo en `~/.config/opencode/prompts/sdd/` y `~/.claude/prompts/sdd/` apuntando al original. Alan no gestiona esos 2 paths; los prompts de fase de Alan en ese mismo dir NO se tocan.
- **Paso 2 — overlays**: `overlays/skills/<skill>/SKILL.md` → `~/.agents/skills/<skill>/SKILL.md`; `overlays/shared/<f>` → `~/.agents/skills/_shared/<f>` (base de Alan en el directorio compartido); `overlays/commands/<f>` → `~/.config/opencode/commands/<f>`. Mecánica por archivo: strip de los bloques `sdd-own` existentes con el mismo id + append del contenido del overlay. Si el target NO existe → **ERROR** (reporta y sale ≠0; nunca crea el base).
- **Paso 3 — merge opencode**: `wiring/opencode.sdd.json` (fragmento SDD) mergeado aditivamente sobre el config real de opencode. Detecta cuál existe: `opencode.jsonc` primero, si no `opencode.json`. Respaldo único `*.bak` antes del primer merge. Se omite con `--skip-opencode`.
- **Paso 4 — registries**: refresh de `.atl/` por proyecto con `--registries <proyecto...>` (solo modo real).

Flags del script: `--check`, `--dry-run`, `--skip-opencode`, `--skip-gentleai-sync`, `--registries <proyecto...>`.

## Cómo evolucionar las skills, los overlays o los agentes SDD

1. **Skill exclusiva**: edita `skills/<skill>/SKILL.md` (igual que antes: el sync la full-instala).
2. **Personalización sobre una skill de Alan**: agrega/modifica el bloque en `overlays/<tipo>/<archivo>` (skills/shared/commands) con un id único `<!-- sdd-own:<id-unico>:start --> … <!-- sdd-own:<id-unico>:end -->`. NUNCA edites la base de Alan ni su copia instalada; el contenido del overlay va solo dentro de los marcadores.
3. **Agentes/prompts SDD**: actualiza `wiring/opencode.sdd.json` y/o `wiring/prompts/sdd/`. Los prompts de los agentes ejecutores son cortos y apuntan a su skill canónica; el del orquestador es el contrato completo en `wiring/prompts/sdd/orchestrator.md`.
4. Verifica sin tocar nada: `./sync-skills.sh --check` (debe reportar cero desyncs).
5. Aplica: `./sync-skills.sh` (o `--skip-gentleai-sync` / `--skip-opencode` según corresponda).

## Reglas de merge del fragmento SDD

- El fragmento contiene SOLO claves SDD: los agentes `gentle-orchestrator`, `sdd-*` y `default_agent`. Nunca agregues `providers`, `mcp`, `permission`, `share`, `model` ni claves de otros agentes.
- El merge es aditivo: lo personal del usuario se preserva siempre; las claves SDD del fragmento ganan sobre las existentes. No borra nada.
- El prompt del orquestador se referencia por archivo (`{file:./prompts/sdd/orchestrator.md}`), nunca inline — el contrato versionado lo despliega el wiring sync.
- El config real puede llamarse `opencode.json` o `opencode.jsonc`; el sync detecta cuál existe (opencode resuelve `.jsonc` primero) y mergea sobre ese archivo.

## setup.sh — excepción sancionada (MCP de GitHub)

`setup.sh` es el wrapper de setup completo: delega en `sync-skills.sh` y, si el sync terminó bien (exit ≤ 1), configura el **MCP de GitHub** en los runtimes detectados. Reglas para agentes que trabajen en este repo:

- **`setup.sh` es el ÚNICO escritor permitido de la clave `mcp` (y `mcpServers`) en configs de runtimes** (`~/.config/opencode/opencode.jsonc|json`, `~/.pi/agent/mcp.json`, `~/.claude.json`, `~/.codex/config.toml`) fuera del pipeline de sync. NUNCA edites esas claves a mano ni agregues `mcp` al fragmento `wiring/opencode.sdd.json` (sigue conteniendo SOLO agentes SDD).
- Las definiciones declarativas viven en **`wiring/mcp.d/<runtime>.json`** — contrato `{runtime, target_mode, target, merge, root_key, server_key, presence, block, alt_docker}`. Para cambiar el endpoint, el bloque o el target de un runtime, edita el envelope y corre `./setup.sh --check`/real (5e); la mecánica de merge (json-key / sección TOML) vive en `setup.sh` (5e), NO en los envelopes.
- **Token**: el PAT de GitHub se persiste en `~/.config/sdd-own/github-mcp.env` (0600, directorio 0700). Nunca se commitea, nunca aparece en argv/logs/reportes (solo fingerprint enmascarado). Para rotar: `./setup.sh` (con TTY) o `--force-mcp-token`.
- Los seams de test (`MCP_DEBUG_SYNC_ARGS*`, `SDD_OWN_GH_API`, `SDD_OWN_DEBUG_CURL_CONFIG`, `MCP_GITHUB_TRANSPORT`) son hooks de verificación; no los uses en producción salvo diagnóstico explícito.
- No corras `./setup.sh` sin flags en máquinas productivas: usa `--check` (verifica) o `--dry-run` (ensayo); el modo real pide token interactivamente y mergea configs.