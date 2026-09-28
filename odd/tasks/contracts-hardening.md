# Feature: contracts-hardening — tres checks que no podían fallar

- **Objective**: arreglar tres gates/defectos que 신고 el change `pi-gh-git-mcp` como follow-ups. (1) el gate C2 de `setup.sh` confunde "agregar una entrada" con "editar config a mano"; (2) el spec del server MCP declara una superficie de tools que no existe mas, y el conteo sin lista no puede detectar drift; (3) el server clasifica timeout y binario ausente como `network_error`.
- **Problem (raiz comun)**: los tres son checks/defectos que no pueden fallar. El mismo malware de "gate que no ve el caso" que escondio el server ausente de pi.
- **Why**: los tres fueron reportados explicitamente como no-arreglados al cerrar `pi-gh-git-mcp`; el usuario autorizo los tres juntos.
- **Scope**: `setup.sh`, `tests/run_red_checks.sh`, `openspec/specs/gh-git-mcp-server/spec.md`, `srv/gh-mcp-server/{src,tests}` + un inventario nuevo. **NO** se agrega el guard de paridad cross-envelope (era un cuarto proposal, no autorizado) — y no se puede agregar en esta rama: daria rojo en `main` hasta que `feat/pi-gh-git-mcp` mergee. Queda como follow-up condicionado a ese merge.
- **Rama**: `feat/contracts-hardening` desde `main`. NO apila sobre `feat/pi-gh-git-mcp` a proposito: los tres fixes son independientes de ese envelope y los archivos no se solapan, asi que apilar solo agregaria dependencia de merge.
- **Constraints (AGENTS.md)**: fuente canonica primero, sync solo con flags; artefactos tecnicos en el idioma del repo (espanol); sin commits fuera de work-unit commits en la rama de feature.

## Contexto de integracion (investigado antes de disenar)

- `run_red_checks.sh` es la suite RED. Es enteramente estatica (grep/jq sobre fuente); su sandbox (`SB_HOME`, bin list en ~L845) **no incluye `uv`**, asi que **no puede correr la suite pytest del server**.
- La suite pytest del server (`srv/gh-mcp-server/tests/`) se corre **a mano** con `uv run pytest`. No hay CI (`.github/workflows/` no existe). O sea: un test pytest nuevo no tiene enforcement automatizado.
- Precedente exacto para asertar la superficie del server: check **T26** (`t "T26 worktree MCP contrato..."`) — grepsa nombres de tools en `src/tool_handlers/*.py` y el catalogo cerrado en `src/envelope.py`.
- T27 tiene un conteo hardcodeado (`n == "10"`). La suite entera sufre del mismo defecto que el spec: conteos en vez de conjuntos.

## T1 — gate C2: distinguir aditivo de edicion manual

- **Causa raiz**: `setup.sh` gatea con `diff -q merged target`, es decir "¿el resultado difiere del archivo?". La pregunta correcta es "¿el usuario edito a mano una entrada que este envelope administra?". Una clave ausente del target no es edicion manual.
- **Fix**: gatear solo ante **conflictos de valor en paths compartidos** entre el target y el `block`; claves ausentes nunca gatean. Se implementa con `paths(scalars)` sobre el block (recursivo, cubre la profundidad real).
- **Contrato a preservar**: `--force` sigue sobrescribiendo; el prompt TTY sigue asking; `.bak.<ts>` se sigue creando cuando el target existia; el conteo del resumen no cambia.
- **Correccion de comentario**: el comentario que afirma que "la creacion aditiva nunca se gatea" es cierto pero por `flag_created`, no por deteccion de ausencia. Corregir el comentario para que no vuelva a misleadear.
- **Tests**: 3 casos en el RED suite contra target temporal en sandbox — (a) solo-aditivo: escribe, no gatea; (b) conflicto de valor en una clave compartida: gatea; (c) `--force`: sobreescribe.

## T2 — superficie de tools: de conteo a inventario verificable

