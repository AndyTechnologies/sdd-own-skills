#!/usr/bin/env bash
# =============================================================================
# cleanup-sdd-own.sh — retira artefactos sdd-own obsoletos tras un rename.
#
# El sync (`sync-skills.sh`) instala nombres nuevos pero NUNCA poda: tras
# renombrar una skill o prompt propio (ej. sdd-product-quest -> product-quest)
# quedan copias originales en ~/.config/sdd-own/ y symlinks en los directorios
# de agentes con el nombre viejo. Este script elimina SOLO esos artefactos.
#
# Contrato de seguridad (idéntico en espíritu a sync-skills.sh):
#   --check      lectura: lista lo obsoleto; exit 0 si limpio, 1 si hay trabajo.
#   --dry-run    ensayo: imprime los rm EXACTOS que correría; no muta nada.
#   (sin flag)   real: imprime el plan y pide confirmación (y/N); con --yes
#                salta el prompt (requerido si no hay TTY).
#   -h/--help    uso.
#   Flag desconocido o mezcla --check+--dry-run -> exit 1.
#
# Rejas de seguridad:
#   R1. La "verdad" canónica es ESTE repo: skills/<dir>/ y
#       wiring/prompts/sdd/*.md. Un artefacto es obsoleto solo si su nombre no
#       tiene contraparte canónica aquí.
#   R2. En los directorios de agentes se eliminan SOLO symlinks cuyo target
#       apunta dentro de $SDD_OWN_DIR (nunca un directorio/archivo real, nunca
#       un symlink ajeno). Los `sdd-*` nativos de Alan son directorios reales
#       o simlinks de gentle-ai: jamás coinciden con ese criterio.
#   R3. `_shared` se excluye SIEMPRE (lo comparte Alan en ~/.agents/skills y
#       los agentes symlinkean a ese directorio compartido, no a sdd-own).
#   R4. SUCESOR REQUERIDO, en tres clases:
#       a) sucesor canónico del repo YA instalado -> se elimina (rename hecho).
#       b) sucesor canónico del repo SIN desplegar -> bloquea TODO el modo real
#          con 'corré ./sync-skills.sh real primero' (el sync lo va a instalar;
#          hasta entonces NO se elimina NADA, exit 1).
#       c) SIN contraparte canónica (poda/eliminación, ej. sdd-council tras la
#          poda v3) o SIN prefijo sdd- -> purgable SOLO con --purge-manual
#          explícito; sin ese flag quedan [MANUAL] y NO bloquean la limpieza
#          de las clases a/b.
#   R5. Un original de $SDD_OWN_DIR solo se elimina si tras quitar los
#       symlinks viejos NO queda ningún symlink apuntándolo (nunca se borra
#       una copia todavía referenciada).
#   R6. rm SIEMPRE con paths exactos (nunca globs) tras pasar los filtros.
#   R7. El target de un symlink se RESUELVE (readlink -f) antes de decidir si
#       apunta dentro de $SDD_OWN_DIR. El matcheo por el texto del target
#       guardado se rompe según cómo cada runtime escribe la ruta relativa
#       (opencode guarda ../../../sdd-own/..., claude ../../../.config/sdd-own/...):
#       un symlink obsoleto nunca debe quedar sin detectar ni borrar.
#   R8. --purge-manual es opt-in EXPLÍCITO y alcanza SOLO la clase c. Las
#       anomalías estructurales (sin SKILL.md, symlink dentro de sdd-own) NUNCA
#       se purgan. El gate STALE (clase b) sigue bloqueando TODO el modo real,
#       incluso con --purge-manual.
#   R9. R9 — obsolete agents in the real opencode config (opencode.jsonc|.json)
#       are pruned ONLY when DERIVED as stale: a {file:./prompts/sdd/*.md}
#       prompt whose file is missing or a <=1-byte tombstone, or an inline
#       prompt referencing ~/<agent-dir>/<skill>/SKILL.md whose skill dir is
#       not deployed. Everything else in the config is preserved byte-for-byte
#       (including the inline gentle-orchestrator prompt); a .bak.sdd-own
#       backup is taken before pruning and auto-restored if post-prune
#       validation fails. Tombstone prompt files (<=1 byte, regular files) in
#       the agent prompt dirs are class-c orphans: purgeable ONLY with
#       --purge-manual. Needs python3 (JSONC parsing); without it and with a
#       config present the script errors with exit 2.
#
# Orden correcto: ./sync-skills.sh (real) primero, luego este script.
# El refresh del registro local es aparte: ./sync-skills.sh --registries <proj>.
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${SDD_OWN_REPO:-$SCRIPT_DIR}"
HOME_DIR="${HOME:-}"
SDD_OWN="${SDD_OWN_DIR:-$HOME_DIR/.config/sdd-own}"

