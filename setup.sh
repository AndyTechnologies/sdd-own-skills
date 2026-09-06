#!/usr/bin/env bash
# =============================================================================
# setup.sh — setup definitivo del repo: skills (vía sync-skills.sh) + MCP GitHub
#
# Delega los pasos 0-4 a sync-skills.sh sin modificarlo, y ejecuta un paso MCP
# autocontenido (paso 5): valida el PAT de GitHub (GET /user, <=3 intentos,
# keep/replace), lo persiste en ~/.config/sdd-own/github-mcp.env (0600, fuera
# del repo) y mergea aditivamente los bloques MCP declarativos de
# wiring/mcp.d/<runtime>.json sobre la config real de cada runtime. Es el UNICO
# escritor autorizado de la clave `mcp` de la config de opencode fuera del
# pipeline de sync (excepcion sancionada; ver AGENTS.md y wiring/mcp.d/README).
#
# Flags:
#   --check                sync --check + estado MCP (sin escribir, sin preguntar)
#   --dry-run              sync dry-run + plan MCP (sin red, sin escribir)
#   --skip-gentleai-sync   se reenvia a sync-skills.sh
#   --skip-opencode        se reenvia a sync-skills.sh
#   --registries <proy>    se reenvia a sync-skills.sh
#   --skip-mcp             omite solo el paso MCP (el sync igual corre)
#   --force-mcp-token      fuerza re-prompt + re-validacion (respaldando .bak)
#
# Exits: 0 ok · 1 uso o --check con drift (token no valido) · 2 fallo de apply
#        (max(sync_exit, mcp_exit)); sync exit >= 2 omite el paso MCP (gate F9)
#
# Seams de prueba (documentados; nunca en produccion):
#   SDD_OWN_GH_API=<base>            override del endpoint (default https://api.github.com)
#   MCP_DEBUG_SYNC_ARGS=<file>       omite la delegacion a sync; escribe exit=<n> + argv (1 por linea)
#   MCP_DEBUG_SYNC_ARGS_EXIT=<n>     exit simulado para el seam (default 0)
#   SDD_OWN_DEBUG_CURL_CONFIG=<file> copia debug del config tmp de curl (contiene el token; solo diagnostico)
#   MCP_GITHUB_TRANSPORT=docker      renderiza alt_docker de cada envelope
#
# Higiene de secretos: el token jamas aparece en argv/logs/output; se lee con
# read -rs, se valida via `curl -K <tmpfile>` (header Bearer en un config 0600
# temporal, borrado al terminar) y los reportes muestran solo huella enmascarada.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$HOME/.config/sdd-own"
ENV_FILE="$ENV_DIR/github-mcp.env"
GH_API="${SDD_OWN_GH_API:-https://api.github.com}"

# ---- contadores y estado globales (reporte) ----------------------------------
sync_exit=0
mcp_exit=0
token_status="ausente"
token_masked=""
token_written=0
scope_change_asked=0
SDD_OWN_VALIDATION_SCOPES=""
mcp_report_ok=0
mcp_report_updated=0
mcp_report_pend=0
mcp_report_skip=0
mcp_report_error=0

usage() {
  cat <<'EOF'
Uso: setup.sh [flags]

  --check                Verifica sync (delegado con --check) + estado MCP sin escribir ni preguntar
  --dry-run              Ensayo: sync en dry-run + plan MCP (sin red, sin escribir)
  --skip-gentleai-sync   Se reenvia a sync-skills.sh
  --skip-opencode        Se reenvia a sync-skills.sh
  --registries <proy>    Se reenvia a sync-skills.sh
  --skip-mcp             Omite solo el paso MCP (el sync igual corre)
  --force-mcp-token      Fuerza re-prompt + re-validacion aunque exista un token valido
  -h, --help             Esta ayuda

Exits: 0 ok · 1 uso o --check con drift · 2 fallo de apply
EOF
}

# ---------- helpers ------------------------------------------------------------

