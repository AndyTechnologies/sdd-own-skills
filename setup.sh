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
ENV_SH="$ENV_DIR/env.sh"     # snippet POSIX (bash/zsh/sh):  export VAR='...'
ENV_FISH="$ENV_DIR/env.fish" # snippet fish:                  set -gx VAR '...'
# shell del usuario para la instruccion de source (fish no parsea `export`).
case "$(basename "${SHELL:-}")" in
  fish) shell_kind="fish" ;;
  zsh)  shell_kind="zsh" ;;
  bash) shell_kind="bash" ;;
  *)    shell_kind="otro" ;;
esac
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
mcp_report_warn=0
deps_missing=()
network_degraded=0
SELECTED_RUNTIMES=()

# ---- limpieza de tmpfiles en cualquier salida (S1) --------------------------
# El config tmp de curl contiene el token literal (curl no expande ${VAR} en -K);
# un trap EXIT garantiza que ningun early-exit entre mktemp y el rm inline deje
# residuales. Los tmpfiles se registran al crearse y el rm inline sigue cubriendo
# la ruta feliz; el trap es la red de seguridad.
CLEANUP_FILES=()
# rc se captura ANTES de limpiar y se restaura al final: el trap nunca altera
# el exit status del script, ni siquiera si rm no existe en el PATH de un
# entorno minimo (RED T17 corre setup.sh con PATH que solo tiene dirname).
trap 'rc=$?; [[ ${#CLEANUP_FILES[@]} -eq 0 ]] || rm -f "${CLEANUP_FILES[@]}" 2>/dev/null; exit "$rc"' EXIT

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
  --force                Sobrescribe config manual MCP en los merges sin pedir TTY
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
  CLEANUP_FILES+=("$tmp" "$body" "$hdr")
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
  chmod 700 "$ENV_DIR"  # S2: ajusta tambien un dir pre-existente mas permisivo
  tmp="$(mktemp "$ENV_DIR/github-mcp.env.XXXXXX")"
  CLEANUP_FILES+=("$tmp")
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

# write_env_snippet <token> — genera los snippets exportables (0600) para source
# manual en el rc del shell: env.sh (POSIX: bash/zsh/sh) y env.fish (fish usa
# `set -gx`, no parsea `export`). NO toca el rc del usuario (opcion "snippet
# manual"): solo escribe los archivos y el reporte imprime la instruccion.
# Los runtimes leen la var del entorno del proceso (opencode {env:}, pi
# bearerTokenEnv, claude ${VAR}, codex bearer_token_env_var); sin la var
# exportada, el MCP remote falla con 400. Idempotente (F2): si un snippet ya
# existe y es identico no se reescribe (RED T15 verifica no-mutacion).
write_env_snippet() {
  local token="$1" tmp mode q qf
  install -d -m 700 "$ENV_DIR"
  chmod 700 "$ENV_DIR"
  # comillas simples robustas: POSIX escapa ' como '\''; fish escapa como \'
  q="${token//\'/\'\\\'\'}"
  qf="${token//\'/\\\'}"

  # 1) env.sh — POSIX
  tmp="$(mktemp "$ENV_DIR/env.sh.XXXXXX")"
  CLEANUP_FILES+=("$tmp")
  printf '# GitHub MCP token — escrito por setup.sh (mode 0600). Source manual:\n' > "$tmp"
  printf '#   source %s\n' "$ENV_SH" >> "$tmp"
  printf 'export GITHUB_PERSONAL_ACCESS_TOKEN=%s\n' "'$q'" >> "$tmp"
  chmod 600 "$tmp"
  if [[ -f "$ENV_SH" ]] && cmp -s "$tmp" "$ENV_SH"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$ENV_SH"
    chmod 600 "$ENV_SH"
    mode="$(stat -c %a "$ENV_SH" 2>/dev/null || printf '??')"
    if [[ "$mode" != "600" ]]; then
      printf '[ERROR] modo inesperado (%s) en %s\n' "$mode" "$ENV_SH" >&2
      exit 2
    fi
  fi

  # 2) env.fish — fish shell
  tmp="$(mktemp "$ENV_DIR/env.fish.XXXXXX")"
  CLEANUP_FILES+=("$tmp")
  printf '# GitHub MCP token — escrito por setup.sh (mode 0600). Source manual:\n' > "$tmp"
  printf '#   source %s\n' "$ENV_FISH" >> "$tmp"
  printf 'set -gx GITHUB_PERSONAL_ACCESS_TOKEN %s\n' "'$qf'" >> "$tmp"
  chmod 600 "$tmp"
  if [[ -f "$ENV_FISH" ]] && cmp -s "$tmp" "$ENV_FISH"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$ENV_FISH"
    chmod 600 "$ENV_FISH"
    mode="$(stat -c %a "$ENV_FISH" 2>/dev/null || printf '??')"
    if [[ "$mode" != "600" ]]; then
      printf '[ERROR] modo inesperado (%s) en %s\n' "$mode" "$ENV_FISH" >&2
      exit 2
    fi
  fi
  snippet_written=1
}

