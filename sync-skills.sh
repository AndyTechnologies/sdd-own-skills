#!/usr/bin/env bash
#
# sync-skills.sh — Sincroniza las skills canónicas de este repo (skills/)
# y el wiring (wiring/) hacia las carpetas globales que usan opencode y pi.
#
# Convención: las skills canónicas viven en este repo y se despliegan a una
# única carpeta real; el resto son symlinks para mantener una única fuente
# de verdad.  Este repo guarda la versión canónica y el script la despliega así:
#
#   SRC  : <repos>/skills/<skill>/
#   DEST : ~/.agents/skills/<skill>/            (carpeta REAL — compartida opencode + pi)
#          ~/.config/opencode/skills/<skill>/   (symlink a ~/.agents/skills/<skill>)
#
# ~/.agents/skills es la única copia física; el resto de runtimes (opencode,
# pi) la leen vía symlinks o por el skill-registry.
#
# Para Claude Code, se crean symlinks adicionales:
#   ~/.claude/skills/<skill>/     -> ../../.agents/skills/<skill>
#   ~/.claude/commands/<file>.md  -> ../.config/opencode/commands/<file>.md  (via symlink)
#   ~/.claude/prompts/sdd/<file>  -> ../.config/opencode/prompts/sdd/<file> (via symlink)
#
# El wiring (wiring/) conecta las skills con el orquestador y también debe
# mantenerse idéntico con los globales; es lo que enruta las fases (p.ej. que
# la quest RFC corre antes de explore). Mapeo:
#
#   wiring/commands/*.md        -> ~/.config/opencode/commands/*.md
#                                 ~/.claude/commands/*.md              (symlink)
#   wiring/prompts/sdd/*.md     -> ~/.config/opencode/prompts/sdd/*.md
#                                 ~/.claude/prompts/sdd/*.md          (symlink)
#   skills/_shared/*.md       -> ~/.agents/skills/_shared/*.md
#                                 ~/.config/opencode/skills/_shared/*.md (symlink)
#
# Sin redundancia: sólo se copia lo que realmente difiere; lo que ya está
# idéntico se reporta como "up-to-date" y no se toca. El script es idempotente
# (ejecutarlo varias veces es un no-op cuando ya está sincronizado).
#
# Uso:
#   ./sync-skills.sh            # sincroniza (copia solo lo que difiere)
#   ./sync-skills.sh --check    # modo verificación: reporta sin copiar
#   ./sync-skills.sh --dry-run  # modo ensayo: muestra qué se haría, sin copiar
#
# Salida (exit code):
#   0 = sincronización completa (todo idéntico o actualizado con éxito)
#   1 = error de estructura/configuración (skills/wiring dir no encontrado, etc.)
#   2 = uno o más copiados fallaron

set -euo pipefail

# --- Resolución de rutas ---------------------------------------------------

# Directorio raíz del repo (carpeta que contiene skills/ y wiring/), calculado
# desde la ubicación de este script para que funcione desde cualquier checkout.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/skills"

# Destinos globales. ~/.agents es la copia física; ~/.config/opencode es un
# symlink que apunta a ~/.agents para evitar duplicación.
DEST_DIRS=(
  "$HOME/.agents/skills"
)
DEST_SYMLINK_DIRS=(
  "$HOME/.config/opencode/skills"
)

# ~/.claude/skills se mantiene como conjunto de symlinks apuntando a .agents/skills
# para conservar una única fuente de verdad; no se copian archivos ahí.
# Análogo para commands y prompts (wiring) de Claude Code.
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_WIRING_BASE="$HOME/.claude"

# Wiring: mapeo de subcarpeta de wiring/ -> lista de destinos globales reales.
# commands/ y prompts/ solo las lee opencode; _shared/ lo comparten los dos
# runtimes (se usa destino por subcarpeta, no un par de raíces como skills).
WIRING_DIR="$SCRIPT_DIR/wiring"