AGENT_SKILL_DIRS=("$HOME_DIR/.agents/skills" "$HOME_DIR/.config/opencode/skills" "$HOME_DIR/.claude/skills")
AGENT_PROMPT_DIRS=("$HOME_DIR/.config/opencode/prompts/sdd" "$HOME_DIR/.claude/prompts/sdd")

MODE="real"
YES=0
PURGE=0                 # 1 = --purge-manual activo (opt-in explícito)

usage() {
  cat <<'EOF'
Uso: cleanup-sdd-own.sh [--check | --dry-run] [--yes] [--purge-manual] [-h]

Retira artefactos sdd-own obsoletos (copias originales en ~/.config/sdd-own y
symlinks de agentes) cuyo nombre no tiene contraparte canónica en el repo y
cuyo sucesor ya está instalado. Corre DESPUÉS de ./sync-skills.sh real.

  --check        lista lo obsoleto; exit 0 = limpio, 1 = hay trabajo.
  --dry-run      imprime el plan sin mutar nada (--check y --dry-run son
                 excluyentes).
  --yes          en modo real, salta la confirmación interactiva.
  --purge-manual en modo real, elimina además los obsoletos sin contraparte
                 canónica (huérfanos de poda, ej. sdd-council) y los sin
                 prefijo sdd- que figuran como [MANUAL]. Nunca toca anomalías
                 estructurales (sin SKILL.md, symlink en sdd-own).
  -h, --help     este mensaje.

Obsolete agents in the opencode config (opencode.jsonc|.json):
  --check/--dry-run report derived stale agents ([CFG] / WOULD-EDIT lines);
  real mode prunes them from the config preserving everything else
  byte-for-byte (auto backup .bak.sdd-own, restored if validation fails).

Variables de entorno para pruebas/aislamiento:
  SDD_OWN_DIR   raíz canónica sdd-own (default $HOME/.config/sdd-own)
  SDD_OWN_REPO  repo cuya skills/ y wiring/prompts/sdd definen los canónicos
EOF
}

for arg in "$@"; do
  case "$arg" in
    --check)
      [[ "$MODE" == "real" ]] || { echo "error: --check y --dry-run son excluyentes" >&2; exit 1; }
      MODE="check"
      ;;
    --dry-run)
      [[ "$MODE" == "real" ]] || { echo "error: --check y --dry-run son excluyentes" >&2; exit 1; }
      MODE="dry"
      ;;
    --yes) YES=1 ;;
    --purge-manual) PURGE=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "error: flag desconocido: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ -n "$HOME_DIR" ]] || { echo "error: HOME vacío" >&2; exit 2; }

# ---------------------------------------------------------------------------
# 0b. R9 — opencode config helpers (detect/prune obsolete agents)
# ---------------------------------------------------------------------------
find_config_file() { # echo the opencode config (jsonc preferred) or nothing
  local cfg="$HOME_DIR/.config/opencode/opencode.jsonc"
  [[ -f "$cfg" ]] || cfg="$HOME_DIR/.config/opencode/opencode.json"
  [[ -f "$cfg" ]] || return 1
  echo "$cfg"
}

