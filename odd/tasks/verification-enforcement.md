# Feature: verification-enforcement — que los checks puedan fallar, y que se pueda saber cual

- **Objective**: cerrar cuatro afirmaciones que el repo hace y nada verifica. (1) la suite pytest del server (110 tests) no tiene enforcement: corre solo a mano; (2) el catalogo cerrado de `error.type` es documental, no codigo, y ya esta violado; (3) los ids de check duplicados hacen que un fallo sea inatribuible; (4) no hay CI en el repo.
- **Problem (raiz comun)**: es la misma enfermedad que `contracts-hardening` anuncio en otra superficie — una afirmacion que nadie verifica. Alli era "26 tools" sin lista, "gateo el diff" en vez de la pregunta correcta, y un tipo unico de excepcion. Aca es "110 tests verdes" sin quien los corra, "catalogo cerrado" sin validacion, y checks cuyo nombre no distingue el bloque que fallo.
- **Why**: los seis pendientes quedaron anotados al cerrar `contracts-hardening`; el usuario analizo los seis con evidencia verificada y autorizo estos cuatro explicitamente.
- **Scope**: `tests/run_red_checks.sh`, `srv/gh-mcp-server/src/envelope.py`, `srv/gh-mcp-server/README.md`, y un workflow nuevo de CI. **NO** incluye (no autorizados, quedan como follow-up): T27 (`n == "10"` sobre `+ ECHO_PROTOCOL`), el aviso `diff` whole-file de `--check`/`--dry-run`, ni el guard de paridad cross-envelope.
- **Rama**: `feat/verification-enforcement` desde `main` @ 72d8bf4. No apila sobre ninguna otra rama.
- **Constraints (AGENTS.md)**: fuente canonica primero, sync solo con flags; artefactos tecnicos en espanol; sin commits fuera de work-unit commits en la rama de feature.
- **Delegacion**: se implementa inline. `gentle-ai-worker` fue rechazado antes por el validador de `## Allowed edit surfaces` (rechaza paths de archivos nuevos) y las subagentes no tienen la facade `gentle_review`; el workflow de CI es exactamente el caso de archivo nuevo.

## Contexto verificado (investigado antes de disenar)

Todo con `archivo:linea`. **La salida de los subagentes NO se toma como evidencia**: uno nunca corrio y otro devolvio referencias de linea que se contradijeron a si mismas; todo lo de abajo se reverifico a mano.

- `.github/workflows/` **no existe**. Cero CI en el repo.
- `tests/run_red_checks.sh` menciona "pytest" en 2 lineas (551, 568) y **ambas son comentarios**. Nunca lo invoca.
- El sandbox de la suite RED (`SB_HOME`, bin list) **no incluye `uv`**, asi que la suite no puede correr pytest hoy tal cual.
- Precedente de paso opcional: helper `skip()` (linea 82) y el exit code ya declara "0 = todo verde (skips permitidos)" (linea 51). Los skips son un resultado legitimo del contrato de la suite.
- Precedente contrario: `command -v jq` (linea 65) es **fail-closed**: sin jq, la suite entera aborta. La asimetria con pytest es correcta y hay que decidirla explicita, no por descuido: no todos los entornos tienen `uv`, y no se puede exigir una herramienta ausente.
- Infra de python ya lista: `pyproject.toml` con `[tool.pytest.ini_options] testpaths=["tests"] pythonpath=["."]`, `uv.lock`, `.venv`. Deps: `fastmcp>=2` runtime, `pytest>=8` dev.
- `srv/gh-mcp-server/README.md:42` documenta como arrancar el server; **no dice como correr los tests**. 110 tests sin instruccion.
- Catalogo de `error.type`: `envelope.py:52` — `err()` acepta cualquier string. Barrido multilinea (el `err(` partido en dos lineas hace que un grep de una sola linea de un numero FALSO): **15 documentados, 15 emitidos**, pero `push_failed` se emite (`src/tool_handlers/local_mutation.py`) y **no esta en el catalogo**; `active_agents` esta documentado y **nunca se emite**. T26 asserta que el *docstring* diga 15 nombres — verifica que el documento sea coherente consigo mismo, no que el codigo cumpla.
- Ids duplicados (verificado): T49 (1367+1558), T50 (1383+1534), T51 (1402+1581), T52 (1413+1592), T53 (1425+1657), T54 (1445+1493), T55 (1459+1472+1690). `ok`/`ko` (78-79) registran SOLO `$TEST_NAME` → un fallo en cualquiera de las dos copias es indistinguible en `[FAIL]`.

