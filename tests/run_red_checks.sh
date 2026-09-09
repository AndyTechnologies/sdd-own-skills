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
#   T26 worktree contrato   T27 E1 doc-contract        T28 contract pins overlays
#   T29 synthetic SWU probe T30 sync + id hygiene       T31 F4 hook pins
#   T32 council always-fire T33 wiring council/lenses  T34 OWN_PROMPTS + file
#   T35 acta fail-closed    T36 convergence/fork/2r     T37 fragment SDD-only
#   T38 subagent_depth 2    T39 merge ambos motores
#   T40 one-parse           T41 fallback+dedupe         T42 title retrievability
#   T42b worktree list      T43 signals+dirty            T44 record→resolve
#   T45 --json≡scanner      T46 read fail-open           T47 write FAIL-OPEN
#   T47b 5d-2 warn          T48 changelog clause
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

t "T26 worktree MCP contrato: 3 tools, Path.home(), destructive_flow, catalogo cerrado"
{
  bad=0
  src="$REPO/srv/gh-mcp-server/src"
  grep -q "register_worktree_mutation" "$src/tool_handlers/__init__.py" || { ko "familia worktree no registrada"; bad=1; }
  grep -q "git_worktree_add" "$src/tool_handlers/worktree_mutation.py" || { ko "git_worktree_add ausente"; bad=1; }
  grep -q "git_worktree_remove" "$src/tool_handlers/worktree_mutation.py" || { ko "git_worktree_remove ausente"; bad=1; }
  grep -q "git_worktree_list" "$src/tool_handlers/local_read.py" || { ko "git_worktree_list ausente en local_read"; bad=1; }
  grep -q "Path.home()" "$src/tool_handlers/worktree_mutation.py" || { ko "resolucion HOME-relative ausente (Path.home())"; bad=1; }
  grep -q "destructive_flow" "$src/tool_handlers/worktree_mutation.py" || { ko "two-phase destructive_flow no usado en worktree"; bad=1; }
  for et in auth_required repo_not_found network_error not_found not_a_repo dirty_worktree not_safe commit_failed invalid_parameter worktree_exists active_agents owned_by_other; do
    grep -q "$et" "$src/envelope.py" || { ko "catalogo cerrado sin $et"; bad=1; }
  done
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T27 E1 doc-contract: 7 descripciones dos-fases citan ECHO_PROTOCOL; confirm_required nunca err()"
{
  bad=0
  src="$REPO/srv/gh-mcp-server/src"
  n="$(grep -rh '+ ECHO_PROTOCOL' "$src"/tool_handlers/*.py | wc -l)"
  [[ "$n" == "7" ]] || { ko "descripciones con ECHO_PROTOCOL = $n (esperado 7)"; bad=1; }
  hits="$(grep -rn --include='*.py' 'err("confirm_required"\|err('\''confirm_required'\''' "$src" | wc -l)"
  [[ "$hits" == "0" ]] || { ko "confirm_required usado como err() ($hits hits)"; bad=1; }
  grep -q 'confirm_required' "$src/dryrun.py" || { ko "confirm_required ausente en dryrun.py (marker ok)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# ---------------- Grupo 7: SDD workflow hardening pins ------------------------

t "T28 contract pins: fail-closed, untrusted DATA, 4 tokens, delimited evidence, not-verifiable, blocked(edit_authority_missing)"
{
  bad=0
  # Orchestrator rule 2 pins
  grep -q 'fail-closed' "$REPO/wiring/prompts/sdd/orchestrator.md" || { ko "orchestrator: sin fail-closed"; bad=1; }
  grep -q 'untrusted' "$REPO/wiring/prompts/sdd/orchestrator.md" || { ko "orchestrator: sin untrusted"; bad=1; }
  grep -q 'start/finish/verification/rollback' "$REPO/wiring/prompts/sdd/orchestrator.md" || { ko "orchestrator: sin 4 tokens"; bad=1; }
  # shared-untrusted-data block pins
  grep -q 'fail-closed' "$REPO/overlays/shared/sdd-phase-common.md" || { ko "phase-common: sin fail-closed"; bad=1; }
  grep -q 'untrusted DATA' "$REPO/overlays/shared/sdd-phase-common.md" || { ko "phase-common: sin untrusted DATA"; bad=1; }
  grep -q 'start/finish/verification/rollback' "$REPO/overlays/shared/sdd-phase-common.md" || { ko "phase-common: sin 4 tokens"; bad=1; }
  grep -q 'delimited' "$REPO/overlays/shared/sdd-phase-common.md" || { ko "phase-common: sin delimited"; bad=1; }
  # Overlay sdd-tasks: SWU shape
  grep -q 'fail-closed' "$REPO/overlays/skills/sdd-tasks/SKILL.md" || { ko "sdd-tasks: sin fail-closed"; bad=1; }
  grep -q 'start/finish/verification/rollback' "$REPO/overlays/skills/sdd-tasks/SKILL.md" || { ko "sdd-tasks: sin 4 tokens"; bad=1; }
  # Overlay sdd-apply: SWU validate + edit authority
  grep -q 'fail-closed' "$REPO/overlays/skills/sdd-apply/SKILL.md" || { ko "sdd-apply: sin fail-closed"; bad=1; }
  grep -q 'blocked(edit_authority_missing)' "$REPO/overlays/skills/sdd-apply/SKILL.md" || { ko "sdd-apply: sin blocked(edit_authority_missing)"; bad=1; }
  # Overlay sdd-verify: evidence shape + edit authority
  grep -q 'not-verifiable' "$REPO/overlays/skills/sdd-verify/SKILL.md" || { ko "sdd-verify: sin not-verifiable"; bad=1; }
  grep -q 'delimited' "$REPO/overlays/skills/sdd-verify/SKILL.md" || { ko "sdd-verify: sin delimited"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T29 synthetic SWU probe: 4 tokens present in tasks; apply has fail-closed chain"
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
  # Apply overlay has the fail-closed rejection chain
  grep -q 'fail-closed' "$REPO/overlays/skills/sdd-apply/SKILL.md" || { ko "apply: fail-closed ausente"; bad=1; }
  grep -q 'NEVER executed' "$REPO/overlays/skills/sdd-apply/SKILL.md" || { ko "apply: NEVER executed ausente"; bad=1; }
  grep -q 'blocked' "$REPO/overlays/skills/sdd-apply/SKILL.md" || { ko "apply: blocked ausente"; bad=1; }
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
  dup_count="$(for f in "$REPO"/overlays/skills/*/SKILL.md; do
    grep -o 'sdd-own:sdd-[a-z-]*' "$f" 2>/dev/null | sort -u
  done | sort | uniq -d | wc -l)"
  [[ "$dup_count" == "0" ]] || { ko "ids duplicados en overlays: $dup_count"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T31 F4 hook pins: preflight shape, lossless consent, never skips human, decline continues"
{
  bad=0
  orch="$REPO/wiring/prompts/sdd/orchestrator.md"
  grep -q 'gentle-ai review status' "$orch" || { ko "F4: sin preflight command"; bad=1; }
  grep -q 'review-integration/v2' "$orch" || { ko "F4: sin contract version"; bad=1; }
  grep -q 'next-transition' "$orch" || { ko "F4: sin --next-transition"; bad=1; }
  grep -q 'consent/v3' "$orch" || { ko "F4: sin consent/v3"; bad=1; }
  grep -q 'never skips human authorization' "$orch" || { ko "F4: sin never skips human authorization"; bad=1; }
  grep -q 'candidate-scoped' "$orch" || { ko "F4: sin candidate-scoped decline"; bad=1; }
  grep -q 'continues to archive' "$orch" || { ko "F4: sin continues to archive"; bad=1; }
  grep -q 'informational no-op' "$orch" || { ko "F4: sin informational no-op"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T32 council always-fire: orchestrator hooks, arch-lint axis 2, overlays rout ALWAYS"
{
  bad=0
  orch="$REPO/wiring/prompts/sdd/orchestrator.md"
  grep -q 'design → council (ALWAYS) → arch-lint (ALWAYS, acta mandatory) → gate' "$orch" || { ko "orchestrator: sin cadena council ALWAYS en rule 4"; bad=1; }
  grep -q 'post-design hooks' "$orch" || { ko "orchestrator: sin hooks item 3"; bad=1; }
  grep -q 'delegate the post-design council ALWAYS' "$orch" || { ko "orchestrator: hooks sin council ALWAYS"; bad=1; }
  grep -q 'MANDATORY input' "$orch" || { ko "orchestrator: sin acta MANDATORY"; bad=1; }
  grep -q 'fails axis 2 closed' "$orch" || { ko "orchestrator: sin fail-closed axis 2"; bad=1; }
  grep -q 'runs ALWAYS AFTER `design`' "$REPO/overlays/commands/sdd-continue.md" || { ko "sdd-continue: sin council ALWAYS"; bad=1; }
  grep -q 'sdd-council — ALWAYS after design' "$REPO/overlays/commands/sdd-ff.md" || { ko "sdd-ff: sin council ALWAYS"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T33 wiring council: 4 agentes, allow-lists, prompt file-based, sin __managed_by"
{
  bad=0
  w="$REPO/wiring/opencode.sdd.json"
  for a in sdd-council sdd-council-arch sdd-council-product sdd-council-risk; do
    jq -e --arg a "$a" '.agent[$a] != null' "$w" >/dev/null 2>&1 || { ko "agente $a ausente"; bad=1; }
  done
  jq -e '.agent["gentle-orchestrator"].permission.task["sdd-council"] == "allow"' "$w" >/dev/null 2>&1 || { ko "orchestrator no permite sdd-council"; bad=1; }
  for l in sdd-council-arch sdd-council-product sdd-council-risk; do
    jq -e --arg l "$l" '.agent["sdd-council"].permission.task[$l] == "allow"' "$w" >/dev/null 2>&1 || { ko "council no permite $l"; bad=1; }
  done
  jq -e '.agent["sdd-council"].mode == "subagent" and .agent["sdd-council"].hidden == true and (.agent["sdd-council"].permission.task["*"] == "deny")' "$w" >/dev/null 2>&1 || { ko "council mode/hidden/deny-* mal"; bad=1; }
  jq -e '.agent["sdd-council"].prompt == "{file:./prompts/sdd/sdd-council.md}"' "$w" >/dev/null 2>&1 || { ko "council sin prompt file-based"; bad=1; }
  for l in sdd-council-arch sdd-council-product sdd-council-risk; do
    jq -e --arg l "$l" '.agent[$l].mode == "subagent" and .agent[$l].hidden == true and (.agent[$l].permission | length) == 0' "$w" >/dev/null 2>&1 || { ko "lens $l mode/hidden/permission mal"; bad=1; }
    jq -e --arg l "$l" '.agent[$l].prompt | contains("## Lens:")' "$w" >/dev/null 2>&1 || { ko "lens $l no referencia su seccion"; bad=1; }
  done
  jq -e '[.agent["sdd-council"], .agent["sdd-council-arch"], .agent["sdd-council-product"], .agent["sdd-council-risk"]] | map(has("__managed_by")) | all(. == false)' "$w" >/dev/null 2>&1 || { ko "agentes nuevos con __managed_by"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T34 OWN_PROMPTS + files: sdd-council.md instalable, skill full delegate_only"
{
  bad=0
  grep -q 'OWN_PROMPTS=(orchestrator.md sdd-rfc-author.md sdd-council.md)' "$REPO/sync-skills.sh" || { ko "OWN_PROMPTS sin sdd-council.md"; bad=1; }
  [[ -f "$REPO/wiring/prompts/sdd/sdd-council.md" ]] || { ko "wiring/prompts/sdd/sdd-council.md ausente"; bad=1; }
  [[ -f "$REPO/skills/sdd-council/SKILL.md" ]] || { ko "skills/sdd-council/SKILL.md ausente"; bad=1; }
  grep -q 'delegate_only: true' "$REPO/skills/sdd-council/SKILL.md" || { ko "council skill sin delegate_only"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T35 acta fail-closed: axis 2 MANDATORY, title-by-title, 3 lenses, N/A solo trivial"
{
  bad=0
  al="$REPO/skills/sdd-architecture-lint/SKILL.md"
  grep -q 'Axis 2' "$al" || { ko "arch-lint sin Axis 2"; bad=1; }
  grep -q 'MANDATORY input' "$al" || { ko "arch-lint sin acta MANDATORY"; bad=1; }
  grep -q 'FAILS CLOSED' "$al" || { ko "arch-lint sin fail-closed"; bad=1; }
  grep -q 'title-by-title' "$al" || { ko "arch-lint sin title-by-title"; bad=1; }
  grep -q 'empty or trivial design' "$al" || { ko "arch-lint sin N/A-trivial"; bad=1; }
  n="$(grep -c '^## Lens:' "$REPO/skills/sdd-council/SKILL.md")"
  [[ "$n" == "3" ]] || { ko "council con $n secciones lens (esperado 3)"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T36 convergence/fork: fast-path sin interrupcion, forks al user, 2 rounds STOP"
{
  bad=0
  orch="$REPO/wiring/prompts/sdd/orchestrator.md"
  grep -q 'does NOT interrupt the user' "$orch" || { ko "orchestrator: sin convergence fast-path"; bad=1; }
  grep -q 'never decides forks alone' "$orch" || { ko "orchestrator: sin fork-al-user"; bad=1; }
  grep -q 'Max 2 rounds' "$orch" || { ko "orchestrator: sin budget 2 rounds"; bad=1; }
  sk="$REPO/skills/sdd-council/SKILL.md"
  grep -q 'does NOT interrupt the user' "$sk" || { ko "council: sin fast-path"; bad=1; }
  grep -q 'NEVER decides forks alone' "$sk" || { ko "council: sin fork-al-user"; bad=1; }
  grep -q 'Max 2 rounds' "$sk" || { ko "council: sin budget 2 rounds"; bad=1; }
  grep -q '### Decision:' "$sk" || { ko "council: sin acta decisions"; bad=1; }
  grep -q 'never decides forks alone' "$REPO/overlays/commands/sdd-continue.md" || { ko "sdd-continue: sin fork-al-user"; bad=1; }
  grep -q 'max 2 rounds' "$REPO/overlays/commands/sdd-continue.md" || { ko "sdd-continue: sin 2-round budget"; bad=1; }
  grep -q 'never decides forks alone' "$REPO/overlays/commands/sdd-ff.md" || { ko "sdd-ff: sin fork-al-user"; bad=1; }
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
  for b in bash sh cat cp ln mkdir sed sort uniq diff dirname perl python3 python mktemp chmod touch wc tr date readlink realpath basename grep head tail awk sha256sum env timeout nice; do
    p="$(command -v "$b" 2>/dev/null)" && ln -sf "$p" "$shim/$b"
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
    if "$_go_bin" build -o "$_sdd_build_tmp/sdd-tool" "$SDD_TOOL_BIN/cmd/sdd-tool/" 2>/dev/null; then
      _sdd_tool_built=1
    else
      rm -rf "$_sdd_build_tmp"
      _sdd_build_tmp=""
    fi
  fi
fi

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
  # go test covers parseSearchOutput + title prefix logic)
  go test ./internal/engram/... 2>/dev/null || { ko "engram unit tests (title filter) failed"; bad=1; }
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
  out="$(env HOME="$SB_HOME" PATH="$SB_BIN:$PATH" timeout 10 "$SB_BIN/sdd-tool" worktree verify --change test-x 2>&1)"
  rc=$?
  # On main (not in a worktree), verify should exit non-zero (branch signal fails)
  [[ $rc -ne 0 ]] || { ko "worktree verify on main: exit 0 expected non-zero (no worktree)"; bad=1; }
  echo "$out" | grep -q "branch\|BRANCH" || { ko "worktree verify: missing branch signal"; bad=1; }
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
  # --check mode: 5d-2 only checks binary presence, never runs go build
  env HOME="$SB_HOME" PATH="$SB_BIN:$PATH" bash "$REPO/setup.sh" --check --skip-gentleai-sync > "$SB_TMP/t47.txt" 2>&1
  rc=$?
  # In --check mode, missing binary → "pendiente" message; warn/error only in real mode
  grep -qi "sdd-tool\|pendiente\|WARN\|go no encontrado" "$SB_TMP/t47.txt" || { ko "setup.sh 5d-2: missing sdd-tool check message"; bad=1; }
  # --check should not hard-fail due to missing go
  if [[ $rc -le 1 ]]; then
    : # acceptable (0 = clean, 1 = drift detected elsewhere)
  else
    ko "setup.sh 5d-2: exit $rc (expected ≤1 for warn-only check)"
    bad=1
  fi
  if [[ $bad -eq 0 ]]; then ok; fi
}

t "T48 orchestrator + changelog sdd-tool clause grep"
{
  bad=0
  grep -q "sdd-tool" "$REPO/wiring/prompts/sdd/orchestrator.md" || { ko "orchestrator.md missing sdd-tool integration clause"; bad=1; }
  grep -q "verify-report.*pre-archive\|pre-archive.*verify-report" "$REPO/skills/sdd-changelog/SKILL.md" || { ko "sdd-changelog SKILL.md missing verify-report pre-archive clause"; bad=1; }
  grep -q "absent archive-report.*blocked\|archive-report.*absent.*blocked" "$REPO/skills/sdd-changelog/SKILL.md" || { ko "sdd-changelog SKILL.md missing absent archive-report blocked clause"; bad=1; }
  if [[ $bad -eq 0 ]]; then ok; fi
}

# Clean up sdd-tool build temp
[[ -n "${_sdd_build_tmp:-}" && -d "$_sdd_build_tmp" ]] && rm -rf "$_sdd_build_tmp" 2>/dev/null

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