cfg_python() { # $1 mode (detect|prune), $2 config, $3 HOME_DIR
  python3 - "$1" "$2" "$3" <<'PYEOF'
import json, os, re, sys

def fail(msg):
    print("error: %s" % msg, file=sys.stderr)
    sys.exit(4)

mode, config, runtime = sys.argv[1], sys.argv[2], sys.argv[3]
cfg_dir = os.path.dirname(config)
try:
    raw = open(config, encoding="utf-8").read()
except OSError as e:
    fail("cannot read %s: %s" % (config, e))

def strip_jsonc(s):
    out = []
    n = len(s)
    i = 0
    state = "NORMAL"  # NORMAL | STRING | LINE | BLOCK
    while i < n:
        c = s[i]
        if state == "STRING":
            out.append(c)
            if c == "\\":
                i += 1
                if i < n:
                    out.append(s[i])
                i += 1
            elif c == '"':
                state = "NORMAL"
                i += 1
            else:
                i += 1
            continue
        if state == "LINE":
            if c == "\n":
                state = "NORMAL"
                out.append(c)
            i += 1
            continue
        if state == "BLOCK":
            if c == "*" and i + 1 < n and s[i + 1] == "/":
                state = "NORMAL"
                i += 2
            else:
                i += 1
            continue
        if c == '"':
            state = "STRING"
            out.append(c)
            i += 1
        elif c == "/" and i + 1 < n and s[i + 1] == "/":
            state = "LINE"
            i += 2
        elif c == "/" and i + 1 < n and s[i + 1] == "*":
            state = "BLOCK"
            i += 2
        elif c == ",":
            j = i + 1
            while j < n:
                ch = s[j]
                if ch in " \t\r\n":
                    j += 1
                    continue
                if ch == "/" and j + 1 < n and s[j + 1] == "/":
                    k2 = s.find("\n", j)
                    j = n if k2 < 0 else k2 + 1
                    continue
                if ch == "/" and j + 1 < n and s[j + 1] == "*":
                    k2 = s.find("*/", j + 2)
                    j = n if k2 < 0 else k2 + 2
                    continue
                break
            if j < n and s[j] in "}]":
                i += 1  # tolerate trailing comma (comments may sit between)
            else:
                out.append(c)
                i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out)

def load_text(s):
    try:
        return json.loads(strip_jsonc(s))
    except Exception as e:
        fail("cannot parse config: %s" % e)

def prompt_file_ok(ref):
    # Any {file:...} reference: resolve relative to the config dir, as an
    # absolute path, or relative to the config dir for bare tokens; a missing
    # or <=1-byte target marks the agent stale.
    if ref.startswith("/"):
        p = ref
    elif ref.startswith("./"):
        p = os.path.join(cfg_dir, ref[2:])
    else:
        p = os.path.join(cfg_dir, ref)
    try:
        return os.stat(p).st_size > 1
    except OSError:
        return False

SKILL_RE = re.compile(r"~/(\.agents/skills|\.config/opencode/skills|\.claude/skills)/([^/]+)/SKILL\.md")

def missing_skills(prompt):
    missing = []
    for m in SKILL_RE.finditer(prompt):
        skill = m.group(2)
        if skill == "_shared":
            continue
        if not os.path.isdir(os.path.join(runtime, m.group(1), skill)):
            missing.append(m.group(0))
    return missing

def stale_agents(data):
    stale = []
    agents = data.get("agent")
    if not isinstance(agents, dict):
        return stale
    for name, body in agents.items():
        if name == "gentle-orchestrator":
            continue
        body = body if isinstance(body, dict) else {}
        prompt = body.get("prompt")
        if not isinstance(prompt, str):
            continue
        if prompt.startswith("{file:"):
            m = re.match(r"^\{file:(.*)\}$", prompt, re.S)
            if m:
                if prompt_file_ok(m.group(1)) is False:
                    stale.append(name)
            else:
                stale.append(name)  # malformed {file: reference never resolves
            continue
        if missing_skills(prompt):
            stale.append(name)
    return stale

def string_end(s, i):
    n = len(s)
    j = i + 1
    while j < n:
        c = s[j]
        if c == "\\":
            j += 2
        elif c == '"':
            return j
        else:
            j += 1
    return n - 1

def skip_ws_comments(s, i):
    n = len(s)
    while i < n:
        c = s[i]
        if c in " \t\r\n":
            i += 1
            continue
        if c == "/" and i + 1 < n and s[i + 1] == "/":
            j = s.find("\n", i)
            i = n if j < 0 else j + 1
            continue
        if c == "/" and i + 1 < n and s[i + 1] == "*":
            j = s.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        break
    return i