## W1 — enforcement local de pytest — DONE (`227f74e`)

- **Causa raiz**: la suite pytest depende de una accion manual. Nadie la corre salvo que se acuerde.
- **Fix**: un check que corra `uv run pytest` en `srv/gh-mcp-server` cuando `uv` esta disponible, y `skip` con un motivo explicito cuando no. El paso va FUERA del sandbox `SB_HOME` (que no tiene `uv`) o con `uv` agregado a su bin list — a decidir contra el codigo real, no de memoria.
- **Contrato a preservar**: el exit code de la suite (0 con skips permitidos) y el conteo de SKIP ya existente. La suite debe seguir siendo verde en un entorno sin `uv` — un `ko` por falta de `uv` seria fail-closed sobre una herramienta opcional y dejaria la suite roja en la maquina del developer's vecino.
- **Tests**: el propio check es el test. Ademas, el pin debe afirmar que el paso **corre** la suite y no una mera comprobacion de existencia de `uv` — un pin que solo verifica que el binario este en el PATH seria otra vez un check que no puede fallar.

## W2 — CI workflow — DONE (`7e48d19`)

- **Causa raiz**: W1 cubre el entorno local; no cubre PRs de otra gente.
- **Riesgo conocido y HONESTO**: la suite RED usa `gh` shim, sandboxes y `/tmp`, y puede no portar a CI tal cual. Si no porta, el workflow debe correr **pytest si** y marcar la suite RED como no bloqueante, o resolver la portabilidad. Decidirlo mirando el codigo, no asumiendo.
- **Decision a tomar explicitamente**: si el workflow corre la suite RED y falla, el PR se bloquea. Si la suite no es portable, agregar un paso que reporte sin bloquear. Un workflow que se pone rojo el primer dia y nadie arregla es peor que no tener CI.

## W3 — atribucion de fallos — DONE (`22c7408`)

- **Causa raiz**: `ok`/`ko` imprimen el nombre, no el bloque. Con ids duplicados, "[FAIL] T49: ..." no dice cual de los dos T49 fallo.
- **Fix**: registrar la identidad del bloque (linea + id) en el registro de fallos, sin romper el formato `[PASS]/[FAIL]` que la gente ya lee. Resolver los duplicados: o se renumeran, o se les da sufijo propio (`T49a`/`T49b`). La suite ya tiene ids con sufijo (`T62a`, `T62b`), asi que hay precedente.
- **Tests**: el formato de salida sigue siendo parseable y ahora distingue bloques.

## W4 — catalogo de `error.type` como codigo — DONE (`9699a0a` + `188e7e6`)

W4 se partio en dos work units porque el catalogo y el emisor ausente son defectos
distintos, con owners distintos y con riesgo distinto. W4a: el catalogo pasa a ser
codigo y `push_failed` entra. W4b: `active_agents` se emite de verdad (gate en la
ruta destructiva), lo que ademas destapo un segundo defecto: remove clasificaba con
`session=None` y denegaba como `owned_by_other` el claim del propio proceso que
llama.