# backup_env_file — rotacion: cp -p (preserva 0600); al sobrescribir el .bak
# previo se conserva a lo sumo UN respaldo (F5)
backup_env_file() {
  [[ -f "$ENV_FILE" ]] || return 0
  cp -p "$ENV_FILE" "$ENV_FILE.bak" || { printf '[ERROR] no se pudo respaldar %s\n' "$ENV_FILE" >&2; exit 2; }
  printf '  [ok]      env file respaldado (.bak) para rotacion\n'
}

# degrade <mensaje> — degradacion suave ante fallo de red (F5): marca la red como
# no disponible, avisa al usuario y deja que el flujo continue (NO aborta).
degrade() {
  network_degraded=1
  printf '  [aviso] %s\n' "$1"
  return 0
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
        degrade "fallo de red al validar el token; no se persiste nada"
        return 0
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

# prompt_scope_change <x-oauth-scopes> [offer_change] — avisa scopes faltantes;
# por defecto ofrece cambiar el token (una vez por run). Con offer_change=0 SOLO
# avisa (no re-pregunta el reemplazo): se usa cuando el usuario ya decidio
# conservar su token, para respetar esa decision sin insistir.
prompt_scope_change() {
  local sc="$1" offer_change="${2:-1}"
  local missing="" need ans=""
  [[ $scope_change_asked -eq 1 ]] && return
  scope_change_asked=1
  if [[ -z "$sc" ]]; then
    printf '  [aviso] token fine-grained: scopes no verificables (continua)\n'
    return
  fi
  # El header llega como "repo, read:org, workflow"; borrar SOLO los espacios
  # (conservar comas) para que el match ",$need," funcione por límite limpio.
  sc="${sc// /}"
  for need in repo read:org workflow; do
    [[ ",$sc," == *",$need,"* ]] || missing="$missing $need"
  done
  [[ -z "$missing" ]] && return
  printf '  [aviso] faltan scopes clasicos:%s (esperado: repo, read:org, workflow)\n' "$missing"
  if [[ "$offer_change" -eq 1 ]] && [[ "$MCP_MODE" == "real" ]] && [[ -t 0 ]]; then
    ans=""
    while true; do
      printf 'Cambiar el token antes de continuar? [s/N] ' >&2
      read -r ans || true
      printf '\n' >&2
      case "$ans" in
        s|S) prompt_new_token "cambio por scopes"; break ;;
        ""|n|N) break ;;
        *) printf '  [aviso] respuesta no valida (s = cambiar, N = conservar); reintento\n' >&2 ;;
      esac
    done
  fi
}

# ---------- merge (paso 5e) ---------------------------------------------------

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
    if merged="$(jq -s --indent 2 --arg k "$root_key" '.[0] as $u | .[1] as $f | $u | .[$k] = ((.[$k] // {}) * $f)' "$target" <(printf '%s\n' "$block") 2>/dev/null)"; then
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

  # C2 gate: config manual con la entrada YA presente no se pisa sin --force o
  # confirmacion TTY (la creacion aditiva — entrada ausente — nunca se gatea).
  if [[ $flag_created -eq 0 ]] && \
     jq -e --arg k "$root_key" --arg s "$server_key" '.[$k]? // empty | has($s)' "$target" >/dev/null 2>&1 && \
     ! printf '%s\n' "$merged" | diff -q - "$target" >/dev/null 2>&1; then
    if [[ $FORCE -eq 1 ]]; then
      : # --force: sobrescribir config manual
    elif [[ ! -t 0 ]]; then
      printf '  [aviso]     %s (%s.%s) difiere; requiere --force o TTY para sobrescribir config manual\n' \
        "${target#$HOME/}" "$root_key" "$server_key"
      mcp_report_pend=$((mcp_report_pend + 1))
      return 0
    else
      ans=""
      read -r -p "$(printf '  Sobrescribir config manual en %s? [y/N] ' "${target#$HOME/}")" ans || true
      case "${ans:-}" in
        y|Y) : ;;
        *)
          printf '  [aviso]     %s (%s.%s) no sobrescrito — config manual preservada\n' \
            "${target#$HOME/}" "$root_key" "$server_key"
          mcp_report_pend=$((mcp_report_pend + 1))
          return 0
          ;;
      esac
    fi
  fi

  if [[ $flag_created -eq 0 ]]; then
    local bak_path="$target.bak.$(date +%Y%m%d-%H%M%S)"
    cp -- "$target" "$bak_path" || { printf '  [ERROR]     no se pudo crear respaldo %s\n' "$bak_path" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; return 2; }
  fi
  # salida pretty (indent=2); los comentarios del .jsonc no se preservan (M3).
  printf '%s\n' "$merged" > "$target" || { printf '  [ERROR]     no se pudo escribir %s\n' "${target#$HOME/}" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; return 2; }
  printf '  [actualizado] %s (%s.%s)%s\n' "${target#$HOME/}" "$root_key" "$server_key" \
    "$([[ $flag_created -eq 1 ]] && printf ' — target creado, sin respaldo' || printf ' (respaldo en .bak.<ts>)')"
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
  # C2 gate (TOML): misma regla que json — no pisar config manual sin --force/TTY.
  if [[ $flag_created -eq 0 ]] && \
     ! printf '%s\n' "$merged" | diff -q - "$target" >/dev/null 2>&1 && \
     python3 - "$target" "$root_key" "$server_key" <<'PYEOF' 2>/dev/null
