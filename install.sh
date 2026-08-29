#!/usr/bin/env bash
# Aplica esta configuración al sistema (hace backup de lo que ya exista).
# No instala paquetes: para eso está setup.sh.
#
# Uso:
#   ./install.sh              copia todo y aplica
#   ./install.sh --dry-run    muestra qué cambiaría, sin tocar nada
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.dotfiles-backup-$STAMP"
STATE="$HOME/.local/state/quickshell"
KEEP_BACKUPS=5
DRY_RUN=0

c_info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
c_warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
c_ok()   { printf '\033[1;32m::\033[0m %s\n' "$*"; }
c_err()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,7p' "$0"; exit 0 ;;
    *) c_err "Opción desconocida: $1 (prueba --dry-run)"; exit 1 ;;
  esac
done

# Si algo falla a mitad de camino, que quede clarísimo dónde está el respaldo
# en vez de dejar al usuario adivinando qué se alcanzó a copiar.
fail_msg() {
  c_err "install.sh falló en la línea $1"
  [ -d "$BACKUP" ] && c_warn "Tu config previa sigue intacta en $BACKUP"
  exit 1
}
trap 'fail_msg "$LINENO"' ERR

# ------------------------------------------------------------------ 0. checks
[ -d "$SRC/.config" ] || { c_err "no encuentro $SRC/.config; ¿estás corriendo esto desde el repo?"; exit 1; }
command -v rsync >/dev/null || { c_err "falta rsync (setup.sh lo instala en la sección 1)"; exit 1; }

RSYNC_FLAGS=(-a)
if [ "$DRY_RUN" -eq 1 ]; then
  RSYNC_FLAGS+=(-n -v)
  c_warn "--dry-run: no se toca nada, solo se muestra"
fi

# ------------------------------------------------------------------ 1. backup
if [ "$DRY_RUN" -eq 0 ]; then
  c_info "Backup de la config actual en $BACKUP"
  mkdir -p "$BACKUP"
  for item in "$SRC"/.config/*; do
    name="$(basename "$item")"
    [ -e "$HOME/.config/$name" ] && cp -a "$HOME/.config/$name" "$BACKUP/"
  done
  for f in .zshrc .bashrc .bash_profile; do
    [ -f "$HOME/$f" ] && cp -a "$HOME/$f" "$BACKUP/"
  done
  if [ -z "$(ls -A "$BACKUP" 2>/dev/null)" ]; then
    rmdir "$BACKUP" 2>/dev/null || true
    c_info "nada que respaldar (primera instalación)"
  fi

  # No dejes que los backups se acumulen para siempre: te quedas con los
  # últimos $KEEP_BACKUPS y podas el resto.
  mapfile -t viejos < <(ls -1d "$HOME"/.dotfiles-backup-* 2>/dev/null | sort | head -n -"$KEEP_BACKUPS" || true)
  if [ "${#viejos[@]}" -gt 0 ]; then
    c_info "Podando ${#viejos[@]} backup(s) viejo(s), me quedo con los últimos $KEEP_BACKUPS"
    rm -rf "${viejos[@]}"
  fi
fi

# ------------------------------------------------------------------ 2. config
c_info "Copiando ~/.config"
mkdir -p "$HOME/.config"
rsync "${RSYNC_FLAGS[@]}" "$SRC/.config/" "$HOME/.config/"
for f in .zshrc .bashrc .bash_profile; do
  [ -f "$SRC/$f" ] || continue
  if [ "$DRY_RUN" -eq 1 ]; then
    c_info "(dry-run) copiaría $f"
  else
    cp -a "$SRC/$f" "$HOME/$f"
  fi
done

if [ "$DRY_RUN" -eq 1 ]; then
  c_ok "dry-run terminado, nada se tocó"
  exit 0
fi

# ------------------------------------------------------------------ 3. shim
# La shell se lanza con LD_PRELOAD de este shim (habilita WebEngineView dentro
# de quickshell). Sin él, hyprland/execs.conf apunta a una .so inexistente.
c_info "Instalando el shim de WebEngine en ~/.local/lib"
mkdir -p "$HOME/.local/lib"
rsync -a "$SRC/local/lib/qs-webengine-shim" "$HOME/.local/lib/"
if command -v g++ >/dev/null; then
  ( cd "$HOME/.local/lib/qs-webengine-shim" && ./build.sh ) || c_warn "no se pudo compilar el shim"
else
  c_warn "falta g++ (base-devel): el shim no se compiló. Corre setup.sh --deps."
fi

# ------------------------------------------------------------------ 4. estado
# En un equipo nuevo no existen los colores generados y la shell arranca sin
# tema (o directamente falla al cargar). Sembramos unos por defecto.
if [ ! -f "$STATE/user/generated/material_colors.scss" ]; then
  c_info "Sembrando colores por defecto en $STATE/user/generated"
  mkdir -p "$STATE/user/generated"
  rsync -a "$SRC/state-seed/user/generated/" "$STATE/user/generated/"
else
  c_info "Ya hay colores generados; no los toco"
fi

# ------------------------------------------------------------------ 5. fuentes
if command -v fc-cache >/dev/null; then
  c_info "Refrescando caché de fuentes"
  fc-cache -f >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ 6. verificación
# Confirma que todo lo que trae el repo realmente llegó a ~/.config antes de
# darlo por bueno (rsync no avisa si algo se saltó por permisos, por ejemplo).
c_info "Verificando la copia"
faltantes=0
while IFS= read -r -d '' rel; do
  [ -e "$HOME/.config/$rel" ] || { c_warn "no llegó: $rel"; faltantes=$((faltantes + 1)); }
done < <(cd "$SRC/.config" && find . -mindepth 1 -maxdepth 1 -printf '%P\0')
if [ "$faltantes" -eq 0 ]; then
  c_ok "todo lo del repo está en ~/.config"
else
  c_warn "$faltantes elemento(s) no llegaron; revisa permisos y vuelve a correr ./install.sh"
fi

# ------------------------------------------------------------------ 7. avisos
echo
if [ -d "$BACKUP" ]; then
  c_ok "Configuración aplicada. Backup en $BACKUP"
else
  c_ok "Configuración aplicada (no había nada previo que respaldar)"
fi
command -v qs >/dev/null || c_warn "No encontré 'qs' (quickshell). Corre ./setup.sh --deps o la shell no cargará."
[ -d "$STATE/.venv" ] || c_warn "Falta el entorno Python ($STATE/.venv). Corre ./setup.sh --venv."
[ -d "$HOME/.local/share/fonts/illogical-impulse-google-sans-flex" ] || \
  c_warn "Falta la fuente Google Sans Flex. Corre ./setup.sh --fonts."
echo "   Ajusta ~/.config/hypr/monitors.conf a tus pantallas."
echo "   Revisa 'wallpaperPath' en ~/.config/illogical-impulse/config.json (apunta a una ruta de la otra máquina)."
echo "   Recarga con: hyprctl reload && qs -c ii"
echo "   ¿Algo no carga? Corre ./doctor.sh"