- **Causa raiz**: el catalogo se declara "cerrado" en un docstring y en el spec, y `err()` no lo valida. El resultado real lo confirma: `push_failed` se emite sin estar en el catalogo, y nadie se entera.
- **Fix**: `err()` valida `error_type` contra el catalogo; un tipo desconocido deja de ser un string cualquiera. Decidir si es raise (falla ruidoso en dev) o no-op con warning (no rompe produccion) — y documentar la eleccion.
- **Contrato a preservar**: `push_failed` es real y lo emite `local_mutation.py`; hay que decidir si entra al catalogo (lo mas probable: se emitio y forgot documentarse) o si el emisor esta mal. `active_agents`, documentado y nunca emitido, se documenta o se elimina.
- **Tests**: un test que intente `err()` con un tipo fuera del catalogo y verifique el comportamiento; y un test que verifique bidireccionalidad (todo tipo emitido esta en el catalogo y todo tipo del catalogo se emite o esta marcado como reservado).

## Follow-ups que NO entran (registrados, no autorizados)

- **T27** (el mas expuesto de los seis, y el mas barato de arreglar): `n == "10"` sobre `+ ECHO_PROTOCOL`. La salida sugerida en su momento —conjunto paralelo en `tools.json` comparado bidireccionalmente contra el set derivado por `ast`— quedo invalidada en parte por W4: agregar un flag por tool a `tools.json` rompe el esquema `{families: {nombre: [strings]}}`. La via ahora disponible es un check que derive el set por `ast` y lo compare contra una lista nombrada **dentro del propio check**, sin tocar `tools.json` ni `tool_inventory.py`.
- **`--check`/`--dry-run`**: el aviso sigue con `diff` whole-file. Superficie de reporte, no escribe.
- **Guard de paridad cross-envelope**: bloqueado hasta que `feat/pi-gh-git-mcp` mergee (daria rojo en `main`).
- **T52** (1603-1606): dos `grep -Fc` sobre el mismo archivo, con el patron del catalogo como superliteral del base → `2 == 2` se cumple aunque los loops bajen de 5 a 2.
- **T62a/T62b** (2089/2110): cuentan `6` sobre la salida del tool contra el numero del fixture que el mismo test planto (1982-2012). El esperado es el input: tautologico.

## Retros

### Lo que el change hizo

Cinco work units, cinco commits: `227f74e` (W1), `7e48d19` (W2), `22c7408` (W3),
`9699a0a` (W4a), `188e7e6` (W4b). Suite pytest: 110 → **135**. Checks RED: 85, con
`T69` nuevo. La suite RED tiene ahora un gate que la corre entera, un `ci.yml`, ids
que dicen que bloque fallo, y un catalogo que puede fallar.

### Lo que resulto ser la enfermedad real: checks que no pueden fallar

Los cuatro pendientes de este change tenian la misma forma, y es la misma forma
que anuncio `contracts-hardening`: **una afirmacion que nadie verifica**.

- "110 tests verdes" — nadie los corria. Ahora T69 los corre en cada corrida.
- "catalogo cerrado" — era prosa, y ya violado en las dos direcciones.
- "T49 fallo" — tres T49; el log no decia cual. Ahora `[bloque N]`.
- "el CI corre la suite" — un workflow sin pytest encima no corria nada. Por eso
  la leg RED lleva un guard que exige ver `PASS: n` en el log: un job que pasa
  porque la suite no arranco es el mismo defecto, con ropa de CI.

El punto que mas conviene conservar: **el pin mas debil era el que parecia el mas
serio**. T26 (catalogo) hacia `grep -q "$et"` sobre el archivo entero: pasa si el
nombre esta en un comentario, y no puede ver un tipo de mas — que es exactamente
la direccion en la que estaba violado. Un check que verifica que el documento sea
coherente consigo mismo se siente como un check y no verifica el codigo.

### Tres cosas que solo se ven corriendo el codigo