# jget <archivo> <filtro-jq> — imprime el valor (raw si escalar string, JSON si objeto)
jget() {
  local file="$1" filter="$2"
  if command -v jq >/dev/null 2>&1; then
    # strings -> raw (sin comillas); objetos/arrays -> tostring (JSON compacto)
    jq -r "$filter | (if type == \"string\" then . else tostring end)" "$file" 2>/dev/null && return 0
    return 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$filter" <<'PY' 2>/dev/null && return 0
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
f = sys.argv[2].strip()
default = None
if " // " in f:
    f, _, dv = f.partition(" // ")
    default = dv.strip().strip('"')
path = [p for p in f.strip().lstrip(".").split(".") if p]
v = d
for p in path:
    v = v.get(p, None) if isinstance(v, dict) else None
    if v is None:
        break
if v is None and default is not None:
    print(default)
elif v is None:
    print("null")
elif isinstance(v, (dict, list)):
    print(json.dumps(v, ensure_ascii=False))
else:
    print(v)
PY
    return 0
  fi
  return 1
}

resolve_opencode_config() {
  if [[ -n "${OPENCODE_CONFIG:-}" ]]; then
    printf '%s\n' "$OPENCODE_CONFIG"
  elif [[ -f "$HOME/.config/opencode/opencode.jsonc" ]]; then
    printf '%s\n' "$HOME/.config/opencode/opencode.jsonc"
  elif [[ -f "$HOME/.config/opencode/opencode.json" ]]; then
    printf '%s\n' "$HOME/.config/opencode/opencode.json"
  fi
}

