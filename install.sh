#!/usr/bin/env bash
# Instala estos dotfiles en ~/.config (hace backup de lo que ya exista).
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.dotfiles-backup-$STAMP"

echo ":: Backup de la config actual en $BACKUP"
mkdir -p "$BACKUP"
for item in "$SRC"/.config/*; do
  name="$(basename "$item")"
  [ -e "$HOME/.config/$name" ] && cp -a "$HOME/.config/$name" "$BACKUP/"
done
for f in .zshrc .bashrc .bash_profile; do
  [ -f "$HOME/$f" ] && cp -a "$HOME/$f" "$BACKUP/"
done

echo ":: Copiando configuración"
mkdir -p "$HOME/.config"
rsync -a "$SRC/.config/" "$HOME/.config/"
for f in .zshrc .bashrc .bash_profile; do
  [ -f "$SRC/$f" ] && cp -a "$SRC/$f" "$HOME/$f"
done

echo ":: Listo. Revisa ~/.config/hypr/monitors.conf (es específico de cada equipo)."
echo ":: Recarga con: hyprctl reload  &&  qs -c ii"