import sys, tomllib
try:
    with open(sys.argv[1], "rb") as f:
        d = tomllib.load(f)
except Exception:
    sys.exit(1)
root = d.get(sys.argv[2])
sys.exit(0 if isinstance(root, dict) and sys.argv[3] in root else 1)
PYEOF
  then
    if [[ $FORCE -eq 1 ]]; then
      : # --force: sobrescribir config manual
    elif [[ ! -t 0 ]]; then
      printf '  [aviso]     %s ([%s.%s]) difiere; requiere --force o TTY para sobrescribir config manual\n' \
        "${target#$HOME/}" "$root_key" "$server_key"
      mcp_report_pend=$((mcp_report_pend + 1))
      return 0
    else
      ans=""
      read -r -p "$(printf '  Sobrescribir config manual en %s? [y/N] ' "${target#$HOME/}")" ans || true
      case "${ans:-}" in
        y|Y) : ;;
        *)
          printf '  [aviso]     %s ([%s.%s]) no sobrescrito — config manual preservada\n' \
            "${target#$HOME/}" "$root_key" "$server_key"
          mcp_report_pend=$((mcp_report_pend + 1))
          return 0
          ;;
      esac
    fi
  fi

  if [[ $flag_created -eq 0 ]]; then
    local bak_path="$target.bak.$(date +%Y%m%d-%H%M%S)"
    cp -- "$target" "$bak_path" || { printf '  [ERROR]     no se pudo crear respaldo %s\n' "$bak_path" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; return 2; }
  fi
  printf '%s\n' "$merged" > "$target" || { printf '  [ERROR]     no se pudo escribir %s\n' "${target#$HOME/}" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; return 2; }
  printf '  [actualizado] %s ([%s.%s])%s\n' "${target#$HOME/}" "$root_key" "$server_key" \
    "$([[ $flag_created -eq 1 ]] && printf ' — target creado, sin respaldo' || printf ' (respaldo en .bak.<ts>)')"
  mcp_report_updated=$((mcp_report_updated + 1))
  return 0
}

# check_runtime_deps <envelope> <runtime> — verifica las deps opcionales de un
# envelope MCP (".deps": ["bin1", ...]) y acumula las faltantes en deps_missing
# como "dep -> MCP server_key (runtime)". Corre en check/dry/real (solo avisa).
check_runtime_deps() {
  local envelope="$1" runtime="$2"
  local deps="" dep server=""
  server="$(jget "$envelope" '.server_key // ""' 2>/dev/null || true)"
  if command -v jq >/dev/null 2>&1; then
    deps="$(jq -r '.deps[]?' "$envelope" 2>/dev/null || true)"
  elif command -v python3 >/dev/null 2>&1; then
    deps="$(python3 - "$envelope" <<'PYEOF' 2>/dev/null || true
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(0)
for dep in d.get("deps") or []:
    print(dep)
PYEOF
)"
  fi
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    if ! command -v "$dep" >/dev/null 2>&1; then
      deps_missing+=("$dep -> MCP $server ($runtime)")
    fi
  done <<< "$deps"
}

