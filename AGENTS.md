# AGENTS.md — Guía para agentes de código

Este repositorio es la **fuente canónica** (única copia) de las skills LLM-first del usuario y del wiring que conecta las fases del flujo **SDD**. Desde aquí se despliega a los runtimes globales (`~/.agents/skills`, `~/.config/opencode/skills`, `~/.claude/skills` y el config de opencode) mediante `sync-skills.sh`.

## Reglas de oro

1. **Nunca edites los globales directamente.** `~/.agents/skills/*`, `~/.config/opencode/skills/*` y `~/.claude/skills/*` son despliegues (copia física o symlinks) de este repo. Edita la skill canónica (`skills/<skill>/SKILL.md`) y corre `./sync-skills.sh`.
2. **Nunca edites `~/.config/opencode/opencode.json` directo.** Es config personal del usuario (providers, mcp, permisos, modelos). Los agentes SDD se gestionan desde `wiring/opencode.sdd.json`; el sync los mergea sin tocar lo personal.
3. **El contrato del orquestador vive en `wiring/prompts/sdd/orchestrator.md`**, no inline en el JSON. Se edita en el repo y se sincroniza; el fragmento lo referencia con `{file:./prompts/sdd/orchestrator.md}`.
4. **No corras `./sync-skills.sh` sin flags en máquinas productivas.** Usa `--check` (verificar) o `--dry-run` (ensayo) salvo que se te pida aplicar explícitamente.
5. **`.atl/` es local** (contiene rutas absolutas del sistema) y está gitignoreado; no lo commitees. Su refresh se hace con `./sync-skills.sh --registries <proyecto...>`.
6. **No hagas commits ni pushes sin que se te pidan.** Git no forma parte del flujo de sync.

## Cómo funciona la sincronización

- `skills/<skill>/` → copia física en `~/.agents/skills/<skill>/`; symlinks en `~/.config/opencode/skills/<skill>/` y `~/.claude/skills/<skill>/`.
- `wiring/commands/` y `wiring/prompts/sdd/` → copias reales en `~/.config/opencode/commands/` y `~/.config/opencode/prompts/sdd/` (+ symlinks en `~/.claude/`).
- `skills/_shared/` → copia física en `~/.agents/skills/_shared/`; `~/.config/opencode/skills/_shared` debe ser symlink a esa copia (si hay un directorio real stale en esa ruta, el sync lo reemplaza).
- `wiring/opencode.sdd.json` → merge de los agentes SDD sobre `~/.config/opencode/opencode.json`. Respaldo único `opencode.json.bak` antes del primer merge. El paso se omite con `--skip-opencode`.

Flags del script: `--check`, `--dry-run`, `--skip-opencode`, `--registries <proyecto...>`.

## Cómo evolucionar las skills o los agentes SDD

1. Edita la skill canónica (`skills/<skill>/SKILL.md`) o el wiring (`wiring/...`).
2. Si cambian agentes SDD (descripción, permisos, prompts), actualiza `wiring/opencode.sdd.json` y/o los prompts en `wiring/prompts/sdd/`. Los prompts de los agentes ejecutores son cortos y apuntan a su skill canónica (`~/.agents/skills/<skill>/SKILL.md`); el del orquestador es el contrato completo en `wiring/prompts/sdd/orchestrator.md`.
3. Verifica sin tocar nada: `./sync-skills.sh --check`.
4. Aplica: `./sync-skills.sh` (o `--skip-opencode` si el merge no corresponde).

## Reglas de merge del fragmento SDD

- El fragmento contiene SOLO claves SDD: los agentes `gentle-orchestrator`, `sdd-*` y `default_agent`. Nunca agregues `providers`, `mcp`, `permission`, `share`, `model` ni claves de otros agentes.
- El merge es aditivo: lo personal del usuario se preserva siempre; las claves SDD del fragmento ganan sobre las existentes. No borra nada.
- El prompt del orquestador se referencia por archivo (`{file:./prompts/sdd/orchestrator.md}`), nunca inline — el contrato versionado lo despliega el wiring sync.