masked() {
  local t="$1"
  if [[ ${#t} -ge 8 ]]; then
    printf '%s....%s' "${t:0:4}" "${t: -4}"
  else
    printf '....'
  fi
}

read_env_token() {
  ( set -a; . "$ENV_FILE"; set +a; printf '%s' "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" )
}

# validate_token <token> — imprime `200|<x-oauth-scopes>` | `invalid <code>` | `network`.
# Los scopes viajan en el propio stdout (no en una global: el caller usa command
# substitution y una asignacion global dentro de ella se perderia en el sub-shell;
# ver bug de scopes corregido en este cambio).
validate_token() {
  local token="$1"
  local tmp body hdr rc=0 code sc
  tmp="$(mktemp "${TMPDIR:-/tmp}/sdd-own-curl.XXXXXX")"
  body="$(mktemp "${TMPDIR:-/tmp}/sdd-own-body.XXXXXX")"
  hdr="$(mktemp "${TMPDIR:-/tmp}/sdd-own-hdr.XXXXXX")"
  chmod 600 "$tmp"
  # F1: el token vive SOLO en el archivo de config (0600, borrado abajo), nunca
  # en argv ni en el ambiente del proceso curl. Nota de compatibilidad: curl no
  # expande ${VAR} dentro de `header =` en configs -K (verificado en 8.21), asi
  # que el valor va literal en el archivo; el 0600 + rm garantizan la higiene.
  printf '# setup.sh validate-config (0600, temporal). No commitear, no compartir.\n' > "$tmp"
  printf 'header = "Authorization: Bearer %s"\n' "$token" >> "$tmp"
  if [[ -n "${SDD_OWN_DEBUG_CURL_CONFIG:-}" ]]; then
    cp "$tmp" "$SDD_OWN_DEBUG_CURL_CONFIG"
    printf 'curl-config: %s\n' "$tmp" >&2
  fi

  curl -sS --max-time 15 -o "$body" -D "$hdr" -K "$tmp" "$GH_API/user" 2>/dev/null || rc=$?

  local ok=0
  if [[ $rc -eq 0 ]]; then
    code="$(awk 'NR==1 {print $2}' "$hdr" 2>/dev/null || true)"
    if [[ "$code" == "200" ]]; then
      # El header de GitHub termina en \r\n; el \r se quita del valor extraido.
      sc="$(awk 'tolower($1) == "x-oauth-scopes:" { sub(/^[^:]*:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit }' "$hdr" 2>/dev/null || true)"
      ok=1
      printf '200|%s\n' "$sc"
    else
      ok=1
      printf 'invalid %s\n' "${code:-?}"
    fi
  fi
  rm -f "$tmp" "$body" "$hdr"
  if [[ $ok -eq 0 ]]; then
    printf 'network\n'
  fi
}

# persist_token <token> <motivo> — escribe el env file 0600 (tmp + mv) y verifica modo
persist_token() {
  local token="$1" why="$2"
  local tmp mode
  install -d -m 700 "$ENV_DIR"
  tmp="$(mktemp "$ENV_DIR/github-mcp.env.XXXXXX")"
  printf '# GitHub MCP token - written by setup.sh (mode 0600). Rotate in the GitHub UI; do not commit.\n' > "$tmp"
  printf 'GITHUB_PERSONAL_ACCESS_TOKEN=%s\n' "$token" >> "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  mode="$(stat -c %a "$ENV_FILE" 2>/dev/null || printf '??')"
  if [[ "$mode" != "600" ]]; then
    printf '[ERROR] modo inesperado (%s) en %s\n' "$mode" "$ENV_FILE" >&2
    exit 2
  fi
  token_status="validado"
  token_masked="$(masked "$token")"
  token_written=1
  printf '  [actualizado] %s (0600) — %s\n' "${ENV_FILE#$HOME/}" "$why"
}

# backup_env_file — rotacion: cp -p (preserva 0600); al sobrescribir el .bak
# previo se conserva a lo sumo UN respaldo (F5)
backup_env_file() {
  [[ -f "$ENV_FILE" ]] || return 0
  cp -p "$ENV_FILE" "$ENV_FILE.bak" || { printf '[ERROR] no se pudo respaldar %s\n' "$ENV_FILE" >&2; exit 2; }
  printf '  [ok]      env file respaldado (.bak) para rotacion\n'
}

# prompt_new_token <motivo> — pide (read -rs), valida <=3, persiste solo con 200
prompt_new_token() {
  local why="$1"
  local tok="" st="" ok=0 try
  for try in 1 2 3; do
    printf 'Token de GitHub (PAT): ' >&2
    read -rs tok || true
    printf '\n' >&2
    if [[ -z "$tok" ]]; then
      printf '  [aviso] token vacio (intento %d/3)\n' "$try"
      continue
    fi
    st="$(validate_token "$tok")"
    case "$st" in
      "200|"*)
        SDD_OWN_VALIDATION_SCOPES="${st#200|}"
        ok=1; break ;;
      network*)
        printf '[ERROR] fallo de red al validar el token; no se persiste nada\n' >&2
        exit 2
        ;;
      *)
        printf '  [aviso] token rechazado (HTTP %s); intento %d/3\n' "${st#invalid }" "$try" ;;
    esac
  done
  if [[ $ok -eq 0 ]]; then
    printf '[ERROR] token no validado tras 3 intentos; no se persiste nada\n' >&2
    exit 2
  fi
  backup_env_file
  persist_token "$tok" "$why"
  prompt_scope_change "$SDD_OWN_VALIDATION_SCOPES"
}

# prompt_scope_change <x-oauth-scopes> — avisa scopes faltantes; ofrece cambio (una vez por run)
prompt_scope_change() {
  local sc="$1"
  local missing="" need ans=""
  [[ $scope_change_asked -eq 1 ]] && return
  scope_change_asked=1
  if [[ -z "$sc" ]]; then
    printf '  [aviso] token fine-grained: scopes no verificables (continua)\n'
    return
  fi
  # El header llega como "repo, read:org, workflow" (comas + espacios); borrar
  # separadores para que el match ",$need," funcione sobre nombres limpios.
  sc="${sc//[ ,]/}"
  for need in repo read:org workflow; do
    [[ ",$sc," == *",$need,"* ]] || missing="$missing $need"
  done
  [[ -z "$missing" ]] && return
  printf '  [aviso] faltan scopes clasicos:%s (esperado: repo, read:org, workflow)\n' "$missing"
  if [[ "$MCP_MODE" == "real" ]] && [[ -t 0 ]]; then
    printf 'Cambiar el token antes de continuar? [y/N] ' >&2
    read -r ans || true
    printf '\n' >&2
    case "$ans" in
      y|Y) prompt_new_token "cambio por scopes" ;;
    esac
  fi
}

