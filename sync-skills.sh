#!/usr/bin/env bash
#
# sync-skills.sh — Sincroniza la personalización SDD-own sobre la instalación de gentle-ai.
#
# Modelo de trabajo (overlay con bloques gestionados):
#
#   - gentle-ai (binario de Gentleman-Programming) INSTALA sus skills/commands/prompts
#     canónicos en ~/.agents/skills, ~/.config/opencode/skills (symlinks),
#     ~/.config/opencode/commands y ~/.config/opencode/prompts/sdd.
#   - Las originales de Alan se respetan SIEMPRE (nunca se pisan).
#   - Nuestra personalización se adhiere como BLOQUES GESTIONADOS anexados al final
#     del archivo original, marcados así:
#
#       <!-- sdd-own:<id-unico>:start -->
#       ...contenido nuestro...
#       <!-- sdd-own:<id-unico>:end -->
#
#   - Mecánica por archivo overlay: (1) se quitan los bloques sdd-own existentes con
#     el mismo id (regex desde start a end, idempotente); (2) si el archivo base no
#     existe → ERROR (nunca se crea el base); (3) se anexa el contenido del overlay.
#     NUNCA se sobreescriben líneas del archivo original.
#
# Estructura del repo:
#
#   skills/<skill>/            skills EXCLUSIVAS nuestras (canonical source en repo)
#   skills/_shared/            codegraph.md (exclusiva) + 8 bootstrap IDÉNTICOS a los de Alan
#   overlays/skills/<skill>/   bloques sdd-own sobre el SKILL.md que gentle-ai instala
#   overlays/shared/<f>.md     bloques sdd-own sobre _shared/<f>
#   overlays/commands/<f>.md   bloques sdd-own sobre ~/.config/opencode/commands/<f>
#   wiring/prompts/sdd/*.md    prompts nuestros (orchestrator.md, sdd-rfc-author.md)
#   wiring/opencode.sdd.json   fragmento SDD mergeado sobre el config real de opencode
#
# Modelo de despliegue (~/.config/sdd-own/ como canónico):
#
#   ~/.config/sdd-own/             origen de TODO lo nuestro (carpeta ya existente)
#     skills/<skill>/              copias físicas ORIGINALES de skills exclusivas
#     skills/_shared/              copias físicas ORIGINALES del bootstrap + codegraph.md (solo-si-falta)
#     prompts/sdd/                 copias físicas ORIGINALES de prompts propios
#     srv/gh-mcp-server/           servidor MCP local (desplegado por setup.sh)
#     github-mcp.env, env.sh, ...  (ya existían; no se tocan)
#
#   ~/.agents/skills/<skill>/      SYMLINK → ../../.config/sdd-own/skills/<skill>
#   ~/.config/opencode/skills/<skill>/ SYMLINK → ../../../.config/sdd-own/skills/<skill>
#   ~/.claude/skills/<skill>/      SYMLINK → ../../.config/sdd-own/skills/<skill>
#
#   _shared (EXCEPCIÓN): este directorio es compartido — la base de Alan (p.ej.
#   sdd-phase-common.md) vive en ~/.agents/skills/_shared/ como directorio REAL,
#   instalada por gentle-ai sync. Nuestros 9 archivos se copian ahí SOLO SI FALTA.
#   ~/.agents/skills/_shared/ NUNCA es symlink. ~/.config/opencode/skills/_shared
#   y ~/.claude/skills/_shared/ son SYMLINKS al directorio real compartido (no a
#   sdd-own), para que los agentes vean la base de Alan + los nuestros.
#
#   Alan: sus skills en ~/.agents/skills/ se mantienen como directorios reales;
#   los overlays hacen strip+append sobre esos archivos sin tocar el base.
#
# Flujo:
#   Paso 0 — gentle-ai sync (solo modo real; flag --skip-gentleai-sync para omitir)
#   Paso 1 — install de lo nuestro (copia original a ~/.config/sdd-own/ + symlinks)
#   Paso 2 — overlays (strip+append sobre los archivos de Alan)
#   Paso 3 — merge del fragmento SDD sobre ~/.config/opencode/opencode.json(c)
#   Paso 4 — registries (.atl) por proyecto
#
# Uso:
#   ./sync-skills.sh                         # sincroniza (corre gentle-ai sync primero)
#   ./sync-skills.sh --skip-gentleai-sync    # omite el paso 0 (ya se corrió sync)
#   ./sync-skills.sh --check                 # modo verificación: reporta sin modificar nada
#   ./sync-skills.sh --dry-run               # modo ensayo: muestra qué se haría, sin ejecutar
#   ./sync-skills.sh --skip-opencode         # no mergea el config de opencode
#   ./sync-skills.sh --registries <proyecto...>  # refresh del registry .atl/ tras el sync
#
# Salida (exit code):
#   0 = sincronizado / verificado sin desyncs
#   1 = error de estructura/configuración o desyncs encontrados en --check
#   2 = uno o más pasos fallaron al aplicar

set -euo pipefail

# --- Resolución de rutas ---------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
SHARED_SRC_DIR="$SKILLS_DIR/_shared"
OVERLAYS_DIR="$SCRIPT_DIR/overlays"
WIRING_DIR="$SCRIPT_DIR/wiring"
PROMPTS_SRC_DIR="$WIRING_DIR/prompts/sdd"

AGENTS_SKILLS_DIR="$HOME/.agents/skills"
OPENCODE_SKILLS_DIR="$HOME/.config/opencode/skills"
OPENCODE_COMMANDS_DIR="$HOME/.config/opencode/commands"
OPENCODE_PROMPTS_SDD_DIR="$HOME/.config/opencode/prompts/sdd"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
CLAUDE_PROMPTS_SDD_DIR="$HOME/.claude/prompts/sdd"