- **Causa raiz**: "26 tools in 5 families" es un **numero sin lista**; un conteo no puede detectar drift. Peor: **21 de 29 tools no se nombran en ningun lado del spec**.
- **Recuento real**: remote read 14, remote mutation 3, local read 5, local mutation **3** (no 4 — el spec cuenta `git_worktree_add/remove` como local mutation, pero hoy viven en su propia familia `worktree_mutation`), worktree mutation 4. **Total 29**.
- **L1 — verdad**: el requirement "Tool surface completeness" pasa a enumerar las 29 tools por familia, con totales derivados de la lista.
- **L2 — anti-recurrencia**: inventario en **un solo lugar legible por maquina** (`srv/gh-mcp-server/tools.json`). El spec lo referencia; un guard RED deriva el set de tools desde el source y exige **igualdad de conjunto** contra ese archivo, en ambas direcciones. Precedente: el cross-check catalog↔lint (T50).
- **Guard pytest equivalente**: test in-process que lee el mismo `tools.json` (autoritativo, pero sin enforcement automatico — ver arriba).
- **Out of scope (hallazgos adjuntos, no solutions)**: validar que `err()` rechace tipos fuera del catalogo (`err()` hoy acepta cualquier string — el catalogo es documental, no codigo), y documentar el near-collision `git_delete_branch` (local) vs `gh_delete_branch` (remote). Anotados como follow-up.

## T3 — clasificacion de fallo de subprocess

- **Causa raiz**: `executor.py` lanza **un solo** `SubprocessError` para `TimeoutExpired` **y** para `OSError`; `server.py` mapea ese tipo unico a `network_error`. Tres fallos distintos, un solo tipo:

  | Fallo real | Tipo que ve el caller | Correto? |
  |---|---|---|
  | link lento / timeout | `network_error` | no — manda a debuggear la red |
  | `gh` o `uv` ausentes (ENOENT) | `network_error` | peor — actively misleading |
  | fallo real de API/DNS | `network_error` | si |

- **Fix**: partir la excepcion (`SubprocessTimeout` vs `SubprocessError`); clasificar en la safety net — timeout → tipo nuevo `timeout`, ENOENT → `not_found` con hint nombrando el binario, OSError generico → `network_error`. Agregar `timeout` al catalogo documentado (`envelope.py` docstring + lista del spec, que T26 ya asserta).
- **Budget**: NO cambiar el numero de 30s a ciegas. Se hace configurable via `GH_GIT_MCP_TIMEOUT_S` (default preserva 30s); el override por tool de `gh_get_run_logs` (120s) ya es el precedente de que el override funciona. Evidencia disponible: **una** muestra en frio (~11s), insuficiente para decidir un nuevo default.
- **Correccion de doc**: el docstring de `server.py` afirma que "`SubprocessError` is re-raised because each handler classifies its own subprocess failures", pero el codigo lo **atrapa** y devuelve `network_error`. Doc y implementacion se contradicen.
- **Tests**: `test_executor.py` tiene 2 tests, ambos de higiene de env, **cero cobertura de clasificacion**. Agregar 3 (timeout, ENOENT, OSError generico) + 1 en el borde del server que afirme el `error.type`. Mas un pin estatico en el RED suite (unico enforcement automatizado disponible).

## Checklist (stable IDs)

- [x] **T1 — gate C2**: discriminador por conflicto de valor; 4 checks RED (T63–T66); comentario corregido; `--force`/TTY/`.bak` intactos. Commit `6d7703a`.

### T1 — notas de implementacion (evidencia)

