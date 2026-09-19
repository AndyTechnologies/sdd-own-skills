#!/usr/bin/env bash
# =============================================================================
# run_red_checks.sh — RED checks de setup.sh (fase de implementacion, P5)
#
# Correr desde cualquier lado; resuelve el repo por SCRIPT_DIR.
#   ./tests/run_red_checks.sh
#
# Mapa de cobertura (design.md, Testing Strategy):
#   T01 sintaxis            T08 token 401 real          T15 presence/creacion (F2)
#   T02 wrap contract (F6)  T09 red fallida real        T16 merge TOML (F3)
#   T03 flags y uso         T10 higiene/argv (F1)       T17 hard deps (F4)
#   T04 argv delegado       T11 scopes faltantes        T18 gate F9
#   T05 no-mutacion host    T12 keep                    T19 check 401 drift
#   T06 no-mutacion check   T13 replace (F5)            T20 check red degradada
#   T07 no-mutacion dry-run T14 colision invalid        T21 regresion + README (F7)
#                                                       T22 env snippets POSIX+fish
#   T23 permisos C2         T24 selector no-interactivo T25 selector pty (toggle)
#   T26 worktree contrato   T27 E1 doc-contract         T28 contract pins + routing-only
#   T29 SWU probe + poda    T30 sync + id hygiene       T31 Paso 3b idempotente (config real)
#   T32 poda council/gates  T33 fragment wiring v3      T34 OWN_PROMPTS exacto (2)
#   T35 acta fail-closed    T36 quest gates (2 ramas)   T37 fragment SDD-only
#   T38 subagent_depth 2    T39 merge ambos motores
#   T40 one-parse           T41 fallback+dedupe         T42 title retrievability
#   T42b worktree list      T43 signals+dirty            T44 record→resolve
#   T45 --json≡scanner      T46 read fail-open           T47 write FAIL-OPEN
#   T47b 5d-2 warn          T48 poda prompts/skills (2 prompts exactos)
#   T49 rfc-author prompt-defined  T50 quest split 50/20 + 2 gates
#   T51 routing lean (sin PR/MCP)  T52 machinery podado ausente
#   T53 Paso 3b en sync (orden+flags)  T54 arch-plan acta + user gate
#   T55 arch-quest ODD triggers      T55 poda hard-gate era
#   T49 catalog schema/corpus   T50 catalog↔lint cross-check
#   T51 catalog single path     T52 shared-loop join
#   T53 quest arch rework
#   T54 plan checklist (anchor + 21 rows + 3 states + evidence mandatory)
#   T55 axis-3 fixtures: clean pass + dirty per-family (L2, severidad del catalogo)
#   T56 axis-3 fixtures: multi -> set completo de blockers (L3)
#   T57 axis-3 fixtures: AMBIGUOUS -> warning, nunca blocker (L4)
#   T58 axis-3 fixtures: n-a-justified suprime (L5) + contradiction dual signal (L6/C7)
#   T59 axis-3 fixtures: missing-checklist + translated-anchor fail-closed (C1/C2)
#   T60 wiring (B5): sdd-architecture-plan agent key + allow-list
#
# Exit: 0 = todo verde (skips permitidos), 1 = fallos.
# =============================================================================

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPERS="$REPO/tests/helpers"
# shellcheck disable=SC1091
source "$HELPERS/sandbox.sh"

# Real home capturado ANTES de que los tests muten HOME (T44+ exporta HOME a un
# sandbox): los legs runtime de T52/T30/T39 contra el host deben usar el HOME
# real del despliegue target, no un sandbox heredado.
REAL_HOME="${HOME:-}"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq requerido para los RED checks" >&2
  exit 2
fi

PASS=0; FAIL=0; SKIP=0
declare -a FAILURES=()
TEST_NAME=""
TEST_START=0
START_EPOCH="$(date +%s)"
TEST_EPOCH="$START_EPOCH"

_t_elapsed() { echo "$(( $(date +%s) - TEST_START ))s"; }

t()   { TEST_NAME="$1"; TEST_START="$(date +%s)"; }
ok()  { PASS=$((PASS + 1)); printf '  [PASS] %-9s %s\n' "($(_t_elapsed))" "$TEST_NAME"; }
ko()  { FAIL=$((FAIL + 1)); FAILURES+=("$TEST_NAME"); printf '  [FAIL] %-9s %s: %s\n' "($(_t_elapsed))" "$TEST_NAME" "$1"; }
skip(){ SKIP=$((SKIP + 1)); printf '  [SKIP] %-9s %s: %s\n' "($(_t_elapsed))" "$TEST_NAME" "$1"; }

cleanup() { stop_fake_api; cleanup_sandboxes; }
trap cleanup EXIT INT TERM

echo "== RED checks de setup.sh (repo: $REPO)"
echo

# ---------------- Warm build de sdd-tool (antes de los sandboxes) ----------------
# El paso 5d-2 de setup.sh compila srv/sdd-tool (`go build`) en CADA modo real.
# Construirlo aca, con el entorno del HOST, calienta GOMODCACHE/GOCACHE: los
# sandboxes reusan ese cache (init_sandbox en helpers/sandbox.sh los inyecta
# con GOPROXY=off) y el 5d-2 baja de ~90s (descarga de modulos en un HOME
# vacio, sin red) a ~1-2s. Sin esto, los tests pty (T09/T12-T14/T22/T25)
# mueren con exit 201 (timeout) y T15 rompe su idempotencia con caches
# parciales dentro del HOME del sandbox.
SDD_TOOL_BIN="$REPO/srv/sdd-tool"
_sdd_tool_built=-1
if [[ -f "$SDD_TOOL_BIN/cmd/sdd-tool/main.go" ]]; then
  # Resolve go binary — try PATH first, then common locations
  _go_bin="$(command -v go 2>/dev/null || true)"
  if [[ -z "$_go_bin" ]]; then
    for _p in /usr/sbin/go /usr/local/go/bin/go "$HOME/go/bin/go"; do
      [[ -x "$_p" ]] && _go_bin="$_p" && break
    done
  fi
  if [[ -n "$_go_bin" ]]; then
    _sdd_build_tmp="$(mktemp -d)"
    # Build from the MODULE root (go.mod live en srv/sdd-tool/; el root del
    # repo no tiene go.mod, asi que construir "$SDD_TOOL_BIN/cmd/sdd-tool/"
    # desde REPO falla silenciosamente). Un fallo de build aca debe ser LOUD,
    # nunca un skip silencioso de T40-T47.
    if ( cd "$SDD_TOOL_BIN" && "$_go_bin" build -o "$_sdd_build_tmp/sdd-tool" ./cmd/sdd-tool/ ) 2>"$_sdd_build_tmp/build-err.txt"; then
      _sdd_tool_built=1
    else
      echo "  [ERROR] sdd-tool build fallo (module root: $SDD_TOOL_BIN):" >&2
      sed 's/^/    /' "$_sdd_build_tmp/build-err.txt" >&2
      rm -rf "$_sdd_build_tmp"
      _sdd_build_tmp=""
    fi
  else
    echo "  [ERROR] go no encontrado en PATH ni ubicaciones comunes; no se puede construir sdd-tool" >&2
  fi
else
  echo "  [ERROR] faltan fuentes de sdd-tool ($SDD_TOOL_BIN/cmd/sdd-tool/main.go); bloque T40-T48 roto" >&2
fi

# ---------------- Grupo 1: sintaxis y contrato declarativo -------------------

t "T01 sintaxis (bash -n setup.sh + sync-skills.sh)"
if bash -n "$REPO/setup.sh" && bash -n "$REPO/sync-skills.sh"; then ok; else ko "bash -n fallo"; fi