def value_end(s, i):
    n = len(s)
    c = s[i]
    if c == '"':
        return string_end(s, i)
    if c in "{[":
        depth = 0
        j = i
        while j < n:
            ch = s[j]
            if ch == '"':
                j = string_end(s, j) + 1
                continue
            if ch == "/" and j + 1 < n and s[j + 1] == "/":
                k = s.find("\n", j)
                j = n if k < 0 else k + 1
                continue
            if ch == "/" and j + 1 < n and s[j + 1] == "*":
                k = s.find("*/", j + 2)
                j = n if k < 0 else k + 2
                continue
            if ch in "{[":
                depth += 1
            elif ch in "}]":
                depth -= 1
                if depth == 0:
                    return j
            j += 1
        return n - 1
    last = i  # primitive: track last non-ws char before the terminator
    j = i
    while j < n:
        ch = s[j]
        if ch in ",}]":
            return last
        if ch == "/" and j + 1 < n and s[j + 1] == "/":
            k = s.find("\n", j)
            j = n if k < 0 else k + 1
            continue
        if ch == "/" and j + 1 < n and s[j + 1] == "*":
            k = s.find("*/", j + 2)
            j = n if k < 0 else k + 2
            continue
        if ch not in " \t\r\n":
            last = j
        j += 1
    return last

data = load_text(raw)
stale = stale_agents(data)
if mode == "detect":
    for nm in sorted(stale):
        print(nm)
    sys.exit(0)

if not stale:
    sys.exit(0)

# Locate agent-registry keys (depth 2, inside the value of the root "agent" key)
n = len(raw)
i = 0
depth = 0
stack = {}          # depth -> bool: inside the agent registry object
last_key = {}       # depth -> most recent key name at that depth
reg_open = -1
key_positions = []  # (quote_pos, name)
while i < n:
    c = raw[i]
    if c in " \t\r\n":
        i += 1
        continue
    if c == "/":
        if i + 1 < n and raw[i + 1] == "/":
            j = raw.find("\n", i)
            i = n if j < 0 else j + 1
        elif i + 1 < n and raw[i + 1] == "*":
            j = raw.find("*/", i + 2)
            i = n if j < 0 else j + 2
        else:
            i += 1
        continue
    if c == '"':
        e = string_end(raw, i)
        name = raw[i + 1:e]
        k = skip_ws_comments(raw, e + 1)
        if k < n and raw[k] == ":":
            last_key[depth] = name
            if depth == 2 and stack.get(2):
                key_positions.append((i, name))
        i = e + 1
        continue
    if c in "{[":
        parent_key = last_key.get(depth)
        depth += 1
        if c == "{":
            inside = parent_key == "agent"
            stack[depth] = inside
            if inside and depth == 2:
                reg_open = i
        else:
            stack[depth] = False
        i += 1
        continue
    if c in "}]":
        depth = max(0, depth - 1)
        i += 1
        continue
    i += 1

if reg_open < 0 or not key_positions:
    fail("agent registry not located; refusing to prune")

all_spans = []  # (name, key_start, value_end) for every registry key
for pos, nm in key_positions:
    e = string_end(raw, pos)
    k = skip_ws_comments(raw, e + 1)
    if k >= n or raw[k] != ":":
        continue
    k2 = skip_ws_comments(raw, k + 1)
    if k2 >= n:
        continue
    all_spans.append((nm, pos, value_end(raw, k2)))
all_spans.sort(key=lambda t: t[1])
if not all_spans:
    fail("no registry keys found; refusing to prune")

last_key_ve = all_spans[-1][2]
ranges = []
run = []

def flush_run():
    global run
    if not run:
        return
    first_ks = run[0][1]
    last_ve = run[-1][2]
    is_last_run = last_ve == last_key_ve
    prev_ve = None
    for (nm2, ks2, ve2) in all_spans:
        if ks2 < first_ks:
            prev_ve = ve2
        else:
            break
    if is_last_run:
        # Remove only the run itself (first_ks..last_ve) unless it starts
        # right after whitespace, so any comment between the previous keep key
        # (or the registry open) and the run survives. When it does start right
        # after whitespace, extend over the preceding comma to avoid a trailing
        # comma; otherwise the trailing comma is JSONC-legal and keeps the
        # comment intact.
        start = first_ks
        if prev_ve is None:
            anchor = reg_open + 1
            j2 = anchor
            while j2 < n and raw[j2] in " \t\r\n":
                j2 += 1
            if j2 < n and raw[j2] == '"':
                start = anchor
        else:
            anchor = skip_ws_comments(raw, prev_ve + 1)
            if anchor < n and raw[anchor] == ",":
                j3 = anchor + 1
                while j3 < n and raw[j3] in " \t\r\n":
                    j3 += 1
                if j3 < n and raw[j3] == '"':
                    start = anchor
        end = last_ve
    else:
        start = first_ks
        k = skip_ws_comments(raw, last_ve + 1)
        if k < n and raw[k] == ",":
            j2 = k + 1
            while j2 < n and raw[j2] in " \t\r\n":
                j2 += 1
            end = j2 - 1
        else:
            end = last_ve
    ranges.append((start, end))
    run = []