SDD_OWN_DIR="$HOME/.config/sdd-own"
SDD_OWN_SKILLS_DIR="$SDD_OWN_DIR/skills"
SDD_OWN_PROMPTS_SDD_DIR="$SDD_OWN_DIR/prompts/sdd"

# Bootstrap _shared: 8 archivos IDÉNTICOS a los de Alan + nuestra exclusiva codegraph.md.
# Se instalan SOLO SI FALTA el target (nunca se sobreescribe lo que ya está instalado).
SHARED_BOOTSTRAP=(README.md engram-convention.md openspec-convention.md persistence-contract.md \
  research-lifecycle.md sdd-orchestrator-sections.md sdd-status-contract.md skill-resolver.md)

# Prompts propios que desplegamos (Alan no gestiona estos 2 paths).
OWN_PROMPTS=(orchestrator.md sdd-rfc-author.md)

# --- Opciones --------------------------------------------------------------

CHECK_MODE=0
DRY_RUN=0
SKIP_OPENCODE=0
SKIP_GENTLEAI_SYNC=0
REGISTRY_PROJECTS=()

next_is_registry=0
for arg in "$@"; do
  if [[ $next_is_registry -eq 1 ]]; then
    case "$arg" in
      --*) next_is_registry=0 ;;
      -*)  next_is_registry=0 ;;
      *)   REGISTRY_PROJECTS+=("$arg"); continue ;;
    esac
  fi
  case "$arg" in
    --check)           CHECK_MODE=1 ;;
    --dry-run)         DRY_RUN=1 ;;
    --skip-opencode)   SKIP_OPENCODE=1 ;;
    --skip-gentleai-sync) SKIP_GENTLEAI_SYNC=1 ;;
    --registries)      next_is_registry=1 ;;
    -h|--help)
      sed -n '1,68p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: opción desconocida: $arg" >&2
      echo "Uso: $0 [--check] [--dry-run] [--skip-opencode] [--skip-gentleai-sync] [--registries <proyecto...>]" >&2
      exit 1
      ;;
  esac
done

if [[ $CHECK_MODE -eq 1 && $DRY_RUN -eq 1 ]]; then
  echo "error: --check y --dry-run son mutuamente excluyentes" >&2
  exit 1
fi

# --- Validación de estructura ---------------------------------------------

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "error: no se encontró el directorio canónico de skills: $SKILLS_DIR" >&2
  exit 1
fi
if [[ ! -d "$OVERLAYS_DIR" ]]; then
  echo "error: no se encontró el directorio de overlays: $OVERLAYS_DIR" >&2
  exit 1
fi

# Skills exclusivas (subdirectorios de skills/ con SKILL.md, excluyendo _shared).
declare -a SKILLS=()
shopt -s nullglob
for _d in "$SKILLS_DIR"/*/; do
  _name="${_d%/}"
  _name="${_name##*/}"
  [[ -n "$_name" && "$_name" != "_shared" ]] && SKILLS+=("$_name")
done
shopt -u nullglob
if [[ ${#SKILLS[@]} -eq 0 ]]; then
  echo "error: no hay skills exclusivas en $SKILLS_DIR" >&2
  exit 1
fi

# Colección de overlay files: <fuente>|<target> (parejas separadas por |).
declare -a OVERLAYS=()
shopt -s nullglob
for _ov in "$OVERLAYS_DIR"/skills/*/SKILL.md; do
  _skill="${_ov%/SKILL.md}"
  _skill="${_skill##*/}"
  OVERLAYS+=("$_ov|$AGENTS_SKILLS_DIR/$_skill/SKILL.md")
done
for _ov in "$OVERLAYS_DIR"/shared/*.md; do
  _f="${_ov##*/}"
  OVERLAYS+=("$_ov|$AGENTS_SKILLS_DIR/_shared/$_f")
done
for _ov in "$OVERLAYS_DIR"/commands/*.md; do
  _f="${_ov##*/}"
  OVERLAYS+=("$_ov|$OPENCODE_COMMANDS_DIR/$_f")