# select_runtimes — selector de runtimes para el deploy MCP (F5). Candidatos:
# union de runtimes declarados en los envelopes filtrando por presencia (misma
# regla que 5a/5f); si algun envelope declara "selectors", restringe a esa lista
# (primera no nula). Sin TTY o modo != real: seleccion automatica de todos.
# Interactivo: espacio = toggle, flechas = mover, Enter = confirmar. La seleccion
# NUNCA se persiste: rige solo para esta ejecucion (SELECTED_RUNTIMES).
select_runtimes() {
  local envelope="" runtime="" presence="" sels="" sel="" union=() list=()
  local i=0 n=0 cur=0 key="" seq="" mark="" check=""
  local envelopes_glob=("$SCRIPT_DIR"/wiring/mcp.d/*.json)
  if [[ -e "${envelopes_glob[0]}" ]]; then
    for envelope in "${envelopes_glob[@]}"; do
      runtime="$(jget "$envelope" '.runtime' 2>/dev/null)" || continue
      union+=("$runtime")
    done
  fi
  # 1) filtro por presencia
  for runtime in "${union[@]:-}"; do
    envelope="$SCRIPT_DIR/wiring/mcp.d/$runtime.json"
    presence="$(jget "$envelope" '.presence // ""' 2>/dev/null || true)"
    if [[ -z "$presence" ]] || bash -c "$presence" 2>/dev/null; then
      list+=("$runtime")
    fi
  done
  # 2) restriccion por "selectors" (primera lista no nula entre envelopes)
  for envelope in "${envelopes_glob[@]:-}"; do
    sel="$(jget "$envelope" '.selectors // null' 2>/dev/null || true)"
    if [[ -n "$sel" && "$sel" != "null" ]]; then
      sels="$sel"
      break
    fi
  done
  if [[ -n "$sels" ]]; then
    local filtered=()
    for runtime in "${list[@]:-}"; do
      if [[ "$sels" == *"\"$runtime\""* ]]; then
        filtered+=("$runtime")
      fi
    done
    list=("${filtered[@]:-}")
  fi
  if [[ ${#list[@]} -eq 0 ]]; then
    printf '  [aviso]     sin runtimes declarados/presentes para configurar\n'
    SELECTED_RUNTIMES=()
    return 0
  fi
  n=${#list[@]}
  for ((i=0; i<n; i++)); do state[$i]=1; done
  # 3) sin TTY o modo != real: todos seleccionados (no interactivo)
  if [[ ! -t 0 || "$MCP_MODE" != "real" ]]; then
    if [[ ! -t 0 ]]; then sel="sin TTY"; else sel="modo $MCP_MODE"; fi
    printf '  [ok]        selector: %s — todos los runtimes seleccionados (%s)\n' "$sel" "${list[*]}"
    SELECTED_RUNTIMES=("${list[@]:-}")
    return 0
  fi
  # 4) loop interactivo
  cur=0
  printf '  Runtimes a configurar (espacio = toggle, Enter = confirmar):\n'
  while :; do
    for ((i=0; i<n; i++)); do
      if [[ $i -eq $cur ]]; then mark='>'; else mark=' '; fi
      if [[ ${state[$i]:-0} -eq 1 ]]; then check='x'; else check=' '; fi
      printf '    %s [%s] %s\n' "$mark" "$check" "${list[$i]}"
    done
    printf '\033[%dA' "$n"
    # IFS= : read -rsn1 aplica word-splitting del token por IFS; un espacio solo
    # se dividiria en cero palabras y la tecla llegaria vacia (break inmediato).
    # Con IFS vacio el caracter crudo se preserva (idioma estandar para teclas).
    IFS= read -rsn1 key || true
    case "$key" in
      " ")
        state[$cur]=$(( 1 - ${state[$cur]:-0} ))
        ;;
      $'\e')
        IFS= read -rsn2 seq || true
        case "$seq" in
          "[A") cur=$(( (cur - 1 + n) % n )) ;;
          "[B") cur=$(( (cur + 1) % n )) ;;
        esac
        ;;
      ""|$'\n'|$'\r')
        break
        ;;
    esac
  done
  printf '\033[%dB' "$n"
  SELECTED_RUNTIMES=()
  for ((i=0; i<n; i++)); do
    if [[ ${state[$i]:-0} -eq 1 ]]; then
      SELECTED_RUNTIMES+=("${list[$i]}")
    fi
  done
  if [[ ${#SELECTED_RUNTIMES[@]} -eq 0 ]]; then
    printf '  [aviso]     ningun runtime seleccionado — no se configuran runtimes\n'
    SELECTED_RUNTIMES=("__none__")
  else
    printf '  [ok]        seleccionados: %s\n' "${SELECTED_RUNTIMES[*]}"
  fi
}

# deploy_permission_roots <runtime> <roots_json> <target> — despliega el allow de
# ~/.agent_worktrees (C2) en la config del runtime respetando MCP_MODE. Idempotente:
# si los permisos ya estan → up-to-date (sin reescritura). Mecanica por runtime:
# opencode external_directory (objeto {glob: 'allow'}), claude additionalDirectories
# + allow tool-specs (literal), pi pi-permission-modes (glob + allowWrite literal),
# codex sandbox_mode workspace-write + writable_roots (literal, TOML).
deploy_permission_roots() {
  local runtime="$1" roots="$2" target="$3"
  local st=""
  case "$runtime" in
    opencode|claude|pi)
      st="$(PERM_TARGET="$target" PERM_RUNTIME="$runtime" PERM_ROOTS="$roots" MCP_MODE="$MCP_MODE" python3 - <<'PYEOF'
import json, os, re, sys

mode = os.environ.get("MCP_MODE", "real")
target = os.environ["PERM_TARGET"]
runtime = os.environ["PERM_RUNTIME"]
try:
    roots = json.loads(os.environ["PERM_ROOTS"])
except Exception:
    print("no-parse"); sys.exit(0)

def load_jsonc(path):
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return {}
    # strip // y /* */ SOLO fuera de strings (los URLs contienen //)
    out = []
    in_str = False
    esc = False
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
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
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i < n and not (text[i] == "*" and i + 1 < n and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(c)
        i += 1
    text = "".join(out)
    text = re.sub(r",\s*([}\]])", r"\1", text)
    try:
        return json.loads(text)
    except Exception:
        return None

conf = load_jsonc(target)
if conf is None or not isinstance(conf, dict):
    print("no-parse"); sys.exit(0)

changed = False
if runtime == "opencode":
    perm = conf.setdefault("permission", {})
    if not isinstance(perm, dict):
        print("no-parse"); sys.exit(0)
    ed = perm.setdefault("external_directory", {})
    if not isinstance(ed, dict):
        # migracion: formato legacy array (contrato viejo) → objeto {item: allow}
        items = list(ed) if isinstance(ed, list) else []
        ed = {it: "allow" for it in items}
        perm["external_directory"] = ed
        changed = True
    for g in roots:
        # el patrón legacy sin punto (~/agent_worktrees) no cubre el root real
        legacy = g.replace("~/.agent_worktrees", "~/agent_worktrees", 1)
        if legacy in ed:
            del ed[legacy]
            changed = True
        if ed.get(g) != "allow":
            rebuilt = {}
            if "*" in ed:
                rebuilt["*"] = ed["*"]
            for k, v in ed.items():
                if k not in ("*", g):
                    rebuilt[k] = v
            rebuilt[g] = "allow"
            perm["external_directory"] = rebuilt
            changed = True
elif runtime == "claude":
    perms = conf.setdefault("permissions", {})
    if not isinstance(perms, dict):
        print("no-parse"); sys.exit(0)
    ad = perms.setdefault("additionalDirectories", [])
    allow = perms.setdefault("allow", [])
    for g in roots:
        lit = g[:-3] if g.endswith("/**") else g
        if lit not in ad:
            ad.append(lit); changed = True
        spec = "Read|Edit|Glob|Grep(%s)" % g
        if spec not in allow:
            allow.append(spec); changed = True
elif runtime == "pi":
    sb = conf.setdefault("sandbox", {})
    perm = conf.setdefault("permission", {})
    if not isinstance(sb, dict) or not isinstance(perm, dict):
        print("no-parse"); sys.exit(0)
    aw = sb.setdefault("allowWrite", [])
    ed = perm.setdefault("external_directory", {})
    if not isinstance(ed, dict):
        ed = {"*": "allow"}; perm["external_directory"] = ed
    # limpiar el patrón legacy sin punto (~/agent_worktrees) → no cubre el root real
    for legacy in ("~/agent_worktrees", "~/agent_worktrees/**"):
        if legacy in aw:
            aw.remove(legacy); changed = True
        if legacy in ed:
            del ed[legacy]; changed = True
    for g in roots:
        lit = g[:-3] if g.endswith("/**") else g
        if lit not in aw:
            aw.append(lit); changed = True
        if g not in ed:
            rebuilt = {}
            if "*" in ed:
                rebuilt["*"] = ed["*"]
            for k, v in ed.items():
                if k not in ("*", g):
                    rebuilt[k] = v
            rebuilt[g] = "allow"
            perm["external_directory"] = rebuilt
            changed = True

if not changed:
    print("up-to-date"); sys.exit(0)
if mode != "real":
    print("pendiente"); sys.exit(0)
os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
with open(target, "w", encoding="utf-8") as f:
    json.dump(conf, f, indent=2)
    f.write("\n")
print("actualizado")
PYEOF
)" || st="runtime-error"
      ;;
    codex)
      st="$(PERM_TARGET="$target" PERM_ROOTS="$roots" MCP_MODE="$MCP_MODE" python3 - <<'PYEOF'
import json, os, pathlib, sys
try:
    import tomllib
except ImportError:
    print("no-tomllib"); sys.exit(0)
try:
    import tomli_w
except ImportError:
    print("no-tomli-w"); sys.exit(0)

mode = os.environ.get("MCP_MODE", "real")
target = os.environ["PERM_TARGET"]
try:
    roots = json.loads(os.environ["PERM_ROOTS"])
except Exception:
    print("no-parse"); sys.exit(0)
p = pathlib.Path(target).expanduser()
conf = {}
if p.exists():
    try:
        with open(p, "rb") as f:
            conf = tomllib.load(f)
    except Exception:
        print("no-parse"); sys.exit(0)
changed = False
if conf.get("sandbox_mode") != "workspace-write":
    conf["sandbox_mode"] = "workspace-write"; changed = True
sww = conf.setdefault("sandbox_workspace_write", {})
if not isinstance(sww, dict):
    print("no-parse"); sys.exit(0)
rl = sww.setdefault("writable_roots", [])
for g in roots:
    lit = g[:-3] if g.endswith("/**") else g
    if lit not in rl:
        rl.append(lit); changed = True
if not changed:
    print("up-to-date"); sys.exit(0)
if mode != "real":
    print("pendiente"); sys.exit(0)
p.parent.mkdir(parents=True, exist_ok=True)
# dumps() a string y luego escritura: si el python fallara (excepcion inesperada)
# el archivo NO queda truncado (tomli_w.dump directo abre "w" y escribe bytes a
# un fd de texto — TypeError que ya rompia el script por set -e).
with open(p, "w", encoding="utf-8") as f:
    f.write(tomli_w.dumps(conf))
print("actualizado")
PYEOF
)" || st="runtime-error"
      ;;
    *)
      printf '%s\n' "no-runtime"
      return 0
      ;;
  esac
  case "$st" in
    up-to-date)
      printf '  [ok]        %s: permisos %s presentes\n' "$runtime" "${target#$HOME/}"
      mcp_report_ok=$((mcp_report_ok + 1)) ;;
    pendiente)
      printf '  [pendiente] %s: permisos %s se agregarian en modo real\n' "$runtime" "${target#$HOME/}"
      mcp_report_pend=$((mcp_report_pend + 1)) ;;
    actualizado)
      printf '  [actualizado] %s: permisos %s agregados\n' "$runtime" "${target#$HOME/}"
      mcp_report_updated=$((mcp_report_updated + 1)) ;;
    no-parse)
      printf '  [aviso]     %s: %s no parseable — revisar manualmente\n' "$runtime" "${target#$HOME/}" ;;
    no-tomllib|no-tomli-w)
      printf '  [aviso]     codex: modulo %s ausente (permisos omitidos)\n' "${st#no-}" ;;
    *)
      printf '  [ERROR]     %s: despliegue de permisos fallo (%s)\n' "$runtime" "$st" >&2
      mcp_report_error=$((mcp_report_error + 1)) ;;
  esac
}

