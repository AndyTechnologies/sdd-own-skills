#!/usr/bin/env bash
# =============================================================================
# run_red_checks.sh — RED checks de setup.sh (fase de implementacion, P5)
#
# Correr desde cualquier lado; resuelve el repo por SCRIPT_DIR.
#   ./tests/run_red_checks.sh
#
# Mapa de cobertura (design.md, Testing Strategy):
#   T01 sintaxis            T09 token 401 real          T16 presence/creacion (F2)
#   T02 wrap contract (F6)  T10 red fallida real        T17 merge TOML (F3)
#   T03 flags y uso         T11 higiene/argv (F1)       T18 hard deps (F4)
#   T04 argv delegado       T12 scopes faltantes        T19 gate F9
#   T05 no-mutacion host    T13 keep                    T20 check 401 drift
#   T06 no-mutacion check   T14 replace (F5)            T21 check red estructural
#   T07 no-mutacion dry-run T15 colision invalid        T22 regresion + README (F7)
#
# Exit: 0 = todo verde (skips permitidos), 1 = fallos.
# =============================================================================

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPERS="$REPO/tests/helpers"
# shellcheck disable=SC1091
source "$HELPERS/sandbox.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq requerido para los RED checks" >&2
  exit 2
fi

PASS=0; FAIL=0; SKIP=0
declare -a FAILURES=()
TEST_NAME=""

t()   { TEST_NAME="$1"; }
ok()  { PASS=$((PASS + 1)); printf '  [PASS] %s\n' "$TEST_NAME"; }
ko()  { FAIL=$((FAIL + 1)); FAILURES+=("$TEST_NAME"); printf '  [FAIL] %s: %s\n' "$TEST_NAME" "$1"; }
skip(){ SKIP=$((SKIP + 1)); printf '  [SKIP] %s: %s\n' "$TEST_NAME" "$1"; }

cleanup() { stop_fake_api; }
trap cleanup EXIT