done
shopt -u nullglob
if [[ ${#OVERLAYS[@]} -eq 0 ]]; then
  echo "error: no hay overlay files en $OVERLAYS_DIR" >&2
  exit 1
fi

# --- Helpers ----------------------------------------------------------------

# Extrae los ids de bloques sdd-own de un overlay file (start -> end por id).
# Devuelve ids únicos en el mismo orden de aparición.
overlay_block_ids() {
  local file="$1"
  perl -0777 -ne 'while (/<!--\s*sdd-own:([^:\s]+):start\s*-->.*?<!--\s*sdd-own:\1:end\s*-->/gs) { print "$1\n" }' "$file" \
    | awk '!seen[$0]++'
}

# Extrae todas las apariciones de ids (start o end) — para validación de integridad.
overlay_all_ids() {
  local file="$1"
  perl -0777 -ne 'while (/<!--\s*sdd-own:([^:\s]+):(start|end)\s*-->/gs) { print "$1\n" }' "$file" | sort -u
}

# Cuenta marcadores start/end de un id en un archivo: "start end".
count_markers() {
  local file="$1" id="$2"
  local s e
  s=$(grep -c "sdd-own:$id:start" "$file" 2>/dev/null || true)
  e=$(grep -c "sdd-own:$id:end" "$file" 2>/dev/null || true)
  printf '%s %s' "${s:-0}" "${e:-0}"
}

# Quita (idempotente) todos los bloques con el id dado de un archivo.
strip_block_id() {
  local file="$1" id="$2"
  perl -0777 -i -pe "s{\Q<!-- sdd-own:$id:start -->\E.*?\Q<!-- sdd-own:$id:end -->\E\s*}{}gs" "$file"
}

# Aplica un overlay file a su target (strip + append). Devuelve 0 sin cambios, 1 aplicado,
# 2 error. Requiere: target existe; base identificable tras el strip; ids únicos globales.
apply_overlay() {
  local src="$1" target="$2"
  local id base_after tmp scount ecount malformed=0

  if [[ ! -f "$target" ]]; then
    printf "   [ERROR]     overlay sin base: %s no existe (¿gentle-ai sync instaló esa skill?)\n" "$target" >&2
    return 2
  fi

  # Validar que el overlay esté bien formado (todo start tiene su end y viceversa).
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    read -r scount ecount < <(count_markers "$src" "$id") || true
    if [[ "${scount:-0}" -ne "${ecount:-0}" ]]; then
      printf "   [ERROR]     overlay malformado (%s: start=%s end=%s): %s\n" "$id" "${scount:-0}" "${ecount:-0}" "$src" >&2
      malformed=1
    fi
  done < <(overlay_all_ids "$src")
  if [[ $malformed -eq 1 ]]; then
    return 2
  fi

  local ids=()
  while IFS= read -r id; do [[ -n "$id" ]] && ids+=("$id"); done < <(overlay_block_ids "$src")
  if [[ ${#ids[@]} -eq 0 ]]; then
    printf "   [ERROR]     overlay sin bloques sdd-own: %s\n" "$src" >&2
    return 2
  fi

  # En todos los modos: un marcador roto previo en el target es una condición de conflicto.
  for id in "${ids[@]}"; do
    read -r scount ecount < <(count_markers "$target" "$id") || true
    if [[ "${scount:-0}" -ne "${ecount:-0}" ]]; then
      printf "   [ERROR]     base con bloques sdd-own rotos (%s: start=%s end=%s): %s\n" "$id" "${scount:-0}" "${ecount:-0}" "$target" >&2
      return 2
    fi
  done

  # Base actual (sin bloques nuestros del id).
  tmp="$target.sdd-own-strip.$$"
  cp "$target" "$tmp" || { printf "   [ERROR]     no se pudo leer %s\n" "$target" >&2; return 2; }
  for id in "${ids[@]}"; do
    strip_block_id "$tmp" "$id"
  done
  base_after="$(cat "$tmp")" || { rm -f "$tmp"; printf "   [ERROR]     no se pudo leer %s\n" "$tmp" >&2; return 2; }

  if [[ -z "$(printf '%s' "$base_after" | tr -d '[:space:]')" ]]; then
    rm -f "$tmp"
    printf "   [ERROR]     base no identificable (solo contiene bloques sdd-own): %s\n" "$target" >&2
    return 2
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    rm -f "$tmp"
    printf "   [pendiente] strip+append %s -> %s (%s bloques)\n" "${src#$SCRIPT_DIR/}" "${target#$HOME/}" "${#ids[@]}"
    return 1
  fi
  if [[ "$CHECK_MODE" -eq 1 ]]; then
    rm -f "$tmp"
    # Verificación: el target debe contener todos los bloques esperados y nada raro.
    local missing=0
    for id in "${ids[@]}"; do
      # aplicado = aparecen start y end del id en el target
      if grep -q "sdd-own:$id:start" "$target" && grep -q "sdd-own:$id:end" "$target"; then
        :
      else
        missing=1
      fi
    done
    # bloques sdd-own presentes que no corresponden al overlay = stale
    local stray=0
    while IFS= read -r id; do
      [[ -z "$id" ]] && continue
      local known=0
      for _i in "${ids[@]}"; do
        [[ "$_i" == "$id" ]] && known=1
      done
      # sdd-phase-common espera 2 bloques: ambos están en ids; cualquier otro sobra.
      [[ "$known" -eq 0 ]] && stray=1
    done < <(overlay_block_ids "$target")
    if [[ "$missing" -eq 1 || "$stray" -eq 1 ]]; then
      printf "   [DESYNC]    %s no contiene los bloques sdd-own esperados\n" "${target#$HOME/}"
      return 1
    fi
    printf "   [ok]        %s contiene los bloques sdd-own esperados\n" "${target#$HOME/}"
    return 0
  fi

  # Modo real: escribir.
  # Separador: solo si el target NO termina en newline. Si ya termina en \n,
  # el bloque se anexa directo y el strip queda byte-idéntico a la base de Alan.
  if [[ -n "$(tail -c 1 "$tmp" | tr -d '\n')" ]]; then
    printf '\n' >> "$tmp" || { rm -f "$tmp"; printf "   [ERROR]     no se pudo escribir %s\n" "$target" >&2; return 2; }
  fi
  cat "$src" >> "$tmp" || { rm -f "$tmp"; printf "   [ERROR]     no se pudo escribir %s\n" "$target" >&2; return 2; }
  printf '\n' >> "$tmp" || { rm -f "$tmp"; printf "   [ERROR]     no se pudo escribir %s\n" "$target" >&2; return 2; }

  # Idempotencia: si el resultado es byte-idéntico al target, no se reescribe.
  if diff -q "$tmp" "$target" >/dev/null 2>&1; then
    rm -f "$tmp"
    printf "   [up-to-date] %s (bloques sdd-own ya aplicados)\n" "${target#$HOME/}"
    return 0
  fi

  if ! mv "$tmp" "$target"; then
    rm -f "$tmp"
    printf "   [ERROR]     no se pudo escribir %s\n" "$target" >&2
    return 2
  fi
  printf "   [aplicado]  %s (strip+append: %s bloques)\n" "${target#$HOME/}" "${#ids[@]}"
  return 1
}

# Sincroniza un directorio source completo → destino (copia física archivo a archivo).
sync_dir() {
  local src="$1" dest="$2"
  local src_file dest_file rel
  local changed=0 rc=0

  if [[ ! -d "$dest" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] crear y copiar %s\n" "$dest"
      return 1
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [FALTA]     %s\n" "$dest"
      return 1
    else
      if ! mkdir -p "$dest"; then
        printf "   [ERROR]     no se pudo crear %s\n" "$dest" >&2
        return 2
      fi
      cp -R "$src/." "$dest/" || { printf "   [ERROR]     copia a %s\n" "$dest" >&2; return 2; }
      printf "   [creado]    %s\n" "$dest"
      return 1
    fi
  fi

  while IFS= read -r -d '' src_file; do
    rel="${src_file#"$src"/}"
    dest_file="$dest/$rel"
    if [[ ! -e "$dest_file" ]] || ! diff -q "$src_file" "$dest_file" >/dev/null 2>&1; then
      changed=1
      if [[ $DRY_RUN -eq 1 ]]; then
        printf "   [pendiente] %s -> %s\n" "${src_file#$SCRIPT_DIR/}" "${dest_file#$HOME/}"
      elif [[ $CHECK_MODE -eq 1 ]]; then
        printf "   [DESYNC]    %s (canónico: %s)\n" "${dest_file#$HOME/}" "${src_file#$SCRIPT_DIR/}"
      else
        mkdir -p "$(dirname "$dest_file")" || { rc=2; break; }
        cp "$src_file" "$dest_file" || { rc=2; break; }
      fi
    fi
  done < <(find "$src" -type f -print0)

  if [[ $rc -eq 2 ]]; then
    printf "   [ERROR]     fallo al sincronizar %s\n" "$dest" >&2
    return 2
  fi
  if [[ $changed -eq 1 ]]; then
    if [[ $CHECK_MODE -eq 0 && $DRY_RUN -eq 0 ]]; then
      printf "   [actualizado] %s\n" "$dest"
    fi
    return 1
  fi
  printf "   [up-to-date] %s\n" "$dest"
  return 0
}

# Helper symlink: crea/reemplaza el symlink dest -> target_relativo.
ensure_symlink() {
  local dest_link="$1" relative_target="$2"

  if [[ -L "$dest_link" ]]; then
    local current
    current="$(readlink "$dest_link")"
    if [[ "$current" == "$relative_target" ]]; then
      printf "   [up-to-date] %s\n" "$dest_link"
      return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] reemplazar symlink %s -> %s\n" "$dest_link" "$relative_target"
      return 1
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [DESYNC]    %s (apunta a %s; debería apuntar a %s)\n" "$dest_link" "$current" "$relative_target"
      return 1
    else
      rm "$dest_link" || { printf "   [ERROR]     no se pudo borrar symlink %s\n" "$dest_link" >&2; return 2; }
    fi
  elif [[ -d "$dest_link" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] reemplazar directorio por symlink %s\n" "$dest_link"
      return 1
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [DESYNC]    %s es un directorio real; debería ser symlink\n" "$dest_link"
      return 1
    else
      # C1: un directorio real puede contener datos (instalación manual); se
      # rescata renombrándolo en vez de borrarlo (rm -rf silencioso = pérdida).
      mv "$dest_link" "${dest_link}.sdd-own-obsolete.$$" || { printf "   [ERROR]     no se pudo renombrar directorio %s\n" "$dest_link" >&2; return 2; }
      printf "   [rescatado]  %s -> %s.sdd-own-obsolete.$$\n" "$dest_link" "$dest_link"
    fi
  elif [[ -f "$dest_link" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] reemplazar archivo por symlink %s\n" "$dest_link"
      return 1
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [DESYNC]    %s es un archivo real; debería ser symlink\n" "$dest_link"
      return 1
    else
      rm "$dest_link" || { printf "   [ERROR]     no se pudo borrar archivo %s\n" "$dest_link" >&2; return 2; }
    fi
  elif [[ -e "$dest_link" ]]; then
    printf "   [ERROR]     %s existe y no es archivo/directorio/symlink\n" "$dest_link" >&2
    return 2
  fi

  if [[ ! -d "$(dirname "$dest_link")" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] crear directorio %s\n" "$(dirname "$dest_link")"
    elif [[ $CHECK_MODE -eq 0 ]]; then
      mkdir -p "$(dirname "$dest_link")" || { printf "   [ERROR]     no se pudo crear %s\n" "$(dirname "$dest_link")" >&2; return 2; }
    fi
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    printf "   [pendiente] symlink %s -> %s\n" "$dest_link" "$relative_target"
    return 1
  elif [[ $CHECK_MODE -eq 1 ]]; then
    printf "   [FALTA]     %s (debería ser symlink a %s)\n" "$dest_link" "$relative_target"
    return 1
  else
    ln -s "$relative_target" "$dest_link" || { printf "   [ERROR]     no se pudo crear symlink %s\n" "$dest_link" >&2; return 2; }
    printf "   [creado]    %s -> %s\n" "$dest_link" "$relative_target"
    return 1
  fi
}

# --- Contadores globales (resumen final) --------------------------------------
# Se inicializan ANTES del paso 0 para que un fallo de gentle-ai sync sume (H1).
total_updated=0
total_failures=0

# --- Paso 0: gentle-ai sync --------------------------------------------------

if [[ $SKIP_GENTLEAI_SYNC -eq 1 ]]; then
  echo "Paso 0 — gentle-ai sync: omitido (--skip-gentleai-sync)"
elif [[ $CHECK_MODE -eq 1 || $DRY_RUN -eq 1 ]]; then
  echo "Paso 0 — gentle-ai sync: no se ejecuta en --check/--dry-run"
elif command -v gentle-ai >/dev/null 2>&1; then
  echo "Paso 0 — gentle-ai sync"
  if ! gentle-ai sync; then
    echo "  [ERROR]     gentle-ai sync falló; se continúa igual con los pasos siguientes" >&2
    total_failures=$((total_failures + 1))
  fi
else
  echo "Paso 0 — gentle-ai sync: [aviso] gentle-ai no encontrado en PATH; se omite (los targets de overlay podrían faltar)" >&2
fi
echo

# --- Paso 1: install de lo nuestro ------------------------------------------

echo "Paso 1 — install de skills exclusivas + bootstrap _shared + prompts"

for skill in "${SKILLS[@]}"; do
  src_skill="$SKILLS_DIR/$skill"
  rc=0
  sync_dir "$src_skill" "$SDD_OWN_SKILLS_DIR/$skill" || rc=$?
  case "$rc" in
    1) total_updated=$((total_updated + 1)) ;;
    2) total_failures=$((total_failures + 1)) ;;
  esac

  # Symlink en ~/.agents/skills/<skill> → ~/.config/sdd-own/skills/<skill>
  # Desde ~/.agents/skills/ hacen falta 2 niveles (..) para llegar a $HOME.
  rc=0
  ensure_symlink "$AGENTS_SKILLS_DIR/$skill" "../../.config/sdd-own/skills/$skill" || rc=$?
  case "$rc" in
    1) total_updated=$((total_updated + 1)) ;;
    2) total_failures=$((total_failures + 1)) ;;
  esac

  # Symlink en ~/.config/opencode/skills/<skill> → ~/.config/sdd-own/skills/<skill>
  # Desde ~/.config/opencode/skills/ hacen falta 3 niveles (..) para llegar a $HOME.
  rc=0
  ensure_symlink "$OPENCODE_SKILLS_DIR/$skill" "../../../.config/sdd-own/skills/$skill" || rc=$?
  case "$rc" in
    1) total_updated=$((total_updated + 1)) ;;
    2) total_failures=$((total_failures + 1)) ;;
  esac

  # Symlink en ~/.claude/skills/<skill> → ~/.config/sdd-own/skills/<skill>
  # Desde ~/.claude/skills/ hacen falta 2 niveles (..) para llegar a $HOME.
  if [[ -d "$HOME/.claude" ]]; then
    rc=0
    ensure_symlink "$CLAUDE_SKILLS_DIR/$skill" "../../.config/sdd-own/skills/$skill" || rc=$?
    case "$rc" in
      1) total_updated=$((total_updated + 1)) ;;
      2) total_failures=$((total_failures + 1)) ;;
    esac
  fi
done

# Bootstrap _shared: excepción — directorio compartido, NO symlink.
# 1) Nuestros canónicos en sdd-own (solo-si-falta).
# 2) ~/.agents/skills/_shared/ = directorio REAL (base de Alan + copia solo-si-falta).
# 3) opencode/claude _shared = symlink al directorio real (no a sdd-own).
echo "  _shared (bootstrap — excepción: directorio compartido)"

# --- 1) Canónicos en ~/.config/sdd-own/skills/_shared/ (solo-si-falta) ---
if [[ ! -d "$SDD_OWN_SKILLS_DIR/_shared" && $CHECK_MODE -eq 0 && $DRY_RUN -eq 0 ]]; then
  mkdir -p "$SDD_OWN_SKILLS_DIR/_shared"
fi
if [[ $DRY_RUN -eq 1 ]]; then
  printf "   [pendiente] asegurar %s (bootstrap)\n" "$SDD_OWN_SKILLS_DIR/_shared"
elif [[ $CHECK_MODE -eq 1 ]]; then
  for f in "${SHARED_BOOTSTRAP[@]}" codegraph.md; do
    if [[ ! -e "$SDD_OWN_SKILLS_DIR/_shared/$f" ]]; then
      printf "   [FALTA]     ~/.config/sdd-own/skills/_shared/%s (bootstrap pendiente)\n" "$f"
      total_updated=$((total_updated + 1))
    fi
  done
else
  for f in "${SHARED_BOOTSTRAP[@]}" codegraph.md; do
    if [[ ! -e "$SDD_OWN_SKILLS_DIR/_shared/$f" ]]; then
      if cp "$SHARED_SRC_DIR/$f" "$SDD_OWN_SKILLS_DIR/_shared/$f"; then
        printf "   [instalado] ~/.config/sdd-own/skills/_shared/%s (solo si falta)\n" "$f"
      else
        printf "   [ERROR]     no se pudo copiar %s\n" "$SHARED_SRC_DIR/$f" >&2
        total_failures=$((total_failures + 1))
      fi
    else
      printf "   [skip]      ~/.config/sdd-own/skills/_shared/%s ya existe (no se toca)\n" "$f"
    fi
  done
fi

# --- 2) ~/.agents/skills/_shared/ = directorio REAL compartido (NUNCA symlink) ---
if [[ -L "$AGENTS_SKILLS_DIR/_shared" ]]; then
  # Es un symlink (estado heredado del sync anterior) → reconvertir a directorio real.
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "   [pendiente] reconvertir %s a directorio real (era symlink)\n" "$AGENTS_SKILLS_DIR/_shared"
  elif [[ $CHECK_MODE -eq 1 ]]; then
    printf "   [DESYNC]    %s es symlink; debe ser directorio real\n" "$AGENTS_SKILLS_DIR/_shared"
    total_updated=$((total_updated + 1))
  else
    if rm "$AGENTS_SKILLS_DIR/_shared" && mkdir -p "$AGENTS_SKILLS_DIR/_shared"; then
      printf "   [reconvertido] %s a directorio real (era symlink)\n" "$AGENTS_SKILLS_DIR/_shared"
    else
      printf "   [ERROR]     no se pudo reconvertir %s a directorio real\n" "$AGENTS_SKILLS_DIR/_shared" >&2
      total_failures=$((total_failures + 1))
    fi
  fi
elif [[ ! -d "$AGENTS_SKILLS_DIR/_shared" ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "   [pendiente] crear %s (dir compartido de Alan)\n" "$AGENTS_SKILLS_DIR/_shared"
  elif [[ $CHECK_MODE -eq 1 ]]; then
    printf "   [FALTA]     %s (dir compartido de Alan)\n" "$AGENTS_SKILLS_DIR/_shared"
    total_updated=$((total_updated + 1))
  else
    if mkdir -p "$AGENTS_SKILLS_DIR/_shared"; then
      printf "   [creado]    %s (dir compartido de Alan)\n" "$AGENTS_SKILLS_DIR/_shared"
    else
      printf "   [ERROR]     no se pudo crear %s\n" "$AGENTS_SKILLS_DIR/_shared" >&2
      total_failures=$((total_failures + 1))
    fi
  fi
else
  # Ya es directorio real: no-op.
  printf "   [up-to-date] %s (directorio real compartido)\n" "$AGENTS_SKILLS_DIR/_shared"
fi

# --- 3) Copiar nuestros 9 archivos al directorio compartido (solo-si-falta) ---
# Mismo patrón que el loop canónico de sdd-own; target = dir real compartido.
if [[ $DRY_RUN -eq 1 ]]; then
  for f in "${SHARED_BOOTSTRAP[@]}" codegraph.md; do
    if [[ ! -e "$AGENTS_SKILLS_DIR/_shared/$f" ]]; then
      printf "   [pendiente] %s/_shared/%s (bootstrap compartido)\n" "${AGENTS_SKILLS_DIR#$HOME/}" "$f"
    fi
  done
elif [[ $CHECK_MODE -eq 1 ]]; then
  for f in "${SHARED_BOOTSTRAP[@]}" codegraph.md; do
    if [[ ! -e "$AGENTS_SKILLS_DIR/_shared/$f" ]]; then
      printf "   [FALTA]     %s/_shared/%s (bootstrap compartido pendiente)\n" "${AGENTS_SKILLS_DIR#$HOME/}" "$f"
      total_updated=$((total_updated + 1))
    fi
  done
else
  for f in "${SHARED_BOOTSTRAP[@]}" codegraph.md; do
    if [[ ! -e "$AGENTS_SKILLS_DIR/_shared/$f" ]]; then
      if cp "$SHARED_SRC_DIR/$f" "$AGENTS_SKILLS_DIR/_shared/$f"; then
        printf "   [instalado] %s/_shared/%s (solo si falta, directorio compartido)\n" "${AGENTS_SKILLS_DIR#$HOME/}" "$f"
      else
        printf "   [ERROR]     no se pudo copiar %s → %s/_shared/%s\n" "$SHARED_SRC_DIR/$f" "${AGENTS_SKILLS_DIR#$HOME/}" "$f" >&2
        total_failures=$((total_failures + 1))
      fi
    else
      printf "   [skip]      %s/_shared/%s ya existe (no se toca)\n" "${AGENTS_SKILLS_DIR#$HOME/}" "$f"
    fi
  done
fi

# --- 4) Symlinks: opencode y claude → directorio real compartido (NO a sdd-own) ---
# OpenCode: desde ~/.config/opencode/skills/ hacen falta 3 niveles para llegar a $HOME.
rc=0
ensure_symlink "$OPENCODE_SKILLS_DIR/_shared" "../../../.agents/skills/_shared" || rc=$?
case "$rc" in
  1) total_updated=$((total_updated + 1)) ;;
  2) total_failures=$((total_failures + 1)) ;;
esac

# Claude: desde ~/.claude/skills/ hacen falta 2 niveles para llegar a $HOME.
if [[ -d "$HOME/.claude" ]]; then
  rc=0
  ensure_symlink "$CLAUDE_SKILLS_DIR/_shared" "../../.agents/skills/_shared" || rc=$?
  case "$rc" in
    1) total_updated=$((total_updated + 1)) ;;
    2) total_failures=$((total_failures + 1)) ;;
  esac