# ---------- merge 5d ------------------------------------------------------------

create_target() {
  local target="$1" root_key="$2" merge_type="$3"
  local dir
  dir="$(dirname "$target")"
  [[ -d "$dir" ]] || mkdir -p "$dir"
  if [[ "$merge_type" == "toml-section" ]]; then
    : > "$target"
  else
    printf '{}\n' > "$target"
  fi
}

# merge_json_key <target> <root_key> <block> <server_key> <modo> <flag_created>
merge_json_key() {
  local target="$1" root_key="$2" block="$3" server_key="$4" mode="$5" flag_created="$6"
  local merged="" merged_ok=0
  if command -v jq >/dev/null 2>&1; then
    if merged="$(jq -s --arg k "$root_key" '.[0] as $u | .[1] as $f | $u | .[$k] = ((.[$k] // {}) * $f)' "$target" <(printf '%s\n' "$block") 2>/dev/null)"; then
      merged_ok=1
    fi
  fi
  if [[ $merged_ok -eq 0 ]] && command -v python3 >/dev/null 2>&1; then
    if merged="$(MERGED_ROOT="$root_key" MERGED_BLOCK="$block" python3 - "$target" <<'PYEOF' 2>/dev/null
import json, os, sys

def load_jsonc(fn):
    s = open(fn, encoding="utf-8").read()
    out, in_str, esc, i, n = [], False, False, 0, len(s)
    while i < n:
        c = s[i]
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == ",":
            j = i + 1
            while j < n and s[j] in " \t\r\n":
                j += 1
            if j < n and s[j] in "}]":
                i += 1
                continue
        out.append(c)
        i += 1
    return json.loads("".join(out))

def deep_merge(base, override):
    out = dict(base)
    for k, v in override.items():
        if isinstance(out.get(k), dict) and isinstance(v, dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out

data = load_jsonc(sys.argv[1])
root = os.environ["MERGED_ROOT"]
frag = json.loads(os.environ["MERGED_BLOCK"])
data[root] = deep_merge(data.get(root) or {}, frag)
sys.stdout.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PYEOF
)"; then
      merged_ok=1
    fi
  fi
  if [[ $merged_ok -eq 0 || -z "$merged" ]]; then
    printf '  [ERROR]     no se pudo mergear %s (%s.%s); requiere jq o python3 (archivo intacto)\n' \
      "${target#$HOME/}" "$root_key" "$server_key" >&2
    mcp_report_error=$((mcp_report_error + 1))
    mcp_exit=2
    return 2
  fi

  # no configurado aun: [pendiente] nunca es error (estado limpio valido)
  if ! jq -e --arg k "$root_key" --arg s "$server_key" '.[$k]? // empty | has($s)' "$target" >/dev/null 2>&1; then
    if [[ "$mode" == "real" ]]; then
      : # se crea/mergea abajo
    else
      printf '  [pendiente] %s (%s.%s) no configurado — estado limpio\n' "${target#$HOME/}" "$root_key" "$server_key"
      mcp_report_pend=$((mcp_report_pend + 1))
      return 0
    fi
  elif printf '%s\n' "$merged" | diff -q - "$target" >/dev/null 2>&1; then
    printf '  [up-to-date] %s (%s.%s)\n' "${target#$HOME/}" "$root_key" "$server_key"
    mcp_report_ok=$((mcp_report_ok + 1))
    return 0
  elif [[ "$mode" != "real" ]]; then
    printf '  [aviso]     %s difiere de la definicion declarada (%s.%s); config manual preservada\n' \
      "${target#$HOME/}" "$root_key" "$server_key"
    mcp_report_pend=$((mcp_report_pend + 1))
    return 0
  fi

  if [[ $flag_created -eq 0 ]] && [[ ! -e "$target.bak" ]]; then
    cp -- "$target" "$target.bak" || { printf '  [ERROR]     no se pudo crear respaldo %s\n' "$target.bak" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; return 2; }
  fi
  printf '%s\n' "$merged" > "$target" || { printf '  [ERROR]     no se pudo escribir %s\n' "${target#$HOME/}" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; return 2; }
  printf '  [actualizado] %s (%s.%s)%s\n' "${target#$HOME/}" "$root_key" "$server_key" \
    "$([[ $flag_created -eq 1 ]] && printf ' — target creado, sin .bak' || printf ' (respaldo en .bak)')"
  mcp_report_updated=$((mcp_report_updated + 1))
  return 0
}

