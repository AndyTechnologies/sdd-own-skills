# wiring/mcp.d — Definiciones declarativas de MCP

Este directorio declara los bloques de configuración MCP de GitHub por runtime. `setup.sh` los consume (paso 5, ver README) y los mergea aditivamente sobre la config real de cada runtime. `setup.sh` es el único escritor autorizado de la clave `mcp` de la config de opencode fuera del pipeline de sync (excepción sancionada, ver AGENTS.md).

## Contrato de envelope (`<runtime>.json`)

| Clave | Tipo | Significado |
|---|---|---|
| `runtime` | string | Id único; coincide con el nombre del archivo |
| `target_mode` | `"opencode-config"` \| `"path"` | `opencode-config`: resolución por detección (`OPENCODE_CONFIG` → `opencode.jsonc` → `opencode.json`); `path`: `target` fijo |
| `target` | string | Ruta (solo `target_mode: "path"`); `~` se expande a `$HOME` |
| `merge` | `"json-key"` \| `"toml-section"` | `json-key`: merge profundo `target[root_key] * block` vía jq `-s` (fallback python3); `toml-section`: sección `[<root_key>.<server_key>]` vía python3 `tomllib` + `tomli-w` |
| `root_key` | string | Clave raíz en el target (`mcp`, `mcpServers`, `mcp_servers`) |
| `server_key` | string | `json-key`: clave wrapper dentro de `block`; `toml-section`: nombre de la sección |
| `presence` | string | Predicado bash evaluado con `bash -c "$presence"` (cadenas fijas del repo, nunca input de usuario): `command -v <runtime>` para pi/claude/codex; detección de config para opencode. `""` = siempre |
| `block` | object | `json-key`: el fragmento nativo **envuelto** bajo `server_key` (ej. `{"github": {...}}`); `toml-section`: cuerpo **pelado** de la sección |
| `alt_docker` | object \| omitido | Variante Docker local; mismo contrato de wrapping que `block`; se renderiza solo con `MCP_GITHUB_TRANSPORT=docker` |

**Regla de wrapping (F6)**: para `merge: "json-key"`, `block` incluye el wrapper `server_key` (`{"github": {...}}`) y el merge es `target[root_key] * block`; para `merge: "toml-section"`, `block` es el cuerpo pelado y `server_key` nombra la sección (`[<root_key>.<server_key>]`, ej. `[mcp_servers.github]`). Aplica igual a `alt_docker`.

**Multi-entry (aditivo dentro de un mismo envelope)**: un mismo `block` de `merge: "json-key"` puede contener VARIOS servidores (ej. el `github` remoto + el `gh-git-mcp` local en opencode). El merge profundo es aditivo por servidor (`target.mcp.github` y `target.mcp["gh-git-mcp"]` coexisten; nunca se borra un servidor ausente del fragmento). `server_key` sigue nombrando SOLO el servidor primario de presencia (`presence` evalúa `has(server_key)`); los servidores adicionales del `block` se mergean igual pero no participan del gate de presencia. `alt_docker` cubre únicamente el servidor con variante contenedor (`github`); un servidor local aditivo (type `local`, token-free) no tiene `alt_docker`.

**Servidor local desplegado (`{{SDD_OWN_DIR}}`)**: un servidor local (type `local`) se lanza con un array de comando cuyo argumento de working-directory usa el placeholder `{{SDD_OWN_DIR}}/srv/<server>` (ej. `["uv","run","--directory","{{SDD_OWN_DIR}}/srv/gh-mcp-server","python","-m","src.server"]`). `setup.sh` sustituye `{{SDD_OWN_DIR}}` por `$HOME/.config/sdd-own` en tiempo de render (igual que `{{ENV_FILE}}` en la variante docker) y despliega el servidor desde el repo a `~/.config/sdd-own/srv/<server>` antes del merge.

## Bloques primarios por runtime

Todos los bloques son **token-free por construcción**: referencian el nombre de la variable, nunca el valor.

| Runtime | Target / clave | Indirección del secreto |
|---|---|---|
| opencode | config detectada / `mcp` | `{env:GITHUB_PERSONAL_ACCESS_TOKEN}` (header Bearer) |
| pi | `~/.pi/agent/mcp.json` / `mcpServers` | `bearerTokenEnv: "GITHUB_PERSONAL_ACCESS_TOKEN"` + `auth: "bearer"` (requerido por pi-mcp-adapter 2.32.1: sin `auth: "bearer"` el token no se resuelve y el adapter auto-detecta OAuth) |
| claude | `~/.claude.json` / `mcpServers` | `${GITHUB_PERSONAL_ACCESS_TOKEN}` (interpolación de Claude Code; nunca `-e` ni literales) |
| codex | `~/.codex/config.toml` / `[mcp_servers.github]` | `bearer_token_env_var = "GITHUB_PERSONAL_ACCESS_TOKEN"` |

## Variante Docker (`alt_docker`)

Con `MCP_GITHUB_TRANSPORT=docker` (override de entorno, sin flag de CLI), `setup.sh` renderiza `alt_docker` en vez del bloque primario: `docker run --rm -i --env-file <envfile> ghcr.io/github/github-mcp-server`. El placeholder `{{ENV_FILE}}` se reemplaza por la ruta absoluta del env file (`~/.config/sdd-own/github-mcp.env`) en tiempo de render (igual que `{{SDD_OWN_DIR}}` se reemplaza por `$HOME/.config/sdd-own` en los servidores locales). Requiere `docker` instalado (fail-fast si falta y el transporte es docker). El env file tolera comentarios (`#`) y líneas vacías (Docker ≥ 20.10).

## Agregar un runtime

1. Crear `wiring/mcp.d/<runtime>.json` con el contrato de arriba (block envuelto o pelado según `merge`).
2. Definir `presence` (predicado bash fijo; `command -v <runtime>` o detección de config).
3. Indicar la indirección del secreto propia del runtime (nunca literales).
4. Opcional: `alt_docker` si el runtime soporta el servidor Docker.
5. `setup.sh` lo detecta y mergea automáticamente; no necesita cambios. Red check de regresión: `./setup.sh --check` y `./sync-skills.sh --check` en cero.