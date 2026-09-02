#!/usr/bin/env bash
#
# sync-skills.sh — Sincroniza las skills canónicas de este repo (skills/)
# hacia las carpetas globales que usan opencode y pi.
#
# Convención (ver README): cada skill vive duplicada en dos rutas del sistema
# y deben mantenerse idénticas (mirror). Este repo guarda la versión canónica:
#
#   SRC  : <repos>/skills/<skill>/
#   DEST : ~/.agents/skills/<skill>/            (compartida opencode + pi)
#          ~/.config/opencode/skills/<skill>/   (específica de opencode)
#
# Ambas rutas son escaneadas por opencode y por pi (via el skill-registry de
# gentle-pi), de modo que sincronizar ambas cubre los dos runtimes.
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
#   1 = error de estructura/configuración (skills dir no encontrado, etc.)
#   2 = uno o más copiados fallaron

set -euo pipefail

# --- Resolución de rutas ---------------------------------------------------

# Directorio raíz del repo (carpeta que contiene skills/), calculado desde la
# ubicación de este script para que funcione desde cualquier checkout.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/skills"

# Destinos globales. Ambas son escaneadas por opencode y pi.
DEST_DIRS=(
  "$HOME/.agents/skills"
  "$HOME/.config/opencode/skills"
)

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
mapfile -t SKILLS < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
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

# --- Ejecución --------------------------------------------------------------

echo "Sincronizando skills desde: $SRC_DIR"
echo "Destinos:"
for d in "${DEST_DIRS[@]}"; do
  echo "  - $d"
done
echo "Skills: ${SKILLS[*]}"
echo

total_updated=0
total_failures=0
total_uptodate=0

for skill in "${SKILLS[@]}"; do
  src_skill="$SRC_DIR/$skill"
  echo "== $skill =="
  for dest_root in "${DEST_DIRS[@]}"; do
    sync_dir "$src_skill" "$dest_root/$skill"
    case "$?" in
      0) total_uptodate=$((total_uptodate + 1)) ;;
      1) total_updated=$((total_updated + 1)) ;;
      2) total_failures=$((total_failures + 1)) ;;
    esac
  done
  echo
done

# --- Resumen ----------------------------------------------------------------

echo "=================================================="
echo "Resumen:"
echo "  Destinos procesados : $(( ${#SKILLS[@]} * ${#DEST_DIRS[@]} ))"
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

if [[ $total_failures -ne 0 ]]; then
  exit 2
fi
exit 0