# merge_toml_section <target> <root_key> <server_key> <block> <modo> <flag_created>
merge_toml_section() {
  local target="$1" root_key="$2" server_key="$3" block="$4" mode="$5" flag_created="$6"
  local merged
  if ! command -v python3 >/dev/null 2>&1; then
    printf '  [ERROR]     merge TOML (%s) requiere python3 (tomllib)\n' "${target#$HOME/}" >&2
    mcp_report_error=$((mcp_report_error + 1))
    mcp_exit=2
    return 2
  fi
  if ! python3 -c 'import tomli_w' >/dev/null 2>&1; then
    printf '  [ERROR]     merge TOML (%s) requiere el modulo tomli-w; se cancela sin tocar el archivo\n' "${target#$HOME/}" >&2
    mcp_report_error=$((mcp_report_error + 1))
    mcp_exit=2
    return 2
  fi
  if ! merged="$(MERGED_ROOT="$root_key" MERGED_SERVER="$server_key" MERGED_BLOCK="$block" python3 - "$target" <<'PYEOF' 2>/dev/null
import json, os, sys, tomllib

try:
    import tomli_w
except ImportError:
    sys.stderr.write("tomli_w missing\n")
    sys.exit(3)

target = sys.argv[1]
if os.path.exists(target) and os.path.getsize(target) > 0:
    with open(target, "rb") as f:
        data = tomllib.load(f)
else:
    data = {}
root = data.setdefault(os.environ["MERGED_ROOT"], {})
root[os.environ["MERGED_SERVER"]] = json.loads(os.environ["MERGED_BLOCK"])
sys.stdout.write(tomli_w.dumps(data))
PYEOF
)"; then
    printf '  [ERROR]     no se pudo mergear %s ([%s.%s]) — TOML\n' "${target#$HOME/}" "$root_key" "$server_key" >&2
    mcp_report_error=$((mcp_report_error + 1))
    mcp_exit=2
    return 2
  fi
  if printf '%s\n' "$merged" | diff -q - "$target" >/dev/null 2>&1; then
    printf '  [up-to-date] %s ([%s.%s])\n' "${target#$HOME/}" "$root_key" "$server_key"
    mcp_report_ok=$((mcp_report_ok + 1))
    return 0
  fi
  if [[ "$mode" != "real" ]]; then
    printf '  [aviso]     %s difiere de la definicion declarada ([%s.%s]); config manual preservada\n' \
      "${target#$HOME/}" "$root_key" "$server_key"
    mcp_report_pend=$((mcp_report_pend + 1))
    return 0
  fi
  if [[ $flag_created -eq 0 ]] && [[ ! -e "$target.bak" ]]; then
    cp -- "$target" "$target.bak" || { printf '  [ERROR]     no se pudo crear respaldo %s\n' "$target.bak" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; return 2; }
  fi
  printf '%s\n' "$merged" > "$target" || { printf '  [ERROR]     no se pudo escribir %s\n' "${target#$HOME/}" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; return 2; }
  printf '  [actualizado] %s ([%s.%s])%s\n' "${target#$HOME/}" "$root_key" "$server_key" \
    "$([[ $flag_created -eq 1 ]] && printf ' — target creado, sin .bak' || printf ' (respaldo en .bak)')"
  mcp_report_updated=$((mcp_report_updated + 1))
  return 0
}

# ---------- main ------------------------------------------------------------------