- **Alcance ejecutado**: 4 checks RED en vez de los 3 especificados. Motivo: el gate de TOML (`merge_toml_section`) arrastraba el **mismo** defecto y su comentario afirmaba *"misma regla que json"*. Arreglar solo el de json dejaba el comentario mintiendo — exactamente la enfermedad que T1 viene a matar. Se aplicó la misma regla a las dos superficies y se agregó T66 para probarla.
- **Discriminador (json)**: `paths(scalars)` del bloque declarado, acotado al subárbol del `server_key`, cruzado contra los paths presentes en el target. Solo gatea si la ruta **ya existe** en el target y su valor **difiere**. Claves ausentes → aditivo → nunca gatea. Fallo de lectura → `conflict_rc=2` → fail-closed (gatea).
- **Discriminador (TOML)**: mismo algoritmo en `python3`/`tomllib`, porque el sandbox y el host pueden no tener `jq` para un target TOML.
- **Clasificación verificada (5 casos json, 7 casos TOML)**: conflicto de valor → gatea; aditivo → no; clave extra del usuario → no; `server_key` ausente → no; identico → no; cambio de tipo (string→array) → gatea; TOML ilegible → fail-closed.
- **RED probado, no afirmado**: T63 se vio rojo (4 aserciones) contra el gate viejo antes de escribir el fix. T66 se reverificó revirtiendo el gate TOML al viejo → 2 aserciones rojas; restaurado → verde. T65 pasa con ambos gates a propósito: no discrimina, cubre que `--force` no se rompió.
- **Trampa de `set -euo pipefail`**: `jq -e` devuelve 1 en "sin conflicto". Desnudo, `set -e` aborta `setup.sh` entero (se vio: exit 1, salida truncada en 5f, 48 checks en rojo). Ambos probes van con `|| rc=$?`.
- **`jq index` no matchea sub-arrays**: `[["a"],["b"]] | index(["a"])` → `null`. La existencia de la ruta se resuelve con un set de paths serializados (`map(tostring) | join(".")`), indexado en paralelo a los paths reales usados por `getpath`.
- **T66 no puede comparar md5**: con codex presente el paso 5g agrega `sandbox_mode` y `[sandbox_workspace_write]` al **mismo** `config.toml`, así que el byte-comparado da falso positivo. La aserción mira la entrada administrada, no el archivo entero.
- **Follow-up (NO arreglado, mismo commenting-mintiendo)**: en modo `--check`/`--dry-run` el mensaje `[aviso] <target> difiere de la definicion declarada; config manual preservada` usa el mismo `diff` Whole-file, así que un merge puramente aditivo se reporta como "config manual". Es superficie de reporte, no de escritura; queda anotado en Follow-ups.
- [x] **T2 — L1 spec**: requirement "Tool surface completeness" enumera 29 tools por familia, totales derivados. Commit `aa1bfee`.
- [x] **T2 — L2 inventario**: `srv/gh-mcp-server/tools.json` como fuente unica; guard RED de igualdad de conjunto en ambas direcciones; test pytest in-process. Commit `aa1bfee`.

### T2 — notas de implementacion (evidencia)

- **La hipotesis de 29 se confirmo** contra el codigo: `ast` sobre los decoradores `@server.tool()` de `src/tool_handlers/*.py` da 14+3+5+3+4 = 29, y ninguna tool registrada fuera de esos 5 modulos. El spec decia 26 y el README 23.
- **El spec estaba mal hasta en la aritmetica**: atribuia `git_worktree_add`/`git_worktree_remove` a local mutation (que tiene 3) cuando viven en su propia familia `worktree_mutation`, y no nombraba `git_worktree_acquire`/`git_worktree_release`.
- **Se corrigio tambien el catalogo de `error.type`** del mismo requirement: listaba 12, T26 asserta 14 (le faltaban `locked_unreadable` y `corrupt_worktree`). T26 NO se toco. T3 va a agregar `timeout` -> 15.
- **El derive vive en el modulo, no en el check**: `src/tool_inventory.py` es la logica compartida por el guard RED y el test pytest. Un guard que deriva distinto de como deriva el test vuelve a tener dos verdades que pueden divergir, que es el defecto que este change elimina.
- **`tools.json` no lleva `total` escrito**: el total se deriva de la lista. Escribirlo a mano reintroduce la desincronizacion que el inventario viene a evitar.
- **T67 discrimina, verificado en 5 modos**: tool faltante en el inventario; tool fantasma; tool movida de familia (nombre presente, familia mal); tool quitada del spec; y —el importante— una tool movida de familia **con el total intacto en 29**, que un check por conteo no veria jamas. Ademas se vio rojo in-suite con el inventario roto, no solo por CLI.
- **Se cambio de harness a mitad de camino**: el writer delegado no pudo arrancar (el validador de surfaces rechaza paths de archivos nuevos, y `gentle_review` no esta expuesta en las subagentes). T2 se implemento inline. El sondeo dejo una linea de comentario en el header que se revirtio.