fi

# Prompts propios → original en ~/.config/sdd-own/prompts/sdd/ + symlinks por
# archivo en ~/.config/opencode/prompts/sdd/ y ~/.claude/prompts/sdd/ (no se
# symlinkea el directorio completo porque ahí conviven prompts de Alan).
echo "  prompts propios (orchestrator.md, sdd-rfc-author.md)"
for pf in "${OWN_PROMPTS[@]}"; do
  src_pf="$PROMPTS_SRC_DIR/$pf"
  dest_own_pf="$SDD_OWN_PROMPTS_SDD_DIR/$pf"
  dest_oc_pf="$OPENCODE_PROMPTS_SDD_DIR/$pf"
  rc=0
  if [[ ! -f "$src_pf" ]]; then
    printf "   [ERROR]     falta el prompt canónico %s\n" "$src_pf" >&2
    total_failures=$((total_failures + 1))
    continue
  fi

  # 1) Original físico → ~/.config/sdd-own/prompts/sdd/<pf>
  if [[ ! -d "$SDD_OWN_PROMPTS_SDD_DIR" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] crear %s\n" "$SDD_OWN_PROMPTS_SDD_DIR"
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [FALTA]     %s\n" "$SDD_OWN_PROMPTS_SDD_DIR"
      total_updated=$((total_updated + 1))
    else
      mkdir -p "$SDD_OWN_PROMPTS_SDD_DIR" || { printf "   [ERROR]     no se pudo crear %s\n" "$SDD_OWN_PROMPTS_SDD_DIR" >&2; total_failures=$((total_failures + 1)); continue; }
    fi
  fi
  if [[ ! -e "$dest_own_pf" ]] || ! diff -q "$src_pf" "$dest_own_pf" >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] %s -> %s\n" "$pf" "${dest_own_pf#$HOME/}"
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [DESYNC]    %s difiere del canónico %s\n" "${dest_own_pf#$HOME/}" "$pf"
      total_updated=$((total_updated + 1))
    else
      mkdir -p "$(dirname "$dest_own_pf")"
      cp "$src_pf" "$dest_own_pf" || { printf "   [ERROR]     no se pudo copiar %s\n" "$dest_own_pf" >&2; total_failures=$((total_failures + 1)); continue; }
      printf "   [actualizado] %s\n" "${dest_own_pf#$HOME/}"
    fi
  else
    printf "   [up-to-date] %s\n" "${dest_own_pf#$HOME/}"
  fi

  # 2) Symlink por archivo en ~/.config/opencode/prompts/sdd/<pf> → original.
  # Desde ~/.config/opencode/prompts/sdd/ hacen falta 3 niveles (..) para llegar
  # a ~/.config; opencode resuelve ese dir (que también contiene prompts de Alan,
  # que NO se tocan).
  rc=0
  ensure_symlink "$dest_oc_pf" "../../../sdd-own/prompts/sdd/$pf" || rc=$?
  case "$rc" in
    1) total_updated=$((total_updated + 1)) ;;
    2) total_failures=$((total_failures + 1)) ;;
  esac

  # 3) Symlink en ~/.claude/prompts/sdd/<pf> → ~/.config/sdd-own/prompts/sdd/<pf>.
  # Desde ~/.claude/prompts/sdd/ hacen falta 3 niveles (..) para llegar a $HOME.
  if [[ -d "$HOME/.claude" ]]; then
    rc=0
    ensure_symlink "$CLAUDE_PROMPTS_SDD_DIR/$pf" "../../../.config/sdd-own/prompts/sdd/$pf" || rc=$?
    case "$rc" in
      1) total_updated=$((total_updated + 1)) ;;
      2) total_failures=$((total_failures + 1)) ;;
    esac
  fi