CHECK_SEEN=0
DRYRUN_SEEN=0
MCP_SKIP=0
FORCE_TOKEN=0
MCP_MODE="real"
SYNC_FLAGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_SEEN=1; MCP_MODE="check"; SYNC_FLAGS+=(--check); shift ;;
    --dry-run) DRYRUN_SEEN=1; MCP_MODE="dry-run"; SYNC_FLAGS+=(--dry-run); shift ;;
    --skip-gentleai-sync|--skip-opencode) SYNC_FLAGS+=("$1"); shift ;;
    --registries)
      [[ $# -ge 2 ]] || { printf 'error: --registries requiere un proyecto\n' >&2; usage; exit 1; }
      SYNC_FLAGS+=(--registries "$2"); shift 2 ;;
    --skip-mcp) MCP_SKIP=1; shift ;;
    --force-mcp-token) FORCE_TOKEN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
if [[ $CHECK_SEEN -eq 1 && $DRYRUN_SEEN -eq 1 ]]; then
  printf 'error: --check y --dry-run son mutuamente excluyentes\n' >&2
  exit 1
fi

# D13 — guardas fail-fast antes de delegar
if ! command -v curl >/dev/null 2>&1; then
  printf '[ERROR] setup.sh requiere curl (validacion del token); se cancela antes de delegar\n' >&2
  exit 2
fi
if [[ "${MCP_GITHUB_TRANSPORT:-}" == "docker" ]] && ! command -v docker >/dev/null 2>&1; then
  printf '[ERROR] MCP_GITHUB_TRANSPORT=docker requiere docker instalado\n' >&2
  exit 2
fi