# ---------- main ------------------------------------------------------------------

CHECK_SEEN=0
DRYRUN_SEEN=0
MCP_SKIP=0
FORCE_TOKEN=0
FORCE=0
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
    --force) FORCE=1; shift ;;
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
    check_runtime_deps "$envelope" "$runtime" || true
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
        printf '  [creado]    %s (target ausente, sin respaldo)\n' "${target#$HOME/}"
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
        decision_keep=1
        if [[ -t 0 ]]; then
          # Una sola decision de token: k conserva, R reemplaza. Validacion
          # estricta: ante respuesta no valida re-preguntamos (no caemos en un
          # default silencioso que el usuario no entiende).
          printf '  [info]      token existente valido (%s)\n' "$token_masked"
          ans=""
          while true; do
            printf 'Conservar el token existente? [k/R] (k = conservar, R = reemplazar) ' >&2
            read -r ans || true
            printf '\n' >&2
            case "$ans" in
              k|K) decision_keep=1; break ;;
              r|R) decision_keep=0; break ;;
              *) printf '  [aviso] respuesta no valida (k = conservar, R = reemplazar)\n' >&2 ;;
            esac
          done
        else
          ans=""
          decision_keep=1
          printf '  [aviso]     sin TTY: se conserva el token existente (no se reescribe)\n'
        fi
        if [[ $decision_keep -eq 0 ]]; then
          if [[ ! -t 0 ]]; then
            printf '[ERROR] reemplazo de token sin TTY: ejecuta interactivamente\n' >&2
            exit 1
          fi
          prompt_new_token "reemplazo del token existente"
        else
          printf '  [ok]        token existente conservado (sin reescritura)\n'
          # Ya se decidio conservar: solo avisar scopes, sin re-preguntar el reemplazo.
          prompt_scope_change "$SDD_OWN_VALIDATION_SCOPES" 0
        fi
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
          degrade "no se pudo validar el token (fallo de red) — estado no verificable"
          ;;
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

