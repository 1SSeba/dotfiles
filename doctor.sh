#!/usr/bin/env bash
# Revisa por qué la shell no carga. No modifica nada.
STATE="$HOME/.local/state/quickshell"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
ok()   { printf '\033[1;32m  ok  \033[0m %s\n' "$*"; }
bad()  { printf '\033[1;31m FALTA\033[0m %s\n' "$*"; fail=1; }
warn() { printf '\033[1;33m  ??  \033[0m %s\n' "$*"; }

echo "== binarios =="
for b in hyprland qs matugen fuzzel kitty fish starship jq g++; do
  command -v "$b" >/dev/null && ok "$b" || bad "$b  (falta el paquete)"
done

echo; echo "== configuración =="
[ -f "$HOME/.config/hypr/hyprland.conf" ] && ok "hyprland.conf" || bad "~/.config/hypr/hyprland.conf"
[ -f "$HOME/.config/quickshell/ii/shell.qml" ] && ok "quickshell/ii/shell.qml" || bad "~/.config/quickshell/ii/shell.qml"
[ -f "$HOME/.config/illogical-impulse/config.json" ] && ok "illogical-impulse/config.json" || bad "config.json de la shell"
while read -r p; do
  [ -e "$HOME/.config/hypr/$p" ] || bad "hyprland.conf hace source de un archivo que no existe: $p"
done < <(grep -h '^[[:space:]]*source[[:space:]]*=' "$HOME/.config/hypr/hyprland.conf" 2>/dev/null | sed 's/.*=[[:space:]]*//')

echo; echo "== shim de WebEngine (LD_PRELOAD) =="
shim="$HOME/.local/lib/qs-webengine-shim/libqs-webengine-shim.so"
[ -f "$shim" ] && ok "$shim" || bad "$shim  → corre: ~/.local/lib/qs-webengine-shim/build.sh"

echo; echo "== estado / colores =="
[ -f "$STATE/user/generated/material_colors.scss" ] && ok "colores generados" || bad "$STATE/user/generated  → ./install.sh los siembra"
[ -d "$STATE/.venv" ] && ok "venv de Python" || bad "$STATE/.venv  → ./setup.sh --venv"

echo; echo "== fuentes =="
fc-list 2>/dev/null | grep -qi 'google sans' && ok "Google Sans Flex" || bad "Google Sans Flex → ./setup.sh --fonts"
fc-list 2>/dev/null | grep -qi 'material symbols' && ok "Material Symbols" || bad "Material Symbols (ttf-material-symbols-variable-git)"

echo; echo "== wallpaper =="
wp=$(jq -r '.background.wallpaperPath // empty' "$HOME/.config/illogical-impulse/config.json" 2>/dev/null)
[ -z "$wp" ] && wp=$(grep -o '"wallpaperPath": *"[^"]*"' "$HOME/.config/illogical-impulse/config.json" 2>/dev/null | head -1 | cut -d'"' -f4)
if [ -n "$wp" ]; then
  [ -f "$wp" ] && ok "wallpaper: $wp" || warn "wallpaperPath apunta a algo que no existe aquí: $wp"
fi

echo; echo "== la shell arranca? =="
if command -v qs >/dev/null; then
  out=$(timeout 15 qs -c ii --check 2>&1 || timeout 15 qs -c ii -n 2>&1)
  if echo "$out" | grep -qiE 'error|cannot|no such|undefined'; then
    printf '\033[1;31m ERROR\033[0m salida de quickshell:\n'
    echo "$out" | grep -iE 'error|cannot|no such|undefined' | head -15 | sed 's/^/       /'
    fail=1
  else
    ok "quickshell carga la config sin errores"
  fi
fi

echo
[ "$fail" -eq 0 ] && printf '\033[1;32mTodo en orden.\033[0m\n' \
                  || printf '\033[1;31mHay cosas faltantes (arriba).\033[0m Prueba: ./setup.sh\n'