done
echo

# --- Paso 2: overlays --------------------------------------------------------

echo "Paso 2 — overlays (strip+append sobre los archivos de Alan)"

# Validación global: ids de bloque únicos entre TODOS los overlays.
# (Lista plana separada por espacios para ser portable a bash 3.2.)
SEEN_IDS_STR=""
for entry in "${OVERLAYS[@]}"; do
  ov_src="${entry%%|*}"
  # ids repetidos DENTRO del mismo overlay = dos bloques con el mismo id (conflicto).
  dup_ids="$(perl -0777 -ne 'while (/<!--\s*sdd-own:([^:\s]+):start\s*-->/gs) { print "$1\n" }' "$ov_src" | sort | uniq -d)"
  if [[ -n "$dup_ids" ]]; then
    echo "error: bloques con el mismo id dentro del overlay ($dup_ids) en $ov_src" >&2
    exit 1
  fi
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if [[ " $SEEN_IDS_STR " == *" $id "* ]]; then
      echo "error: id de bloque duplicado entre overlays: $id (en $ov_src)" >&2
      exit 1
    fi
    SEEN_IDS_STR="$SEEN_IDS_STR $id"
  done < <(overlay_block_ids "$ov_src")
done

for entry in "${OVERLAYS[@]}"; do
  ov_src="${entry%%|*}"
  ov_target="${entry#*|}"
  case "$ov_src" in
    */commands/*) printf "  overlay command: %s\n" "${ov_src##*/}";;
    */shared/*)    printf "  overlay shared:  %s\n" "${ov_src##*/}";;
    *)             printf "  overlay skill:   %s\n" "$(basename "$(dirname "$ov_src")")";;
  esac
  rc=0
  apply_overlay "$ov_src" "$ov_target" || rc=$?
  case "$rc" in
    1) total_updated=$((total_updated + 1)) ;;
    2) total_failures=$((total_failures + 1)) ;;
  esac
