# sandbox.sh — helpers de aislamiento para los RED checks de setup.sh.
# Se sourcea desde run_red_checks.sh (NO es un script ejecutable).
#
# Provee un HOME aislado con targets plausibles (opencode.jsonc, .pi, .codex),
# bins falsos por runtime, la fake API de GitHub, y run_setup/run_setup_pty que
# ejecutan setup.sh con el seam de sync y la API fake. Nada de esto toca el
# HOME real ni los configs reales del host.

SB_ROOT=""
SB_HOME=""
SB_BIN=""
SB_TMP=""
SB_PORT=""
declare -a SB_API_PIDS=()
declare -a SB_ROOTS=()

# init_sandbox — crea un sandbox fresco: HOME aislado, bin/ y tmp/.
init_sandbox() {
  SB_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sdd-red.XXXXXX")"
  SB_ROOTS+=("$SB_ROOT")
  SB_HOME="$SB_ROOT/home"
  SB_BIN="$SB_ROOT/bin"
  SB_TMP="$SB_ROOT/tmp"
  mkdir -p "$SB_HOME/.config/opencode" "$SB_HOME/.pi/agent" "$SB_HOME/.codex" \
           "$SB_HOME/.config/sdd-own" "$SB_BIN" "$SB_TMP"
  # config de opencode con mcp pre-existente (se preserva en el merge)
  printf '{\n  "mcp": {\n    "codegraph": {"command": "codegraph", "args": []}\n  }\n}\n' \
    > "$SB_HOME/.config/opencode/opencode.jsonc"
  # pi presente PERO sin target mcp.json (para el path de creación, F2)
  add_bin pi
  SB_ENV=(
    HOME="$SB_HOME"
    TMPDIR="$SB_TMP"
    OPENCODE_CONFIG=""
    MCP_DEBUG_SYNC_ARGS="$SB_TMP/sync-seam.txt"
  )
}

# add_bin <name> — stub ejecutable de runtime (exit 0)
add_bin() {
  printf '#!/usr/bin/env bash\nexit 0\n' > "$SB_BIN/$1"
  chmod +x "$SB_BIN/$1"
}

# add_bin_script <name> <script> — binario falso con cuerpo custom
add_bin_script() {
  printf '%s\n' "$2" > "$SB_BIN/$1"
  chmod +x "$SB_BIN/$1"
}

# start_fake_api [code] [scopes] [fail_first] — levanta la API fake; SB_PORT.
# Cada llamada registra su PID en SB_API_PIDS; stop_fake_api mata TODOS.
# El hijo redirige stdout/stderr a archivos del sandbox para jamás heredar los
# FDs del runner (un orphan con el pipe del runner abierto cuelga al llamador).
start_fake_api() {
  FAKE_API_CODE="${1:-200}" FAKE_API_SCOPES="${2:-repo, read:org, workflow}" \
    FAKE_API_FAIL_FIRST="${3:-0}" \
    FAKE_API_LOG="$SB_TMP/api.log" FAKE_API_CMDLINE="$SB_TMP/api.cmdlines" \
    python3 "$HELPERS/fake_api.py" > "$SB_TMP/api.port" 2> "$SB_TMP/api.stderr" &
  SB_API_PIDS+=("$!")
  local i
  for i in $(seq 1 100); do
    [[ -s "$SB_TMP/api.port" ]] && break
    sleep 0.05
  done
  SB_PORT="$(head -1 "$SB_TMP/api.port" 2>/dev/null || true)"
}

# stop_fake_api — frena TODAS las APIs fake registradas
stop_fake_api() {
  local pid
  for pid in "${SB_API_PIDS[@]:-}"; do
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  done
  for pid in "${SB_API_PIDS[@]:-}"; do
    [[ -n "$pid" ]] && wait "$pid" 2>/dev/null || true
  done
  SB_API_PIDS=()
}

# cleanup_sandboxes — borra TODOS los sandboxes creados en la corrida.
# La causa histórica de tmpfs lleno era que el trap EXIT solo paraba fake APIs
# y nunca removía $SB_ROOT; un corte de luz/internet dejaba decenas de dirs
# ~/.80MB huérfanos que convertían write errors en falsos FAILs de contrato.
cleanup_sandboxes() {
  local root
  for root in "${SB_ROOTS[@]:-}"; do
    [[ -n "$root" && -d "$root" ]] && rm -rf "$root" 2>/dev/null || true
  done
  SB_ROOTS=()
}

# api_dead_port — SB_PORT a un puerto sin listener (fallo de red determinista)
api_dead_port() {
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(f"127.0.0.1:{s.getsockname()[1]}")
s.close()
PY
}

# seed_env_file <token> — precarga el env file 0600 en el HOME del sandbox
seed_env_file() {
  umask 077
  printf 'GITHUB_PERSONAL_ACCESS_TOKEN=%s\n' "$1" > "$SB_HOME/.config/sdd-own/github-mcp.env"
  chmod 600 "$SB_HOME/.config/sdd-own/github-mcp.env"
}

# set_seam_exit <n> — exit simulado del sync para este test (gate F9)
set_seam_exit() {
  SB_ENV+=(MCP_DEBUG_SYNC_ARGS_EXIT="$1")
}

# add_env <K=V> ... — env extras para el proximo run
add_env() {
  SB_ENV+=("$@")
}

# run_setup <args...> — setup.sh en el sandbox SIEMPRE sin TTY (stdin
# /dev/null), para que el flujo no-interactivo sea determinista aunque el
# runner corra desde una terminal real (un TTY heredado haria que setup
# entrara al loop interactivo del token con el prompt invisible en el log).
# Salida en $SB_TMP/out.txt, exit en $SB_TMP/exit. Los tests que prueban
# prompts interactivos usan run_setup_pty, no esta funcion.
run_setup() {
  env "${SB_ENV[@]}" SDD_OWN_GH_API="http://$SB_PORT" PATH="$SB_BIN:$PATH" \
    bash "$REPO/setup.sh" "$@" < /dev/null > "$SB_TMP/out.txt" 2>&1
  echo $? > "$SB_TMP/exit"
}

# run_setup_pty <timeout> <prompt=answer;...> <args...> — setup.sh bajo pty;
# <prompt=answer> con \n explicito para read -r; salida en $SB_TMP/out.txt
run_setup_pty() {
  local timeout="$1" spec="$2"
  shift 2
  python3 "$HELPERS/pty_run.py" "$timeout" "$SB_TMP/out.txt" "$spec" -- \
    env "${SB_ENV[@]}" SDD_OWN_GH_API="http://$SB_PORT" PATH="$SB_BIN:$PATH" \
    bash "$REPO/setup.sh" "$@" > "$SB_TMP/pty.exit" 2>&1
  echo $? > "$SB_TMP/exit"
  SB_PTY_RC="$(cat "$SB_TMP/pty.exit")"
}

# out_contains <substring> — otra aserción cómoda
out_contains() {
  grep -qF -- "$1" "$SB_TMP/out.txt"
}

# snapshot_tree <dir> <outfile> — md5 + mtimes de todos los archivos
snapshot_tree() {
  ( cd "$1" && find . -type f -exec md5sum {} \; -exec stat -c '%n %Y' {} \; | sort ) > "$2"
}

# env_file_mtime/lines — inspección cómoda del env file
env_file_mtime() {
  stat -c %Y "$SB_HOME/.config/sdd-own/github-mcp.env" 2>/dev/null || echo 0
}
env_file_lines() {
  cat "$SB_HOME/.config/sdd-own/github-mcp.env" 2>/dev/null
}