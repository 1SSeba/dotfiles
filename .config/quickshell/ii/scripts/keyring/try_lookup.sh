#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Con el keyring bloqueado NO hay que llamar a secret-tool: pedir un secreto
# bloqueado dispara un prompt de desbloqueo y secret-tool se queda esperándolo.
# Al arrancar pasa siempre (la shell pide el keyring antes de que la pantalla
# de bloqueo lo desbloquee), y como unlock.sh mata y relanza gnome-keyring, ese
# prompt nunca se contesta: secret-tool quedaba colgado para siempre,
# KeyringStorage creía que seguía leyendo y no reintentaba nunca — Spotify,
# Google, Mail y las API keys aparecían desconectados hasta reiniciar la shell.
# Bloqueado = no disponible todavía; el que llama reintenta.
if ! "${SCRIPT_DIR}/is_unlocked.sh"; then
    echo 'locked'
    exit 2
fi

# Y un tope por si igual se cuelga (secret service reiniciándose, dbus lento).
data=$(timeout 15 secret-tool lookup 'application' 'illogical-impulse')
status=$?

if [[ -n "$data" ]]; then
    echo "$data"
    exit 0
fi

# secret-tool itself uses exit 1 for "no such secret". Anything else (dbus
# hiccup at login, secret service briefly unreachable, timeout...) is NOT
# the same as "there's no data" — reporting it as "not found" made
# KeyringStorage.qml wipe and overwrite the real keyring blob (tokens for
# Spotify, Google, Mail, etc. all live in that one JSON) on a purely
# transient failure. Treat anything but a clean "not found" as unavailable
# so the caller retries instead of nuking real data.
if [[ $status -ne 1 ]]; then
    echo 'lookup failed'
    exit 2
fi

# Se volvió a bloquear entre medio: tampoco es "no hay datos"
if "${SCRIPT_DIR}/is_unlocked.sh"; then
    echo 'not found'
    exit 1
else
    echo 'locked'
    exit 2
fi