done

# Symlinks de Claude para los commands overlaid (sdd-new.md, sdd-continue.md).
if [[ -d "$HOME/.claude" ]]; then
  for _c in "$OVERLAYS_DIR"/commands/*.md; do
    _f="${_c##*/}"
    rc=0
    ensure_symlink "$CLAUDE_COMMANDS_DIR/$_f" "../../.config/opencode/commands/$_f" || rc=$?
    case "$rc" in
      1) total_updated=$((total_updated + 1)) ;;
      2) total_failures=$((total_failures + 1)) ;;
    esac
  done
fi
echo

# --- Paso 3: OpenCode config (merge del fragmento SDD) ------------------------

# Mergea SOLO los agentes SDD canonizados en wiring/opencode.sdd.json sobre el
# config real de opencode. El config real puede llamarse opencode.json o
# opencode.jsonc (opencode resuelve .jsonc PRIMERO si existe); se detecta cuál
# existe y se mergea sobre ese. Nunca borra claves personales.
sync_opencode_config() {
  local fragment="$WIRING_DIR/opencode.sdd.json"
  local target=""

  if [[ $SKIP_OPENCODE -eq 1 ]]; then
    printf "OpenCode config: saltado (--skip-opencode)\n"
    return 0
  fi

  if [[ -n "${OPENCODE_CONFIG:-}" ]]; then
    target="$OPENCODE_CONFIG"
  elif [[ -f "$HOME/.config/opencode/opencode.jsonc" ]]; then
    target="$HOME/.config/opencode/opencode.jsonc"
  elif [[ -f "$HOME/.config/opencode/opencode.json" ]]; then
    target="$HOME/.config/opencode/opencode.json"
  else
    printf "   [FALTA]     no existe %s ni %s; el fragmento SDD queda disponible en wiring/opencode.sdd.json\n" \
      "$HOME/.config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.json"
    return 0
  fi

  if [[ ! -f "$fragment" ]]; then
    echo "error: no se encontró el fragmento SDD: $fragment" >&2
    exit 1
  fi

  local merged=""
  local merged_ok=0
  if command -v jq >/dev/null 2>&1; then
    if merged="$(jq -s --indent 2 '.[0] as $u | .[1] as $f | ($u | .agent = ((.agent // {}) * $f.agent) | if (has("default_agent") | not) then .default_agent = $f.default_agent else . end | if (has("$schema") | not) then .["$schema"] = $f["$schema"] else . end)' "$target" "$fragment" 2>/dev/null)"; then
      merged_ok=1
    fi
  fi
  if [[ $merged_ok -eq 0 ]] && command -v python3 >/dev/null 2>&1; then
    if merged="$(python3 - "$target" "$fragment" <<'PYEOF'
import json
import sys


def load_jsonc(fn):
    """JSON con tolerancia a comas finales (JSONC de opencode), sin tocar strings."""
    s = open(fn, encoding="utf-8").read()
    out = []
    in_str = False
    esc = False
    i = 0
    n = len(s)
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
    """Equivalente al `*` de jq: merge recursivo, gana el override."""
    out = dict(base)
    for k, v in override.items():
        if isinstance(out.get(k), dict) and isinstance(v, dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


user = load_jsonc(sys.argv[1])
frag = load_jsonc(sys.argv[2])
user["agent"] = deep_merge(user.get("agent") or {}, frag["agent"])
if "default_agent" not in user:
    user["default_agent"] = frag["default_agent"]
if "$schema" not in user:
    user["$schema"] = frag.get("$schema")
sys.stdout.write(json.dumps(user, indent=2, ensure_ascii=False) + "\n")
PYEOF
)"; then
      merged_ok=1
    fi
  fi
  if [[ $merged_ok -eq 0 || -z "$merged" ]]; then
    printf "   [ERROR]     no se pudo mergear el fragmento SDD en %s (requiere jq o python3; se cancela sin tocar el archivo)\n" "$target" >&2
    return 2
  fi

  if printf '%s\n' "$merged" | diff -q - "$target" >/dev/null 2>&1; then
    printf "   [up-to-date] %s (fragmento SDD)\n" "$target"
    return 0
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    printf "   [pendiente] merge %s (fragmento SDD)\n" "${target#$HOME/}"
    return 1
  fi
  if [[ $CHECK_MODE -eq 1 ]]; then
    printf "   [DESYNC]    %s difiere del fragmento SDD\n" "${target#$HOME/}"
    return 1
  fi

  if [[ ! -e "$target.bak" ]]; then
    cp -- "$target" "$target.bak" || { printf "   [ERROR]     no se pudo crear respaldo %s\n" "$target.bak" >&2; return 2; }
  fi
  # salida pretty (indent=2); los comentarios del .jsonc no se preservan (M3).
  printf '%s\n' "$merged" > "$target" || { printf "   [ERROR]     no se pudo escribir %s\n" "$target" >&2; return 2; }
  printf "   [actualizado] %s (respaldo en .bak)\n" "$target"
  return 1
}

