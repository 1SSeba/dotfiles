#!/usr/bin/env bash
# Copia la config viva de ~/.config hacia este repo.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXC=(--exclude='*.bak.*' --exclude='*.bak' --exclude='*.bak[0-9]*' --exclude='*.bak-*'
     --exclude='*.tar.gz' --exclude='ii-backups' --exclude='.git' --exclude='__pycache__'
     --exclude='*.log' --exclude='config.json.antes-widgets' --exclude='gtk-3.0/bookmarks')
cd "$HOME/.config"
for d in hypr quickshell/ii illogical-impulse fish kitty foot fuzzel matugen wlogout \
         mpv cava micro kde-material-you-colors gtk-3.0 gtk-4.0 Kvantum zshrc.d autostart; do
  [ -e "$d" ] && rsync -a --delete --relative "${EXC[@]}" "./$d" "$R/.config/"
done
for f in starship.toml mimeapps.list gtkrc gtkrc-2.0 kdeglobals; do
  [ -f "$f" ] && rsync -a "${EXC[@]}" "$f" "$R/.config/"
done
for f in .zshrc .bashrc .bash_profile; do
  [ -f "$HOME/$f" ] && rsync -a "$HOME/$f" "$R/$f"
done
# El shim de WebEngine vive fuera de ~/.config
if [ -d "$HOME/.local/lib/qs-webengine-shim" ]; then
  mkdir -p "$R/local/lib/qs-webengine-shim"
  rsync -a --exclude='*.so' "$HOME/.local/lib/qs-webengine-shim/" "$R/local/lib/qs-webengine-shim/"
fi

echo ":: repo actualizado en $R"