for span in all_spans:
    if span[0] in stale:
        run.append(span)
    else:
        flush_run()
flush_run()

if not ranges:
    fail("no removable ranges computed; refusing to prune")

new_raw = raw
for s, e in sorted(ranges, key=lambda t: -t[0]):
    new_raw = new_raw[:s] + new_raw[e + 1:]

new_data = load_text(new_raw)
leftover = stale_agents(new_data)
if leftover:
    fail("prune validation: stale agents remain: %s" % sorted(leftover))
keep_before = {nm for nm, _, _ in all_spans if nm not in stale}
keep_after = set(new_data.get("agent", {}).keys())
if keep_before != keep_after:
    lost = sorted(keep_before - keep_after)
    added = sorted(keep_after - keep_before)
    fail("prune validation: keep agents changed; lost=%s added=%s" % (lost, added))

tmp = config + ".sdd-own.tmp"
try:
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(new_raw)
        f.flush()
        os.fsync(f.fileno())
    st = os.stat(config)
    os.chmod(tmp, st.st_mode)
    os.replace(tmp, config)
except OSError as e:
    fail("cannot write %s: %s" % (config, e))
sys.exit(0)
PYEOF
}

CONFIG_FILE=""
CFG_PY=""
command -v python3 >/dev/null 2>&1 && CFG_PY="$(command -v python3)"
CONFIG_FILE="$(find_config_file)"
if [[ -n "$CONFIG_FILE" && -z "$CFG_PY" ]]; then
  echo "error: python3 requerido para inspeccionar el config de opencode ($CONFIG_FILE)" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# 1. Canónicos del repo