echo "Paso 0 — delegacion a sync-skills.sh${SYNC_FLAGS[*]:+ (flags: ${SYNC_FLAGS[*]})}"
if [[ -n "${MCP_DEBUG_SYNC_ARGS:-}" ]]; then
  printf 'exit=%s\n' "${MCP_DEBUG_SYNC_ARGS_EXIT:-0}" > "$MCP_DEBUG_SYNC_ARGS"
  if [[ ${#SYNC_FLAGS[@]} -gt 0 ]]; then
    printf '%s\n' "${SYNC_FLAGS[@]}" >> "$MCP_DEBUG_SYNC_ARGS"
  fi
  sync_exit="${MCP_DEBUG_SYNC_ARGS_EXIT:-0}"
  printf '  [aviso] seam MCP_DEBUG_SYNC_ARGS: delegacion omitida (exit simulado=%s)\n' "$sync_exit"
else
  "$SCRIPT_DIR/sync-skills.sh" "${SYNC_FLAGS[@]}" || sync_exit=$?
fi

echo
if [[ $sync_exit -ge 2 ]]; then
  printf '[ERROR] sync-skills.sh fallo (exit %d); paso MCP omitido (gate F9)\n' "$sync_exit" >&2
  exit 2
fi

if [[ $MCP_SKIP -eq 1 ]]; then
  echo "Paso 5 — MCP de GitHub: omitido (--skip-mcp)"
  exit $sync_exit
fi

echo "Paso 5 — MCP de GitHub (modo: $MCP_MODE)"

# ---- 5a deteccion de runtimes + resolucion de targets ---------------------------
echo "  5a — deteccion de runtimes"
CREATED_TARGETS=()
envelopes=("$SCRIPT_DIR"/wiring/mcp.d/*.json)
if [[ -e "${envelopes[0]}" ]]; then
  for envelope in "${envelopes[@]}"; do
    runtime="$(jget "$envelope" '.runtime')" || { printf '  [ERROR]     envelope invalido: %s\n' "${envelope##*/}" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; continue; }
    presence="$(jget "$envelope" '.presence // ""')"
    if [[ -n "$presence" ]] && ! bash -c "$presence"; then
      printf '  [aviso]     %s: runtime ausente — definicion declarada, merge omitido\n' "$runtime"
      mcp_report_skip=$((mcp_report_skip + 1))
      continue
    fi
    target_mode="$(jget "$envelope" '.target_mode')"
    target=""
    if [[ "$target_mode" == "opencode-config" ]]; then
      target="$(resolve_opencode_config)"
      if [[ -z "$target" ]]; then
        printf '  [aviso]     opencode: sin config detectada\n'
        mcp_report_skip=$((mcp_report_skip + 1))
        continue
      fi
      printf '  [ok]        opencode: config detectada (%s)\n' "${target#$HOME/}"
    else
      target="$(jget "$envelope" '.target')"
      [[ "$target" == \~/* ]] && target="${HOME}${target#\~}"
      printf '  [ok]        %s: instalado (target %s)\n' "$runtime" "${target#$HOME/}"
    fi
    merge="$(jget "$envelope" '.merge')"
    root_key="$(jget "$envelope" '.root_key')"
    server_key="$(jget "$envelope" '.server_key')"
    if [[ ! -e "$target" ]]; then
      if [[ "$MCP_MODE" == "real" ]]; then
        create_target "$target" "$root_key" "$merge"
        printf '  [creado]    %s (target ausente, sin .bak)\n' "${target#$HOME/}"
        CREATED_TARGETS+=("$target")
      else
        printf '  [pendiente] %s: target ausente — se crearia y mergearia\n' "${target#$HOME/}"
        mcp_report_pend=$((mcp_report_pend + 1))
      fi
    fi
  done
fi

# ---- 5b + 5c gate de token y persistencia ----------------------------------------
echo "  5b — gate de token (solo modo real pide; check/dry-run no red en dry-run)"
if [[ "$MCP_MODE" == "real" ]]; then
  existing=""
  if [[ -f "$ENV_FILE" ]]; then
    existing="$(read_env_token)"
  fi
  if [[ $FORCE_TOKEN -eq 1 || -z "$existing" ]]; then
    if [[ ! -t 0 ]]; then
      printf '[ERROR] modo real sin TTY y se necesita token: ejecuta interactivamente o precarga %s (0600)\n' "$ENV_FILE" >&2
      exit 1
    fi
    prompt_new_token "$([[ $FORCE_TOKEN -eq 1 ]] && printf 'forzado por --force-mcp-token' || printf 'configuracion inicial')"
  else
    st="$(validate_token "$existing")"
    case "$st" in
      network*)
        printf '  [aviso]     sin red al validar el token existente; se conserva el env file sin reescribir\n'
        token_status="no verificable (red)"
        token_masked="$(masked "$existing")"
        ;;
      "200|"*)
        SDD_OWN_VALIDATION_SCOPES="${st#200|}"
        token_status="existente (valido)"
        token_masked="$(masked "$existing")"
        if [[ -t 0 ]]; then
          ans=""
          printf 'Mantener el token existente? [k/R] ' >&2
          read -r ans || true
          printf '\n' >&2
        else
          ans=""
          printf '  [aviso]     sin TTY: se conserva el token existente (no se reescribe)\n'
        fi
        case "$ans" in
          r|R)
            if [[ ! -t 0 ]]; then
              printf '[ERROR] reemplazo de token sin TTY: ejecuta interactivamente\n' >&2
              exit 1
            fi
            prompt_new_token "reemplazo del token existente"
            ;;
          *)
            printf '  [ok]        token existente conservado (sin reescritura)\n'
            prompt_scope_change "$SDD_OWN_VALIDATION_SCOPES"
            ;;
        esac
        ;;
      invalid*)
        printf '  [aviso]     token existente rechazado (HTTP %s)\n' "${st#invalid }"
        if [[ ! -t 0 ]]; then
          printf '[ERROR] token invalido y sin TTY: ejecuta interactivamente o precarga el env file\n' >&2
          exit 1
        fi
        prompt_new_token "reemplazo del token invalido"
        ;;
    esac
  fi
elif [[ "$MCP_MODE" == "check" ]]; then
  if [[ -f "$ENV_FILE" ]]; then
    existing="$(read_env_token)"
    if [[ -z "$existing" ]]; then
      printf '  [ok]        env file presente pero sin token (estado limpio valido)\n'
      token_status="env file sin token"
    else
      st="$(validate_token "$existing")"
      case "$st" in
        "200|"*)
          SDD_OWN_VALIDATION_SCOPES="${st#200|}"
          token_status="valido"
          printf '  [ok]        token valido (%s)\n' "$(masked "$existing")"
          prompt_scope_change "$SDD_OWN_VALIDATION_SCOPES" ;;
        invalid*)
          token_status="no valido (drift)"
          printf '  [DESYNC]    token del env file rechazado (HTTP %s) — drift\n' "${st#invalid }"
          mcp_exit=1 ;;
        network*)
          token_status="no verificable (red)"
          printf '  [ERROR]     no se pudo validar el token (fallo de red) — estado estructural\n' >&2
          mcp_exit=2 ;;
      esac
    fi
  else
    printf '  [ok]        token ausente — estado limpio valido (--check no escribe)\n'
  fi
else
  if [[ -f "$ENV_FILE" ]]; then
    printf '  [pendiente] se validaria el token existente (--dry-run no hace red)\n'
  else
    printf '  [pendiente] se pediria el token interactivamente (modo real)\n'
  fi
fi

# ---- 5d merges por runtime ---------------------------------------------------------
echo "  5d — merges por runtime"
for envelope in "${envelopes[@]:-}"; do
  runtime="$(jget "$envelope" '.runtime')" || continue
  presence="$(jget "$envelope" '.presence // ""')"
  if [[ -n "$presence" ]] && ! bash -c "$presence"; then continue; fi
  target_mode="$(jget "$envelope" '.target_mode')"
  if [[ "$target_mode" == "opencode-config" ]]; then
    target="$(resolve_opencode_config)"
    [[ -z "$target" ]] && continue
  else
    target="$(jget "$envelope" '.target')"
    [[ "$target" == \~/* ]] && target="${HOME}${target#\~}"
  fi
  [[ -e "$target" ]] || continue
  merge="$(jget "$envelope" '.merge')"
  root_key="$(jget "$envelope" '.root_key')"
  server_key="$(jget "$envelope" '.server_key')"
  created=0
  for t in "${CREATED_TARGETS[@]:-}"; do
    [[ "$t" == "$target" ]] && { created=1; break; }
  done
  if [[ "${MCP_GITHUB_TRANSPORT:-}" == "docker" ]]; then
    block="$(jget "$envelope" '.alt_docker')"
    if [[ -z "$block" || "$block" == "null" ]]; then
      printf '  [ERROR]     %s: MCP_GITHUB_TRANSPORT=docker sin alt_docker\n' "$runtime" >&2
      mcp_report_error=$((mcp_report_error + 1))
      mcp_exit=2
      continue
    fi
    block="${block//\{\{ENV_FILE\}\}/$ENV_FILE}"
    printf '  [ok]        %s: variante docker declarada ({{ENV_FILE}} -> %s)\n' "$runtime" "${ENV_FILE#$HOME/}"
  else
    block="$(jget "$envelope" '.block')"
  fi
  if [[ "$merge" == "toml-section" ]]; then
    merge_toml_section "$target" "$root_key" "$server_key" "$block" "$MCP_MODE" "$created"
  else
    merge_json_key "$target" "$root_key" "$block" "$server_key" "$MCP_MODE" "$created"
  fi
done

# ---- reporte final ------------------------------------------------------------------
echo
echo "=================================================="
echo "Resumen:"
printf '  Sync skills     : exit %s\n' "$sync_exit"
if [[ $MCP_SKIP -eq 1 ]]; then
  printf '  Paso MCP        : omitido (--skip-mcp)\n'
else
  printf '  Paso MCP        : %s\n' "$MCP_MODE"
fi
printf '  Env file        : %s\n' "$( [[ -f "$ENV_FILE" ]] && printf '%s (mode %s)' "${ENV_FILE#$HOME/}" "$(stat -c %a "$ENV_FILE" 2>/dev/null || printf '?')" || printf 'ausente' )"
printf '  Token GitHub    : %s%s\n' "$token_status" "$([[ -n "$token_masked" ]] && printf ' (%s)' "$token_masked" || true)"
printf '  MCP [up-to-date]: %d\n' "$mcp_report_ok"
printf '  MCP [actualizado]: %d\n' "$mcp_report_updated"
printf '  MCP [pendiente] : %d\n' "$mcp_report_pend"
printf '  MCP [aviso]     : %d (runtimes ausentes / saltados)\n' "$mcp_report_skip"
printf '  MCP [ERROR]     : %d\n' "$mcp_report_error"

final_exit=$(( sync_exit > mcp_exit ? sync_exit : mcp_exit ))
exit "$final_exit"