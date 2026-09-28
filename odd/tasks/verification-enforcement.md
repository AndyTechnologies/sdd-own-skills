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

## W1 — enforcement local de pytest

- **Causa raiz**: la suite pytest depende de una accion manual. Nadie la corre salvo que se acuerde.
- **Fix**: un check que corra `uv run pytest` en `srv/gh-mcp-server` cuando `uv` esta disponible, y `skip` con un motivo explicito cuando no. El paso va FUERA del sandbox `SB_HOME` (que no tiene `uv`) o con `uv` agregado a su bin list — a decidir contra el codigo real, no de memoria.
- **Contrato a preservar**: el exit code de la suite (0 con skips permitidos) y el conteo de SKIP ya existente. La suite debe seguir siendo verde en un entorno sin `uv` — un `ko` por falta de `uv` seria fail-closed sobre una herramienta opcional y dejaria la suite roja en la maquina del developer's vecino.
- **Tests**: el propio check es el test. Ademas, el pin debe afirmar que el paso **corre** la suite y no una mera comprobacion de existencia de `uv` — un pin que solo verifica que el binario este en el PATH seria otra vez un check que no puede fallar.

## W2 — CI workflow

- **Causa raiz**: W1 cubre el entorno local; no cubre PRs de otra gente.
- **Riesgo conocido y HONESTO**: la suite RED usa `gh` shim, sandboxes y `/tmp`, y puede no portar a CI tal cual. Si no porta, el workflow debe correr **pytest si** y marcar la suite RED como no bloqueante, o resolver la portabilidad. Decidirlo mirando el codigo, no asumiendo.
- **Decision a tomar explicitamente**: si el workflow corre la suite RED y falla, el PR se bloquea. Si la suite no es portable, agregar un paso que reporte sin bloquear. Un workflow que se pone rojo el primer dia y nadie arregla es peor que no tener CI.

## W3 — atribucion de fallos

- **Causa raiz**: `ok`/`ko` imprimen el nombre, no el bloque. Con ids duplicados, "[FAIL] T49: ..." no dice cual de los dos T49 fallo.
- **Fix**: registrar la identidad del bloque (linea + id) en el registro de fallos, sin romper el formato `[PASS]/[FAIL]` que la gente ya lee. Resolver los duplicados: o se renumeran, o se les da sufijo propio (`T49a`/`T49b`). La suite ya tiene ids con sufijo (`T62a`, `T62b`), asi que hay precedente.
- **Tests**: el formato de salida sigue siendo parseable y ahora distingue bloques.

## W4 — catalogo de `error.type` como codigo

- **Causa raiz**: el catalogo se declara "cerrado" en un docstring y en el spec, y `err()` no lo valida. El resultado real lo confirma: `push_failed` se emite sin estar en el catalogo, y nadie se entera.
- **Fix**: `err()` valida `error_type` contra el catalogo; un tipo desconocido deja de ser un string cualquiera. Decidir si es raise (falla ruidoso en dev) o no-op con warning (no rompe produccion) — y documentar la eleccion.
- **Contrato a preservar**: `push_failed` es real y lo emite `local_mutation.py`; hay que decidir si entra al catalogo (lo mas probable: se emitio y forgot documentarse) o si el emisor esta mal. `active_agents`, documentado y nunca emitido, se documenta o se elimina.
- **Tests**: un test que intente `err()` con un tipo fuera del catalogo y verifique el comportamiento; y un test que verifique bidireccionalidad (todo tipo emitido esta en el catalogo y todo tipo del catalogo se emite o esta marcado como reservado).

## Follow-ups que NO entran (registrados, no autorizados)

- **T27** (`run_red_checks.sh:795`): cuenta `n == "10"` sobre `+ ECHO_PROTOCOL` (hay 13 menciones; 10 con el prefijo). Es el unico lugar de la suite que menciona el token, y no nombra ninguno → un handler destructivo pierde el sufijo de confirmacion de dos fases y uno de lectura lo gana, y reporta PASS. Salida barata: conjunto paralelo en `tools.json` con comparacion bidireccional contra el set derivado por `ast`, reutilizando `tool_inventory.py` (OJO: `tools.json` es `{families: {nombre: [strings]}}`, sin campos por tool — agregar un flag por tool romperia el esquema).
- **`--check`/`--dry-run`**: el aviso sigue con `diff` whole-file. Superficie de reporte, no escribe.
- **Guard de paridad cross-envelope**: bloqueado hasta que `feat/pi-gh-git-mcp` mergee (daria rojo en `main`).
- **T52** (1603-1606): dos `grep -Fc` sobre el mismo archivo, con el patron del catalogo como superliteral del base → `2 == 2` se cumple aunque los loops bajen de 5 a 2.
- **T62a/T62b** (2089/2110): cuentan `6` sobre la salida del tool contra el numero del fixture que el mismo test planto (1982-2012). El esperado es el input: tautologico.

## Retros

(pendiente de completar en el close del change)