# ---------------------------------------------------------------------------
skill_canons=()
for d in "$REPO"/skills/*/; do
  [[ -d "$d" ]] || continue
  b="$(basename "$d")"
  [[ "$b" == "_shared" ]] && continue
  skill_canons+=("$b")
done
prompt_canons=()
for f in "$REPO"/wiring/prompts/sdd/*.md; do
  [[ -f "$f" ]] || continue
  prompt_canons+=("$(basename "$f")")
done
if [[ ${#skill_canons[@]} -eq 0 || ${#prompt_canons[@]} -eq 0 ]]; then
  echo "error: no se pudieron resolver los canónicos del repo ($REPO)" >&2
  exit 2
fi

in_canon() { # $1 nombre, resto = lista canónica
  local n="$1"; shift
  local c
  for c in "$@"; do [[ "$c" == "$n" ]] && return 0; done
  return 1
}

# ---------------------------------------------------------------------------
# 2. Inventario de obsoletos
# ---------------------------------------------------------------------------
declare -a RM_LINKS=()      # symlinks exactos a eliminar
declare -a RM_ORIG=()       # originales exactos a eliminar
declare -a MANUAL=()        # obsoletos sin sucesor/prefijo: revisión manual
declare -a PURGE_ORIG=()    # obsoletos clase c: purgables SOLO con --purge-manual
declare -a CFG_STALE=()     # agentes obsoletos derivados en el config de opencode
SYNC_FIRST=0                # 1 = falta desplegar sucesores -> no mutar nada

# is_link_into <path> <subpath-prefix> -> 0 si el symlink apunta dentro de sdd-own
is_link_into() {
  [[ -L "$1" ]] || return 1
  local raw t
  raw="$(readlink "$1" 2>/dev/null || true)"
  case "$raw" in
    /*) t="$raw" ;;
    *)  t="$(cd "$(dirname "$1")" && readlink -f "$1" 2>/dev/null || echo "$raw")" ;;
  esac
  case "$t" in
    "$SDD_OWN"/*) [[ "$t" == "$2"* ]] && return 0 ;;
  esac
  return 1
}

# referrer_count <basename> <nombre-original> -> cuenta symlinks de agentes
# cuyo target contiene el path original
referrer_count() {
  local base="$1" orig="$2" n=0 d e raw t
  for d in "${AGENT_SKILL_DIRS[@]}" "${AGENT_PROMPT_DIRS[@]}"; do
    [[ -d "$d" ]] || continue
    for e in "$d"/*; do
      [[ -L "$e" ]] || continue
      raw="$(readlink "$e" 2>/dev/null || true)"
      case "$raw" in
        /*) t="$raw" ;;
        *)  t="$(cd "$(dirname "$e")" && readlink -f "$e" 2>/dev/null || echo "$raw")" ;;
      esac
      case "$t" in
        *"$base"*) n=$((n + 1)) ;;
      esac
    done
  done
  echo "$n"
}

# scan_sddo <directorio> <tipo> <prefijo-target-agentes> <lista canonica...>
#   tipo = skills|prompts -> determina suffijo y sucesor
scan_dir() { # $1 dir raíz bajo SDD_OWN, $2 tipo, resto = canónicos
  local dir="$1" tipo="$2"; shift 2
  local e name succ orig succ_path
  for e in "$dir"/*; do
    [[ -e "$e" || -L "$e" ]] || continue
    name="$(basename "$e")"
    [[ "$name" == "_shared" ]] && continue
    in_canon "$name" "$@" && continue      # canónico actual -> nunca obsoleto
    succ="${name#sdd-}"
    if [[ -L "$e" ]]; then
      # symlink dentro de sdd-own: nunca borramos symlinks aquí (raro); revisión
      MANUAL+=("$e (symlink en sdd-own, revisar)")
      continue
    fi
    if [[ "$tipo" == "skills" ]]; then
      [[ -f "$e/SKILL.md" ]] || { MANUAL+=("$e (sin SKILL.md, revisar)"); continue; }
      succ_path="$SDD_OWN/skills/$succ"
    else
      succ_path="$SDD_OWN/prompts/sdd/$succ"
    fi
    if [[ "$succ" != "$name" && -e "$succ_path" ]]; then
      RM_ORIG+=("$e")
    elif [[ "$succ" != "$name" ]]; then
      if in_canon "$succ" "$@"; then
        SYNC_FIRST=1
        MANUAL+=("$e (sucesor canónico '$succ' sin desplegar: corré ./sync-skills.sh real primero)")
      else
        PURGE_ORIG+=("$e")
        MANUAL+=("$e (sin contraparte canónica '$succ': huérfano de poda — purgable SOLO con --purge-manual)")
      fi
    else
      PURGE_ORIG+=("$e")
      MANUAL+=("$e (obsoleto sin prefijo sdd- ni sucesor: purgable SOLO con --purge-manual)")
    fi
  done
}

scan_dir "$SDD_OWN/skills" skills "${skill_canons[@]}"
[[ -d "$SDD_OWN/prompts/sdd" ]] && scan_dir "$SDD_OWN/prompts/sdd" prompts "${prompt_canons[@]}"

# Symlinks obsoletos en los directorios de agentes (SOLO symlinks -> sdd-own)
scan_links() { # $1 dir, $2 prefijo target sdd-own, resto = canónicos
  local dir="$1" prefix="$2"; shift 2
  [[ -d "$dir" ]] || return 0
  local e name
  for e in "$dir"/*; do
    [[ -L "$e" ]] || continue
    name="$(basename "$e")"
    [[ "$name" == "_shared" ]] && continue
    in_canon "$name" "$@" && continue
    is_link_into "$e" "$prefix" && RM_LINKS+=("$e")
  done
}

scan_links "$HOME_DIR/.agents/skills" "$SDD_OWN/skills" "${skill_canons[@]}"
scan_links "$HOME_DIR/.config/opencode/skills" "$SDD_OWN/skills" "${skill_canons[@]}"
scan_links "$HOME_DIR/.claude/skills" "$SDD_OWN/skills" "${skill_canons[@]}"
scan_links "$HOME_DIR/.config/opencode/prompts/sdd" "$SDD_OWN/prompts/sdd" "${prompt_canons[@]}"
scan_links "$HOME_DIR/.claude/prompts/sdd" "$SDD_OWN/prompts/sdd" "${prompt_canons[@]}"

# Tombstones (regular files <= 1 byte) in the agent prompt dirs: leftovers of
# the poda rename era, class-c orphans -> purgeable ONLY with --purge-manual
scan_tombstones() { # $1 dir, resto = canónicos
  local dir="$1"; shift
  [[ -d "$dir" ]] || return 0
  local e name sz
  for e in "$dir"/*; do
    [[ -f "$e" && ! -L "$e" ]] || continue
    name="$(basename "$e")"
    [[ "$name" == "_shared" ]] && continue
    in_canon "$name" "$@" && continue
    sz="$(wc -c < "$e" 2>/dev/null || echo 0)"
    [[ "$sz" -le 1 ]] || continue
    PURGE_ORIG+=("$e")
    MANUAL+=("$e (tombstone <=1 byte en dir de prompts de agente: purgable SOLO con --purge-manual)")
  done
}
scan_tombstones "$HOME_DIR/.config/opencode/prompts/sdd" "${prompt_canons[@]}"
scan_tombstones "$HOME_DIR/.claude/prompts/sdd" "${prompt_canons[@]}"

# R9 — obsolete agents in the real opencode config (derived detection)
CFG_STALE=()
if [[ -n "$CONFIG_FILE" && -n "$CFG_PY" ]]; then
  cfg_tmp="$(mktemp)"
  if ! cfg_python detect "$CONFIG_FILE" "$HOME_DIR" > "$cfg_tmp"; then
    echo "error: no se pudo inspeccionar el config de opencode ($CONFIG_FILE)" >&2
    rm -f "$cfg_tmp"
    exit 2
  fi
  while IFS= read -r a; do CFG_STALE+=("$a"); done < "$cfg_tmp"
  rm -f "$cfg_tmp"
fi

# ---------------------------------------------------------------------------
# 3. Reporte
# ---------------------------------------------------------------------------
work=0
report_plan() { # $1 modo (check|dry|real)
  local m="$1"
  if [[ "$SYNC_FIRST" -eq 1 ]]; then
    echo "[STALE] faltan sucesores canónicos por desplegar: corré ./sync-skills.sh real primero"
  fi
  local p
  for p in "${RM_LINKS[@]}"; do echo "$m: symlink obsoleto: $p"; work=1; done
  for p in "${RM_ORIG[@]}"; do echo "$m: original obsoleto: $p"; work=1; done
  local a q u
  for a in "${CFG_STALE[@]}"; do echo "[CFG] opencode config: agent '$a' is obsolete"; work=1; done
  for q in "${MANUAL[@]}"; do echo "[MANUAL] $q"; work=1; done
  if [[ "$PURGE" -eq 1 ]]; then
    for u in "${PURGE_ORIG[@]}"; do echo "[PURGE] $u (se eliminará en modo real)"; work=1; done
  fi
}

case "$MODE" in
  check)
    report_plan "check"
    if [[ "$work" -eq 0 ]]; then echo "limpio: sin artefactos obsoletos."; exit 0; else exit 1; fi
    ;;
  dry)
    report_plan "dry-run"
    p=
    for p in "${RM_LINKS[@]}"; do echo "  WOULD-RM  rm -f -- '$p'"; done
    for p in "${RM_ORIG[@]}"; do if [[ -d "$p" ]]; then echo "  WOULD-RM  rm -rf -- '$p'"; else echo "  WOULD-RM  rm -f -- '$p'"; fi; done
    if [[ "$PURGE" -eq 1 ]]; then
      for p in "${PURGE_ORIG[@]}"; do if [[ -d "$p" ]]; then echo "  WOULD-RM  rm -rf -- '$p'  (--purge-manual)"; else echo "  WOULD-RM  rm -f -- '$p'  (--purge-manual)"; fi; done
    fi
    for a in "${CFG_STALE[@]}"; do echo "  WOULD-EDIT opencode config: remove obsolete agent '$a' from '$CONFIG_FILE'"; done
    if [[ "$work" -eq 0 ]]; then echo "limpio: sin artefactos obsoletos."; exit 0; else exit 1; fi
    ;;
esac

# ---------------------------------------------------------------------------
# 4. Real
# ---------------------------------------------------------------------------
report_plan "real"
if [[ "$work" -eq 0 ]]; then echo "limpio: sin artefactos obsoletos."; exit 0; fi
if [[ "$SYNC_FIRST" -eq 1 ]]; then
  echo "error: hay sucesores sin instalar; corré ./sync-skills.sh real y reintentá." >&2
  exit 1
fi

if [[ $YES -eq 0 ]]; then
  if [[ -t 0 ]]; then
    extra=""
    if [[ "$PURGE" -eq 1 && ${#PURGE_ORIG[@]} -gt 0 ]]; then extra=", $(( ${#PURGE_ORIG[@]} )) purgable(s)"; fi
    if [[ ${#CFG_STALE[@]} -gt 0 ]]; then extra="$extra, $(( ${#CFG_STALE[@]} )) agente(s) obsoleto(s) del config"; fi
    printf '¿Eliminar %d symlinks, %d originales%s? [y/N] ' "${#RM_LINKS[@]}" "${#RM_ORIG[@]}" "$extra"
    read -r reply
    [[ "$reply" == "y" || "$reply" == "Y" ]] || { echo "cancelado."; exit 1; }
  else
    echo "error: modo real sin TTY requiere --yes" >&2
    exit 1
  fi
fi

# Fase Cfg (R9): poda de agentes obsoletos del config de opencode — respaldo,
# splice validado, restauración automática ante fallo
if [[ ${#CFG_STALE[@]} -gt 0 && -n "$CONFIG_FILE" && -n "$CFG_PY" ]]; then
  cp -p -- "$CONFIG_FILE" "$CONFIG_FILE.bak.sdd-own" || { echo "error: no se pudo respaldar $CONFIG_FILE" >&2; exit 1; }
  if ! cfg_python prune "$CONFIG_FILE" "$HOME_DIR"; then
    echo "error: falló la poda del config de opencode; se restaura el respaldo" >&2
    cp -p -- "$CONFIG_FILE.bak.sdd-own" "$CONFIG_FILE" 2>/dev/null || true
    exit 1
  fi
  for a2 in "${CFG_STALE[@]}"; do
    echo "  [OK] config pruned: obsolete agent '$a2' removed from '$CONFIG_FILE'"
  done
fi

# Fase A: symlinks obsoletos (path exacto, rm del link — jamás toca el target)
p=
for p in "${RM_LINKS[@]}"; do
  rm -f -- "$p" && echo "  [OK] symlink eliminado: $p" || { echo "error: no se pudo eliminar $p" >&2; exit 1; }
done

# Fase B: originales — solo si ningún symlink restante los referencia (R5)
for p in "${RM_ORIG[@]}"; do
  base="$(basename "$p")"
  if [[ "$(referrer_count "$base" "$p")" -gt 0 ]]; then
    echo "error: $p todavía referenciado por symlinks; no se elimina" >&2
    exit 1
  fi
  if [[ -d "$p" ]]; then
    rm -rf -- "$p" && echo "  [OK] original eliminado: $p" || { echo "error: no se pudo eliminar $p" >&2; exit 1; }
  else
    rm -f -- "$p" && echo "  [OK] original eliminado: $p" || { echo "error: no se pudo eliminar $p" >&2; exit 1; }
  fi
done

# Fase C: purgables clase c — SOLO con --purge-manual; anomalías estructurales jamás
if [[ "$PURGE" -eq 1 && ${#PURGE_ORIG[@]} -gt 0 ]]; then
  for p in "${PURGE_ORIG[@]}"; do
    base="$(basename "$p")"
    if [[ "$(referrer_count "$base" "$p")" -gt 0 ]]; then
      echo "error: $p todavía referenciado por symlinks; no se purga" >&2
      exit 1
    fi
    if [[ -d "$p" ]]; then
      rm -rf -- "$p" && echo "  [OK] purgado: $p" || { echo "error: no se pudo purgar $p" >&2; exit 1; }
    else
      rm -f -- "$p" && echo "  [OK] purgado: $p" || { echo "error: no se pudo purgar $p" >&2; exit 1; }
    fi
  done
fi

hard_manual=$(( ${#MANUAL[@]} - ${#PURGE_ORIG[@]} ))
if [[ "$PURGE" -eq 1 && ${#PURGE_ORIG[@]} -gt 0 ]]; then
  echo "limpieza completa. ${#PURGE_ORIG[@]} ítem(s) purgados."
elif [[ "$hard_manual" -gt 0 ]]; then
  echo "limpieza completa. $hard_manual ítem(s) pendientes de revisión manual (ver [MANUAL])."
else
  echo "limpieza completa."
fi
exit 0