echo "== RED checks de setup.sh (repo: $REPO)"
echo

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
  run_setup --bogus >/dev/null 2>&1
  [[ "$(cat "$SB_TMP/exit")" == "1" ]] || { ko "flag desconocido: exit $(cat "$SB_TMP/exit") != 1"; bad=1; }
  [[ -e "$SB_TMP/sync-seam.txt" ]] && { ko "flag desconocido: seam creado (delego antes de abortar)"; bad=1; }
  run_setup --check --dry-run >/dev/null 2>&1
  [[ "$(cat "$SB_TMP/exit")" == "1" ]] || { ko "--check --dry-run: exit $(cat "$SB_TMP/exit") != 1"; bad=1; }
  [[ -e "$SB_TMP/sync-seam.txt" ]] && { ko "--check --dry-run: seam creado (no aborto antes de delegar)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T04 argv delegado: solo flags entendidos por sync"
{
  bad=0
  init_sandbox
  run_setup --check --skip-mcp >/dev/null 2>&1
  grep -q -- "--skip-mcp" "$SB_TMP/sync-seam.txt" && { ko "argv: --skip-mcp filtrado pero reenviado"; bad=1; }
  grep -q -- "--check" "$SB_TMP/sync-seam.txt" || { ko "argv: --check no llego al seam"; bad=1; }
  grep -q "^exit=" "$SB_TMP/sync-seam.txt" || { ko "argv: sin linea de exit en el seam"; bad=1; }
  run_setup --registries /tmp/proy >/dev/null 2>&1
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

t "T09 token invalido (401): 3 intentos, nada persistido, exit 2"
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

t "T10 red fallida en modo real: nada persistido, exit 2"
{
  bad=0
  init_sandbox; start_fake_api 200; stop_fake_api
  run_setup_pty 30 'Token de GitHub (PAT): =ghp_NET\n'
  [[ "$(cat "$SB_TMP/exit")" == "2" ]] || { ko "exit $(cat "$SB_TMP/exit") != 2"; bad=1; }
  grep -q "fallo de red" "$SB_TMP/out.txt" || { ko "sin mensaje de fallo de red"; bad=1; }
  [[ -e "$SB_HOME/.config/sdd-own/github-mcp.env" ]] && { ko "env file creado sin validacion"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T11 higiene de secretos y argv (F1)"
{
  bad=0
  tok="ghp_REDTEST123"
  exp_mask="${tok:0:4}....${tok: -4}"
  init_sandbox; start_fake_api 200
  add_env SDD_OWN_DEBUG_CURL_CONFIG="$SB_TMP/curl-config.txt"
  run_setup_pty 45 "Token de GitHub (PAT): =${tok}\\n;Cambiar el token antes de continuar? [y/N] =n\\n"
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

t "T12 scopes faltantes: aviso + opcion de cambio, run continua"
{
  bad=0
  init_sandbox; start_fake_api 200 "read:org"
  run_setup_pty 45 'Token de GitHub (PAT): =ghp_SCOPES\n;Cambiar el token antes de continuar? [y/N] =n\n'
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "faltan scopes clasicos" "$SB_TMP/out.txt" || { ko "sin aviso de scopes faltantes"; bad=1; }
  [[ -f "$SB_HOME/.config/sdd-own/github-mcp.env" ]] || { ko "token no persistido"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 4: persistencia y rotacion ---------------------------

t "T13 keep: token existente valido conservado (k)"
{
  bad=0
  init_sandbox; start_fake_api 200
  seed_env_file "ghp_T1KEEP123"
  m0="$(env_file_mtime)"
  run_setup_pty 45 'Mantener el token existente? [k/R] =k\n;Cambiar el token antes de continuar? [y/N] =n\n'
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "conservado (sin reescritura)" "$SB_TMP/out.txt" || { ko "sin reporte keep"; bad=1; }
  env_file_lines | grep -q "ghp_T1KEEP123" || { ko "env file no conserva el token"; bad=1; }
  [[ "$(env_file_mtime)" == "$m0" ]] || { ko "env file reescrito en keep (mtime cambio)"; bad=1; }
  [[ -e "$SB_HOME/.config/sdd-own/github-mcp.env.bak" ]] && { ko "keep creo .bak"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T14 replace (F5): R respalda .bak 0600 y rota; a lo sumo un .bak"
{
  bad=0
  init_sandbox; start_fake_api 200
  seed_env_file "ghp_T1REPLACE"
  run_setup_pty 45 'Mantener el token existente? [k/R] =R\n;Token de GitHub (PAT): =ghp_T2REPLACE\n;Cambiar el token antes de continuar? [y/N] =n\n'
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

t "T15 colision: env file invalido existente se reemplaza con .bak del invalido"
{
  bad=0
  init_sandbox; start_fake_api 200 "" 1   # primer request 401, resto 200
  seed_env_file "ghp_STALEINV"
  run_setup_pty 45 'Token de GitHub (PAT): =ghp_NEWVALID\n;Cambiar el token antes de continuar? [y/N] =n\n'
  [[ "$(cat "$SB_TMP/exit")" == "0" ]] || { ko "exit $(cat "$SB_TMP/exit") != 0"; bad=1; }
  grep -q "reemplazo del token invalido" "$SB_TMP/out.txt" || { ko "sin flujo de reemplazo del invalido"; bad=1; }
  grep -q "ghp_STALEINV" "$SB_HOME/.config/sdd-own/github-mcp.env.bak" || { ko ".bak no conserva el invalido previo"; bad=1; }
  env_file_lines | grep -q "ghp_NEWVALID" || { ko "env file no actualizado"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 5: merges por runtime --------------------------------

t "T16 presence/creacion (F2): pi crea target sin .bak; re-run up-to-date; resto preservado"
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
  [[ -e "$ocf.bak" ]] || { ko "opencode existente sin .bak en su primer merge"; bad=1; }
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

t "T17 merge TOML (F3): [mcp_servers.github] correcto, resto preservado; tomli-w ausente → ERROR exit 2"
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

t "T18 hard deps (F4): curl ausente y docker ausente con TRANSPORT=docker → exit 2 pre-delegacion"
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

t "T19 gate F9: sync exit 2 omite el paso MCP y propaga exit 2"
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

t "T20 --check + token invalido → exit 1 (drift)"
{
  bad=0
  init_sandbox; start_fake_api 401
  seed_env_file "ghp_DRIFT001"
  run_setup --check </dev/null
  [[ "$(cat "$SB_TMP/exit")" == "1" ]] || { ko "exit $(cat "$SB_TMP/exit") != 1"; bad=1; }
  grep -q "DESYNC" "$SB_TMP/out.txt" || { ko "sin marcador [DESYNC]"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T21 --check + API inalcanzable → exit 2 (estructural)"
{
  bad=0
  init_sandbox
  SB_PORT="$(api_dead_port)"
  seed_env_file "ghp_NETCHECK"
  run_setup --check </dev/null
  [[ "$(cat "$SB_TMP/exit")" == "2" ]] || { ko "exit $(cat "$SB_TMP/exit") != 2"; bad=1; }
  grep -q "estado estructural" "$SB_TMP/out.txt" || { ko "sin reporte estructural"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T22 regresion sync + excepcion sancionada en README (F7)"
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

stop_fake_api
echo
echo "== Resumen RED checks =="
printf '  PASS: %d   FAIL: %d   SKIP: %d\n' "$PASS" "$FAIL" "$SKIP"
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  printf '  Fallos: %s\n' "${FAILURES[*]}"
  exit 1
fi
echo "  Verde."
exit 0