t "T02 wrap contract (F6): bloques json-key envueltos; codex desnudo; sin tokens"
{
  bad=0
  for env in opencode pi claude; do
    jq -e '.block | type == "object" and has("github")' "$REPO/wiring/mcp.d/$env.json" >/dev/null 2>&1 || { ko "envelope $env: bloque no envuelto bajo server_key"; bad=1; }
  done
  jq -e '.block | type == "object" and (has("github") | not)' "$REPO/wiring/mcp.d/codex.json" >/dev/null 2>&1 || { ko "codex: bloque no es cuerpo desnudo"; bad=1; }
  for env in opencode pi claude codex; do
    jq -e '.block | tostring | contains("https://api.githubcopilot.com/mcp/")' "$REPO/wiring/mcp.d/$env.json" >/dev/null 2>&1 || { ko "envelope $env: URL remota ausente"; bad=1; }
  done
  # alt_docker es un objeto {command,args}: verificar el contrato docker
  # (--rm -i --env-file + imagen) sin depender del join textual de los args.
  jq -e '.alt_docker | tostring | contains("docker") and contains("--rm") and contains("--env-file") and contains("ghcr.io/github/github-mcp-server")' "$REPO/wiring/mcp.d/opencode.json" >/dev/null 2>&1 || { ko "opencode: alt_docker ausente o incompleto"; bad=1; }
  grep -q '"mcp"' "$REPO/wiring/opencode.sdd.json" && { ko "wiring/opencode.sdd.json gano una clave mcp"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T03 flags: flag desconocido y conflicto check+dry-run (exit 1, sin delegar)"
{
  bad=0
  init_sandbox
  run_setup --bogus </dev/null >/dev/null 2>&1
  [[ "$(cat "$SB_TMP/exit")" == "1" ]] || { ko "flag desconocido: exit $(cat "$SB_TMP/exit") != 1"; bad=1; }
  [[ -e "$SB_TMP/sync-seam.txt" ]] && { ko "flag desconocido: seam creado (delego antes de abortar)"; bad=1; }
  run_setup --check --dry-run </dev/null >/dev/null 2>&1
  [[ "$(cat "$SB_TMP/exit")" == "1" ]] || { ko "--check --dry-run: exit $(cat "$SB_TMP/exit") != 1"; bad=1; }
  [[ -e "$SB_TMP/sync-seam.txt" ]] && { ko "--check --dry-run: seam creado (no aborto antes de delegar)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T04 argv delegado: solo flags entendidos por sync"
{
  bad=0
  init_sandbox
  run_setup --check --skip-mcp </dev/null >/dev/null 2>&1
  grep -q -- "--skip-mcp" "$SB_TMP/sync-seam.txt" && { ko "argv: --skip-mcp filtrado pero reenviado"; bad=1; }
  grep -q -- "--check" "$SB_TMP/sync-seam.txt" || { ko "argv: --check no llego al seam"; bad=1; }
  grep -q "^exit=" "$SB_TMP/sync-seam.txt" || { ko "argv: sin linea de exit en el seam"; bad=1; }
  run_setup --registries /tmp/proy </dev/null >/dev/null 2>&1
  grep -q -- "--registries" "$SB_TMP/sync-seam.txt" || { ko "argv: --registries no se reenvio"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 2: no-mutacion y estados limpios ---------------------

t "T05 no-mutacion host: --check no toca el repo"
{
  bad=0
  ( cd "$REPO" && git status --porcelain ) > "$SB_TMP/git-before.txt" 2>/dev/null
  ( cd "$REPO" && ./setup.sh --check ) > "$SB_TMP/host-check.txt" 2>&1
  rc=$?
  ( cd "$REPO" && git status --porcelain ) > "$SB_TMP/git-after.txt" 2>/dev/null
  diff -q "$SB_TMP/git-before.txt" "$SB_TMP/git-after.txt" >/dev/null || { ko "git status cambio tras --check"; bad=1; }
  [[ $rc -eq 0 ]] || { ko "host --check exit $rc != 0"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T06 no-mutacion sandbox: --check no escribe nada y no promptea"
{
  bad=0
  init_sandbox; start_fake_api 200
  snapshot_tree "$SB_HOME" "$SB_TMP/tree-before.txt"
  run_setup --check </dev/null
  snapshot_tree "$SB_HOME" "$SB_TMP/tree-after.txt"
  diff -q "$SB_TMP/tree-before.txt" "$SB_TMP/tree-after.txt" >/dev/null || { ko "sandbox --check muto archivos"; bad=1; }
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "sandbox --check exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "estado limpio" "$SB_TMP/out.txt" || { ko "sin reporte de estado limpio"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T07 no-mutacion sandbox: --dry-run no escribe nada"
{
  bad=0
  init_sandbox; start_fake_api 200
  snapshot_tree "$SB_HOME" "$SB_TMP/tree-before.txt"
  run_setup --dry-run </dev/null
  snapshot_tree "$SB_HOME" "$SB_TMP/tree-after.txt"
  diff -q "$SB_TMP/tree-before.txt" "$SB_TMP/tree-after.txt" >/dev/null || { ko "sandbox --dry-run muto archivos"; bad=1; }
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "sandbox --dry-run exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 3: gate de token y secretos --------------------------

t "T08 token invalido (401): 3 intentos, nada persistido, exit 2"
{
  bad=0
  init_sandbox; start_fake_api 401
  run_setup_pty 45 'Token de GitHub (PAT): =ghp_BAD1\n;Token de GitHub (PAT): =ghp_BAD2\n;Token de GitHub (PAT): =ghp_BAD3\n'
  [[ "$(cat "$SB_TMP/exit")" == "2" ]] || { ko "exit $(cat "$SB_TMP/exit") != 2 tras 3 rechazos"; bad=1; }
  grep -q "intento 3/3" "$SB_TMP/out.txt" || { ko "sin aviso intento 3/3"; bad=1; }
  grep -q "no se persiste nada" "$SB_TMP/out.txt" || { ko "sin mensaje de no-persistencia"; bad=1; }
  [[ -e "$SB_HOME/.config/sdd-own/github-mcp.env" ]] && { ko "env file creado con token invalido"; bad=1; }
  grep -q "ghp_BAD" "$SB_TMP/out.txt" && { ko "token visible en la salida (read -rs con eco!)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T09 red fallida en modo real: degradacion suave (F5), nada persistido, exit 0"
{
  bad=0
  init_sandbox; start_fake_api 200; stop_fake_api
  run_setup_pty 30 'Token de GitHub (PAT): =ghp_NET\n;Runtimes a configurar=\n'
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0 (degradacion, no aborto)"; bad=1; }
  grep -q "\[aviso\].*fallo de red" "$SB_TMP/out.txt" || { ko "sin aviso de degradacion por red"; bad=1; }
  grep -q "no se persiste nada" "$SB_TMP/out.txt" || { ko "sin mensaje de no-persistencia"; bad=1; }
  [[ -e "$SB_HOME/.config/sdd-own/github-mcp.env" ]] && { ko "env file creado sin validacion"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T10 higiene de secretos y argv (F1)"
{
  bad=0
  tok="ghp_REDTEST123"
  exp_mask="${tok:0:4}....${tok: -4}"
  init_sandbox; start_fake_api 200
  add_env SDD_OWN_DEBUG_CURL_CONFIG="$SB_TMP/curl-config.txt"
  run_setup_pty 45 "Token de GitHub (PAT): =${tok}\\n;Cambiar el token antes de continuar? [s/N] =n\\n;Runtimes a configurar=\\n"
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  envf="$SB_HOME/.config/sdd-own/github-mcp.env"
  [[ "$(stat -c %a "$envf")" == "600" ]] || { ko "mode $(stat -c %a "$envf") != 600"; bad=1; }
  # F1: el token aparece SOLO donde debe — config curl 0600 y env file 0600 —
  grep -rq "$tok" "$SB_TMP" --exclude='curl-config.txt' && { ko "token filtrado a archivos de salida/logs"; bad=1; }
  [[ -f "$SB_TMP/curl-config.txt" ]] || { ko "dump de config curl ausente"; bad=1; }
  grep -q "Bearer $tok" "$SB_TMP/curl-config.txt" || { ko "config curl no transporta el token (mecanismo F1 roto)"; bad=1; }
  grep -q "$tok" "$SB_TMP/out.txt" && { ko "token visible en la salida"; bad=1; }
  [[ -f "$SB_TMP/api.cmdlines" ]] && grep -q "$tok" "$SB_TMP/api.cmdlines" && { ko "token en cmdline de curl hijo"; bad=1; }
  # Falso positivo a evitar: el debug imprime el PATH del tmpfile (contiene
  # "sdd-own-curl"); lo que importa es que no QUEDEN archivos sin borrar.
  leftovers=$(compgen -G "$SB_TMP/sdd-own-curl.*" 2>/dev/null | head -1)
  [[ -n "$leftovers" ]] && { ko "tmpfile de curl sin borrar: $leftovers"; bad=1; }
  grep -qF "$exp_mask" "$SB_TMP/out.txt" || { ko "reporte sin huella enmascarada ($exp_mask)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T11 scopes faltantes: aviso + opcion de cambio, run continua"
{
  bad=0
  init_sandbox; start_fake_api 200 "read:org"
  run_setup_pty 45 'Token de GitHub (PAT): =ghp_SCOPES\n;Cambiar el token antes de continuar? [s/N] =n\n;Runtimes a configurar=\n'
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "faltan scopes clasicos" "$SB_TMP/out.txt" || { ko "sin aviso de scopes faltantes"; bad=1; }
  [[ -f "$SB_HOME/.config/sdd-own/github-mcp.env" ]] || { ko "token no persistido"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 4: persistencia y rotacion ---------------------------

t "T12 keep: token existente valido conservado (k)"
{
  bad=0
  init_sandbox; start_fake_api 200
  seed_env_file "ghp_T1KEEP123"
  m0="$(env_file_mtime)"
  run_setup_pty 45 'Conservar el token existente? [k/R] =k\n;Runtimes a configurar=\n'
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "conservado (sin reescritura)" "$SB_TMP/out.txt" || { ko "sin reporte keep"; bad=1; }
  env_file_lines | grep -q "ghp_T1KEEP123" || { ko "env file no conserva el token"; bad=1; }
  [[ "$(env_file_mtime)" == "$m0" ]] || { ko "env file reescrito en keep (mtime cambio)"; bad=1; }
  [[ -e "$SB_HOME/.config/sdd-own/github-mcp.env.bak" ]] && { ko "keep creo .bak"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T13 replace (F5): R respalda .bak 0600 y rota; a lo sumo un .bak"
{
  bad=0
  init_sandbox; start_fake_api 200
  seed_env_file "ghp_T1REPLACE"
  run_setup_pty 45 'Conservar el token existente? [k/R] =R\n;Token de GitHub (PAT): =ghp_T2REPLACE\n;Cambiar el token antes de continuar? [s/N] =n\n;Runtimes a configurar=\n'
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  bak="$SB_HOME/.config/sdd-own/github-mcp.env.bak"
  [[ -f "$bak" ]] || { ko "sin .bak tras replace"; bad=1; }
  [[ "$(stat -c %a "$bak")" == "600" ]] || { ko ".bak mode $(stat -c %a "$bak") != 600"; bad=1; }
  grep -q "ghp_T1REPLACE" "$bak" || { ko ".bak no contiene el token anterior"; bad=1; }
  env_file_lines | grep -q "ghp_T2REPLACE" || { ko "env file no roto a T2"; bad=1; }
  env_file_lines | grep -q "ghp_T1REPLACE" && { ko "token viejo persistido en env file"; bad=1; }
  n="$(ls "$SB_HOME/.config/sdd-own/"*.bak 2>/dev/null | wc -l)"
  [[ "$n" == "1" ]] || { ko "cantidad de .bak = $n (esperado 1)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T14 colision: env file invalido existente se reemplaza con .bak del invalido"
{
  bad=0
  init_sandbox; start_fake_api 200 "" 1   # primer request 401, resto 200
  seed_env_file "ghp_STALEINV"
  run_setup_pty 45 'Token de GitHub (PAT): =ghp_NEWVALID\n;Cambiar el token antes de continuar? [s/N] =n\n;Runtimes a configurar=\n'
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "reemplazo del token invalido" "$SB_TMP/out.txt" || { ko "sin flujo de reemplazo del invalido"; bad=1; }
  grep -q "ghp_STALEINV" "$SB_HOME/.config/sdd-own/github-mcp.env.bak" || { ko ".bak no conserva el invalido previo"; bad=1; }
  env_file_lines | grep -q "ghp_NEWVALID" || { ko "env file no actualizado"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 5: merges por runtime --------------------------------

t "T15 presence/creacion (F2): pi crea target sin .bak; re-run up-to-date; resto preservado"
{
  bad=0
  init_sandbox; start_fake_api 200
  seed_env_file "ghp_CREATE01"
  run_setup </dev/null   # sin TTY: auto-keep del token valido
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "\[creado\]" "$SB_TMP/out.txt" || { ko "sin reporte [creado]"; bad=1; }
  grep -q "claude: runtime ausente" "$SB_TMP/out.txt" || { ko "claude no reportado ausente"; bad=1; }
  grep -q "codex: runtime ausente" "$SB_TMP/out.txt" || { ko "codex no reportado ausente"; bad=1; }
  pif="$SB_HOME/.pi/agent/mcp.json"
  [[ -f "$pif" ]] || { ko "pi mcp.json no creado"; bad=1; }
  jq -e '.mcpServers.github.url == "https://api.githubcopilot.com/mcp/"' "$pif" >/dev/null 2>&1 || { ko "bloque pi invalido"; bad=1; }
  [[ -e "$pif.bak" ]] && { ko "pi recien creado con .bak"; bad=1; }
  ocf="$SB_HOME/.config/opencode/opencode.jsonc"
  ls "$ocf".bak.* >/dev/null 2>&1 || { ko "opencode existente sin .bak en su primer merge"; bad=1; }
  jq -e '.mcp.github' "$ocf" >/dev/null 2>&1 || { ko "opencode: mcp.github no mergeado"; bad=1; }
  jq -e '.mcp.codegraph' "$ocf" >/dev/null 2>&1 || { ko "opencode: mcp.codegraph perdido en el merge"; bad=1; }
  snapshot_tree "$SB_HOME" "$SB_TMP/t1.txt"
  run_setup </dev/null
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "re-run exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "\[up-to-date\]" "$SB_TMP/out.txt" || { ko "re-run sin [up-to-date]"; bad=1; }
  snapshot_tree "$SB_HOME" "$SB_TMP/t2.txt"
  diff -q "$SB_TMP/t1.txt" "$SB_TMP/t2.txt" >/dev/null || { ko "re-run muto archivos (no idempotente)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T16 merge TOML (F3): [mcp_servers.github] correcto, resto preservado; tomli-w ausente → ERROR exit 2"
{
  bad=0
  init_sandbox; start_fake_api 200
  add_bin codex
  printf '[owner]\nname = "andy"\n\n[project]\ndir = "/tmp"\n' > "$SB_HOME/.codex/config.toml"
  seed_env_file "ghp_TOML001"
  if python3 -c 'import tomli_w' >/dev/null 2>&1; then
    # El sandbox redirige HOME, asi que python3 pierde el site-packages del
    # usuario real (donde vive tomli_w). Exponerlo via PYTHONPATH para que el
    # happy path pueda importarlo; si el host no lo tiene, skip (el fail-fast
    # estructurado se verifica igual abajo con el shim).
    pypath="$(python3 -c 'import site; print(site.getusersitepackages())' 2>/dev/null || true)"
    add_env PYTHONPATH="$pypath"
    run_setup </dev/null
    [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
    python3 - "$SB_HOME/.codex/config.toml" <<'PY' > /dev/null
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
g = d.get("mcp_servers", {}).get("github", {})
assert g.get("url") == "https://api.githubcopilot.com/mcp/", g
assert g.get("bearer_token_env_var") == "GITHUB_PERSONAL_ACCESS_TOKEN", g
assert d.get("owner", {}).get("name") == "andy", "seccion owner perdida"
PY
    rc=$?
    [[ $rc -eq 0 ]] || { ko "merge TOML invalido o seccion perdida"; bad=1; }
    snapshot_tree "$SB_HOME/.codex" "$SB_TMP/cx1.txt"
    run_setup </dev/null
    grep -q "\[up-to-date\]" "$SB_TMP/out.txt" || { ko "re-run TOML sin [up-to-date]"; bad=1; }
    snapshot_tree "$SB_HOME/.codex" "$SB_TMP/cx2.txt"
    diff -q "$SB_TMP/cx1.txt" "$SB_TMP/cx2.txt" >/dev/null || { ko "re-run TOML muto archivos"; bad=1; }
  else
    skip "tomli_w no importable en el host; solo fail-fast estructurado"
  fi
  # tomli-w ausente: shim de python3 que falla en import tomli_w
  add_bin_script python3 '#!/usr/bin/env bash
for a in "$@"; do [[ "$a" == *tomli_w* ]] && { echo "No module named tomli_w" >&2; exit 1; }; done
exec /usr/bin/python3 "$@"'
  before="$(md5sum "$SB_HOME/.codex/config.toml" | cut -d' ' -f1)"
  run_setup </dev/null
  [[ "$(cat "$SB_TMP/exit")" == "2" ]] || { ko "tomli-w ausente: exit $(cat "$SB_TMP/exit") != 2"; bad=1; }
  grep -q "tomli-w" "$SB_TMP/out.txt" || { ko "sin error de tomli-w"; bad=1; }
  after="$(md5sum "$SB_HOME/.codex/config.toml" | cut -d' ' -f1)"
  [[ "$before" == "$after" ]] || { ko "config.toml tocado con tomli-w ausente"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T17 hard deps (F4): curl ausente y docker ausente con TRANSPORT=docker → exit 2 pre-delegacion"
{
  bad=0
  init_sandbox
  minbin="$SB_ROOT/minbin"
  mkdir -p "$minbin"
  ln -sf "$(command -v dirname)" "$minbin/dirname"
  env -i HOME="$SB_HOME" PATH="$minbin" MCP_DEBUG_SYNC_ARGS="$SB_TMP/seam-docker.txt" \
    /usr/bin/bash "$REPO/setup.sh" --check > "$SB_TMP/out-curl.txt" 2>&1
  rc1=$?
  [[ $rc1 -eq 2 ]] || { ko "curl ausente: exit $rc1 != 2"; bad=1; }
  [[ -e "$SB_TMP/seam-docker.txt" ]] && { ko "curl ausente: delego antes de abortar"; bad=1; }
  init_sandbox
  add_env MCP_GITHUB_TRANSPORT=docker
  run_setup --check </dev/null
  [[ "$(cat "$SB_TMP/exit")" == "2" ]] || { ko "docker ausente: exit $(cat "$SB_TMP/exit") != 2"; bad=1; }
  grep -q "requiere docker" "$SB_TMP/out.txt" || { ko "sin error de docker"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 6: gates de salida -----------------------------------

t "T18 gate F9: sync exit 2 omite el paso MCP y propaga exit 2"
{
  bad=0
  init_sandbox; start_fake_api 200
  set_seam_exit 2
  run_setup --check </dev/null
  [[ "$(cat "$SB_TMP/exit")" == "2" ]] || { ko "exit $(cat "$SB_TMP/exit") != 2"; bad=1; }
  grep -q "gate F9" "$SB_TMP/out.txt" || { ko "sin reporte gate F9"; bad=1; }
  grep -q "Paso 5 — MCP" "$SB_TMP/out.txt" && { ko "paso MCP corrio con sync exit 2"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T19 --check + token invalido → exit 1 (drift)"
{
  bad=0
  init_sandbox; start_fake_api 401
  seed_env_file "ghp_DRIFT001"
  run_setup --check </dev/null
  [[ "$(cat "$SB_TMP/exit")" == "1" ]] || { ko "exit $(cat "$SB_TMP/exit") != 1"; bad=1; }
  grep -q "DESYNC" "$SB_TMP/out.txt" || { ko "sin marcador [DESYNC]"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T20 --check + API inalcanzable → degradacion (F5): exit 0, aviso, sin estructural"
{
  bad=0
  init_sandbox
  SB_PORT="$(api_dead_port)"
  seed_env_file "ghp_NETCHECK"
  run_setup --check </dev/null
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0 (degradacion, no estructural)"; bad=1; }
  grep -q "\[aviso\].*fallo de red" "$SB_TMP/out.txt" || { ko "sin aviso de degradacion por red"; bad=1; }
  grep -q "estado estructural" "$SB_TMP/out.txt" && { ko "se reporta estado estructural en degradacion"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T21 regresion sync + excepcion sancionada en README (F7)"
{
  bad=0
  init_sandbox
  # timeout acota un posible stall ambiental del --check (no deberia pasar;
  # si pasa, la verificacion F7 queda pendiente de re-ejecucion manual).
  ( cd "$REPO" && timeout 120 ./sync-skills.sh --check ) > "$SB_TMP/sync-check.txt" 2>&1
  rc=$?
  if [[ $rc -eq 124 ]]; then
    ko "sync-skills.sh --check colgado >120s (stall ambiental); re-ejecutarlo a mano"
    bad=1
  elif [[ $rc -ne 0 ]]; then
    ko "sync-skills.sh --check exit $rc != 0"
    bad=1
  fi
  grep -qi "excepci.n sancionada" "$REPO/README.md" || { ko "README sin excepcion sancionada"; bad=1; }
  grep -q "wiring/mcp.d" "$REPO/README.md" || { ko "README sin referencia a wiring/mcp.d"; bad=1; }
  grep -q "github-mcp.env" "$REPO/AGENTS.md" || { ko "AGENTS.md sin ruta del env file"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# -----------------------------------------------------------------------------

t "T22 env snippets: env.sh (POSIX) + env.fish (fish) 0600, export/set -gx, instruccion de source del shell"
{
  bad=0
  case "$(basename "${SHELL:-}")" in
    fish) rc_expected="config.fish" ;;
    zsh)  rc_expected=".zshrc" ;;
    *)    rc_expected=".bashrc" ;;
  esac
  init_sandbox; start_fake_api 200
  run_setup_pty 45 'Token de GitHub (PAT): =ghp_T22SNIP\n;Cambiar el token antes de continuar? [s/N] =n\n;Runtimes a configurar=\n'
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  s="$SB_HOME/.config/sdd-own/env.sh"
  f="$SB_HOME/.config/sdd-own/env.fish"
  [[ -f "$s" ]] || { ko "env.sh no generado"; bad=1; }
  [[ -f "$f" ]] || { ko "env.fish no generado"; bad=1; }
  [[ "$(stat -c %a "$s")" == "600" ]] || { ko "env.sh mode $(stat -c %a "$s") != 600"; bad=1; }
  [[ "$(stat -c %a "$f")" == "600" ]] || { ko "env.fish mode $(stat -c %a "$f") != 600"; bad=1; }
  grep -q "^export GITHUB_PERSONAL_ACCESS_TOKEN=" "$s" || { ko "env.sh sin export"; bad=1; }
  grep -q "^set -gx GITHUB_PERSONAL_ACCESS_TOKEN " "$f" || { ko "env.fish sin set -gx"; bad=1; }
  grep -q "ghp_T22SNIP" "$s" || { ko "env.sh sin token"; bad=1; }
  grep -q "ghp_T22SNIP" "$f" || { ko "env.fish sin token"; bad=1; }
  out_contains "source" || { ko "sin instruccion de source en la salida"; bad=1; }
  grep -q "$rc_expected" "$SB_TMP/out.txt" || { ko "instruccion no nombra $rc_expected (shell del host)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T23 permisos C2: opencode external_directory objeto con ~/.agent_worktrees/**; idempotente"
{
  bad=0
  init_sandbox; start_fake_api 200
  seed_env_file "ghp_PERM001"
  run_setup </dev/null
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  ocf="$SB_HOME/.config/opencode/opencode.jsonc"
  jq -e '.permission.external_directory["~/.agent_worktrees/**"] == "allow"' "$ocf" >/dev/null 2>&1 \
    || { ko "permission.external_directory sin ~/.agent_worktrees/** = allow (objeto)"; bad=1; }
  jq -e '.mcp.codegraph' "$ocf" >/dev/null 2>&1 || { ko "mcp.codegraph perdido por el patcher de permisos"; bad=1; }
  grep -q "permisos .*agregados" "$SB_TMP/out.txt" || { ko "sin reporte [actualizado] de permisos"; bad=1; }
  m1="$(stat -c %Y "$ocf")"
  sleep 1.1
  run_setup </dev/null
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "re-run exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "permisos .*presentes" "$SB_TMP/out.txt" || { ko "re-run sin reporte de permisos presentes"; bad=1; }
  m2="$(stat -c %Y "$ocf")"
  [[ "$m1" == "$m2" ]] || { ko "re-run reescribio la config (permisos no idempotentes)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T24 selector no interactivo (--check): todos los runtimes, sin prompts"
{
  bad=0
  init_sandbox; start_fake_api 200
  seed_env_file "ghp_SELCHK"
  run_setup --check </dev/null
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "todos los runtimes seleccionados" "$SB_TMP/out.txt" || { ko "sin seleccion automatica de todos en --check"; bad=1; }
  grep -q "Runtimes a configurar (espacio" "$SB_TMP/out.txt" && { ko "selector interactivo mostrado en --check"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T25 selector interactivo (pty): espacio deselecciona opencode; pi se mergea"
{
  bad=0
  init_sandbox; start_fake_api 200
  seed_env_file "ghp_SELPTY"
  run_setup_pty 45 'Conservar el token existente? [k/R] =k\n;Runtimes a configurar= \n'
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "seleccionados: pi" "$SB_TMP/out.txt" || { ko "sin reporte de seleccion final (pi)"; bad=1; }
  grep -q "no seleccionado en el selector" "$SB_TMP/out.txt" || { ko "sin [skip] del runtime deseleccionado"; bad=1; }
  pif="$SB_HOME/.pi/agent/mcp.json"
  [[ -f "$pif" ]] || { ko "pi mcp.json no creado"; bad=1; }
  jq -e '.mcpServers.github' "$pif" >/dev/null 2>&1 || { ko "bloque pi ausente"; bad=1; }
  ocf="$SB_HOME/.config/opencode/opencode.jsonc"
  if jq -e '.mcp.github' "$ocf" >/dev/null 2>&1; then
    ko "opencode mergeado pese a estar deseleccionado"; bad=1
  fi
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T26 worktree MCP contrato: 4 tools, Path.home(), destructive_flow, catalogo cerrado"
{
  bad=0
  src="$REPO/srv/gh-mcp-server/src"
  grep -q "register_worktree_mutation" "$src/tool_handlers/__init__.py" || { ko "familia worktree no registrada"; bad=1; }
  grep -q "git_worktree_add" "$src/tool_handlers/worktree_mutation.py" || { ko "git_worktree_add ausente"; bad=1; }
  grep -q "git_worktree_remove" "$src/tool_handlers/worktree_mutation.py" || { ko "git_worktree_remove ausente"; bad=1; }
  grep -q "git_worktree_acquire" "$src/tool_handlers/worktree_mutation.py" || { ko "git_worktree_acquire ausente"; bad=1; }
  grep -q "git_worktree_release" "$src/tool_handlers/worktree_mutation.py" || { ko "git_worktree_release ausente"; bad=1; }
  grep -q "git_worktree_list" "$src/tool_handlers/local_read.py" || { ko "git_worktree_list ausente en local_read"; bad=1; }
  grep -q "Path.home()" "$src/worktree_state.py" || { ko "resolucion HOME-relative ausente (Path.home() en worktree_state)"; bad=1; }
  grep -q "destructive_flow" "$src/tool_handlers/worktree_mutation.py" || { ko "two-phase destructive_flow no usado en worktree"; bad=1; }
  for et in auth_required repo_not_found network_error not_found not_a_repo dirty_worktree not_safe commit_failed invalid_parameter worktree_exists active_agents owned_by_other locked_unreadable corrupt_worktree; do
    grep -q "$et" "$src/envelope.py" || { ko "catalogo cerrado sin $et"; bad=1; }
  done
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T27 E1 doc-contract: 10 descripciones dos-fases citan ECHO_PROTOCOL; confirm_required nunca err()"
{
  bad=0
  src="$REPO/srv/gh-mcp-server/src"
  n="$(grep -rh '+ ECHO_PROTOCOL' "$src"/tool_handlers/*.py | wc -l)"
  [[ "$n" == "10" ]] || { ko "descripciones con ECHO_PROTOCOL = $n (esperado 10)"; bad=1; }
  hits="$(grep -rn --include='*.py' 'err("confirm_required"\|err('\''confirm_required'\''' "$src" | wc -l)"
  [[ "$hits" == "0" ]] || { ko "confirm_required usado como err() ($hits hits)"; bad=1; }
  grep -q 'confirm_required' "$src/dryrun.py" || { ko "confirm_required ausente en dryrun.py (marker ok)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 7: SDD workflow hardening pins ------------------------

t "T28 contract pins + routing-only: fail-closed, untrusted DATA, 4 tokens, delimited evidence (phase-common)"
{
  bad=0
  # shared-untrusted-data block pins (sobreviven en sdd-phase-common.md)
  grep -q 'fail-closed' "$REPO/overlays/shared/sdd-phase-common.md" || { ko "phase-common: sin fail-closed"; bad=1; }
  grep -q 'untrusted DATA' "$REPO/overlays/shared/sdd-phase-common.md" || { ko "phase-common: sin untrusted DATA"; bad=1; }
  grep -q 'start/finish/verification/rollback' "$REPO/overlays/shared/sdd-phase-common.md" || { ko "phase-common: sin 4 tokens"; bad=1; }
  grep -q 'delimited' "$REPO/overlays/shared/sdd-phase-common.md" || { ko "phase-common: sin delimited"; bad=1; }
  # v3: no hay overlays de skills; la extension es routing-only
  n_over="$(find "$REPO/overlays" -mindepth 2 -type f | wc -l)"
  [[ "$n_over" == "1" ]] || { ko "overlays con $n_over archivos (esperado 1: phase-common)"; bad=1; }
  grep -q 'Unified quest flow' "$REPO/wiring/sdd-own-routing.md" || { ko "routing: sin flujo unificado"; bad=1; }
  grep -q 'binding mandate' "$REPO/wiring/sdd-own-routing.md" || { ko "routing: sin binding mandate"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T29 SWU probe: 4 tokens en tasks archivado + routing solo extiende agent-routing"
{
  bad=0
  # Extract a synthetic SWU block and assert all 4 tokens.
  # Pins the archived change dir (post-archive probe re-point, 2026-09-08).
  tasks_file="$REPO/openspec/changes/archive/2026-09-08-sdd-workflow-hardening/tasks.md"
  [[ -f "$tasks_file" ]] || { ko "T29: tasks archivado no hallado: $tasks_file"; bad=1; }
  swu_block="$(grep -A4 '```sh' "$tasks_file" | head -5)"
  for tok in start finish verification rollback; do
    echo "$swu_block" | grep -q "^${tok}:" || { ko "SWU probe: token $tok ausente en tasks.md"; bad=1; }
  done
  # v3: la aplicacion del contrato SWU se orquesta sin overlays; routing-only.
  grep -q 'routing only' "$REPO/wiring/sdd-own-routing.md" || { ko "routing: sin clausula routing-only"; bad=1; }
  grep -q '100% native gentle-ai' "$REPO/wiring/sdd-own-routing.md" || { ko "routing: sin clausula 100% native"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T30 sync idempotency + id hygiene: zero desyncs post-sync, 0 errors"
{
  bad=0
  # Post-sync state: full sync applied by orchestration. The invariant is now
  # zero desyncs, exit 0, Errores 0 — not the pre-sync 4-desync shape.
  ( cd "$REPO" && timeout 120 ./sync-skills.sh --check --skip-gentleai-sync ) > "$SB_TMP/t30-check.txt" 2>&1
  rc=$?
  [[ $rc -eq 124 ]] && { ko "sync-skills.sh --check colgado >120s (stall ambiental)"; bad=1; }
  # Post-sync invariant: zero DESYNC lines (sync already applied).
  expect_desync="$(grep -c '^\s*\[DESYNC\]' "$SB_TMP/t30-check.txt")"
  [[ "$expect_desync" == "0" ]] || { ko "check desyncs = $expect_desync (esperado 0: full sync applied)"; bad=1; }
  grep -q '\[ERROR\]\s*:\s*0\|Errores\s*:\s*0' "$SB_TMP/t30-check.txt" || { ko "check reporta errores estructurales"; bad=1; }
  [[ "$rc" -eq 0 ]] || { ko "check en estado post-sync exit $rc != 0"; bad=1; }
  # Duplicate id check across all overlay files: a unique id MUST live in
  # exactly one file (its :start/:end marker pair). Count ids that span files.
  # v3: unico overlay superviviente es shared/sdd-phase-common.md (7 ids shared-*).
  dup_count="$(for f in "$REPO"/overlays/shared/*.md; do
    grep -o 'sdd-own:[a-z][a-z-]*' "$f" 2>/dev/null | sort -u
  done | sort | uniq -d | wc -l)"
  [[ "$dup_count" == "0" ]] || { ko "ids duplicados en overlays: $dup_count"; bad=1; }
  n_ids="$(grep -o 'sdd-own:[a-z][a-z-]*' "$REPO/overlays/shared/sdd-phase-common.md" | sort -u | wc -l)"
  [[ "$n_ids" == "7" ]] || { ko "phase-common: $n_ids ids unicos (esperado 7)"; bad=1; }
  # Un solo par de marcadores sdd-own:agent-routing define el splice en sync-skills.sh
  n_markers="$(grep -c 'sdd-own:agent-routing' "$REPO/sync-skills.sh")"
  [[ "$n_markers" == "2" ]] || { ko "sync-skills.sh: marcadores sdd-own:agent-routing = $n_markers (esperado 2)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T31 Paso 3b machinery: sync_routing_extension consume wiring file + splice idempotente"
{
  bad=0
  ss="$REPO/sync-skills.sh"
  # La funcion Paso 3b existe y consume el contrato de routing
  grep -q 'sync_routing_extension()' "$ss" || { ko "Paso 3b: sin funcion sync_routing_extension"; bad=1; }
  grep -q 'sdd-own-routing.md' "$ss" || { ko "Paso 3b: sin wiring/sdd-own-routing.md"; bad=1; }
  # Marcadores python del splice con el contrato exacto (start/end sdd-own dentro
  # de la seccion agent-routing; PLAIN y ESC para detectar el formato almacenado)
  grep -qF 'PLAIN_START = "<!-- gentle-ai:agent-routing -->"' "$ss" || { ko "Paso 3b: sin PLAIN_START"; bad=1; }
  grep -qF 'PLAIN_END   = "<!-- /gentle-ai:agent-routing -->"' "$ss" || { ko "Paso 3b: sin PLAIN_END"; bad=1; }
  grep -qF 'SDD_START   = "<!-- sdd-own:agent-routing:start -->"' "$ss" || { ko "Paso 3b: sin SDD_START"; bad=1; }
  grep -qF 'SDD_END     = "<!-- sdd-own:agent-routing:end -->"' "$ss" || { ko "Paso 3b: sin SDD_END"; bad=1; }
  grep -q 'python3 - "\$target" "\$file" "\$CHECK_MODE" "\$DRY_RUN"' "$ss" || { ko "Paso 3b: sin splice python con CHECK/DRY"; bad=1; }
  # Live idempotencia: el config real del orquestador porta EXACTAMENTE un par
  # sdd-own:agent-routing dentro de su seccion gentile-ai:agent-routing (el resto
  # del prompt es 100% Alan; la secuencia completa la valida T31b).
  ocf="${OPENCODE_CONFIG:-$REAL_HOME/.config/opencode/opencode.jsonc}"
  [[ -f "$ocf" ]] || ocf="${OPENCODE_CONFIG:-$REAL_HOME/.config/opencode/opencode.json}"
  pout="$(jq -r '.agent["gentle-orchestrator"].prompt // empty' "$ocf" 2>/dev/null)"
  [[ -n "$pout" ]] || { ko "T31: prompt del orquestador no legible en $ocf"; bad=1; }
  res="$(printf '%s' "$pout" | python3 -c '
import sys
p = sys.stdin.read()
i = p.find("<!-- gentle-ai:agent-routing -->")
j = p.find("<!-- /gentle-ai:agent-routing -->", i)
if i < 0 or j < 0:
    sys.exit(2)
sec = p[i:j]
print(sec.count("sdd-own:agent-routing"))
')"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    ko "T31: seccion agent-routing ausente en config real (exit $rc)"
    bad=1
  elif [[ "$res" != "2" ]]; then
    ko "T31: pares sdd-own en seccion agent-routing = $res (esperado 2: 1 par)"; bad=1
  fi
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T32 poda council/gates: allow-list sin council ni hard gates; skills/overlays podadas"
{
  bad=0
  w="$REPO/wiring/opencode.sdd.json"
  # D15 (v3 U1): el allow-list del orquestador EXCLUYE council y toda la machinery
  # podada (hard gates, pre-experience); los 3 agentes propios SI estan.
  for a in sdd-council sdd-hard-gate sdd-hard-verify sdd-pre-experience; do
    jq -e --arg a "$a" '.agent["gentle-orchestrator"].permission.task[$a] == null' "$w" >/dev/null 2>&1 || { ko "allow-list permite $a"; bad=1; }
  done
  for a in sdd-architecture-plan sdd-architecture-lint sdd-rfc-author; do
    jq -e --arg a "$a" '.agent["gentle-orchestrator"].permission.task[$a] == "allow"' "$w" >/dev/null 2>&1 || { ko "allow-list no permite $a"; bad=1; }
  done
  # Directories podados: skills/overlays de la era v2 ya no existen
  for s in sdd-quest sdd-council sdd-changelog; do
    [[ -e "$REPO/skills/$s" ]] && { ko "skills/$s no podada"; bad=1; }
  done
  # overlays/skills y overlays/commands pueden quedar como dirs vacios (git
  # conserva el arbol); lo que no puede sobrevivir es NINGUN archivo adentro.
  n_sk="$(find "$REPO/overlays/skills" -type f 2>/dev/null | wc -l)"
  [[ "$n_sk" == "0" ]] || { ko "overlays/skills con $n_sk archivos (poda U1)"; bad=1; }
  n_cm="$(find "$REPO/overlays/commands" -type f 2>/dev/null | wc -l)"
  [[ "$n_cm" == "0" ]] || { ko "overlays/commands con $n_cm archivos (poda U1)"; bad=1; }
  # El routing extension no menciona council ni machinery podada
  n="$(grep -ciE 'council|hard.gate|pre.experience' "$REPO/wiring/sdd-own-routing.md")"
  [[ "$n" == "0" ]] || { ko "routing con $n menciones de machinery podada"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T33 fragment wiring v3: orquestador solo permission; subagent_depth 2; sin __managed_by"
{
  bad=0
  w="$REPO/wiring/opencode.sdd.json"
  # D8 (v3 U1): el fragment NO porta prompt del orquestador — la fuente canónica
  # del contrato es el prompt inline de Alan en el config real; el fragment
  # SOLO agrega la llave permission del orquestador.
  jq -e '(.agent["gentle-orchestrator"] | keys) == ["permission"]' "$w" >/dev/null 2>&1 || { ko "orchestrator fragment con mas que permission"; bad=1; }
  jq -e '.agent["gentle-orchestrator"].permission.question == "allow"' "$w" >/dev/null 2>&1 || { ko "orchestrator question != allow"; bad=1; }
  # subagent_depth top-level (R1) habilita el encadenamiento profundo
  jq -e '.subagent_depth == 2' "$w" >/dev/null 2>&1 || { ko "subagent_depth != 2"; bad=1; }
  # Los 3 agentes propios: hidden subagents, sin __managed_by, permission vacio (deny por default)
  for a in sdd-architecture-plan sdd-architecture-lint sdd-rfc-author; do
    jq -e --arg a "$a" '.agent[$a].mode == "subagent" and .agent[$a].hidden == true' "$w" >/dev/null 2>&1 || { ko "$a no es subagent hidden"; bad=1; }
    jq -e --arg a "$a" '(.agent[$a].permission | length) == 0' "$w" >/dev/null 2>&1 || { ko "$a con permission no vacio"; bad=1; }
    jq -e --arg a "$a" '.agent[$a] | has("__managed_by") | not' "$w" >/dev/null 2>&1 || { ko "$a con __managed_by"; bad=1; }
  done
  # arch-plan y rfc-author: prompts file-based apuntando a wiring/prompts/sdd
  jq -e '.agent["sdd-architecture-plan"].prompt == "{file:./prompts/sdd/sdd-architecture-plan.md}"' "$w" >/dev/null 2>&1 || { ko "arch-plan sin prompt file-based"; bad=1; }
  jq -e '.agent["sdd-rfc-author"].prompt == "{file:./prompts/sdd/sdd-rfc-author.md}"' "$w" >/dev/null 2>&1 || { ko "rfc-author sin prompt file-based"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T34 OWN_PROMPTS exacto: 2 prompts instalables (rfc-author + arch-plan), deploy loop, delegate_only"
{
  bad=0
  grep -q 'OWN_PROMPTS=(sdd-rfc-author.md sdd-architecture-plan.md)' "$REPO/sync-skills.sh" || { ko "OWN_PROMPTS no es (rfc-author, arch-plan)"; bad=1; }
  for f in sdd-rfc-author.md sdd-architecture-plan.md; do
    [[ -f "$REPO/wiring/prompts/sdd/$f" ]] || { ko "wiring/prompts/sdd/$f ausente"; bad=1; }
  done
  grep -qF 'for pf in "${OWN_PROMPTS[@]}"' "$REPO/sync-skills.sh" || { ko "sync-skills.sh sin deploy loop de OWN_PROMPTS"; bad=1; }
  # Los prompts file-based de los 2 agentes propios definen el rol sub-agent:
  # el orquestador los llama como sub-agentes, no como skills full-install.
  grep -q 'You are the `sdd-rfc-author` sub-agent' "$REPO/wiring/prompts/sdd/sdd-rfc-author.md" || { ko "rfc-author sin rol sub-agent"; bad=1; }
  grep -q 'You are the dedicated `sdd-architecture-plan` SDD sub-agent' "$REPO/wiring/prompts/sdd/sdd-architecture-plan.md" || { ko "arch-plan sin rol sub-agent"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T35 acta fail-closed POST-apply: arch-plan.md MANDATORY, title-by-title, N/A solo trivial"
{
  bad=0
  al="$REPO/skills/sdd-architecture-lint/SKILL.md"
  # D9 (v3 U1): axis 2 corre POST-apply contra el acta arch-plan.md; acta
  # ausente → fail-closed; el lint nunca corre pre-apply.
  grep -q 'post-apply' "$al" || { ko "arch-lint sin post-apply"; bad=1; }
  grep -q 'POST-apply' "$al" || { ko "arch-lint sin POST-apply (axis 2)"; bad=1; }
  grep -q 'arch-plan.md' "$al" || { ko "arch-lint sin acta arch-plan.md"; bad=1; }
  grep -q 'MANDATORY input' "$al" || { ko "arch-lint sin acta MANDATORY"; bad=1; }
  grep -q 'FAILS CLOSED' "$al" || { ko "arch-lint sin fail-closed"; bad=1; }
  grep -q 'title-by-title' "$al" || { ko "arch-lint sin title-by-title"; bad=1; }
  grep -q 'empty or trivial design' "$al" || { ko "arch-lint sin N/A-trivial"; bad=1; }
  # delegate_only: el lint corre como sub-agente del orquestador (ALWAYS hook)
  grep -q '^  delegate_only: true' "$al" || { ko "arch-lint sin delegate_only"; bad=1; }
  # axis 3 strings (presentes tras el axis-3 rework)
  grep -q 'Axis 3' "$al" || { ko "arch-lint sin Axis 3 section"; bad=1; }
  grep -qF 'axis_3 pass' "$al" || { ko "arch-lint sin axis_3 verdict form"; bad=1; }
  grep -qF 'axis_3 fail' "$al" || { ko "arch-lint sin axis_3 fail verdict"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T36 quest gates (2 ramas): product-quest y arch-quest skills existen con delegate_only + permisos"
{
  bad=0
  # Las 2 skills de quest viven como full-install con delegate_only: el
  # orquestador las dispara como sub-agentes (nunca autoconsulta).
  for sq in sdd-product-quest sdd-architecture-quest; do
    [[ -f "$REPO/skills/$sq/SKILL.md" ]] || { ko "skills/$sq/SKILL.md ausente"; bad=1; }
    grep -q '^  delegate_only: true' "$REPO/skills/$sq/SKILL.md" || { ko "$sq sin delegate_only"; bad=1; }
  done
  # Product Quest: hard budget 50 y un RFC gate explicito
  grep -q 'Product Quest = **50**' "$REPO/skills/sdd-product-quest/SKILL.md" || { ko "product-quest: sin budget 50"; bad=1; }
  grep -q 'One explicit RFC gate' "$REPO/skills/sdd-product-quest/SKILL.md" || { ko "product-quest: sin RFC gate"; bad=1; }
  # Architecture Quest: hard budget 20 y su propio RFC gate
  grep -q 'Architecture Quest = **20**' "$REPO/skills/sdd-architecture-quest/SKILL.md" || { ko "arch-quest: sin budget 20"; bad=1; }
  grep -q 'One explicit RFC gate' "$REPO/skills/sdd-architecture-quest/SKILL.md" || { ko "arch-quest: sin RFC gate"; bad=1; }
  # Ambos gates SIEMPRE con intervencion humana (nunca auto-approve)
  n1="$(grep -c 'never auto-approve\|NEVER auto-approve' "$REPO/skills/sdd-product-quest/SKILL.md")"
  n2="$(grep -c 'never auto-approve\|NEVER auto-approve' "$REPO/skills/sdd-architecture-quest/SKILL.md")"
  [[ $((n1 + n2)) -ge 2 ]] || { ko "quests sin clausulas never auto-approve (n=$((n1 + n2)))"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T37 fragment SDD-only: sin mcp ni runtimes; keys sancionadas; default_agent preservado"
{
  bad=0
  w="$REPO/wiring/opencode.sdd.json"
  jq -e 'has("mcp") | not' "$w" >/dev/null 2>&1 || { ko "fragment con mcp (viola R1)"; bad=1; }
  for k in providers permission share model; do
    jq -e --arg k "$k" 'has($k) | not' "$w" >/dev/null 2>&1 || { ko "fragment con llave $k"; bad=1; }
  done
  jq -e 'keys | sort == ["$schema","agent","default_agent","subagent_depth"]' "$w" >/dev/null 2>&1 || { ko "keys del fragment no sancionadas"; bad=1; }
  jq -e '.default_agent | type == "string"' "$w" >/dev/null 2>&1 || { ko "default_agent perdido"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T38 subagent_depth: 2 en fragment y en config instalado (jsonc-first)"
{
  bad=0
  jq -e '.subagent_depth == 2' "$REPO/wiring/opencode.sdd.json" >/dev/null 2>&1 || { ko "fragment sin subagent_depth==2"; bad=1; }
  ocf="$HOME/.config/opencode/opencode.jsonc"
  [[ -f "$ocf" ]] || ocf="$HOME/.config/opencode/opencode.json"
  [[ -f "$ocf" ]] || { ko "config instalado no hallado ($ocf)"; bad=1; }
  jq -e '.subagent_depth == 2' "$ocf" >/dev/null 2>&1 || { ko "config instalado sin subagent_depth==2 (pre-sync esperado)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T39 merge extendido en ambos motores: --check zero desyncs con jq y con python forzado"
{
  bad=0
  # Leg 1: engine jq (normal).
  ( cd "$REPO" && timeout 120 ./sync-skills.sh --check --skip-gentleai-sync ) > "$SB_TMP/t39-jq.txt" 2>&1
  rc=$?
  [[ $rc -eq 124 ]] && { ko "leg jq colgado >120s"; bad=1; }
  d="$(grep -c '^\s*\[DESYNC\]' "$SB_TMP/t39-jq.txt")"
  [[ "$d" == "0" ]] || { ko "leg jq desyncs = $d (esperado 0)"; bad=1; }
  grep -q '\[ERROR\]\s*:\s*0\|Errores\s*:\s*0' "$SB_TMP/t39-jq.txt" || { ko "leg jq errores estructurales"; bad=1; }

  # Leg 2: engine python forzado — ocultar jq de PATH con un shim del dir completo.
  jq_holders=()
  while IFS= read -r e; do
    [[ -n "$e" && -x "$e/jq" ]] && jq_holders+=("$e")
  done < <(printf '%s' "$PATH" | tr ':' '\n')
  shim="$SB_TMP/nojq"
  mkdir -p "$shim"
  for b in bash sh cat cp ln mkdir sed sort uniq diff dirname perl python3 python mktemp chmod touch wc tr date readlink realpath basename grep head tail awk sha256sum env timeout nice find rm; do
    p="$(PATH="/usr/bin:/bin" command -v "$b" 2>/dev/null)" || p="$(command -v "$b" 2>/dev/null)"
    [[ -n "$p" ]] && ln -sf "$p" "$shim/$b"
  done
  clean_path=""
  while IFS= read -r e; do
    skip=0
    for h in "${jq_holders[@]}"; do [[ "$e" == "$h" ]] && skip=1; done
    [[ -n "$e" && $skip -eq 0 ]] && clean_path="${clean_path:+$clean_path:}$e"
  done < <(printf '%s' "$PATH" | tr ':' '\n')
  nojq_env="PATH=$shim:$clean_path"
  if env "$nojq_env" bash -c 'command -v jq' >/dev/null 2>&1; then
    ko "shim no oculto jq (command -v jq sigue resolviendo)"; bad=1
  fi
  ( cd "$REPO" && env "$nojq_env" timeout 120 ./sync-skills.sh --check --skip-gentleai-sync ) > "$SB_TMP/t39-py.txt" 2>&1
  rc=$?
  [[ $rc -eq 124 ]] && { ko "leg python colgado >120s"; bad=1; }
  d="$(grep -c '^\s*\[DESYNC\]' "$SB_TMP/t39-py.txt")"
  [[ "$d" == "0" ]] || { ko "leg python desyncs = $d (esperado 0)"; bad=1; }
  grep -q '\[ERROR\]\s*:\s*0\|Errores\s*:\s*0' "$SB_TMP/t39-py.txt" || { ko "leg python errores estructurales"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo sdd-tool: T40–T48 ----------------------------------------
# (El warm build de sdd-tool vive al inicio del suite, antes de los sandboxes:
# calienta GOMODCACHE/GOCACHE del host para que el 5d-2 de setup.sh en los
# sandboxes no descargue modulos ni compile desde cero.)

t "T40 sdd-tool one-parse (scanner lazy)"
if [[ $_sdd_tool_built -eq 1 ]]; then
  bad=0
  init_sandbox
  cp "$_sdd_build_tmp/sdd-tool" "$SB_BIN/sdd-tool"
  # --help exits 0 and prints subcommands; verify no panic and no extra output
  out="$(env HOME="$SB_HOME" PATH="$SB_BIN:$PATH" timeout 10 "$SB_BIN/sdd-tool" --help 2>&1)"
  rc=$?
  [[ $rc -eq 0 ]] || { ko "sdd-tool --help exit $rc != 0"; bad=1; }
  echo "$out" | grep -q "worktree" || { ko "sdd-tool --help missing worktree subcommand"; bad=1; }
  echo "$out" | grep -q "retro"   || { ko "sdd-tool --help missing retro subcommand";   bad=1; }
  echo "$out" | grep -q "bug"     || { ko "sdd-tool --help missing bug subcommand";     bad=1; }
  echo "$out" | grep -q "dashboard"|| { ko "sdd-tool --help missing dashboard subcommand"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
else
  skip "sdd-tool binario no construido (go ausente o build fallo)"
fi

t "T41 sdd-tool retro fallback+dedupe (none store)"
if [[ $_sdd_tool_built -eq 1 ]]; then
  bad=0
  init_sandbox
  cp "$_sdd_build_tmp/sdd-tool" "$SB_BIN/sdd-tool"
  out="$(env HOME="$SB_HOME" PATH="$SB_BIN:$PATH" timeout 10 "$SB_BIN/sdd-tool" retro lookup --change test-x 2>&1)"
  rc=$?
  [[ $rc -eq 0 ]] || { ko "retro lookup exit $rc != 0"; bad=1; }
  # none store returns empty precisely, no crash
  echo "$out" | grep -qi "error\|panic\|exception" && { ko "retro lookup returned error on empty store"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
else
  skip "sdd-tool binario no construido"
fi

t "T42 sdd-tool title retrievability (engram title-key filter)"
if [[ $_sdd_tool_built -eq 1 ]]; then
  bad=0
  # Unit-level proof: engram title filter only returns sdd/*/retrospective entries.
  # Build the binary and run retro lookup which exercises the engram search →
  # title-prefix filter path (even when engram CLI is absent, the adapter
  # returns gracefully).
  init_sandbox
  cp "$_sdd_build_tmp/sdd-tool" "$SB_BIN/sdd-tool"
  out="$(env HOME="$SB_HOME" PATH="$SB_BIN:$PATH" timeout 10 "$SB_BIN/sdd-tool" retro lookup --mode engram --change test-x 2>&1)"
  rc=$?
  # engram CLI absent → lookup returns 0 with empty result (fail-open read)
  [[ $rc -eq 0 ]] || { ko "retro lookup (engram mode) exit $rc != 0"; bad=1; }
  # Verify the binary was compiled with the title filter path (integration:
  # go test covers parseSearchOutput + title prefix logic). go.mod vive en
  # srv/sdd-tool/ — correr desde el module root, no del root del repo.
  ( cd "$SDD_TOOL_BIN" && go test ./internal/engram/... 2>/dev/null ) || { ko "engram unit tests (title filter) failed"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
else
  skip "sdd-tool binario no construido"
fi

t "T42b sdd-tool worktree list (empty — no agent_worktrees)"
if [[ $_sdd_tool_built -eq 1 ]]; then
  bad=0
  init_sandbox
  cp "$_sdd_build_tmp/sdd-tool" "$SB_BIN/sdd-tool"
  out="$(env HOME="$SB_HOME" PATH="$SB_BIN:$PATH" timeout 10 "$SB_BIN/sdd-tool" worktree list 2>&1)"
  rc=$?
  [[ $rc -eq 0 ]] || { ko "worktree list exit $rc != 0"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
else
  skip "sdd-tool binario no construido"
fi

t "T43 sdd-tool worktree verify (3 signals — main branch)"
if [[ $_sdd_tool_built -eq 1 ]]; then
  bad=0
  init_sandbox
  cp "$_sdd_build_tmp/sdd-tool" "$SB_BIN/sdd-tool"
  # Stub gentle-ai (scanner signal 3): sin el stub el sandbox no tiene
  # gentle-ai, el scanner falla y verify aborta en "FAIL-OPEN: scanner parse
  # failed (signal 3)" sin emitir la linea de branch — el test quedaria
  # rojo pese a que la senal de branch es la que se quiere ejercitar.
  printf '#!/usr/bin/env bash\nprintf '\''{"artifactStore":"openspec","changes":[]}'\''\n' > "$SB_BIN/gentle-ai"
  chmod +x "$SB_BIN/gentle-ai"
  out="$(env HOME="$SB_HOME" PATH="$SB_BIN:$PATH" timeout 10 "$SB_BIN/sdd-tool" worktree verify --change test-x 2>&1)"
  rc=$?
  # On main (not in a worktree), verify should exit non-zero (branch signal fails)
  [[ $rc -ne 0 ]] || { ko "worktree verify on main: exit 0 expected non-zero (no worktree)"; bad=1; }
  # Case-insensitive: el binario emite "Branch:" (B mayuscula) — un grep
  # "branch\|BRANCH" sensible a mayusculas jamas matchea "Branch:".
  echo "$out" | grep -qi "branch" || { ko "worktree verify: missing branch signal"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
else
  skip "sdd-tool binario no construido"
fi

t "T44 sdd-tool bug record→resolve→list (incidents lifecycle)"
if [[ $_sdd_tool_built -eq 1 ]]; then
  bad=0
  init_sandbox
  cp "$_sdd_build_tmp/sdd-tool" "$SB_BIN/sdd-tool"
  export HOME="$SB_HOME"
  export PATH="$SB_BIN:$PATH"
  # Record
  rec_out="$(timeout 10 "$SB_BIN/sdd-tool" bug record --summary "test blocker: failing build" --kind blocker --change test-x 2>&1)"
  rec_rc=$?
  [[ $rec_rc -eq 0 ]] || { ko "bug record exit $rec_rc != 0"; bad=1; }
  # List (should show the incident)
  list_out="$(timeout 10 "$SB_BIN/sdd-tool" bug list 2>&1)"
  list_rc=$?
  [[ $list_rc -eq 0 ]] || { ko "bug list exit $list_rc != 0"; bad=1; }
  echo "$list_out" | grep -q "test-x\|blocker" || { ko "bug list: incident not found in output"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
else
  skip "sdd-tool binario no construido"
fi

t "T45 sdd-tool --json (scanner passthrough, no TUI)"
if [[ $_sdd_tool_built -eq 1 ]]; then
  bad=0
  init_sandbox
  cp "$_sdd_build_tmp/sdd-tool" "$SB_BIN/sdd-tool"
  out="$(env HOME="$SB_HOME" PATH="$SB_BIN:$PATH" timeout 10 "$SB_BIN/sdd-tool" dashboard --json 2>&1)"
  rc=$?
  # --json should exit non-zero (no gentle-ai binary) but print JSON schema hint, not crash
  echo "$out" | grep -qi "panic\|exception" && { ko "dashboard --json panicked"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
else
  skip "sdd-tool binario no construido"
fi

t "T46 sdd-tool read fail-open (absent scanner, no crash)"
if [[ $_sdd_tool_built -eq 1 ]]; then
  bad=0
  init_sandbox
  cp "$_sdd_build_tmp/sdd-tool" "$SB_BIN/sdd-tool"
  # Run without gentle-ai in PATH → scanner fails, should exit non-zero but not panic
  out="$(env HOME="$SB_HOME" PATH="$SB_BIN:$PATH" timeout 10 "$SB_BIN/sdd-tool" worktree list --json 2>&1)"
  rc=$?
  echo "$out" | grep -qi "panic\|exception\|fatal" && { ko "worktree list --json panicked on absent scanner"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
else
  skip "sdd-tool binario no construido"
fi

t "T47 sdd-tool write FAIL-OPEN (bug record exits non-zero with marker when DB unusable)"
if [[ $_sdd_tool_built -eq 1 ]]; then
  bad=0
  init_sandbox
  cp "$_sdd_build_tmp/sdd-tool" "$SB_BIN/sdd-tool"
  # Make the DB path unusable: put a regular file where the incidents.db
  # directory tree should be, so MkdirAll fails.
  unsafedir="$SB_HOME/.config/sdd-own/srv/sdd-tool"
  mkdir -p "$(dirname "$unsafedir")"
  rm -rf "$unsafedir"
  echo "not-a-directory" > "$unsafedir"
  out="$(env HOME="$SB_HOME" PATH="$SB_BIN:$PATH" timeout 10 "$SB_BIN/sdd-tool" bug record --change test-x --summary "should fail" --kind blocker 2>&1)"
  rc=$?
  # D2: write failure must be loud FAIL-OPEN, never silent success
  [[ $rc -ne 0 ]] || { ko "bug record: exit 0 on unusable DB (should fail loudly)"; bad=1; }
  echo "$out" | grep -qi "FAIL-OPEN" || { ko "bug record: missing FAIL-OPEN marker on write failure"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
else
  skip "sdd-tool binario no construido"
fi

t "T47b setup.sh 5d-2 warn (no Go → warn, no error)"
{
  bad=0
  init_sandbox
  # Create a minimal fake Go that always fails (used only if real mode reaches 5d-2)
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_BIN/go"
  chmod +x "$SB_BIN/go"
  # Route through the sandbox seam (MCP_DEBUG_SYNC_ARGS, igual que los tests
  # hermanos via run_setup): el sync-skills.sh REAL no debe correr dentro del
  # sandbox vacio (gate F9 → exit 2). Con el seam, 5d-2 se evalua en --check:
  # binario ausente → "pendiente", warn-only, exit 0.
  run_setup --check --skip-gentleai-sync
  rc="$(cat "$SB_TMP/exit")"
  # In --check mode, missing binary → "pendiente" message; warn/error only in real mode
  grep -qi "sdd-tool\|pendiente\|WARN\|go no encontrado" "$SB_TMP/out.txt" || { ko "setup.sh 5d-2: missing sdd-tool check message"; bad=1; }
  # --check should not hard-fail due to missing go: 0 = clean, 1 = drift;
  # 2 (gate F9) must never fire from a stub sync.
  if [[ "$rc" -le 1 ]]; then
    : # acceptable (0 = clean, 1 = drift detected elsewhere)
  else
    ko "setup.sh 5d-2: exit $rc (expected ≤1 for warn-only check)"
    bad=1
  fi
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T48 poda prompts/skills: wiring/prompts/sdd con EXACTAMENTE 2 prompts; skills changelog/quest/council ausentes"
{
  bad=0
  # v3 (poda total): los unicos prompts propios son rfc-author + arch-plan.
  n_prompts="$(ls "$REPO/wiring/prompts/sdd/"*.md 2>/dev/null | wc -l)"
  [[ "$n_prompts" == "2" ]] || { ko "wiring/prompts/sdd con $n_prompts prompts (esperado 2)"; bad=1; }
  for f in sdd-rfc-author.md sdd-architecture-plan.md; do
    [[ -f "$REPO/wiring/prompts/sdd/$f" ]] || { ko "wiring/prompts/sdd/$f ausente"; bad=1; }
  done
  # Skills podadas de la era U1/U2 no existen
  for s in sdd-changelog sdd-quest sdd-council; do
    [[ -e "$REPO/skills/$s" ]] && { ko "skills/$s no podada"; bad=1; }
  done
  # El cierre de changelog quedo fuera del pipeline v3 (sin orchestrator propio)
  n="$(grep -rilE 'changelog' "$REPO/wiring" 2>/dev/null | wc -l)"
  [[ "$n" == "0" ]] || { ko "wiring con $n referencias a changelog"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T49 rfc-author prompt-defined: file-based en fragment, nunca skill target, branch-parametric"
{
  bad=0
  w="$REPO/wiring/opencode.sdd.json"
  # Q40 (v3): rfc-author y arch-plan son agentes prompt-defined ({file:...}),
  # NO skills full-install; el fragment apunta a wiring/prompts/sdd.
  jq -e '.agent["sdd-rfc-author"].prompt == "{file:./prompts/sdd/sdd-rfc-author.md}"' "$w" >/dev/null 2>&1 || { ko "rfc-author sin prompt file-based"; bad=1; }
  jq -e '.agent["sdd-architecture-plan"].prompt == "{file:./prompts/sdd/sdd-architecture-plan.md}"' "$w" >/dev/null 2>&1 || { ko "arch-plan sin prompt file-based"; bad=1; }
  [[ -e "$REPO/skills/sdd-rfc-author" ]] && { ko "skills/sdd-rfc-author existe (debe ser prompt)"; bad=1; }
  ra="$REPO/wiring/prompts/sdd/sdd-rfc-author.md"
  grep -q 'branch-parametric' "$ra" || { ko "rfc-author: sin branch-parametric"; bad=1; }
  grep -q 'You NEVER interview the human' "$ra" || { ko "rfc-author: sin never-interview"; bad=1; }
  grep -q 'NEVER assemble both' "$ra" || { ko "rfc-author: sin never-assemble-both"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T50 quest split 50/20 + 2 gates: skills dedicadas con budgets, RFC gates y reopens-only-branch"
{
  bad=0
  pq="$REPO/skills/sdd-product-quest/SKILL.md"
  aq="$REPO/skills/sdd-architecture-quest/SKILL.md"
  # Product Quest: budget 50 + RFC gate + reopen solo rama product
  grep -q 'Product Quest = \*\*50\*\*' "$pq" || { ko "product-quest: sin budget 50"; bad=1; }
  grep -q 'One explicit RFC gate' "$pq" || { ko "product-quest: sin RFC gate"; bad=1; }
  grep -q 'reopens ONLY the product branch' "$pq" || { ko "product-quest: sin reopen-only-product"; bad=1; }
  # Architecture Quest: budget 20 + RFC gate + reopen solo rama architecture
  grep -q 'Architecture Quest = \*\*20\*\*' "$aq" || { ko "arch-quest: sin budget 20"; bad=1; }
  grep -q 'One explicit RFC gate' "$aq" || { ko "arch-quest: sin RFC gate"; bad=1; }
  grep -q 'reopens ONLY the architecture branch' "$aq" || { ko "arch-quest: sin reopen-only-arch"; bad=1; }
  # rfc-author: nunca entrevista al human ni ensambla ambos RFCs (branch-parametric)
  ra="$REPO/wiring/prompts/sdd/sdd-rfc-author.md"
  grep -Fq 'product-rfc.md` OR `arch-rfc.md' "$ra" || { ko "rfc-author: sin dual-artifact OR"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T51 routing lean: sin PR/merge/MCP en el routing extension; clausula 100% native"
{
  bad=0
  rt="$REPO/wiring/sdd-own-routing.md"
  # El routing NO replica machinery de repo (PR/merge/MCP): eso es del core.
  n="$(grep -cE 'draft PR|merge ALWAYS human|MCP surfaces|gh-git-mcp|nextRecommended' "$rt")"
  [[ "$n" == "0" ]] || { ko "routing no-lean: $n menciones de PR/merge/MCP"; bad=1; }
  grep -q '100% native gentle-ai (ODD/SDD)' "$rt" || { ko "routing: sin clausula 100% native"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T52 machinery podado ausente: sin sdd-attempt/hard-gate/pre-experience en routing ni skills; lint ALWAYS"
{
  bad=0
  rt="$REPO/wiring/sdd-own-routing.md"
  # La machinery U1/U2 (ledger, hard gates, pre-experience) no dejo rastro
  n="$(grep -ciE 'sdd-attempt|hard.gate|hard.verify|pre.experience' "$rt")"
  [[ "$n" == "0" ]] || { ko "routing con $n menciones de machinery podada"; bad=1; }
  # El unico hook post-apply es el lint ALWAYS (segunda mirada antes de verify/archive)
  grep -q 'sdd-architecture-lint always runs as the independent' "$rt" || { ko "routing: sin lint ALWAYS"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T53 Paso 3b en sync: orden 3 < 3b < 4 + salteado --skip-opencode + exit contract 0/1/2"
{
  bad=0
  ss="$REPO/sync-skills.sh"
  # Orden estructural: Paso 3 (merge opencode) < Paso 3b (routing) < Paso 4 (registries)
  i3="$(grep -n '^# --- Paso 3:' "$ss" | head -1 | cut -d: -f1)"
  i3b="$(grep -n 'sync_routing_extension()' "$ss" | head -1 | cut -d: -f1)"
  i4="$(grep -n '^# --- Paso 4:' "$ss" | head -1 | cut -d: -f1)"
  [[ -n "$i3" && -n "$i3b" && -n "$i4" ]] || { ko "Paso 3b: encabezados no hallados"; bad=1; }
  [[ "$i3" -lt "$i3b" && "$i3b" -lt "$i4" ]] || { ko "Paso 3b desordenado ($i3 < $i3b < $i4)"; bad=1; }
  # El skip-opencode saltea tambien el routing extension
  grep -q '\[salteado\]   routing extension (--skip-opencode)' "$ss" || { ko "Paso 3b: sin salteado --skip-opencode"; bad=1; }
  # Exit contract documentado: 0 = up-to-date, 1 = pendiente/DESYNC/actualizado, 2 = estructura
  grep -q '0 = up-to-date' "$ss" || { ko "Paso 3b: sin exit 0 contract"; bad=1; }
  grep -q '2 = error de estructura/configuración' "$ss" || { ko "Paso 3b: sin exit 2 contract"; bad=1; }
  # La funcion consume wiring/sdd-own-routing.md
  grep -q 'sdd-own-routing.md' "$ss" || { ko "Paso 3b: no consume wiring/sdd-own-routing.md"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T54 arch-plan acta + user gate: post-spec pre-design, resolvable, fail-closed, user gate"
{
  bad=0
  ap="$REPO/wiring/prompts/sdd/sdd-architecture-plan.md"
  grep -q 'binding architecture plan acta' "$ap" || { ko "arch-plan: sin acta binding"; bad=1; }
  grep -q 'titled decisions' "$ap" || { ko "arch-plan: sin titled decisions"; bad=1; }
  grep -q 'resolvable against the inputs' "$ap" || { ko "arch-plan: sin resolvable"; bad=1; }
  grep -q 'fail-closed' "$ap" || { ko "arch-plan: sin fail-closed"; bad=1; }
  grep -q 'Design MUST NOT start until the user approves your plan' "$ap" || { ko "arch-plan: sin user gate"; bad=1; }
  # El routing encadena arch-rfc aprobado -> arquitectura-plan (acta binding)
  grep -q 'An approved arch-rfc.md precedes sdd-architecture-plan' "$REPO/wiring/sdd-own-routing.md" || { ko "routing: sin cadena arch-rfc->plan"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T55 arch-quest ODD triggers: mandato = approved Product RFC; budget 20; STOP/blocked sin mandato"
{
  bad=0
  aq="$REPO/skills/sdd-architecture-quest/SKILL.md"
  # El arch-quest arranca del Product RFC aprobado (mandato vinculante)
  grep -q 'approved Product RFC' "$aq" || { ko "arch-quest: sin mandato approved Product RFC"; bad=1; }
  grep -q 'Architecture Quest = **20**' "$aq" || { ko "arch-quest: sin budget 20"; bad=1; }
  grep -q 'STOP and report' "$aq" || { ko "arch-quest: sin STOP/report"; bad=1; }
  # En el routing: la rama de arquitectura exige design ahead o incertidumbre arq
  grep -q 'substantial with' "$REPO/wiring/sdd-own-routing.md" || { ko "routing: sin condicion de incertidumbre"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T55 poda hard-gate era: wiring/prompts/sdd sin hard-gate/hard-verify/pre-experience; fragment sin agentes gates"
{
  bad=0
  # U1/U2 podado: los prompts de hard gates/verify/pre-experience no existen
  for f in sdd-hard-gate.md sdd-hard-verify.md sdd-pre-experience.md; do
    [[ -e "$REPO/wiring/prompts/sdd/$f" ]] && { ko "wiring/prompts/sdd/$f no podado"; bad=1; }
  done
  # Las skills de la era gates tampoco existen
  for s in sdd-hard-gate sdd-hard-verify sdd-pre-experience; do
    [[ -e "$REPO/skills/$s" ]] && { ko "skills/$s no podada"; bad=1; }
  done
  # El fragment no define agentes de gates
  w="$REPO/wiring/opencode.sdd.json"
  for a in sdd-hard-gate sdd-hard-verify sdd-pre-experience; do
    jq -e --arg a "$a" '.agent[$a] == null' "$w" >/dev/null 2>&1 || { ko "fragment define $a"; bad=1; }
  done
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 9: plan checklist contract (U5, T54) ----------------

t "T54 plan checklist: anchor ## Principios no verificables (byte-exact Spanish), 21 rows, 3 states, evidence mandatory, translated rejected"
{
  bad=0
  pf="$REPO/wiring/prompts/sdd/sdd-architecture-plan.md"
  [[ -f "$pf" ]] || { ko "plan prompt ausente"; bad=1; }
  # C1/C2: the literal Spanish anchor MUST be present (byte-exact)
  grep -qF '## Principios no verificables' "$pf" || { ko "anchor '## Principios no verificables' ausente (C1/C2 fail-closed)"; bad=1; }
  # The English translation MUST NOT satisfy the gate (C1: translated rejected)
  grep -qF '## Non-verifiable principles' "$pf" && { ko "English translation '## Non-verifiable principles' rejected (C1)"; bad=1; }
  grep -qF '## Unverifiable Principles' "$pf" && { ko "English translation '## Unverifiable Principles' rejected (C1)"; bad=1; }
  # 21 rows: P01..P10 + A01..A11 referenced as table data rows in the checklist contract
  # PIN DEFECTO CORREGIDO en RED (mismo protocolo que U2/T52): el patron original
  # grep -Fc '| P0' contaba SOLO P01..P09 (9 lineas) porque P10 empieza '| P1' —
  # el umbral >=10 era insatisfacible con una tabla natural de 21 filas. El
  # patron corregido `^\| P[0-9]{2} ` cuenta las 10 filas P reales; el pin sigue
  # cayendo RED identico a 0 filas pre-implementacion.
  nprin="$(grep -cE '^\| P[0-9]{2} ' "$pf")"
  [[ "$nprin" -ge 10 ]] || { ko "P-rows in checklist = $nprin (esperado >=10)"; bad=1; }
  nanti="$(grep -cE '^\| A[0-9]{2} ' "$pf")"
  [[ "$nanti" -ge 11 ]] || { ko "A-rows in checklist = $nanti (esperado >=11)"; bad=1; }
  # 3 states: applicable, direction-evidence, n-a-justified
  grep -qF 'applicable' "$pf" || { ko "state 'applicable' ausente en checklist"; bad=1; }
  grep -qF 'direction-evidence' "$pf" || { ko "state 'direction-evidence' ausente en checklist"; bad=1; }
  grep -qF 'n-a-justified' "$pf" || { ko "state 'n-a-justified' ausente en checklist"; bad=1; }
  # evidence/justification MANDATORY per row — the contract must declare it explicitly
  # PIN DEFECTO CORREGIDO en RED: (1) los legs usaban grep -Fi (fixed strings) con
  # alternancias \| literales — jamas matcheaban la intencion regex; (2) el patron
  # 'evidence[^.]*(mandatory|REQUIRED)' hacia false-green contra la linea existente
  # "explore/research evidence (required)" (required = input paths, no evidence del
  # checklist). Corregido a -E con la frase del contrato ('direction evidence')
  # que no existe pre-implementacion; RED identico (el ko se mantiene hasta que el
  # checklist contrato aterriza).
  grep -qiE 'direction evidence[^.]*(mandatory|REQUIRED)' "$pf" || { ko "sin declaration de direction evidence mandatory"; bad=1; }
  grep -qiE 'justification[^.]*(mandatory|REQUIRED)' "$pf" || { ko "sin declaration de justification mandatory (C5)"; bad=1; }
  # never omitted — the contract must say the section is never omitted (C6)
  grep -qiE 'never omitted' "$pf" || { ko "sin 'never omitted' clause (C6)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 8: catalog de principios de arquitectura (P5, U2) -----

t "T50 catalog↔lint cross-check (S4): every catalog ID in lint, every lint ID in catalog, both directions"
{
  bad=0
  catf="$REPO/skills/_shared/architecture-principles.md"
  lintf="$REPO/skills/sdd-architecture-lint/SKILL.md"
  [[ -f "$catf" ]] || { ko "catalog ausente"; bad=1; }
  [[ -f "$lintf" ]] || { ko "lint SKILL ausente"; bad=1; }
  if [[ $bad -eq 0 ]]; then
    # Direction 1: every catalog ID must appear in the lint (lint implements all catalog checks)
    for id in P01 P02 P03 P04 P05 P06 P07 P08 P09 P10 A01 A02 A03 A04 A05 A06 A07 A08 A09 A10 A11; do
      grep -qF "$id" "$lintf" || { ko "lint missing catalog ID $id (catalog→lint direction)"; bad=1; }
    done
    # Direction 2: every lint axis-3 check ID must exist in the catalog (lint→catalog direction)
    # Extract IDs referenced as axis-3 checks in the lint (grep the P/A pattern in axis-3 context)
    lint_ids="$(grep -oE '(P|A)[0-9]{2}' "$lintf" | sort -u)"
    cat_ids="$(grep -oE '(P|A)[0-9]{2}' "$catf" | sort -u)"
    # Every lint ID must be in the catalog
    for lid in $lint_ids; do
      echo "$cat_ids" | grep -qxF "$lid" || { ko "lint references ID $lid not in catalog (lint→catalog direction)"; bad=1; }
    done
  fi
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T49 catalog schema/corpus: P01..P10 labeled, A01..A11 rows, severities blocker"
{
  bad=0
  catf="$REPO/skills/_shared/architecture-principles.md"
  [[ -f "$catf" ]] || { ko "catalog ausente: skills/_shared/architecture-principles.md"; bad=1; }
  grep -q '^## Principles' "$catf" || { ko "catalog sin seccion ## Principles"; bad=1; }
  grep -q '^## Anti-patterns' "$catf" || { ko "catalog sin seccion ## Anti-patterns"; bad=1; }
  np="$(grep -c '^### P[0-9][0-9] — ' "$catf")"
  [[ "$np" == "10" ]] || { ko "principios = $np (esperado 10)"; bad=1; }
  for fld in '^- Definition:' '^- Concrete evidence:' '^- Default severity:'; do
    n="$(grep -c "$fld" "$catf")"
    [[ "$n" == "10" ]] || { ko "campo '$fld' = $n (esperado 10)"; bad=1; }
  done
  grep -q '^| ID | Name | Definition | Concrete evidence | Default severity |$' "$catf" || { ko "tabla anti-patterns sin columnas exactas (schema D2)"; bad=1; }
  na="$(grep -cE '^\| A[0-9]{2} \|' "$catf")"
  [[ "$na" == "11" ]] || { ko "filas anti-patterns = $na (esperado 11)"; bad=1; }
  nb="$(grep -c '^- Default severity: blocker$' "$catf")"
  [[ "$nb" == "10" ]] || { ko "severidades P = $nb (esperado 10 blocker)"; bad=1; }
  nt="$(grep -cE '^\| A[0-9]{2} \|.*\| blocker \|$' "$catf")"
  [[ "$nt" == "11" ]] || { ko "severidades A = $nt (esperado 11 blocker)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T51 catalog single path: canonical file, no shebang, no per-skill copies"
{
  bad=0
  catf="$REPO/skills/_shared/architecture-principles.md"
  [[ -f "$catf" ]] || { ko "catalog ausente: skills/_shared/architecture-principles.md"; bad=1; }
  head -1 "$catf" 2>/dev/null | grep -q '^#!' && { ko "catalog con shebang (data module, nunca ejecutable — threat matrix T51)"; bad=1; }
  heads="$(grep -rl '^## Principles' "$REPO/skills" "$REPO/wiring" 2>/dev/null | wc -l)"
  [[ "$heads" == "1" ]] || { ko "corpus duplicado: $heads archivos con ## Principles (esperado 1: single source S3/S4)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T52 shared-loop join: catalog junto a codegraph.md en todos los loops, copy-only-if-missing, --check lo reconoce"
{
  bad=0
  ss="$REPO/sync-skills.sh"
  # PIN DEFECTO CORREGIDO (documentado en apply-progress U2): el patron base
  # original terminaba en "; do", con lo que solo contaba loops SIN catalogar
  # (base=0 tras un join correcto) y hacia la invariante insatisfacible
  # (paridad: k == 5-k -> k=2.5 en 5 sitios). El ko "debe igualar codegraph.md"
  # muestra la intencion: base = loops que llevan codegraph.md (con o sin
  # catalog); cat == base <=> catalog en TODOS. RED identico (0/5).
  loops_base="$(grep -Fc 'for f in "${SHARED_BOOTSTRAP[@]}" codegraph.md' "$ss")"
  loops_cat="$(grep -Fc 'for f in "${SHARED_BOOTSTRAP[@]}" codegraph.md architecture-principles.md; do' "$ss")"
  [[ "$loops_base" -ge 2 ]] || { ko "loops base shared = $loops_base (esperado >=2, acta D1)"; bad=1; }
  [[ "$loops_cat" == "$loops_base" ]] || { ko "catalog no unido a TODOS los loops shared ($loops_cat/$loops_base; debe igualar codegraph.md)"; bad=1; }
  guard="$(grep -c 'ya existe (no se toca)' "$ss")"
  [[ "$guard" -ge 2 ]] || { ko "guard copy-only-if-missing ausente ($guard sitios, S2)"; bad=1; }
  grep -Fq 'cp "$SHARED_SRC_DIR/$f"' "$ss" || { ko "instalacion no copia desde SHARED_SRC_DIR (fuente unica)"; bad=1; }
  # Runtime leg against the host: --check MUST recognize the catalog in either
  # valid state — pending (a [FALTA] row naming the file) or installed (an
  # [up-to-date] directory row for _shared, or the deployed catalog present and
  # byte-identical to the canonical source). A genuinely missing catalog fails
  # every signal and keeps the original ko. The full "zero desyncs" invariant
  # is T30/T39 and is evaluated in U6.
  # PIN DEFECTO CORREGIDO (apply-progress U7): the first leg grepped the literal
  # filename, which only appears in [FALTA] (pending) rows; once the sync
  # installs the catalog, --check prints directory-level [up-to-date] rows and
  # never names the file — false negative on the very state it must verify.
  # The REAL_HOME pin correction from U2 stays below, unchanged.
  # PIN DEFECTO CORREGIDO (documentado en apply-progress U2): el leg debe usar
  # el HOME REAL de despliegue (REAL_HOME, capturado arriba para este proposito
  # exacto) — T44 exporta HOME a un sandbox y nunca lo restaura, con lo que el
  # leg sin override corria --check contra el sandbox vacio (rc=2, "overlay sin
  # base", Errores<>0) y fallaba por el harness, no por el codigo. RED
  # identico: pre-implementacion el leg sigue ko por "check no reconoce el
  # catalog"; el error estructural fake desaparece.
  ( cd "$REPO" && env HOME="$REAL_HOME" timeout 120 ./sync-skills.sh --check --skip-gentleai-sync ) > "$SB_TMP/t52-check.txt" 2>&1
  rc=$?
  [[ $rc -eq 124 ]] && { ko "leg check colgado >120s"; bad=1; }
  grep -q '\[ERROR\]\s*:\s*0\|Errores\s*:\s*0' "$SB_TMP/t52-check.txt" || { ko "check con errores estructurales (regresion S1)"; bad=1; }
  # PIN DEFECTO CORREGIDO (apply-progress U7): the original leg grepped the
  # literal filename, which only appears in [FALTA] (pending) rows. Once the
  # catalog is installed, --check prints directory-level [up-to-date] rows for
  # _shared and never names the file — false negative on the installed state
  # that this leg exists to verify. The catalog is now accepted in EITHER
  # state, and a genuinely missing catalog still fails closed:
  #   1) PENDING   — a [FALTA] row names the file in --check output
  #   2) INSTALLED — --check reports the _shared loop [up-to-date] AND the
  #                  deployed catalog exists
  #   3) INSTALLED — the deployed catalog is byte-identical to the canonical
  #                  source (cmp -s; md5-equivalent)
  t52_ok=0
  grep -q 'architecture-principles\.md' "$SB_TMP/t52-check.txt" && t52_ok=1
  if grep -q '\[up-to-date\].*_shared' "$SB_TMP/t52-check.txt" \
     && [[ -f "$REAL_HOME/.config/sdd-own/skills/_shared/architecture-principles.md" ]]; then
    t52_ok=1
  fi
  if [[ -f "$REAL_HOME/.config/sdd-own/skills/_shared/architecture-principles.md" ]] \
     && cmp -s "$REPO/skills/_shared/architecture-principles.md" \
              "$REAL_HOME/.config/sdd-own/skills/_shared/architecture-principles.md"; then
    t52_ok=1
  fi
  [[ $t52_ok -eq 0 ]] && { ko "check no reconoce el catalog en el loop shared"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T53 quest arch rework v3: skill unificada PODADA (sdd-quest ausente); split product/arch con budgets y gates propios"
{
  bad=0
  # v3 (poda total): la skill unificada sdd-quest (8 base Qs + branch table +
  # stack trigger, design D6) NO existe; fue reemplazada por dos skills
  # dedicadas con budgets/gates propios (ver T36/T50/T55 del grupo 7).
  [[ -e "$REPO/skills/sdd-quest" ]] && { ko "skills/sdd-quest no podada (split v3)"; bad=1; }
  # Sin restos del design D6 en el wiring: ni la routing extension ni el
  # fragment mencionan la quest unificada; solo las ramas split.
  n="$(grep -cE 'sdd-quest|branch table|base context questions' "$REPO/wiring/sdd-own-routing.md")"
  [[ "$n" == "0" ]] || { ko "routing con $n restos del quest unificado (D6)"; bad=1; }
  # El catalogo de principios sigue por path en skills/_shared (fuente unica) y
  # alimenta el LINT (axis 3, T49/T52), no la entrevista de quest (S3/S4).
  catf="$REPO/skills/_shared/architecture-principles.md"
  [[ -f "$catf" ]] || { ko "catalog ausente: skills/_shared/architecture-principles.md"; bad=1; }
  heads="$(grep -rl '^## Principles' "$REPO/skills" "$REPO/wiring" 2>/dev/null | wc -l)"
  [[ "$heads" == "1" ]] || { ko "corpus duplicado: $heads archivos con ## Principles (esperado 1)"; bad=1; }
  # Las 2 skills split existen y conservan sus budgets (regresion spec A1/A2)
  grep -q 'Product Quest = **50**' "$REPO/skills/sdd-product-quest/SKILL.md" || { ko "Product Quest budget 50 alterado"; bad=1; }
  grep -q 'Architecture Quest = **20**' "$REPO/skills/sdd-architecture-quest/SKILL.md" || { ko "Architecture Quest budget 20 alterado"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 10: axis-3 fixtures (U6, T55-T59) + wiring (T60) ------
# Fixtures en tests/fixtures/arch-principles/ (contrato acta: clean, 1 dirty por
# familia, multi, missing-checklist, translated-anchor, expected.json). El proxy
# deterministico de axis-3 lee los markers de implementation.md (VIOLATION ->
# blocker a severidad del catalogo; AMBIGUOUS -> warning; CONTRADICTION -> dual
# signal) y compara contra expected.json (D9: machine-readable RED, L2/L3/L4/L5).

FIX="$REPO/tests/fixtures/arch-principles"
CATALOG="$REPO/skills/_shared/architecture-principles.md"

t "T55 axis-3 fixtures: clean pass (0 markers -> axis_3 pass) y dirty per-family (VIOLATION del ID exacto -> blocker, severidad del catalogo, L2)"
{
  bad=0
  [[ -f "$FIX/expected.json" ]] || { ko "expected.json ausente"; bad=1; }
  jq -e '.schema == "sdd/arch-principles-fixtures/v1"' "$FIX/expected.json" >/dev/null 2>&1 || { ko "expected.json sin schema pin"; bad=1; }
  # clean: cero markers -> cero blockers -> axis_3 pass; expected coincide
  clean_impl="$FIX/clean/implementation.md"
  [[ -f "$clean_impl" ]] || { ko "clean/implementation.md ausente"; bad=1; }
  nm="$(grep -cE '^(VIOLATION|AMBIGUOUS|CONTRADICTION)\(' "$clean_impl")"
  [[ "$nm" == "0" ]] || { ko "clean con $nm markers (esperado 0)"; bad=1; }
  [[ -f "$FIX/clean/acta.md" ]] || { ko "clean/acta.md ausente"; bad=1; }
  grep -qF '## Principios no verificables' "$FIX/clean/acta.md" || { ko "clean acta sin anchor literal (C6)"; bad=1; }
  jq -e '.fixtures.clean.axis_3 == "pass" and (.fixtures.clean.blockers | length) == 0' "$FIX/expected.json" >/dev/null 2>&1 || { ko "expected clean != axis_3 pass, 0 blockers"; bad=1; }
  # dirty per familia: cada dirty/<ID>/ tiene EXACTAMENTE 1 VIOLATION(<ID>) y
  # expected lo marca axis_3 fail con blockers == [ID]; severidad leida del catalogo
  for id in P01 P02 P03 P04 P05 P06 P07 P08 P09 P10 A01 A02 A03 A04 A05 A06 A07 A08 A09 A10 A11; do
    d="$FIX/dirty/$id"
    [[ -f "$d/implementation.md" ]] || { ko "dirty/$id/implementation.md ausente"; bad=1; }
    nv="$(grep -cE "^VIOLATION\($id\):" "$d/implementation.md")"
    [[ "$nv" == "1" ]] || { ko "dirty/$id con $nv VIOLATION($id) (esperado 1)"; bad=1; }
    nt="$(grep -cE '^(VIOLATION|AMBIGUOUS|CONTRADICTION)\(' "$d/implementation.md")"
    [[ "$nt" == "1" ]] || { ko "dirty/$id con $nt markers totales (esperado 1: solo su familia, L2)"; bad=1; }
    jq -e --arg id "$id" '.fixtures["dirty/" + $id].axis_3 == "fail" and (.fixtures["dirty/" + $id].blockers == [$id])' "$FIX/expected.json" >/dev/null 2>&1 || { ko "expected dirty/$id != fail + blockers [$id]"; bad=1; }
    # severidad del ID leida del catalogo (D2: siempre blocker hoy)
    if [[ "$id" == P* ]]; then
      grep -A3 "^### $id " "$CATALOG" | grep -q 'Default severity: blocker' || { ko "catalog severidad $id != blocker"; bad=1; }
    else
      grep -E "^\| $id \|" "$CATALOG" | grep -q '| blocker |$' || { ko "catalog severidad $id != blocker"; bad=1; }
    fi
  done
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T56 axis-3 fixtures: multi -> set completo de blockers (L3, todos los findings, no solo el primero)"
{
  bad=0
  d="$FIX/multi"
  [[ -f "$d/implementation.md" ]] || { ko "multi/implementation.md ausente"; bad=1; }
  markers="$(grep -oE '^VIOLATION\((P|A)[0-9]{2}\)' "$d/implementation.md" | sed -E 's/^VIOLATION\(//; s/\)$//' | sort)"
  exp="$(jq -r '.fixtures.multi.blockers | sort | join("\n")' "$FIX/expected.json" 2>/dev/null)"
  [[ -n "$markers" ]] || { ko "multi sin markers VIOLATION"; bad=1; }
  [[ -n "$exp" ]] || { ko "expected multi sin blockers"; bad=1; }
  [[ "$markers" == "$exp" ]] || { ko "multi: markers != expected ($(echo "$markers" | tr '\n' ' ') vs $(echo "$exp" | tr '\n' ' '))"; bad=1; }
  n="$(grep -c . <<< "$markers")"
  [[ "$n" -ge 3 ]] || { ko "multi con solo $n violaciones (necesita >=3 para probar set completo)"; bad=1; }
  jq -e '.fixtures.multi.axis_3 == "fail"' "$FIX/expected.json" >/dev/null 2>&1 || { ko "expected multi != axis_3 fail"; bad=1; }
  # acta multi: los IDs violados estan applicable en el checklist (no suprimidos)
  for id in $markers; do
    grep -E "^\| $id \| applicable \|" "$d/acta.md" >/dev/null || { ko "multi acta: $id no applicable"; bad=1; }
  done
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T57 axis-3 fixtures: AMBIGUOUS -> warning, nunca blocker; axis_3 pass con solo warnings (L4)"
{
  bad=0
  d="$FIX/warning"
  [[ -f "$d/implementation.md" ]] || { ko "warning/implementation.md ausente"; bad=1; }
  na="$(grep -cE '^AMBIGUOUS\(' "$d/implementation.md")"
  [[ "$na" -ge 1 ]] || { ko "warning sin markers AMBIGUOUS"; bad=1; }
  nb="$(grep -cE '^(VIOLATION|CONTRADICTION)\(' "$d/implementation.md")"
  [[ "$nb" == "0" ]] || { ko "warning con $nb markers de blocker (esperado 0: solo sospechas no confirmadas)"; bad=1; }
  for mid in $(grep -oE '^AMBIGUOUS\((P|A)[0-9]{2}\)' "$d/implementation.md" | sed -E 's/^AMBIGUOUS\(//; s/\)$//'); do
    jq -e --arg id "$mid" '.fixtures.warning.warnings | index($id) != null' "$FIX/expected.json" >/dev/null 2>&1 || { ko "warning: $mid no en expected.warnings"; bad=1; }
    jq -e --arg id "$mid" '.fixtures.warning.blockers | index($id) == null' "$FIX/expected.json" >/dev/null 2>&1 || { ko "warning: $mid en expected.blockers (warning nunca es blocker, L4)"; bad=1; }
  done
  jq -e '.fixtures.warning.axis_3 == "pass" and (.fixtures.warning.blockers | length) == 0' "$FIX/expected.json" >/dev/null 2>&1 || { ko "expected warning != axis_3 pass (warnings no fallan axis 3)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T58 axis-3 fixtures: n-a-justified suprime con justificacion visible (L5); contradiction -> dual signal mismo ID (L6/C7)"
{
  bad=0
  # N/A suppress: na-justified/ declara P08 n-a-justified -> VIOLATION(P08)
  # suprimida (sin blocker) y la justificacion es visible en el acta
  d="$FIX/na-justified"
  [[ -f "$d/acta.md" ]] || { ko "na-justified/acta.md ausente"; bad=1; }
  grep -E '^\| P08 \| n-a-justified \|' "$d/acta.md" | grep -qiE 'out of scope|because|no aplica' || { ko "na-justified: P08 sin justificacion visible (L5)"; bad=1; }
  grep -q '^VIOLATION(P08):' "$d/implementation.md" || { ko "na-justified: falta VIOLATION(P08) para probar la supresion"; bad=1; }
  nb="$(grep -cE '^(VIOLATION|CONTRADICTION)\(' "$d/implementation.md")"
  [[ "$nb" == "1" ]] || { ko "na-justified con $nb violaciones (esperado 1, la suprimible)"; bad=1; }
  jq -e '.fixtures["na-justified"].axis_3 == "pass" and (.fixtures["na-justified"].blockers | length) == 0 and (.fixtures["na-justified"].suppressed == ["P08"])' "$FIX/expected.json" >/dev/null 2>&1 || { ko "expected na-justified != pass, 0 blockers, suppressed [P08]"; bad=1; }
  # dual: dual/ declara P02 applicable + CONTRADICTION(P02) -> axis 2 unmet
  # mandate (C7) Y axis 3 blocker en el MISMO ID (L6)
  dd="$FIX/dual"
  [[ -f "$dd/acta.md" ]] || { ko "dual/acta.md ausente"; bad=1; }
  grep -E '^\| P02 \| applicable \|' "$dd/acta.md" >/dev/null || { ko "dual: P02 no applicable en acta"; bad=1; }
  grep -q '^CONTRADICTION(P02):' "$dd/implementation.md" || { ko "dual: falta CONTRADICTION(P02)"; bad=1; }
  jq -e '.fixtures.dual.axis_3 == "fail" and (.fixtures.dual.blockers == ["P02"]) and (.fixtures.dual.axis_2_unmet == ["P02"])' "$FIX/expected.json" >/dev/null 2>&1 || { ko "expected dual != fail + dual signal P02 mismo ID (L6/C7)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T59 axis-3 fixtures: missing-checklist y translated-anchor fail-closed (C1/C2 - solo el anchor literal espanol satisface presencia)"
{
  bad=0
  # missing-checklist: acta SIN '## Principios no verificables' -> axis 2 fail-closed (C2)
  d="$FIX/missing-checklist"
  [[ -f "$d/acta.md" ]] || { ko "missing-checklist/acta.md ausente"; bad=1; }
  grep -qF '## Principios no verificables' "$d/acta.md" && { ko "missing-checklist: anchor presente (debe faltar, C2)"; bad=1; }
  jq -e '.fixtures["missing-checklist"].axis_2 == "fail-closed"' "$FIX/expected.json" >/dev/null 2>&1 || { ko "expected missing-checklist != axis_2 fail-closed"; bad=1; }
  # translated-anchor: SOLO titulo en ingles -> NO satisface la presencia (C1)
  d2="$FIX/translated-anchor"
  [[ -f "$d2/acta.md" ]] || { ko "translated-anchor/acta.md ausente"; bad=1; }
  grep -qF '## Principios no verificables' "$d2/acta.md" && { ko "translated-anchor: anchor espanol presente (esperado solo ingles)"; bad=1; }
  grep -qE '^## (Non-verifiable|Unverifiable) [Pp]rinciples' "$d2/acta.md" || { ko "translated-anchor: falta titulo traducido"; bad=1; }
  jq -e '.fixtures["translated-anchor"].axis_2 == "fail-closed"' "$FIX/expected.json" >/dev/null 2>&1 || { ko "expected translated-anchor != axis_2 fail-closed"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T60 wiring (B5): sdd-architecture-plan agent key (subagent, hidden, file-based) + orchestrator allow-list"
{
  bad=0
  w="$REPO/wiring/opencode.sdd.json"
  jq -e '.agent["sdd-architecture-plan"] != null' "$w" >/dev/null 2>&1 || { ko "agente sdd-architecture-plan ausente"; bad=1; }
  jq -e '.agent["sdd-architecture-plan"].mode == "subagent" and .agent["sdd-architecture-plan"].hidden == true and (.agent["sdd-architecture-plan"].permission | length) == 0' "$w" >/dev/null 2>&1 || { ko "sdd-architecture-plan mode/hidden/permission mal"; bad=1; }
  jq -e '.agent["sdd-architecture-plan"].prompt == "{file:./prompts/sdd/sdd-architecture-plan.md}"' "$w" >/dev/null 2>&1 || { ko "sdd-architecture-plan sin prompt file-based (B4)"; bad=1; }
  jq -e '.agent["gentle-orchestrator"].permission.task["sdd-architecture-plan"] == "allow"' "$w" >/dev/null 2>&1 || { ko "orchestrator no permite sdd-architecture-plan (allow-list B5)"; bad=1; }
  [[ -f "$REPO/wiring/prompts/sdd/sdd-architecture-plan.md" ]] || { ko "wiring/prompts/sdd/sdd-architecture-plan.md ausente (B3)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# Clean up sdd-tool build temp
[[ -n "${_sdd_build_tmp:-}" && -d "$_sdd_build_tmp" ]] && rm -rf "$_sdd_build_tmp" 2>/dev/null

stop_fake_api
echo
echo "== Resumen RED checks =="
printf '  PASS: %d   FAIL: %d   SKIP: %d   (%ds total)\n' "$PASS" "$FAIL" "$SKIP" "$(( $(date +%s) - START_EPOCH ))"
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  printf '  Fallos: %s\n' "${FAILURES[*]}"
  exit 1
fi
echo "  Verde."
exit 0