- [x] **T3 — clasificacion**: excepcion partida; timeout/ENOENT/generico clasificados; `timeout` en el catalogo; `GH_GIT_MCP_TIMEOUT_S` configurable con default 30s; docstring de `server.py` corregido; 4 tests nuevos + pin RED. Commit `8070738`.
- [x] **T4 — verde**: `tests/run_red_checks.sh` 100% verde y `uv run pytest` del server verde. Commit final.

### T3 — notas de implementacion (evidencia)

- **Tres excepciones, no dos.** El doc pedia partir en `SubprocessTimeout` vs `SubprocessError`, pero `not_found` con hint que nombre el binario requiere distinguir ENOENT de un OSError generico. Se agrego una tercera: `SubprocessBinaryMissing(binary=...)`. Sin ella, el hint tendria que parsear el texto del `OSError`.
- **Las dos especificas heredan de `SubprocessError`**: `gh_auth.py:34` y `worktree_state.py:454` catchean la base y no se tocaron. El orden de los `except` en la safety net es load-bearing: la base va ultima.
- **El default de 30 s no se toco.** Se hizo configurable con `GH_GIT_MCP_TIMEOUT_S`, leido en cada llamada (no al importar) para que un test lo pueda cambiar. Valor invalido o no positivo vuelve al default: una env var mal puesta no debe dejar comandos sin deadline. Los overrides por tool preexistentes (`gh_get_run_logs` 120 s, `codegraph init` 60 s) siguen mandando sobre la env var, y esa precedencia tiene test.
- **Doc que mentia**: el docstring de `server.py` decia que `SubprocessError` se re-lanza porque cada handler clasifica su propio fallo de subprocess. El codigo lo ATRAPA y devuelve `network_error`. Corregido.
- **T68 se escribio antes del fix**: rojo con 9 aserciones. Ademas T26 paso a assertar `timeout`, asi que el catalogo/documento/spec van en la misma direccion (14 -> 15 tipos).
- **Los greps de mapeo de T68 colapsan whitespace con `tr -d '[:space:]'`**: la primera version buscaba el literal `err("timeout"` y fallaba porque el `err(` estaba partido en dos lineas. Un pin que falla por formato empuja a un fix que no arregla nada.
- **pytest tambien discrimina, y eso es lo que importa** (el pin estatico es weak por naturaleza): degradando SOLO el mapeo a `network_error` con los `except` intactos, fallan 3 tests de borde de `server.py`; volviendo al tipo unico en `executor.py`, fallan 3 de executor. La suite pytest no tenia NINGUNA cobertura de clasificacion antes de esto.
- **Trampa de evidencia**: el primer sabotaje de A metio placeholders `_P1`/`_P2` inexistentes, y 2 de los 5 fallos vinieron por `NameError` del arm, no por el mapeo. Hubo que repetirlo degradando solo el mapeo para tener evidencia honesta. Un rojo que falla por la razon equivocada es peor que no tener rojo: te hace creer que el check cubre algo que no cubre.

## Follow-ups (NO en este change)

- Guard de paridad cross-envelope (todo runtime declarado expone los mismos `block` keys). **Condicionado**: dariá rojo en `main` hasta que `feat/pi-gh-git-mcp` mergee; agregarlo despues de ese merge.
- Validacion en codigo del catalogo de `error.type` (`err()` hoy acepta cualquier string).
- Correr la suite pytest del server de forma automatizada: hoy no hay CI y el sandbox RED no tiene `uv`, asi que los tests de clasificacion no tienen enforcement automatico. Es el gap de fondo mas grande de este change.
- Paridad de `gh-git-mcp` en `wiring/mcp.d/claude.json`.
- El aviso de `--check`/`--dry-run` ("difiere de la definicion declarada; config manual preservada") sigue usando el `diff` whole-file: un merge puramente aditivo se reporta como edicion manual. Misma conflanza, superficie de reporte.
- `T27` y el resto de la suite RED tienen la enfermedad del conteo (`n == "10"` hardcodeado) que T2 corrige en el spec. La suite queda para otro change.