# ---- 5d preflight: sync del servidor MCP local a sdd-own -----------------------
echo "  5d — sync del servidor MCP local (srv/gh-mcp-server)"
GH_SERVER_SRC="$SCRIPT_DIR/srv/gh-mcp-server"
GH_SERVER_DEST="$ENV_DIR/srv/gh-mcp-server"
if [[ ! -d "$GH_SERVER_SRC" ]]; then
  printf '  [ERROR]     fuente del servidor no encontrada: %s\n' "$GH_SERVER_SRC" >&2
  mcp_report_error=$((mcp_report_error + 1))
  mcp_exit=2
elif [[ ! -d "$GH_SERVER_DEST" ]]; then
  if [[ "$MCP_MODE" == "check" ]]; then
    printf '  [FALTA]     %s (servidor no desplegado)\n' "${GH_SERVER_DEST#$HOME/}"
    mcp_report_pend=$((mcp_report_pend + 1))
  elif [[ "$MCP_MODE" == "dry-run" ]]; then
    printf '  [pendiente] copiar servidor MCP a %s\n' "${GH_SERVER_DEST#$HOME/}"
    mcp_report_pend=$((mcp_report_pend + 1))
  else
    mkdir -p "$(dirname "$GH_SERVER_DEST")" || { printf '  [ERROR]     no se pudo crear %s\n' "$(dirname "$GH_SERVER_DEST")" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; }
    cp -R "$GH_SERVER_SRC" "$GH_SERVER_DEST" || { printf '  [ERROR]     no se pudo copiar el servidor a %s\n' "$GH_SERVER_DEST" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; }
    printf '  [creado]    %s (servidor MCP desplegado)\n' "${GH_SERVER_DEST#$HOME/}"
    mcp_report_updated=$((mcp_report_updated + 1))
  fi
