#!/usr/bin/env bash
# Terminal del bind Super+Return.
#
# Por que existe en vez de usar `kitty -1` pelado: --single-instance usa un
# socket por USUARIO, no por compositor. Con mas de una sesion de Hyprland
# abierta a la vez, el `kitty -1` nuevo le pide a la instancia que ya existe
# —que vive en la otra sesion— que abra la ventana, y la abre ALLA. Desde tu
# pantalla se ve exactamente como que el bind no hace nada.
#
# --instance-group ata la instancia unica a la firma del compositor actual,
# asi cada sesion de Hyprland tiene la suya y la ventana cae donde estas.
group="${HYPRLAND_INSTANCE_SIGNATURE:-${WAYLAND_DISPLAY:-default}}"

if command -v kitty >/dev/null 2>&1; then
    exec kitty --single-instance --instance-group "kitty-${group}" "$@"
fi

# Mismos alternativos que el launch_first_available.sh de upstream
for cmd in foot alacritty wezterm konsole kgx uxterm xterm; do
    if command -v "$cmd" >/dev/null 2>&1; then
        exec "$cmd" "$@"
    fi
done
exit 1