## Retros

### Que era este change, en una frase

Tres "checks que no podían fallar": tres gates o afirmaciones que parecian proteger
algo y no protegian nada. La raiz comun no era que faltara logica — era que cada
uno hacia la pregunta equivocada.

### Lecciones que se llevan

**1. Un conteo no es un inventario.** El defecto de fondo de T2. "26 tools en 5
familias" no puede detectar drift porque no dice QUE tools son. La forma correcta
es igualdad de conjunto en ambas direcciones, y la forma que revela el defecto mas
fuerte es el caso que un conteo SIEMPRE deja pasar: una tool movida de familia con
el total intacto en 29. Ese caso se uso como la prueba de que T67 discrimina.

**2. Un unico tipo de excepcion hace imposible clasificar.** El defecto de fondo
de T3. No era un bug de mapeo: era que la safety net no tenia con que decidir.
Partir el tipo NO fue agregar precision, fue habilitar la decision.

**3. La pregunta equivocada no se arregla cambiandola de nombre.** El defecto de
fondo de T1. `diff merged target` respondia "¿cambio algo?" cuando la pregunta era
"¿el usuario edito un valor que este envelope administra?". Gatear por la pregunta
equivocada no es un gate conservador: es un gate que bloquea lo legitimo y deja
pasar lo que deberia bloquear.

**4. Un pin que falla por el motivo equivocado es peor que no tener pin.** T68
tenia `grep 'err("timeout"'` y fallaba porque el `err(` estaba partido en dos
lineas. Un rojo que no significa lo que dice empuja a un fix que no arregla nada,
y entrena a desconfiar del check. Los pins Estaticos tienen que colapsar
whitespace y afirmar el CONTRATO, no el formato.

**5. El sabotage con placeholders da evidencia falsa.** Al verificar T3 meti
`_P1`/`_P2` inexistentes; 2 de 5 fallos vinieron por `NameError` del `except`, no
por el mapeo degradado. Un rojo que falla por la razon equivocada convence de que
el check cubre algo que no cubre. Verificar un check es un trabajo con su propio
esfuerzo: hay que degradar UNA variable, no reescribir el mecanismo.

### Lo que quedo sin resolver (honestamente)

- **El gap de fondo no se toco**: los tests pytest del server siguen sin
  enforcement automatico (no hay CI, y el sandbox RED no tiene `uv`). T3 agrego 18
  tests de clasificacion que se van a romper en silencio la proxima vez que se
  rompa el clasificador. Es el follow-up mas importante y es el unico que no es
  cosmico.
- **La superficie de reporte de `--check`/`--dry-run` de `setup.sh` sigue con el
  `diff` whole-file** (anotado en Follow-ups). Misma enfermedad que T1 pero en
  una superficie que no escribe, asi que no se toco.
- **T27 y el resto de la suite RED tienen la enfermedad del conteo** (`n == "10"`).
  T2 la corrigio en el spec; la suite queda para otro change.
- **`err()` sigue aceptando cualquier string**: el catalogo cerrado de `error.type`
  es documental, no codigo. Anotado como follow-up desde el inicio, sigue igual.

### Sobre el proceso

El harness cambio a mitad de camino: el writer delegado no arranco (el validador de
surfaces rechaza paths de archivos nuevos, y las subagentes no tienen la facade
`gentle_review`), asi que T2 y T3 se implementaron inline. El sondeo dejo una linea
de comentario en el header que se revirtio. Ademas el primer commit de T2 llevo
3 de 6 archivos por un `git add` incompleto — detectado revisando
`git show --stat`, no por el test. Ninguno de los dos errores cambio el resultado
final, pero los dos son la clase de cosa que aparece si nadie mira el diff.