else
  gh_server_changed=0
  while IFS= read -r -d '' gh_src_file; do
    gh_rel="${gh_src_file#"$GH_SERVER_SRC"/}"
    gh_dest_file="$GH_SERVER_DEST/$gh_rel"
    if [[ ! -e "$gh_dest_file" ]] || ! diff -q "$gh_src_file" "$gh_dest_file" >/dev/null 2>&1; then
      gh_server_changed=1
      break
    fi
  done < <(find "$GH_SERVER_SRC" -type f -print0)
  if [[ $gh_server_changed -eq 1 ]]; then
    if [[ "$MCP_MODE" == "check" ]]; then
      printf '  [DESYNC]    %s difiere de la fuente del repo\n' "${GH_SERVER_DEST#$HOME/}"
      mcp_report_pend=$((mcp_report_pend + 1))
    elif [[ "$MCP_MODE" == "dry-run" ]]; then
      printf '  [pendiente] actualizar %s (difiere de la fuente)\n' "${GH_SERVER_DEST#$HOME/}"
      mcp_report_pend=$((mcp_report_pend + 1))
    else
      cp -R "$GH_SERVER_SRC/." "$GH_SERVER_DEST/" || { printf '  [ERROR]     no se pudo actualizar %s\n' "$GH_SERVER_DEST" >&2; mcp_report_error=$((mcp_report_error + 1)); mcp_exit=2; }
      printf '  [actualizado] %s\n' "${GH_SERVER_DEST#$HOME/}"
      mcp_report_updated=$((mcp_report_updated + 1))
    fi
  else
    printf '  [up-to-date] %s\n' "${GH_SERVER_DEST#$HOME/}"
    mcp_report_ok=$((mcp_report_ok + 1))
  fi
fi
echo

# ---- 5d-2 preflight: build sdd-tool (Go binary) ------------------------------------
echo "  5d-2 — build sdd-tool (Go binary)"
if command -v go >/dev/null 2>&1; then
  SDD_TOOL_BIN="$ENV_DIR/bin/sdd-tool"
  SDD_TOOL_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/srv/sdd-tool"
  if [[ -d "$SDD_TOOL_SRC" ]] && [[ -f "$SDD_TOOL_SRC/cmd/sdd-tool/main.go" ]]; then
    if [[ "$MCP_MODE" == "check" ]]; then
      if [[ -x "$SDD_TOOL_BIN" ]]; then
        printf '  [up-to-date] %s\n' "${SDD_TOOL_BIN#$HOME/}"
        mcp_report_ok=$((mcp_report_ok + 1))
      else
        printf '  [pendiente]  sdd-tool no compilado; se construira en modo real\n'
        mcp_report_pend=$((mcp_report_pend + 1))
      fi
    elif [[ "$MCP_MODE" == "dry-run" ]]; then
      printf '  [pendiente]  compilar %s (dry-run no ejecuta go build)\n' "${SDD_TOOL_BIN#$HOME/}"
      mcp_report_pend=$((mcp_report_pend + 1))
    else
      mkdir -p "$(dirname "$SDD_TOOL_BIN")"
      if go build -o "$SDD_TOOL_BIN" "$SDD_TOOL_SRC/cmd/sdd-tool/" 2>&1 && [[ -x "$SDD_TOOL_BIN" ]]; then
        chmod 755 "$SDD_TOOL_BIN"
        printf '  [compiled]   %s\n' "${SDD_TOOL_BIN#$HOME/}"
        mcp_report_updated=$((mcp_report_updated + 1))
      else
        printf '  [WARN]       go build failed; sdd-tool no disponible (no bloqueante)\n' >&2
        mcp_report_warn=$((mcp_report_warn + 1))
      fi
    fi
  else
    printf '  [skip]       srv/sdd-tool no encontrado en el repo\n'
  fi
else
  printf '  [WARN]       go no encontrado; sdd-tool no compilado (no bloqueante)\n' >&2
fi
echo

# ---- 5e selector de runtimes (F5) ---------------------------------------------------
echo "  5e — selector de runtimes"
select_runtimes
echo

# ---- 5f merges por runtime ---------------------------------------------------------
echo "  5f — merges por runtime"
for envelope in "${envelopes[@]:-}"; do
  runtime="$(jget "$envelope" '.runtime')" || continue
  presence="$(jget "$envelope" '.presence // ""')"
  if [[ -n "$presence" ]] && ! bash -c "$presence"; then continue; fi
  if [[ "${#SELECTED_RUNTIMES[@]}" -gt 0 ]] && ! [[ " ${SELECTED_RUNTIMES[*]:-} " == *" $runtime "* ]]; then
    printf '  [skip]      %s: no seleccionado en el selector\n' "$runtime"
    mcp_report_skip=$((mcp_report_skip + 1))
    continue
  fi
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
  # Placeholder del directorio propio (servidor local): se sustituye en el bloque
  # seleccionado (docker o normal) por la ruta absoluta de ~/.config/sdd-own.
  block="${block//\{\{SDD_OWN_DIR\}\}/$ENV_DIR}"
  if [[ "$merge" == "toml-section" ]]; then
    merge_toml_section "$target" "$root_key" "$server_key" "$block" "$MCP_MODE" "$created"
  else
    merge_json_key "$target" "$root_key" "$block" "$server_key" "$MCP_MODE" "$created"
  fi
done