echo "Paso 3 — merge del fragmento SDD sobre el config real de opencode"
rc=0
sync_opencode_config || rc=$?
case "$rc" in
  1) total_updated=$((total_updated + 1)) ;;
  2) total_failures=$((total_failures + 1)) ;;
esac
echo

# --- Paso 4: Registries (.atl) ------------------------------------------------

refresh_project_registries() {
  local dir rc=0 failures=0

  if [[ ${#REGISTRY_PROJECTS[@]} -eq 0 ]]; then
    return 0
  fi
  if ! command -v gentle-ai >/dev/null 2>&1; then
    printf "   [aviso]     gentle-ai no encontrado; se omite refresh de registries\n"
    return 0
  fi

  echo "Registries (.atl) — refresh por proyecto"
  for dir in "${REGISTRY_PROJECTS[@]}"; do
    if [[ ! -d "$dir" ]]; then
      printf "   [ERROR]     no es un directorio: %s\n" "$dir" >&2
      failures=$((failures + 1))
      continue
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] %s: gentle-ai skill-registry refresh --force\n" "$dir"
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [FALTA]     %s: registry desactualizado o pendiente de verificar\n" "$dir"
    else
      rc=0
      (cd "$dir" && gentle-ai skill-registry refresh --force) || rc=$?
      if [[ $rc -eq 0 ]]; then
        printf "   [actualizado] %s\n" "$dir"
      else
        printf "   [ERROR]     falló refresh de registry en %s\n" "$dir" >&2
        failures=$((failures + 1))
      fi
    fi
  done
  return "$failures"
}

echo "Paso 4 — registries"
rc=0
refresh_project_registries || rc=$?
total_failures=$((total_failures + rc))
echo

# --- Resumen ----------------------------------------------------------------

echo "=================================================="
echo "Resumen:"
echo "  Skills exclusivas : ${#SKILLS[@]}"
echo "  Overlays          : ${#OVERLAYS[@]}"
echo "  Up-to-date/ok     : -"
echo "  Actualizados      : $total_updated"
echo "  Errores           : $total_failures"

desync=0
if [[ $CHECK_MODE -eq 1 ]]; then
  echo "  (modo verificación --check: no se modificó ningún archivo)"
  if [[ $total_failures -eq 0 && $total_updated -eq 0 ]]; then
    echo "  Estado            : sincronizado (cero desyncs)"
  else
    echo "  Estado            : hay desyncs o faltantes (ver líneas [DESYNC]/[FALTA]/[ERROR])"
    desync=1
  fi
elif [[ $DRY_RUN -eq 1 ]]; then
  echo "  (modo ensayo --dry-run: no se modificó ningún archivo)"
elif [[ $total_failures -eq 0 ]]; then
  echo "  Estado            : sincronizado (base de Alan + bloques sdd-own aplicados)"
fi

if [[ $total_failures -ne 0 ]]; then
  exit 2
fi
if [[ $CHECK_MODE -eq 1 && $desync -eq 1 ]]; then
  exit 1
fi
exit 0