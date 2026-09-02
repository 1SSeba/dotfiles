#!/bin/bash
# Restaura los wallpapers animados (video) al arrancar Hyprland, uno por monitor.
#
# A diferencia de la versión vieja (que switchwall.sh regeneraba en cada cambio de
# wallpaper), este script es estático: simplemente lee el estado que switchwall.sh
# ya guarda en config.json (background.wallpaperPath / wallpaperPathByMonitor) y
# lanza mpvpaper para cada monitor conectado cuyo wallpaper efectivo sea un video.
# No hace falta tocarlo a mano ni regenerarlo.

SHELL_CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
VIDEO_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 video-align-x=0.5 video-align-y=0.5 load-scripts=no"

is_video() {
    local extension="${1##*.}"
    [[ "$extension" == "mp4" || "$extension" == "webm" || "$extension" == "mkv" || "$extension" == "avi" || "$extension" == "mov" ]]
}

[ -f "$SHELL_CONFIG_FILE" ] || exit 0
command -v mpvpaper &>/dev/null || exit 0
command -v hyprctl &>/dev/null || exit 0
command -v jq &>/dev/null || exit 0

# Hyprland puede tardar un toque en tener listos los monitores al arrancar.
for i in $(seq 1 20); do
    monitor_count=$(hyprctl monitors -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
    [ "$monitor_count" -gt 0 ] && break
    sleep 0.5
done

global_path=$(jq -r '.background.wallpaperPath // ""' "$SHELL_CONFIG_FILE")

for monitor in $(hyprctl monitors -j | jq -r '.[].name'); do
    path=$(jq -r --arg m "$monitor" '.wallpaperPathByMonitor[$m] // ""' "$SHELL_CONFIG_FILE")
    [ -z "$path" ] && path="$global_path"

    if [ -n "$path" ] && [ -f "$path" ] && is_video "$path"; then
        mpvpaper -o "$VIDEO_OPTS" "$monitor" "$path" &
        sleep 0.1
    fi
done