# ---- 5g permisos de archivo: allow de ~/.agent_worktrees (C2) ------------------------
echo "  5g — permisos de ~/.agent_worktrees (C2)"
for envelope in "${envelopes[@]:-}"; do
  runtime="$(jget "$envelope" '.runtime')" || continue
  presence="$(jget "$envelope" '.presence // ""')"
  if [[ -n "$presence" ]] && ! bash -c "$presence"; then continue; fi
  if [[ "${#SELECTED_RUNTIMES[@]}" -gt 0 ]] && ! [[ " ${SELECTED_RUNTIMES[*]:-} " == *" $runtime "* ]]; then
    continue
  fi
  roots="$(jget "$envelope" '.permission_roots // null')"
  if [[ -z "$roots" || "$roots" == "null" || "$roots" == "[]" ]]; then continue; fi
  case "$runtime" in
    pi)
      target="$HOME/.pi/agent/permission-mode/permission-mode.json" ;;
    opencode)
      target="$(resolve_opencode_config)"
      [[ -n "$target" ]] || continue ;;
    *)
      target="$(jget "$envelope" '.target')"
      [[ "$target" == \~/* ]] && target="${HOME}${target#\~}" ;;
  esac
  deploy_permission_roots "$runtime" "$roots" "$target"
done

# ---- 5h snippet del shell: provision del token al entorno de los agentes -----------
echo "  5h — env snippet (source manual: token disponible para todos los runtimes)"
if [[ "$MCP_MODE" == "real" ]]; then
  if [[ -f "$ENV_FILE" ]]; then
    cur="$(read_env_token)"
    if [[ -n "$cur" ]]; then
      write_env_snippet "$cur"
      printf '  [ok]        snippets generados (0600): %s, %s\n' "${ENV_SH#$HOME/}" "${ENV_FISH#$HOME/}"
    else
      printf '  [aviso]     env file sin token — snippets no generados\n'
    fi
  else
    printf '  [aviso]     sin env file — snippets no generados\n'
  fi
elif [[ "$MCP_MODE" == "check" ]]; then
  for f in "$ENV_SH" "$ENV_FISH"; do
    if [[ -f "$f" ]]; then
      printf '  [ok]        %s presente (mode %s)\n' "${f#$HOME/}" "$(stat -c %a "$f" 2>/dev/null || printf '?')"
    else
      printf '  [pendiente] %s ausente — se genera en modo real\n' "${f#$HOME/}"
    fi
  done
else
  printf '  [pendiente] env snippets se generarian en modo real\n'
fi

# ---- reporte final ------------------------------------------------------------------
# Las deps MCP faltantes cuentan como avisos/pendientes en el resumen.
if [[ ${#deps_missing[@]} -gt 0 ]]; then
  mcp_report_pend=$((mcp_report_pend + ${#deps_missing[@]}))
fi

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
printf '  Env snippets    : %s\n' "$( [[ -f "$ENV_SH" && -f "$ENV_FISH" ]] && printf '%s (mode %s)' "${ENV_SH#$HOME/}" "$(stat -c %a "$ENV_SH" 2>/dev/null || printf '?')" || printf 'ausente' )"
printf '  Token GitHub    : %s%s\n' "$token_status" "$([[ -n "$token_masked" ]] && printf ' (%s)' "$token_masked" || true)"
printf '  MCP [up-to-date]: %d\n' "$mcp_report_ok"
printf '  MCP [actualizado]: %d\n' "$mcp_report_updated"
printf '  MCP [pendiente] : %d\n' "$mcp_report_pend"
 printf '  MCP [aviso]     : %d (runtimes ausentes / saltados)\n' "$mcp_report_skip"
 printf '  MCP [ERROR]     : %d\n' "$mcp_report_error"
 printf '  MCP [WARN]      : %d (builds no bloqueantes)\n' "$mcp_report_warn"
if [[ ${#deps_missing[@]} -gt 0 ]]; then
  printf '  Dependencias faltantes:\n'
  for dep_missing in "${deps_missing[@]}"; do
    printf '  [aviso]     %s\n' "$dep_missing"
  done
fi

if [[ "$MCP_MODE" == "real" ]] && [[ -f "$ENV_SH" && -f "$ENV_FISH" ]]; then
  printf '\n  ======== Para activar el token en los agentes (opencode, Pi, Claude, Codex) ========\n'
  case "$shell_kind" in
    fish)
      printf '  1) Agrega esta linea a tu ~/.config/fish/config.fish y abre una terminal nueva:\n'
      printf '       source %s\n' "${ENV_FISH/#$HOME/\~}"
      ;;
    bash|zsh)
      printf '  1) Agrega esta linea a tu ~/.%src (o el rc de tu shell) y abre una terminal nueva:\n' "$shell_kind"
      printf '       source %s\n' "${ENV_SH/#$HOME/\~}"
      ;;
    *)
      printf '  1) Shell no reconocido (%s). Agrega UNA de estas dos lineas a tu rc:\n' "${SHELL:-vacio}"
      printf '       bash/zsh:  source %s\n' "${ENV_SH/#$HOME/\~}"
      printf '       fish:      source %s\n' "${ENV_FISH/#$HOME/\~}"
      ;;
  esac
  printf '  2) Reinicia %s: el MCP github (remote api.githubcopilot.com) lee\n' "${SHELL:+tu agente}opencode"
  printf '     GITHUB_PERSONAL_ACCESS_TOKEN del entorno del proceso. Sin la var exportada,\n'
  printf '     el literal {env:...} queda sin resolver y el endpoint responde 400.\n'
fi

final_exit=$(( sync_exit > mcp_exit ? sync_exit : mcp_exit ))
exit "$final_exit"