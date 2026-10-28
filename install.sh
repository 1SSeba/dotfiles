#!/usr/bin/env bash
# Aplica esta configuración al sistema (hace backup de lo que ya exista).
# No instala paquetes: para eso está setup.sh.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.dotfiles-backup-$STAMP"
STATE="$HOME/.local/state/quickshell"

c_info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
c_warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
c_ok()   { printf '\033[1;32m::\033[0m %s\n' "$*"; }

# ------------------------------------------------------------------ 1. backup
c_info "Backup de la config actual en $BACKUP"
mkdir -p "$BACKUP"
for item in "$SRC"/.config/*; do
  name="$(basename "$item")"
  [ -e "$HOME/.config/$name" ] && cp -a "$HOME/.config/$name" "$BACKUP/"
done
for f in .zshrc .bashrc .bash_profile; do
  [ -f "$HOME/$f" ] && cp -a "$HOME/$f" "$BACKUP/"
done

# ------------------------------------------------------------------ 2. config
c_info "Copiando ~/.config"
mkdir -p "$HOME/.config"
rsync -a "$SRC/.config/" "$HOME/.config/"
for f in .zshrc .bashrc .bash_profile; do
  [ -f "$SRC/$f" ] && cp -a "$SRC/$f" "$HOME/$f"
done

# Rutas absolutas de la máquina de origen -> el $HOME de esta
for f in .config/fish/fish_variables .config/hypr/hyprlock/colors.conf .config/illogical-impulse/config.json; do
  [ -f "$HOME/$f" ] && sed -i "s|/home/scruzd|$HOME|g" "$HOME/$f"
done

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

# ------------------------------------------------------------------ 6. avisos
echo
c_ok "Configuración aplicada. Backup en $BACKUP"
command -v qs >/dev/null || c_warn "No encontré 'qs' (quickshell). Corre ./setup.sh --deps o la shell no cargará."
[ -d "$STATE/.venv" ] || c_warn "Falta el entorno Python ($STATE/.venv). Corre ./setup.sh --venv."
[ -d "$HOME/.local/share/fonts/illogical-impulse-google-sans-flex" ] || \
  c_warn "Falta la fuente Google Sans Flex. Corre ./setup.sh --fonts."
echo "   Ajusta ~/.config/hypr/monitors.conf a tus pantallas."
echo "   Revisa 'wallpaperPath' en ~/.config/illogical-impulse/config.json (apunta a una ruta de la otra máquina)."
echo "   Recarga con: hyprctl reload && qs -c ii"
echo "   ¿Algo no carga? Corre ./doctor.sh"