# --- Opciones --------------------------------------------------------------

CHECK_MODE=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --check)    CHECK_MODE=1 ;;
    --dry-run)  DRY_RUN=1 ;;
    -h|--help)
      sed -n '1,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: opción desconocida: $arg" >&2
      echo "Uso: $0 [--check] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# --- Validación de estructura ---------------------------------------------

if [[ ! -d "$SRC_DIR" ]]; then
  echo "error: no se encontró el directorio canónico de skills: $SRC_DIR" >&2
  echo "¿Ejecutas este script desde el checkout correcto del repo?" >&2
  exit 1
fi

# Colección de skills canónicas (subdirectorios de skills/ con SKILL.md).
mapfile -t SKILLS < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | grep -v '^_shared$')
if [[ ${#SKILLS[@]} -eq 0 ]]; then
  echo "error: no hay skills en $SRC_DIR" >&2
  exit 1
fi

# --- Helper: sincroniza un directorio origen a un destino -------------------
#
# Imprime su propio feedback y devuelve:
#   0 = sin cambios (up-to-date)
#   1 = actualizado / pendiente de actualizar
#   2 = error
sync_dir() {
  local src="$1"
  local dest="$2"
  local src_file dest_file rel
  local changed=0
  local rc=0

  if [[ ! -d "$dest" ]]; then
    # El directorio destino no existe: hay que crearlo entero.
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] crear y copiar %s\n" "$dest"
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [FALTA]     %s\n" "$dest"
    else
      if ! mkdir -p "$dest"; then
        printf "   [ERROR]     no se pudo crear %s\n" "$dest" >&2
        return 2
      fi
      cp -R "$src/." "$dest/" || { printf "   [ERROR]     copia a %s\n" "$dest" >&2; return 2; }
      printf "   [creado]    %s\n" "$dest"
    fi
    return 1
  fi

  # Sincronización archivo a archivo dentro del directorio de la skill.
  while IFS= read -r -d '' src_file; do
    rel="${src_file#"$src"/}"
    dest_file="$dest/$rel"
    if [[ ! -e "$dest_file" ]] || ! diff -q "$src_file" "$dest_file" >/dev/null 2>&1; then
      changed=1
      if [[ $DRY_RUN -eq 1 ]]; then
        printf "   [pendiente] %s -> %s\n" "${src_file#$SRC_DIR/}" "${dest_file#$HOME/}"
      elif [[ $CHECK_MODE -eq 1 ]]; then
        printf "   [DESYNC]    %s (canónico: %s)\n" "${dest_file#$HOME/}" "${src_file#$SRC_DIR/}"
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

# --- Helper: sincroniza wiring/ hacia sus destinos reales --------------------
#
# Reutiliza sync_dir por unidad de destino. Cada subcarpeta de wiring/
# ("commands", "prompts", "_shared") se mapea a rutas destino ABSOLUTAS que
# opencode/pi leen realmente:
#
#   wiring/commands/*.md        -> ~/.config/opencode/commands/*.md
#   wiring/prompts/sdd/*.md     -> ~/.config/opencode/prompts/sdd/*.md
#   skills/_shared/*.md        -> ~/.agents/skills/_shared/*.md
#                                 ~/.config/opencode/skills/_shared (symlink)
#
# Los archivos globales que no existen como canónicos en wiring/ se dejan
# intactos (no se borra nada del destino).
sync_wiring() {
  local sub dest total_updated=0 total_failures=0 total_uptodate=0

  if [[ ! -d "$WIRING_DIR" ]]; then
    echo "error: no se encontró el directorio de wiring: $WIRING_DIR" >&2
    return 2
  fi

  echo "Wiring (sincronizando $WIRING_DIR)"
  for sub in "${!WIRING_SUBDIR_DESTS[@]}"; do
    local src_sub="${WIRING_SUBDIR_SRCS[$sub]:-$WIRING_DIR/$sub}"
    [[ -d "$src_sub" ]] || continue
    for dest in ${WIRING_SUBDIR_DESTS[$sub]}; do
      # `|| rc=$?` captura el código sin abortar bajo `set -e`; si falla anticipadamente
      # (rc ya seteado por un comando previo del bucle), lo reseteamos por iteración.
      local rc=0
      sync_dir "$src_sub" "$dest" || rc=$?
      case "$rc" in
        0) total_uptodate=$((total_uptodate + 1)) ;;
        1) total_updated=$((total_updated + 1)) ;;
        2) total_failures=$((total_failures + 1)) ;;
      esac
    done
  done

  printf "  Wiring resumen   : up-to-date=%s actualizados=%s errores=%s\n" \
    "$total_uptodate" "$total_updated" "$total_failures"

  # --- Symlinks de wiring en ~/.config/opencode que apuntan a ~/.agents --------
  # Solo _shared necesita symlink porque su copia real vive en ~/.agents/skills/_shared;
  # commands y prompts son copias reales en ~/.config/opencode.
  local wiring_link="$HOME/.config/opencode/skills/_shared"
  # El symlink vive en ~/.config/opencode/skills/, que está 3 niveles bajo $HOME,
  # así que necesita ../../../ para llegar a ~/.agents/skills/_shared.
  local wiring_target="../../../.agents/skills/_shared"
  if [[ -L "$wiring_link" ]]; then
    local current
    current="$(readlink "$wiring_link")"
    if [[ "$current" == "$wiring_target" ]]; then
      printf "   [up-to-date] %s\n" "$wiring_link"
    else
      if [[ $DRY_RUN -eq 1 ]]; then
        printf "   [pendiente] reemplazar symlink %s -> %s\n" "$wiring_link" "$wiring_target"
      elif [[ $CHECK_MODE -eq 1 ]]; then
        printf "   [DESYNC]    %s (debería apuntar a %s)\n" "$wiring_link" "$wiring_target"
      else
        rm "$wiring_link" && ln -s "$wiring_target" "$wiring_link" && printf "   [creado]    %s -> %s\n" "$wiring_link" "$wiring_target" || printf "   [ERROR]     symlink %s\n" "$wiring_link" >&2
      fi
    fi
  elif [[ ! -e "$wiring_link" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] symlink %s -> %s\n" "$wiring_link" "$wiring_target"
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [FALTA]     %s (debería ser symlink a %s)\n" "$wiring_link" "$wiring_target"
    else
      mkdir -p "$(dirname "$wiring_link")" && ln -s "$wiring_target" "$wiring_link" && printf "   [creado]    %s -> %s\n" "$wiring_link" "$wiring_target" || printf "   [ERROR]     symlink %s\n" "$wiring_link" >&2
    fi
  fi

  return "$total_failures"
}

# Mapeo subcarpeta (wiring/<sub>) -> rutas destino ABSOLUTAS completas.
# commands/prompts solo opencode (~/.config/opencode); _shared es la única copia
# física en ~/.agents/skills/_shared; ~/.config/opencode/skills/_shared es un
# symlink a esa ubicación.
declare -A WIRING_SUBDIR_DESTS=(
  [commands]="$HOME/.config/opencode/commands"
  [prompts]="$HOME/.config/opencode/prompts"
  [_shared]="$HOME/.agents/skills/_shared"
)

# Fuente por subcarpeta de wiring. commands/prompts viven en wiring/;
# _shared vive en skills/_shared (las skills los referencian como skills/_shared/…).
declare -A WIRING_SUBDIR_SRCS=(
  [commands]="$WIRING_DIR/commands"
  [prompts]="$WIRING_DIR/prompts"
  [_shared]="$SRC_DIR/_shared"
)

# --- Ejecución --------------------------------------------------------------

echo "Sincronizando skills desde: $SRC_DIR"
echo "Destinos:"
for d in "${DEST_DIRS[@]}"; do
  echo "  - $d  (copia física)"
done
for d in "${DEST_SYMLINK_DIRS[@]}"; do
  echo "  - $d  (symlink a ~/.agents/skills)"
done
echo "Skills: ${SKILLS[*]}"
echo

total_updated=0
total_failures=0
total_uptodate=0

for skill in "${SKILLS[@]}"; do
  src_skill="$SRC_DIR/$skill"
  echo "== $skill =="
  # 1) Copia física a ~/.agents/skills
  rc=0
  sync_dir "$src_skill" "$HOME/.agents/skills/$skill" || rc=$?
  case "$rc" in
    0) total_uptodate=$((total_uptodate + 1)) ;;
    1) total_updated=$((total_updated + 1)) ;;
    2) total_failures=$((total_failures + 1)) ;;
  esac

  # 2) Symlinks en destinos que apuntan a ~/.agents/skills
  for dest_root in "${DEST_SYMLINK_DIRS[@]}"; do
    dest_link="$dest_root/$skill"
    # ~/.config/opencode/skills/<skill> está 3 niveles bajo $HOME
    # (opencode/skills/<skill> a partir de ~/.config), así que necesita ../../..
    # para llegar a ~/.agents/skills/<skill>.
    relative_target="../../../.agents/skills/$skill"

    # Si ya es un symlink correcto, up-to-date.
    if [[ -L "$dest_link" ]]; then
      current_target="$(readlink "$dest_link")"
      if [[ "$current_target" == "$relative_target" ]]; then
        printf "   [up-to-date] %s\n" "$dest_link"
        total_uptodate=$((total_uptodate + 1))
        continue
      else
        # Symlink apunta a otro lado: reemplazar.
        if [[ $DRY_RUN -eq 1 ]]; then
          printf "   [pendiente] reemplazar symlink %s -> %s\n" "$dest_link" "$relative_target"
          total_updated=$((total_updated + 1))
          continue
        elif [[ $CHECK_MODE -eq 1 ]]; then
          printf "   [DESYNC]    %s (debería apuntar a %s, apunta a %s)\n" "$dest_link" "$relative_target" "$current_target"
          total_updated=$((total_updated + 1))
          continue
        else
          rm "$dest_link" || { printf "   [ERROR]     no se pudo borrar symlink viejo %s\n" "$dest_link" >&2; total_failures=$((total_failures + 1)); continue; }
        fi
      fi
    # Si existe como directorio real, reemplazar por symlink.
    elif [[ -d "$dest_link" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        printf "   [pendiente] reemplazar directorio por symlink %s\n" "$dest_link"
        total_updated=$((total_updated + 1))
        continue
      elif [[ $CHECK_MODE -eq 1 ]]; then
        printf "   [DESYNC]    %s es un directorio real; debería ser symlink\n" "$dest_link"
        total_updated=$((total_updated + 1))
        continue
      else
        rm -rf "$dest_link" || { printf "   [ERROR]     no se pudo borrar directorio %s\n" "$dest_link" >&2; total_failures=$((total_failures + 1)); continue; }
      fi
    fi

    # Crear directorio padre si falta.
    if [[ ! -d "$(dirname "$dest_link")" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        printf "   [pendiente] crear directorio %s\n" "$(dirname "$dest_link")"
      elif [[ $CHECK_MODE -eq 0 ]]; then
        mkdir -p "$(dirname "$dest_link")" || { printf "   [ERROR]     no se pudo crear %s\n" "$(dirname "$dest_link")" >&2; total_failures=$((total_failures + 1)); continue; }
      fi
    fi

    # Crear el symlink.
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] symlink %s -> %s\n" "$dest_link" "$relative_target"
      total_updated=$((total_updated + 1))
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [FALTA]     %s (debería ser symlink a %s)\n" "$dest_link" "$relative_target"
      total_updated=$((total_updated + 1))
    else
      ln -s "$relative_target" "$dest_link" || { printf "   [ERROR]     no se pudo crear symlink %s\n" "$dest_link" >&2; total_failures=$((total_failures + 1)); continue; }
      printf "   [creado]    %s -> %s\n" "$dest_link" "$relative_target"
      total_updated=$((total_updated + 1))
    fi
  done
  echo
done

# --- Wiring (commands/prompts/_shared) ---------------------------------------
echo "--------------------------------------------------"
wiring_status=0
sync_wiring || wiring_status=$?
if [[ $wiring_status -ne 0 ]]; then
  total_failures=$((total_failures + wiring_status))
fi
echo

# --- Resumen ----------------------------------------------------------------

echo "=================================================="
echo "Resumen:"
echo "  Destinos procesados : $(( ${#SKILLS[@]} * ( ${#DEST_DIRS[@]} + ${#DEST_SYMLINK_DIRS[@]} ) ))"
echo "  Up-to-date          : $total_uptodate"
echo "  Actualizados        : $total_updated"
echo "  Errores             : $total_failures"

if [[ $CHECK_MODE -eq 1 ]]; then
  echo "  (modo verificación --check: no se modificó ningún archivo)"
elif [[ $DRY_RUN -eq 1 ]]; then
  echo "  (modo ensayo --dry-run: no se modificó ningún archivo)"
elif [[ $total_failures -eq 0 ]]; then
  echo "  Estado              : sincronizado (versión canónica == globales)"
fi

# --- Symlinks en ~/.claude/skills (espejo de .agents) ----------------------
# En lugar de copiar archivos, creamos symlinks relativos a .agents/skills para
# mantener una única fuente de verdad y evitar duplicación.
echo "--------------------------------------------------"
claude_total_created=0
claude_total_updated=0
claude_total_uptodate=0
claude_total_failures=0

if [[ -d "$CLAUDE_SKILLS_DIR" ]]; then
  echo "Claude skills (symlinks a $CLAUDE_SKILLS_DIR)"
  for skill in "${SKILLS[@]}"; do
    src_skill="$HOME/.agents/skills/$skill"
    dest_link="$CLAUDE_SKILLS_DIR/$skill"

    # Resolución de ruta relativa desde ~/.claude/skills/<skill> -> ~/.agents/skills/<skill>
    relative_target="../../.agents/skills/$skill"

    # Si ya existe como symlink y apunta al destino correcto, está up-to-date.
    if [[ -L "$dest_link" ]]; then
      current_target="$(readlink "$dest_link")"
      if [[ "$current_target" == "$relative_target" ]]; then
        printf "   [up-to-date] %s\n" "$dest_link"
        claude_total_uptodate=$((claude_total_uptodate + 1))
        continue
      else
        # Symlink apunta a otro lado: lo reemplazamos.
        if [[ $DRY_RUN -eq 1 ]]; then
          printf "   [pendiente] reemplazar symlink %s -> %s\n" "$dest_link" "$relative_target"
          claude_total_updated=$((claude_total_updated + 1))
          continue
        elif [[ $CHECK_MODE -eq 1 ]]; then
          printf "   [DESYNC]    %s (debería apuntar a %s, apunta a %s)\n" "$dest_link" "$relative_target" "$current_target"
          claude_total_updated=$((claude_total_updated + 1))
          continue
        else
          rm "$dest_link" || { printf "   [ERROR]     no se pudo borrar symlink viejo %s\n" "$dest_link" >&2; claude_total_failures=$((claude_total_failures + 1)); continue; }
        fi
      fi
    # Si existe como directorio real, lo reemplazamos por symlink (solo en ejecución real).
    elif [[ -d "$dest_link" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        printf "   [pendiente] reemplazar directorio por symlink %s\n" "$dest_link"
        claude_total_updated=$((claude_total_updated + 1))
        continue
      elif [[ $CHECK_MODE -eq 1 ]]; then
        printf "   [DESYNC]    %s es un directorio real; debería ser symlink\n" "$dest_link"
        claude_total_updated=$((claude_total_updated + 1))
        continue
      else
        rm -rf "$dest_link" || { printf "   [ERROR]     no se pudo borrar directorio %s\n" "$dest_link" >&2; claude_total_failures=$((claude_total_failures + 1)); continue; }
      fi
    fi

    # Crear el directorio padre si falta.
    if [[ ! -d "$(dirname "$dest_link")" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        printf "   [pendiente] crear directorio %s\n" "$(dirname "$dest_link")"
      elif [[ $CHECK_MODE -eq 0 ]]; then
        mkdir -p "$(dirname "$dest_link")" || { printf "   [ERROR]     no se pudo crear %s\n" "$(dirname "$dest_link")" >&2; claude_total_failures=$((claude_total_failures + 1)); continue; }
      fi
    fi

    # Crear el symlink.
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] symlink %s -> %s\n" "$dest_link" "$relative_target"
      claude_total_created=$((claude_total_created + 1))
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [FALTA]     %s (debería ser symlink a %s)\n" "$dest_link" "$relative_target"
      claude_total_created=$((claude_total_created + 1))
    else
      ln -s "$relative_target" "$dest_link" || { printf "   [ERROR]     no se pudo crear symlink %s\n" "$dest_link" >&2; claude_total_failures=$((claude_total_failures + 1)); continue; }
      printf "   [creado]    %s -> %s\n" "$dest_link" "$relative_target"
      claude_total_created=$((claude_total_created + 1))
    fi
  done
  printf "  Claude skills    : up-to-date=%s creados/reemplazados=%s errores=%s\n" \
    "$claude_total_uptodate" "$claude_total_created" "$claude_total_failures"
else
  echo "Claude skills: $CLAUDE_SKILLS_DIR no existe; se omite."
fi
echo

# --- Wiring para Claude (symlinks en ~/.claude) ------------------------------
# Creamos symlinks relativos en ~/.claude que apuntan a las carpetas reales de
# ~/.config/opencode para commands y prompts, manteniene una única fuente de
# verdad.  Para _shared, el destino ya son ~/.agents/skills/_shared y
# ~/.config/opencode/skills/_shared; no hace falta duplicar en ~/.claude
# porque los agentes de Claude Code leen directamente ~/.claude/skills (que
# ya son symlinks a .agents) y ahí ya está el contenido de _shared.
echo "--------------------------------------------------"
claude_wiring_total_created=0
claude_wiring_total_updated=0
claude_wiring_total_uptodate=0
claude_wiring_total_failures=0

# Mapa de wiring/<subcarpeta> -> destino real en ~/.config/opencode (origen del
# symlink en ~/.claude).  Keys: subdirectorios de wiring/.
declare -A CLAUDE_WIRING_SYMLINKS=(
  [commands]="$HOME/.config/opencode/commands"
  [prompts]="$HOME/.config/opencode/prompts"
)

for sub in "${!CLAUDE_WIRING_SYMLINKS[@]}"; do
  src_dir="${CLAUDE_WIRING_SYMLINKS[$sub]}"
  dest_base="$CLAUDE_WIRING_BASE/$sub"
  [[ -d "$src_dir" ]] || continue

  echo "Claude wiring: $sub (symlinks a $src_dir)"
  while IFS= read -r -d '' src_file; do
    rel="${src_file#"$src_dir"/}"
    dest_link="$dest_base/$rel"
    # ~/.claude/<sub>/<file> está 2 niveles bajo $HOME (Claude + <sub>),
    # así que necesita ../../ para llegar a ~/.config/opencode/<sub>/<file>.
    relative_target="../../.config/opencode/$sub/$rel"

    # Evaluar si ya es un symlink correcto.
    if [[ -L "$dest_link" ]]; then
      current_target="$(readlink "$dest_link")"
      if [[ "$current_target" == "$relative_target" ]]; then
        printf "   [up-to-date] %s\n" "$dest_link"
        claude_wiring_total_uptodate=$((claude_wiring_total_uptodate + 1))
        continue
      else
        # Symlink apunta a otro lado: reemplazar.
        if [[ $DRY_RUN -eq 1 ]]; then
          printf "   [pendiente] reemplazar symlink %s -> %s\n" "$dest_link" "$relative_target"
          claude_wiring_total_updated=$((claude_wiring_total_updated + 1))
          continue
        elif [[ $CHECK_MODE -eq 1 ]]; then
          printf "   [DESYNC]    %s (debería apuntar a %s, apunta a %s)\n" "$dest_link" "$relative_target" "$current_target"
          claude_wiring_total_updated=$((claude_wiring_total_updated + 1))
          continue
        else
          rm "$dest_link" || { printf "   [ERROR]     no se pudo borrar symlink viejo %s\n" "$dest_link" >&2; claude_wiring_total_failures=$((claude_wiring_total_failures + 1)); continue; }
        fi
      fi
    # Si existe como archivo regular, reemplazar.
    elif [[ -f "$dest_link" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        printf "   [pendiente] reemplazar archivo por symlink %s\n" "$dest_link"
        claude_wiring_total_updated=$((claude_wiring_total_updated + 1))
        continue
      elif [[ $CHECK_MODE -eq 1 ]]; then
        printf "   [DESYNC]    %s es un archivo real; debería ser symlink\n" "$dest_link"
        claude_wiring_total_updated=$((claude_wiring_total_updated + 1))
        continue
      else
        rm "$dest_link" || { printf "   [ERROR]     no se pudo borrar archivo %s\n" "$dest_link" >&2; claude_wiring_total_failures=$((claude_wiring_total_failures + 1)); continue; }
      fi
    fi

    # Crear directorio padre si falta.
    if [[ ! -d "$(dirname "$dest_link")" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        printf "   [pendiente] crear directorio %s\n" "$(dirname "$dest_link")"
      elif [[ $CHECK_MODE -eq 0 ]]; then
        mkdir -p "$(dirname "$dest_link")" || { printf "   [ERROR]     no se pudo crear %s\n" "$(dirname "$dest_link")" >&2; claude_wiring_total_failures=$((claude_wiring_total_failures + 1)); continue; }
      fi
    fi

    # Crear el symlink.
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "   [pendiente] symlink %s -> %s\n" "$dest_link" "$relative_target"
      claude_wiring_total_created=$((claude_wiring_total_created + 1))
    elif [[ $CHECK_MODE -eq 1 ]]; then
      printf "   [FALTA]     %s (debería ser symlink a %s)\n" "$dest_link" "$relative_target"
      claude_wiring_total_created=$((claude_wiring_total_created + 1))
    else
      ln -s "$relative_target" "$dest_link" || { printf "   [ERROR]     no se pudo crear symlink %s\n" "$dest_link" >&2; claude_wiring_total_failures=$((claude_wiring_total_failures + 1)); continue; }
      printf "   [creado]    %s -> %s\n" "$dest_link" "$relative_target"
      claude_wiring_total_created=$((claude_wiring_total_created + 1))
    fi
  done < <(find "$src_dir" -type f -print0)
  printf "  Claude wiring (%s): up-to-date=%s creados/reemplazados=%s errores=%s\n" \
    "$sub" "$claude_wiring_total_uptodate" "$claude_wiring_total_created" "$claude_wiring_total_failures"
done
echo

if [[ $total_failures -ne 0 || $claude_total_failures -ne 0 || $claude_wiring_total_failures -ne 0 ]]; then
  exit 2
fi
exit 0
