# sdd-own-skills

Repositorio público de la **personalización SDD del usuario** sobre **gentle-ai** (binario de Gentleman-Programming, v3.0.x, ODD-first), bajo el modelo **bloques gestionados**: skills exclusivas nuestras (full install) + un único overlay sobre `_shared` + la **routing extension** (nuestro único gancho sobre el prompt inline del orquestador).

El binario `gentle-ai` instala sus propias skills/commands/prompts (las originales de Alan) en `~/.agents/skills`, `~/.config/opencode/skills` (symlinks), `~/.config/opencode/commands` y `~/.config/opencode/prompts/sdd`. Este repo NO las reemplaza: se adhiere con **skills exclusivas nuestras** (full install), **overlays** que anexan bloques `<!-- sdd-own:<id>:start --> … <!-- sdd-own:<id>:end -->` al final de los archivos de Alan (strip+append idempotente, nunca pisa el original) y la **routing extension** sobre el prompt inline del orquestador (Paso 3b).

**Modelo de despliegue**: los canónicos de TODO lo nuestro viven en `~/.config/sdd-own/` (`skills/<skill>` originales físicos, `skills/_shared/` bootstrap, `prompts/sdd/`). Los directorios de agentes son SYMLINKS a esos canónicos — `~/.agents/skills/<skill>` (skills exclusivas), `~/.config/opencode/skills/<skill>` y `~/.claude/skills/<skill>` → `~/.config/sdd-own/skills/<skill>` (editar el original se propaga a los tres, sin replicación). **Excepción `_shared`**: `~/.agents/skills/_shared/` es un directorio REAL compartido (base de Alan instalada por `gentle-ai sync` + nuestras copias solo-si-falta); `~/.config/opencode/skills/_shared` y `~/.claude/skills/_shared` symlinkean a ese directorio compartido, NO a sdd-own. `setup.sh` despliega además el servidor MCP local en `~/.config/sdd-own/srv/gh-mcp-server`, y el sync (Paso 3b) inyecta la routing extension en el prompt inline del orquestador del config real de opencode.

---

## ¿Qué contiene?

### Skills exclusivas (`skills/`)

Cada carpeta es nuestra y se **full-instala**: la copia física ORIGINAL va a `~/.config/sdd-own/skills/<skill>/` y `~/.agents/skills/<skill>/`, `~/.config/opencode/skills/<skill>/` y `~/.claude/skills/<skill>/` son symlinks a esa copia:

| Skill | Rol |
|-------|-----|
| `product-quest` | **Product Quest (rama product del RFC pre-pass):** entrevista acotada UNA pregunta a la vez (tope duro de 50) + gate RFC explícito (`Approval: approved`); produce `product-rfc.md` (mandato vinculante). Corre SIEMPRE después del explore (ODD y SDD). |
| `architecture-quest` | **Architecture Quest (rama architecture):** entrevista acotada (tope duro de 20) + gate RFC; produce `arch-rfc.md`. Corre cuando el pedido involucra producto/features o decisiones de arquitectura; cambios mecánicos o solo de documentación pueden saltearla. |
| `architecture-lint` | Segunda mirada independiente POST-apply, como parte de la verificación del apply: verifica contra los RFCs generados (`product-rfc.md` / `arch-rfc.md`), el acta `arch-plan.md` cuando se produjo (fail-closed si el arch-plan corrió pero el acta falta), y la implementación contra el catálogo compartido de principios (P01..P10/A01..A11, eje 3 con veredicto independiente). **Siempre corre después del apply.** |
| `skill-sdd-blueprint` | Reference/patrón para crear skills SDD nuevas sin tocar `nextRecommended` ni sobre-ingeniar. |
| `ui-design` | Decisiones de UI (dark luxury / premium), diseño de sistemas, accesibilidad. |
| `web-search` | Búsqueda web con preferencia por MCP dedicados (donsetch, context7). |
| `grilling` | Primitiva de entrevista acotada: UNA pregunta a la vez, tope duro de 50, branch-following. **User-invoked only.** |
| `grill-me` | Alias user-invoked que delega a `grilling`. |
| `hf-cli` | CLI de Hugging Face Hub (`hf`). |
| `typescript` | Patrones estrictos de TypeScript. **Procedencia: Gentleman-Skills (MIT), vendida tal cual.** |
| `tailwind-4` | Patrones de Tailwind CSS 4. **Procedencia: Gentleman-Skills (MIT), vendida tal cual.** |
| `zod-4` | Patrones de Zod 4 (breaking changes vs v3). **Procedencia: Gentleman-Skills (MIT), vendida tal cual.** |
| `playwright` | Patrones de E2E con Playwright (Page Objects, selectors, MCP). **Procedencia: Gentleman-Skills (MIT), vendida tal cual.** |
| `github-pr` | Pull requests de alta calidad con conventional commits y `gh`. **Procedencia: Gentleman-Skills (MIT), vendida tal cual.** |
| `using-git-worktrees` | Aislamiento de workspace vía worktrees: tools nativas primero, fallback `git worktree`, verificación de seguridad. **Procedencia: vendida de [obra/superpowers](https://github.com/obra/superpowers) (MIT, Jesse Vincent); adaptación mínima (frontmatter de suite + nota de provenance).** |
| `test-fixing` | Arreglar tests fallidos agrupando por causa raíz (red → diagnóstico → patch → re-run) hasta suite verde; stack-neutral. **Procedencia: adaptada de [mhattingpete/claude-skills-marketplace](https://github.com/mhattingpete/claude-skills-marketplace) `engineering-workflow-plugin/skills/test-fixing` (Apache-2.0).** |
| `github-automation` | Automatización/operaciones de GitHub vía el MCP oficial (superficie `github_*`): repos, issues, branches, commits, PR review/merge/status (no creación), Actions y code search; cero tokens en la skill. **Authoría propia: sdd-own-skills (fresh reauthoring, repo MIT).** |
| `archify` | Diagramas de arquitectura/workflow/sequence/dataflow/lifecycle como HTML autocontenido (JSON IR tipado → render+validación con Node, sin dependencias). **Procedencia: [tt-a1i/archify](https://github.com/tt-a1i/archify) (MIT), vendida tal cual desde el release asset estable v2.16.0.** |
| `convert-documents-to-markdown` | Convertir Word (.doc/.docx), PowerPoint (.ppt/.pptx), Excel (.xls/.xlsx), OpenDocument (.odt/.ods/.odp), RTF, EPUB, CSV y PDF a Markdown GitHub-Flavored con el CLI de anydoc (Node 20+, `npx -y @firecrawl/anydoc`, sin install). **Procedencia: [firecrawl/anydoc](https://github.com/firecrawl/anydoc) (MIT), vendida tal cual desde el `SKILL.md` de main.** |
| `red-suite-hygiene` | Higiene del harness de RED checks ante desechos ambientales: sandboxes `/tmp/sdd-red.*` huérfanos (fill tmpfs), fake_apis ppid=1, write errors que se disfrazan de FAILs de contrato. Preflight → sweep → re-run limpio → clasificar FAIL real vs ambiental. **Authoría propia: sdd-own-skills.** |

Las skills vendidas vienen de [Gentleman-Programming/Gentleman-Skills](https://github.com/Gentleman-Programming/Gentleman-Skills) (`curated/`), repo **MIT**; cada `SKILL.md` conserva su frontmatter tal cual (4 con `license: Apache-2.0` declarada, `github-pr` sin campo de licencia — se respeta la licencia del archivo individual). No se renombró contenido ni se alteró el frontmatter.

### Bootstrap de `_shared` (`skills/_shared/`)

- `codegraph.md` — nuestra exclusiva (directrices CodeGraph del repo).
- 8 bootstrap **idénticos a los de Alan**: `README.md`, `engram-convention.md`, `openspec-convention.md`, `persistence-contract.md`, `research-lifecycle.md`, `sdd-orchestrator-sections.md`, `sdd-status-contract.md`, `skill-resolver.md`.

Se instalan **SOLO SI FALTA** (never overwrite): si el archivo ya está instalado — por `gentle-ai sync` o por un sync anterior — no se toca. `~/.agents/skills/_shared/` es un directorio REAL compartido (base de Alan + nuestras copias); `~/.config/opencode/skills/_shared` y `~/.claude/skills/_shared` deben ser symlinks a ese directorio compartido (no a sdd-own), para que los agentes vean la base de Alan + los nuestros.

### Overlays (`overlays/`)

Personalización sobre archivos que instala gentle-ai (las originales de Alan). Cada overlay contiene SOLO bloques `<!-- sdd-own:<id-unico>:start --> … <!-- sdd-own:<id-unico>:end -->`; el sync hace **strip** (quita los bloques con el mismo id ya aplicados) + **append** (anexa el contenido al final del archivo de Alan). NUNCA se sobrescriben líneas del original.

En la poda v3 quedó **UN solo overlay**: las carpetas `overlays/skills/` (quest/explore/propose/spec) y `overlays/commands/` (`sdd-new`, `sdd-continue`, `sdd-ff`) fueron eliminadas — sus contratos viven ahora en la **routing extension** (`wiring/sdd-own-routing.md`, Paso 3b) y en las skills propias.

| Overlay | Target | Bloques |
|---------|--------|---------|
| `overlays/shared/sdd-phase-common.md` | `~/.agents/skills/_shared/sdd-phase-common.md` | 7 bloques `shared-*`: language-domain-contract, quest-explore-contract, caveman-communication, no-git-crudo, result-contract-strictness, untrusted-data, worktree-binding |

### Wiring (`wiring/`)

- `wiring/sdd-own-routing.md` — **routing extension**: nuestro ÚNICO gancho sobre el prompt del orquestador. El Paso 3b del sync lo inyecta como bloque `sdd-own:agent-routing` dentro de la sección `<!-- gentle-ai:agent-routing -->` del prompt INLINE de Alan (strip+append idempotente; maneja el formato PLAIN y JSON-escaped del prompt almacenado). NUNCA se toca una línea del prompt de Alan.
- `wiring/prompts/sdd/rfc-author.md` — prompt del subagente autor de los RFCs (recibe las Q&A recolectadas, **no entrevista**, branch-parametric: ensambla UNA rama por corrida).
- `wiring/prompts/sdd/architecture-plan.md` — prompt del subagente que produce el `arch-plan.md` (acta con decisiones tituladas + user gate).
- `wiring/opencode.sdd.json` — fragmento merge-safe con los agentes SDD (se mergea sobre el config real de opencode; ver sección de merge).

Alan **no gestiona** esos 2 prompts; el prompt del orquestador ya NO es nuestro (lo porta inline gentle-ai v3 en el config real) y los prompts de fase de Alan (`sdd-apply.md`, etc.) viven en el mismo directorio y NO se tocan.

---

## Sincronización (`sync-skills.sh`)

El flujo del sync (en orden):

1. **Paso 0 — `gentle-ai sync`**: instala/resetea las bases canónicas de Alan (skills, commands, prompts). Solo en modo real; con `--skip-gentleai-sync` se omite; si el binario no está en PATH, avisa y sigue.
2. **Paso 1 — install de lo nuestro**: skills exclusivas (original en `~/.config/sdd-own/skills/<skill>/` + symlinks en `~/.agents/skills/<skill>/`, `~/.config/opencode/skills/<skill>/` y `~/.claude/skills/<skill>/`), bootstrap de `_shared` (solo si falta: copia a `~/.config/sdd-own/skills/_shared/` y al directorio real compartido `~/.agents/skills/_shared/`, con los `_shared` de opencode/claude como symlinks al compartido), y los prompts propios (`rfc-author.md`, `architecture-plan.md`) a `~/.config/sdd-own/prompts/sdd/` (+ symlink por archivo en `~/.config/opencode/prompts/sdd/` y `~/.claude/prompts/sdd/`).
3. **Paso 2 — overlays**: strip+append de cada `overlays/**` sobre su target de Alan (en v3: el único superviviente es `overlays/shared/sdd-phase-common.md`). Si el target no existe → **ERROR** explícito (probablemente `gentle-ai sync` no instaló esa skill; nunca se crea el base).
4. **Paso 3 — merge opencode**: fragmento SDD sobre el config real (detecta `.jsonc` primero, si no `.json`).
5. **Paso 3b — routing extension**: inyecta `wiring/sdd-own-routing.md` como bloque `sdd-own:agent-routing` dentro de la sección `agent-routing` del prompt inline del orquestador en el config real de opencode (`sync_routing_extension()`, idempotente, respeta `--check`/`--dry-run`).
6. **Paso 4 — registries**: `--registries <proyecto...>` refresca el skill-registry `.atl/` de cada proyecto (solo modo real).

Es idempotente: el strip+append re-aplica los bloques sin duplicarlos; los bootstrap solo se instalan si faltan; los full-copy de exclusivas solo se escriben si difieren.

```bash
./sync-skills.sh                                  # paso 0 (gentle-ai sync) + install + overlays + merge
./sync-skills.sh --skip-gentleai-sync             # omite gentle-ai sync (ya corrió hace poco)
./sync-skills.sh --check                          # verifica sin modificar (reporta desyncs)
./sync-skills.sh --dry-run                        # ensayo: muestra qué se haría, sin escribir nada
./sync-skills.sh --skip-opencode                  # NO mergea el config de opencode
./sync-skills.sh --registries <p1> <p2> ...       # refresca el registry .atl/ de cada proyecto tras el sync
```

Flags:

- `--check`: solo verifica y reporta (estructura de overlays, targets existentes, marcadores únicos, skills esperadas presentes, desyncs: target sin los bloques esperados, prompts que difieren del repo). No muta nada y **no corre** `gentle-ai sync`. Exit `0` = sincronizado (cero desyncs); `1` = desyncs/faltantes detectados; `2` = errores estructurales/fallos.
- `--dry-run`: muestra `[pendiente]` para cada acción que ejecutaría, sin escribir nada y sin correr `gentle-ai sync`.
- `--skip-gentleai-sync`: omite el paso 0 (útil cuando `gentle-ai sync` ya corrió hace poco).
- `--skip-opencode`: omite el merge del config (el fragmento queda disponible en `wiring/opencode.sdd.json`).
- `--registries <proyecto...>`: acumula directorios de proyectos; tras el sync corre `gentle-ai skill-registry refresh --force` en cada uno (con `--check`/`--dry-run` solo reporta).

Salida (exit code): `0` = sincronizado / verificado sin desyncs (cero desyncs), `1` = desyncs/faltantes detectados (en `--check`), `2` = errores estructurales o fallos al aplicar.

**Semántica de errores**: cualquier condición de conflicto — target de overlay faltante, base no identificable (archivo que solo contiene bloques sdd-own), marcardores rotos o ids de bloque duplicados — produce mensaje claro y exit ≠ 0. NUNCA se clobberea un archivo de Alan: el strip+append solo toca bloques sdd-own, los bootstrap jamás sobrescriben, y los full-copy de exclusivas solo pueden pisar skills de la keep-list (las de Alan no están versionadas aquí).

#### Merge de opencode (fragmento SDD)

El repo versiona **`wiring/opencode.sdd.json`**, un fragmento merge-safe que contiene SOLO claves SDD: `$schema`, `agent` (la entrada `gentle-orchestrator` — que porta SOLO `permission`, el allow-list — y los agentes propios `rfc-author`, `architecture-plan`, `architecture-lint`), `default_agent` y la llave sancionada `subagent_depth`. El sync lo mergea sobre el config real de opencode — que puede llamarse `opencode.json` o `opencode.jsonc` (opencode resuelve `.jsonc` primero si ambos existen; el script lo detecta y mergea sobre ese):

- **Añade** los agentes SDD que falten y **actualiza** los existentes (`description`, `mode`, `hidden`, `permission`, `prompt` — solo en agentes propios, como `{file:./prompts/sdd/...}` — `variant`).
- **Preserva todo lo personal**: `providers`, `mcp`, `permission`, `models`, `share`, otros agentes y `default_agent` si ya está seteado. Nada se borra; las claves del fragmento ganan solo en las claves SDD.
- **Respaldo único**: antes del primer merge se escribe `<config>.bak` (solo si no existe ya); los merges siguientes no lo sobrescriben. `--skip-opencode` desactiva el paso completo.
- **Prompt del orquestador**: NO se referencia por archivo — es inline (Alan, ~86k chars) y el fragmento NO lo porta. El único aporte nuestro a ese prompt es el **bloque de routing vía Paso 3b** (sección `agent-routing`, fuente `wiring/sdd-own-routing.md`).
- El merge usa `jq` si está disponible; si el config global es JSONC (p. ej. comas finales que opencode tolera) o falta `jq`, usa `python3` con un merge recursivo equivalente (ambos motores implementan `subagent_depth` fragment-wins).

#### Refresh de registries (`.atl/`)

`./sync-skills.sh --registries <proyecto1> <proyecto2> ...` ejecuta `gentle-ai skill-registry refresh --force` en cada proyecto listado (con el proyecto como cwd) después del sync. Requiere el CLI `gentle-ai` en el PATH; si no está, avisa y omite el paso. El `.atl/` de cada proyecto es local (contiene rutas absolutas) y está gitignoreado. Con `--check`/`--dry-run` solo reporta estado (`[FALTA]` / `[pendiente]`) sin ejecutar nada.

#### Limpieza post-rename (`cleanup-sdd-own.sh`)

El sync despliega nombres nuevos pero **nunca poda**: tras un rename propio quedan copias originales en `~/.config/sdd-own/` y symlinks viejos en los directorios de agentes. `cleanup-sdd-own.sh` retira SOLO esos artefactos, después de correr el sync real:

```bash
./sync-skills.sh                    # primero: despliega los nombres nuevos
./cleanup-sdd-own.sh --check        # lista lo obsoleto (exit 0 = limpio, 1 = hay trabajo)
./cleanup-sdd-own.sh --dry-run      # imprime los rm EXACTOS sin mutar nada
./cleanup-sdd-own.sh                # real: plan + confirmación y/N (o --yes sin TTY)
./cleanup-sdd-own.sh --purge-manual # real + purga los [MANUAL] de poda (opt-in)
```

Rejas: la "verdad" canónica es el repo (`skills/*` + `wiring/prompts/sdd/*.md`); en los directorios de agentes se eliminan SOLO symlinks que apunten dentro de `$SDD_OWN_DIR` — el target se RESUELVE (`readlink -f`) para cubrir las grafías relativas de cada runtime (opencode guarda `../../../sdd-own/...`, claude `../../../.config/sdd-own/...`), nunca se matchea el texto del target; `_shared` se excluye siempre; un obsoleto `sdd-<name>` solo se borra si su sucesor `<name>` está canónico en el repo **y** ya instalado (si falta desplegar → `[STALE]` y aborta sin mutar nada); los obsoletos sin contraparte canónica (poda/eliminación, ej. `sdd-council` tras la poda v3) van a `[MANUAL]`: nunca se borran automáticamente ni bloquean la limpieza del resto, y solo se eliminan con `--purge-manual` explícito. Las anomalías estructurales (directorio sin `SKILL.md`, symlink dentro de sdd-own) jamás se tocan, ni con `--purge-manual`. El refresh de `.atl/` es aparte (`--registries`). Variables de entorno para aislar pruebas: `SDD_OWN_DIR`, `SDD_OWN_REPO`.

#### Quick-start (clonar el repo)

```bash
git clone https://github.com/AndyTechnologies/sdd-own-skills.git sdd-own-skills
cd sdd-own-skills
./sync-skills.sh            # corre gentle-ai sync (bases de Alan) + install de lo nuestro + overlays + merge SDD
./sync-skills.sh --check    # verifica que todo quedó sincronizado (cero desyncs)
```

Requiere `gentle-ai` (v3.0.x) instalado y en el PATH; si no está, el sync avisa y continúa (los targets de overlay podrían faltar y el paso 2 los reportaría como error).

---

## Setup completo (`setup.sh`)

Wrapper de un solo comando que **delega en `sync-skills.sh`** y, si el sync terminó bien, configura el **MCP de GitHub** en los runtimes detectados. Uso típico en una máquina nueva:

```bash
./setup.sh                            # sync real completo + configurar MCP de GitHub (interactivo)
./setup.sh --skip-gentleai-sync       # omite gentle-ai sync (ya corrió hace poco)
./setup.sh --check                    # verifica sync + estado MCP sin escribir nada
./setup.sh --dry-run                  # ensayo: muestra qué haría, sin escribir nada
./setup.sh --registries <p1> <p2>     # delega --registries al sync (refresh .atl/)
./setup.sh --skip-mcp                 # solo el sync, sin el paso MCP
./setup.sh --force-mcp-token          # en modo real, pedir token aunque exista uno válido
./setup.sh --force                    # sobrescribir config manual MCP sin pedir confirmación
```

**Cómo funciona** (paso 5 del script):

1. **Delegación** (paso 0): corre `sync-skills.sh` con el subconjunto de flags que entiende (`--check`, `--dry-run`, `--skip-gentleai-sync`, `--skip-opencode`, `--registries <proyecto...>`). Los flags propios (`--skip-mcp`, `--force-mcp-token`) nunca se reenvían. Si el sync falla con exit ≥ 2, el paso MCP se omite (gate F9) y `setup.sh` sale con ese mismo código. `--check` y `--dry-run` son mutuamente excluyentes (exit 1 si van juntos).
2. **Detección de runtimes** (5a): las definiciones declarativas viven en `wiring/mcp.d/<runtime>.json`; cada una declara su archivo target, la clave raíz y el bloque a mergear. Runtimes no instalados se reportan como `[aviso]` y se omiten:
   - `opencode` → configuración detectada (`$OPENCODE_CONFIG`, si no `~/.config/opencode/opencode.jsonc`, si no `.json`), clave `mcp`.
   - `pi` → `~/.pi/agent/mcp.json`, clave `mcpServers` (usa `auth: "bearer"` + `bearerTokenEnv`, requisito del adapter).
   - `claude` → `~/.claude.json`, clave `mcpServers`.
   - `codex` → `~/.codex/config.toml`, sección `[mcp_servers.github]`.
3. **Gate de token** (5b, solo modo real): si no hay token, pide un **PAT de GitHub** por prompt oculto (`read -rs`) y lo valida contra `https://api.github.com/user` (seam `SDD_OWN_GH_API`). El token se guarda en **`~/.config/sdd-own/github-mcp.env`** (directorio 0700, archivo 0600, solo el fingerprint enmascarado en el reporte). Con token válido existente, pregunta si mantener o rotar (auto-keep sin TTY; `--force-mcp-token` fuerza la pregunta).
4. **Merges** (5e): aplica el bloque declarado en cada target presente (json-key merge sobre la clave raíz; sección TOML para codex, preservando el resto del archivo). En `--check` los merges pendientes/divergentes se reportan (`[pendiente]` / `[aviso]`) sin tocar nada; en modo real se aplican y se reportan `[actualizado]` / `[up-to-date]`.

**Excepción sancionada** (F7): `setup.sh` es el ÚNICO escritor permitido de la clave `mcp` en la config real de opencode fuera del pipeline de sync. El fragmento `wiring/opencode.sdd.json` nunca contiene `mcp`; los agentes SDD se siguen gestionando por sync (paso 3) y el MCP de GitHub por `setup.sh`, sin pisarse.

**Exportar el token a los runtimes** (claude/codex leen `GITHUB_PERSONAL_ACCESS_TOKEN` de la env):

```bash
set -a; source ~/.config/sdd-own/github-mcp.env; set +a
```

**Variante Docker** (sin token en disco): `MCP_GITHUB_TRANSPORT=docker ./setup.sh` usa el contenedor oficial (`ghcr.io/github/github-mcp-server`) con `--env-file`, y los bloques por runtime apuntan al binario docker en vez del endpoint remoto. Requiere `docker` en el PATH.

**Semántica de salida**: `0` = todo bien; `1` = estructura/conflicto (flags excluyentes, modo real sin TTY con token necesario, o token inválido/rechazado en check); `2` = fallo estructural (sync falló). La red/API inalcanzable **no** es estructural: degrada con `[aviso]` y exit 0 (modo real y `--check`, T09/T20). En `--check`, un MCP no configurado con token ausente es **estado limpio válido** (exit 0); solo los rechazos del API (401/403) marcan token drift (exit 1).

**Seams de test** (no tocar en producción): `MCP_DEBUG_SYNC_ARGS=<file>` (escribe `exit=<n>` + argv de la delegación; `MCP_DEBUG_SYNC_ARGS_EXIT` simula el exit del sync), `SDD_OWN_GH_API` (base URL de la API), `SDD_OWN_DEBUG_CURL_CONFIG=<path>` (dump del config temporal de curl — **contiene el token**, solo diagnóstico y borra el dump después), `MCP_GITHUB_TRANSPORT`.

---

## Nuestra personalización del pipeline SDD

El pipeline de gentle-ai v3 (ODD-first) es nativo; este repo NO lo reemplaza. Nuestro aporte se reduce a: la **routing extension** (el único gancho sobre el orquestador), las skills/agentes del ecosistema RFC propio y un único overlay sobre `_shared`. Fuera de esos triggers, el flujo es 100% nativo de gentle-ai.

### 0. El flujo completo de un vistazo

![Flujo SDD configurado](docs/diagrams/sdd-flow.png)

Diagrama del pipeline SDD que configura este repo (generado con nuestra skill `archify`). Camino principal — `ODD nativo → Explore → Product Quest (budget 50) → RFC gate → seed ALWAYS del task doc (odd/tasks/<feature>.md) → Architecture Quest (budget 20, cuando el product RFC o el explore exponen decisiones de arquitectura) → RFC gate → Architecture Plan (solo cambios sustanciales, acta integrada al task doc + user gate) → Design → Tasks → Apply → Architecture Lint (post-apply, contra los RFCs + task doc + acta) → Verify + Archive`. En cambios mecánicos o solo de documentación el flujo saltea ambas quests; si además el cambio no es sustancial, saltea también el Architecture Plan. El council de 3 lentes (era U2) fue retirado del flujo canónico (maquinaria retenida, no invocable desde el orquestador).

- **HTML interactivo**: [`docs/diagrams/sdd-flow.html`](docs/diagrams/sdd-flow.html) (autocontenido, ábrelo en el navegador; incluye 3 vistas guiadas).
- **Fuente editable**: [`docs/diagrams/sdd-flow.workflow.json`](docs/diagrams/sdd-flow.workflow.json) (JSON IR schema v2; editar y re-renderizar/validar con la skill `archify`).

### 1. El RFC es la source of truth (quest bifurcado en dos ramas con gates)

- **Product Quest** (`product-quest`, después de explore): entrevista acotada UNA pregunta a la vez (tope duro de **50**) + **gate RFC explícito** presentado SOBRE el RFC ensamblado por `rfc-author` (`Approval: pending → approved`); produce `product-rfc.md` (mandato vinculante) y, al aprobarse, **siembra SIEMPRE el task doc** `odd/tasks/<feature>.md` (todos los tamaños de cambio). **Corre SIEMPRE después del explore** (ODD-first); solo los cambios mecánicos o solo de documentación pueden saltear ambas quests a criterio del orquestador.
- **Architecture Quest** (`architecture-quest`, tope duro de **20** + gate RFC): produce `arch-rfc.md`. Corre cuando el product RFC aprobado o los hallazgos del explore exponen decisiones de arquitectura, o el usuario pide explícitamente trabajo de arquitectura.
- **`rfc-author`** (subagente file-based) ensambla el RFC canónico de CADA rama desde las Q&A recolectadas — nunca entrevista, nunca ensambla ambas ramas en una corrida (branch-parametric). El gate se presenta DESPUÉS del ensamblado (decisión 5): el RFC nace `Approval: pending` y el orquestador presenta el gate al usuario.
- **Nunca se auto-aprueba una decisión** en nombre del usuario: cada gate requiere aprobación explícita; `needs-changes` reabre SOLO la rama afectada dentro de su presupuesto restante.

### 2. El routing del orquestador (Paso 3b)

Sin tocar `nextRecommended` ni el prompt inline de Alan, el orquestador enruta por la **routing extension**: el bloque `sdd-own:agent-routing` (fuente `wiring/sdd-own-routing.md`) vive dentro de la sección `agent-routing` del prompt del orquestador REAL (config global de opencode), inyectado por el Paso 3b del sync. Es la autoridad en TODA ruta de entrada (command, lenguaje natural, modo auto). Los commands de Alan (`/sdd-new`, `/sdd-continue`, `/sdd-ff`) se dejan intactos: las reglas del quest/RFC viven solo en el bloque de routing.

### 3. Architecture Plan y lint post-apply

- **`architecture-plan`** (subagente file-based) produce el acta con decisiones tituladas + **user gate**, entre el arch-rfc y el design. Corre solo para cambios sustanciales/grandes que necesitan planificación más profunda (`substantial/large and needs deeper planning`); consume los RFCs aprobados (`product-rfc.md` / `arch-rfc.md`) + los hallazgos del explore + el task doc `odd/tasks/<feature>.md`, e **integra su acta EN el task doc** (`## Architecture Plan Acta`, artefacto `arch-plan.md` — sin archivo separado).
- **`architecture-lint`** corre SIEMPRE después del apply, como parte de la verificación del apply (antes de dar el cambio por completo): estilo de segunda mirada que (1) verifica requisitos/scope de los boundaries implementados, (2) verifica contra los RFCs generados (`product-rfc.md` / `arch-rfc.md`) y, cuando el arch-plan corrió, el acta (`## Architecture Plan Acta` del task doc, fail-closed si el arch-plan corrió pero el acta falta) título por título contra el task doc Y la implementación, y (3) verifica la implementación contra el catálogo compartido de principios de arquitectura (P01..P10 / A01..A11, resuelto por path con veredicto independiente pass|fail). La remediación va PRIMERO al writer (apply), con corrección acotada (máx 2 rondas en auto); solo un hallazgo que invalide una decisión de arquitectura re-lanza `architecture-plan` (acotado al eje afectado).
- **`sdd-research`** — evidencia externa auditada (fase de soporte nativa del ecosistema; el `architecture-plan` la delega según necesidad de evidencia).

### 4. Contratos transversales (`sdd-phase-common.md`)

Único overlay superviviente: 7 bloques `sdd-own:shared-*` anexados al `_shared/sdd-phase-common.md` de Alan — **Language Domain Contract** (artefactos en inglés, registro neutral), **Quest↔Explore contract** (la exploración corre PRIMERO y las quests consumen sus hallazgos; el quest gatea el RFC sobre el artefacto ensamblado y si un RFC aprobado resulta no implementable se devuelve a `needs-changes`), caveman-communication, no-git-crudo, result-contract-strictness, untrusted-data y worktree-binding.

---

## Estructura

```
sdd-own-skills/
├── LICENSE
├── README.md
├── AGENTS.md                       # guía para agentes de código que trabajan en este repo
├── sync-skills.sh                  # gentle-ai sync + install exclusivas + overlays + merge SDD + registries
├── setup.sh                        # wrapper de sync + paso MCP de GitHub (wiring/mcp.d)
├── skills/
│   ├── <skill>/SKILL.md            # SOLO nuestras exclusivas (full install)
│   └── _shared/                    # codegraph.md + 8 bootstrap idénticos a los de Alan (solo si falta)
├── overlays/
│   └── shared/sdd-phase-common.md   # ÚNICO overlay (7 bloques sdd-own sobre _shared de Alan)
├── wiring/
│   ├── opencode.sdd.json           # fragmento merge-safe: agentes SDD para opencode
│   ├── sdd-own-routing.md          # routing extension (bloque inyectado en el prompt del orquestador, Paso 3b)
│   ├── mcp.d/                      # definiciones declarativas MCP por runtime (opencode/pi/claude/codex)
│   └── prompts/sdd/                # rfc-author.md + architecture-plan.md (los 2 prompts propios)
├── engram-snapshot/                # artifacts de Engram (diseño/implementación del quest gate)
├── docs/                           # diagrams/ (flujo SDD: PNG + HTML + JSON IR)
└── .gitignore                      # ignora .atl/ (registry con rutas absolutas locales)
```

---

## Licencia

**Este repositorio** está bajo **MIT** (ver [`LICENSE`](LICENSE)) — cubre la colección, la sincronización (`sync-skills.sh`), el setup (`setup.sh` + `wiring/mcp.d`), el wiring, las skills propias (`product-quest`, `architecture-quest`, `architecture-lint`, `skill-sdd-blueprint`, `ui-design`, `web-search`, `github-automation` — fresh reauthoring) y el overlay de `_shared`.

**Proveniencia de las skills vendidas**: `typescript`, `tailwind-4`, `zod-4`, `playwright` y `github-pr` provienen de [Gentleman-Programming/Gentleman-Skills](https://github.com/Gentleman-Programming/Gentleman-Skills) (`curated/`, repo **MIT**), descargadas tal cual con su frontmatter original (las 4 primeras declaran `license: Apache-2.0`; `github-pr` no declara). Cada skill conserva la licencia de su archivo individual según su autor upstream.

**Proveniencia de las skills adaptadas**: 

- `using-git-worktrees` viene de [obra/superpowers](https://github.com/obra/superpowers) (`tools/git/worktrees/SKILL.md`, **MIT**, Copyright 2025 Jesse Vincent); se adaptó solo el frontmatter (suite `sdd-own-skills` + metadata original + nota de provenance) sin tocar el contenido.
- `test-fixing` viene de [mhattingpete/claude-skills-marketplace](https://github.com/mhattingpete/claude-skills-marketplace) `engineering-workflow-plugin/skills/test-fixing` (**Apache-2.0**); se adaptó para ser stack-neutral conservando la estructura de diagnóstico.
- `github-automation` es de autoría propia (fresh reauthoring) y no deriva de ninguna fuente externa.
- `archify` viene de [tt-a1i/archify](https://github.com/tt-a1i/archify) (**MIT**); se vendió el paquete estable tal cual (release asset `archify.zip` v2.16.0, ver `skills/archify/README.md` y `skill-release.json`). Runtime sin dependencias externas (Node builtins).
- `convert-documents-to-markdown` viene de [firecrawl/anydoc](https://github.com/firecrawl/anydoc) (**MIT**, Copyright 2026 Sideguide Technologies Inc.); se vendió el `SKILL.md` tal cual (ver `skills/convert-documents-to-markdown/README.md`). Runtime: `npx -y @firecrawl/anydoc` (Node 20+, sin install).

**Skills de Alan no versionadas aquí**: las demás skills del ecosistema (`sdd-apply`, `sdd-verify`, `branch-pr`, `go-testing`, etc.) las instala `gentle-ai sync` desde sus fuentes canónicas; este repo solo las personaliza vía el overlay compartido (`overlays/shared/`) y la routing extension (`wiring/sdd-own-routing.md`). Se respeta la licencia declarada en cada una según su autor upstream.