1. **`bash -n` no alcanza.** Al reescribir el header de `t`/`ok`/`ko`/`skip` (W3) borre sin querer `START_EPOCH`/`TEST_EPOCH`, usados en el resumen final. `bash -n` dio verde: la sintaxis estaba bien. La suite corrio los 85 checks y murio en el resumen con `START_EPOCH: unbound variable` bajo `set -u`. Solo lo delata la corrida.
2. **La salida de un subagente no es evidencia.** Uno nunca corrio; otro devolvio referencias de linea que se contradijeron entre secciones. Todo el contexto de este doc se reverifico a mano antes de disenar. Costo: se duplico el trabajo, y quedo la assurance correcta.
3. **La capability de write delegado tiene un hole estructural**: el validador de `## Allowed edit surfaces` rechaza paths de archivos que aun no existen, y las subagentes no tienen la facade `gentle_review`. Los archivos nuevos (el CI) y los tests nuevos no se pueden delegar todavia.

### Los tests mios que afirmaban cosas falsas

Ocurrio cuatro veces en este change, y siempre la realidad corrigio al test:

- El scan de `error.type` emissions era un regex de texto; el docstring decia "AST". Un `err(...)` comentado contaba. Ahora es AST de verdad.
- El test afirmaba que el scan ignoraba codigo muerto bajo `if False:`. No: es una llamada valida. El limite quedo escrito como invariante explicita.
- Fijaba `not_safe` para el drift entre fases; el gate de PID corre antes del flujo, asi que responde `active_agents`. La garantia que importa ("no borra") quedo fijada, y la recomputacion de `safe` tiene su propio test por la unica via que la alcanza.
- El `_spec_types` del catalogo fallo dos veces por regex: `$` con `re.M` corta en la primera linea de una lista multilinea, y `(.*?)\n\s*\n` se comia la linea del bullet siguiente incluia `confirm_required` como si fuera un tipo. Se parseo por lineas.

Cada uno se resolvio **midiendo el comportamiento, no ajustando la expectativa**.
Un test que espera algo imposible se adapta al codigo en vez de medirlo: es el
mismo defecto que una afirmacion sin verificar, pero con la apariencia de test.

### La leccion mas cara: una regla precisa es implementable; una regla ambigua se reporta como implementada

`active_agents` estuvo en el catalogo desde `2026-09-07-sdd-mcp-worktree`, con un
spec que decia "pre-checks (dirty, active agents, owner match)" y un reporte de
verificacion que declaraba "32/32 PASS — live-pid -> active_agents". No habia
codigo. La causa no fue falta de tiempo: fue que la regla no se podia escribir sin
elegir una tension que nadie habia resuelto — el lock guarda `os.getpid()`, asi que
"denegar si hay PID vivo" al pie de la letra impide remover el worktree que el
servidor mismo acaba de tomar. Sin esa eleccion explicita, la frase queda como
algo que se puede repetir en un reporte sin poder codificar.

Y al implementarla aparecio un defecto que el hueco tapaba: `remove` clasifica con
`session=None`, con lo cual **toda** identidad se declara distinta, incluida la
propia — el servidor no podia remover su propio worktree, y el error le decia que
era de otro. Un gate faltante no solo deja un hueco: oculta los defectos que hay
detras.

### Pendiente de decision del usuario (no bloquea el code)

El host tiene 3 desyncs (`./setup.sh --check`): `_shared/sdd-phase-common.md` sin
marcadores `sdd-own:`, `opencode.jsonc` divergente del fragmento SDD, y el bloque de
la routing extension ausente. Producen los 7 FAIL de la suite RED (T05, T21, T30x2,
T31, T39x2) — **baseline conocido, verificado tambien sobre `main` con contenido
identico**, asi que no es de esta rama. La hipotesis inicial (working tree sucio)
se publico, se refuto cuando los mismos 7 fallaron con un arbol limpio y commiteado,
y se descarta. Los mtimes (12:15) son anteriores a las corridas de hoy. Decision
tomada: seguir con el code y sincronizar el host al final. La fragilidad de que la
suite falle por una archivo untracked del usuario queda **fuera de scope**.
