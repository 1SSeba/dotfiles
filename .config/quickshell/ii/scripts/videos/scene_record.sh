#!/usr/bin/env bash
# Graba con "escenas": compone varias fuentes (pantalla, ventana, cámara,
# imagen) sobre un lienzo y mezcla varias fuentes de audio (sistema, micrófono,
# audio por aplicación). Las escenas se arman desde el Scene Studio, el editor
# flotante de Super+G o la página de grabación de Settings.
#
# No reemplaza a record.sh, que sigue sirviendo los atajos rápidos sin escena.
#
# Arquitectura (probada a mano, ver el plan de la feature):
#   - Cada fuente de video que hay que capturar de la pantalla (pantalla y
#     ventana) es un wf-recorder escribiendo mpegts a su propio FIFO.
#   - Cada fuente de audio por aplicación es un pw-record escribiendo PCM
#     crudo a su propio FIFO.
#   - Un ffmpeg final lee todos los FIFOs + cámaras + imágenes, compone con
#     -filter_complex (scale + overlay en orden z), mezcla el audio con amix
#     y codifica el archivo.
#
# Cambiar de escena implica cortar y reiniciar (~1s), que es el modelo acordado.

CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
STATE_FILE="$HOME/.local/state/quickshell/states.json"
RUNTIME_DIR="/tmp/quickshell/scene_record"
PIDFILE="$RUNTIME_DIR/pids"
MARKER="$RUNTIME_DIR/marker" # lo que busca pgrep para saber si ya está grabando

mkdir -p "$RUNTIME_DIR"

getdate() { date '+%Y-%m-%d_%H.%M.%S'; }
getactivemonitor() { hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'; }
getdefaultmonitorsource() { echo "$(pactl get-default-sink).monitor"; }

# Resuelve el nombre de nodo de una app (ej. "cs2") al object.serial de su
# stream de SALIDA que está sonando ahora.
#
# Hay que hacerlo por serial y no por nombre aunque pw-record acepte las dos
# cosas, por dos razones comprobadas:
#   - el nombre no es único: una app suele tener un nodo de salida Y uno de
#     entrada con el MISMO node.name, así que por nombre podés terminar
#     grabando el micrófono de la app en vez de lo que suena;
#   - si el target no existe, pw-record no falla: cae al source por defecto y
#     te graba el micrófono sin decir nada. Por eso el caller corta si esto
#     devuelve vacío.
resolve_app_serial() {
    local name="$1"
    pw-dump 2>/dev/null | jq -r --arg n "$name" '
        .[] | select(.type == "PipeWire:Interface:Node") | .info.props
        | select(."media.class" == "Stream/Output/Audio")
        | select(."node.name" == $n)
        | ."object.serial"' | head -n1
}

# fracción (0-1) * total -> píxeles pares (algunos encoders rechazan impares)
frac_to_px() {
    awk -v f="$1" -v r="$2" 'BEGIN{v=int(f*r+0.5); if (v%2) v--; if (v<2) v=2; print v}'
}
frac_to_pos() {
    awk -v f="$1" -v r="$2" 'BEGIN{printf "%.0f", f*r}'
}

set_recording_state() {
    local state=$1
    local epoch=0
    [[ "$state" == "true" ]] && epoch=$(date +%s)
    local tmp
    tmp=$(mktemp)
    jq ".record.enable = $state | .record.startEpoch = $epoch" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

stop_recording() {
    notify-send "Recording Stopped" "Stopped" -a 'Recorder' & disown
    if [[ -f "$PIDFILE" ]]; then
        # ffmpeg primero y con SIGINT, para que cierre el mp4 con su trailer.
        # Si se matan antes los productores, el FIFO se corta de golpe y el
        # archivo puede quedar sin índice.
        local ffmpeg_pid
        ffmpeg_pid=$(head -n1 "$PIDFILE")
        [[ -n "$ffmpeg_pid" ]] && kill -INT "$ffmpeg_pid" 2>/dev/null
        sleep 0.4
        tail -n +2 "$PIDFILE" | while read -r pid; do
            [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
        done
        rm -f "$PIDFILE"
    fi
    rm -f "$RUNTIME_DIR"/*.fifo "$MARKER"
    set_recording_state false
}

if pgrep -f "$MARKER" > /dev/null; then
    stop_recording
    exit 0
fi

# ─────────────────────────────────────────────────────────── config y escena

CUSTOM_PATH=$(jq -r ".screenRecord.savePath" "$CONFIG_FILE" 2>/dev/null)
RECORDING_DIR="${CUSTOM_PATH:-$HOME/Videos}"
PRESET=$(jq -r '.screenRecord.x264Preset // "veryfast"' "$CONFIG_FILE")
ENCODER=$(jq -r '.screenRecord.encoder // "software"' "$CONFIG_FILE")
FPS=$(jq -r '.screenRecord.frameRate // 0' "$CONFIG_FILE")
[[ "$FPS" == "0" || "$FPS" == "null" ]] && FPS=60
ACTIVE_SCENE_ID=$(jq -r '.screenRecord.activeSceneId // "screen"' "$CONFIG_FILE")

SCENE=$(jq -c --arg id "$ACTIVE_SCENE_ID" \
    '(.screenRecord.scenes[]? | select(.id == $id)) // {"name":"Pantalla","sources":[],"audio":[]}' "$CONFIG_FILE")
SCENE_NAME=$(jq -r '.name // "?"' <<< "$SCENE")
# Solo las fuentes visibles, en orden de capa
SOURCES=$(jq -c '[.sources[]? | select((.visible // true) == true)] | sort_by(.z // 0)' <<< "$SCENE")
AUDIO=$(jq -c '[.audio[]? | select((.muted // false) == false)]' <<< "$SCENE")
# Una escena sin ninguna fuente de audio saldría muda, que casi nunca es lo
# que se quiere (y es fácil de provocar sin darse cuenta). Si no hay nada,
# se graba el audio del sistema. Para grabar sin audio a propósito, se
# silencian las fuentes desde el mezclador.
if [[ "$(jq 'length' <<< "$AUDIO")" == "0" && "$(jq '.audio | length // 0' <<< "$SCENE")" == "0" ]]; then
    AUDIO='[{"type":"system","id":"","name":"Audio del sistema","volume":1}]'
fi

MONITOR="$(getactivemonitor)"
read -r MON_W MON_H < <(hyprctl monitors -j | jq -r --arg m "$MONITOR" '.[] | select(.name == $m) | "\(.width) \(.height)"')

CANVAS_W=$(jq -r '.screenRecord.canvasWidth // 0' "$CONFIG_FILE")
CANVAS_H=$(jq -r '.screenRecord.canvasHeight // 0' "$CONFIG_FILE")
[[ "$CANVAS_W" == "0" || "$CANVAS_W" == "null" ]] && CANVAS_W="$MON_W"
[[ "$CANVAS_H" == "0" || "$CANVAS_H" == "null" ]] && CANVAS_H="$MON_H"

mkdir -p "$RECORDING_DIR"
cd "$RECORDING_DIR" || exit 1
rm -f "$RUNTIME_DIR"/*.fifo
OUTFILE="./recording_$(getdate).mp4"

# ───────────────────────────────────────────────── fuentes de video → ffmpeg

# El lienzo de fondo es una entrada sintética: así una escena puede no tener
# ninguna fuente de pantalla (ej. solo cámara) y seguir teniendo un fondo.
FF_INPUTS=(-f lavfi -i "color=c=black:s=${CANVAS_W}x${CANVAS_H}:r=${FPS}")
FILTER=""
LAST="[0:v]"
IDX=1
PRODUCERS=()

n_sources=$(jq 'length' <<< "$SOURCES")
for ((i = 0; i < n_sources; i++)); do
    SRC=$(jq -c ".[$i]" <<< "$SOURCES")
    TYPE=$(jq -r '.type' <<< "$SRC")

    PX=$(frac_to_pos "$(jq -r '.x // 0' <<< "$SRC")" "$CANVAS_W")
    PY=$(frac_to_pos "$(jq -r '.y // 0' <<< "$SRC")" "$CANVAS_H")
    PW=$(frac_to_px "$(jq -r '.width // 1' <<< "$SRC")" "$CANVAS_W")
    PH=$(frac_to_px "$(jq -r '.height // 1' <<< "$SRC")" "$CANVAS_H")
    OPACITY=$(jq -r '.opacity // 1' <<< "$SRC")

    case "$TYPE" in
    screen)
        SRC_MONITOR=$(jq -r '.monitor // ""' <<< "$SRC")
        [[ -z "$SRC_MONITOR" || "$SRC_MONITOR" == "null" ]] && SRC_MONITOR="$MONITOR"
        FIFO="$RUNTIME_DIR/video${IDX}.fifo"
        mkfifo "$FIFO"
        wf-recorder -o "$SRC_MONITOR" -m mpegts -x yuv420p -r "$FPS" \
            -p "preset=ultrafast" -p "tune=zerolatency" -f "$FIFO" -y >/dev/null 2>&1 &
        PRODUCERS+=($!)
        FF_INPUTS+=(-thread_queue_size 512 -i "$FIFO")
        ;;
    window)
        # No hay captura real por ventana con las herramientas instaladas:
        # se recorta el rectángulo donde está la ventana. Si el usuario la
        # mueve, el recorte no la sigue hasta reiniciar la escena.
        ADDRESS=$(jq -r '.address // ""' <<< "$SRC")
        CLASS=$(jq -r '.appClass // ""' <<< "$SRC")
        TITLE=$(jq -r '.appTitle // ""' <<< "$SRC")
        # El address cambia cuando la app se reinicia: si no está, se vuelve a
        # buscar la ventana por clase (y título si hace falta).
        GEOM=$(hyprctl clients -j | jq -r --arg a "$ADDRESS" --arg c "$CLASS" --arg t "$TITLE" '
            ([.[] | select(.address == $a)] + [.[] | select(.class == $c and .title == $t)] + [.[] | select(.class == $c)])
            | first | select(. != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        if [[ -z "$GEOM" ]]; then
            notify-send "Recording" "No encontré la ventana «${TITLE:-$CLASS}», la salteo" -a 'Recorder' & disown
            continue
        fi
        FIFO="$RUNTIME_DIR/video${IDX}.fifo"
        mkfifo "$FIFO"
        wf-recorder -g "$GEOM" -m mpegts -x yuv420p -r "$FPS" \
            -p "preset=ultrafast" -p "tune=zerolatency" -f "$FIFO" -y >/dev/null 2>&1 &
        PRODUCERS+=($!)
        FF_INPUTS+=(-thread_queue_size 512 -i "$FIFO")
        ;;
    webcam)
        DEVICE=$(jq -r '.device // ""' <<< "$SRC")
        [[ -z "$DEVICE" || ! -e "$DEVICE" ]] && continue
        FF_INPUTS+=(-f v4l2 -thread_queue_size 512 -i "$DEVICE")
        ;;
    image)
        IMGPATH=$(jq -r '.path // ""' <<< "$SRC")
        [[ -z "$IMGPATH" || ! -f "$IMGPATH" ]] && continue
        FF_INPUTS+=(-loop 1 -framerate "$FPS" -i "$IMGPATH")
        ;;
    *)
        continue
        ;;
    esac

    # Escalar al tamaño de la caja y componer encima de lo que ya haya.
    SCALED="[s${IDX}]"
    NEXT="[o${IDX}]"
    FILTER+="[${IDX}:v]scale=${PW}:${PH},format=yuva420p,colorchannelmixer=aa=${OPACITY}${SCALED};"
    FILTER+="${LAST}${SCALED}overlay=${PX}:${PY}:eof_action=pass${NEXT};"
    LAST="$NEXT"
    IDX=$((IDX + 1))
done

# ───────────────────────────────────────────────── fuentes de audio → ffmpeg

AUDIO_LABELS=()
n_audio=$(jq 'length' <<< "$AUDIO")
for ((i = 0; i < n_audio; i++)); do
    ENTRY=$(jq -c ".[$i]" <<< "$AUDIO")
    ATYPE=$(jq -r '.type' <<< "$ENTRY")
    AID=$(jq -r '.id // ""' <<< "$ENTRY")
    AVOL=$(jq -r '.volume // 1' <<< "$ENTRY")

    case "$ATYPE" in
    system)
        SOURCE_NAME="$AID"
        [[ -z "$SOURCE_NAME" || "$SOURCE_NAME" == "null" ]] && SOURCE_NAME="$(getdefaultmonitorsource)"
        FF_INPUTS+=(-f pulse -thread_queue_size 1024 -i "$SOURCE_NAME")
        ;;
    mic)
        [[ -z "$AID" || "$AID" == "null" ]] && continue
        FF_INPUTS+=(-f pulse -thread_queue_size 1024 -i "$AID")
        ;;
    app)
        # pw-record se engancha al stream de la app y escribe PCM crudo a un
        # FIFO que ffmpeg lee como una entrada más. En la escena se guarda el
        # NOMBRE del nodo (estable), pero acá hay que traducirlo al serial de
        # ahora (ver resolve_app_serial).
        [[ -z "$AID" || "$AID" == "null" ]] && continue
        ASERIAL=$(resolve_app_serial "$AID")
        if [[ -z "$ASERIAL" ]]; then
            notify-send "Recording" "«$(jq -r '.name // .id' <<< "$ENTRY")» no está reproduciendo audio, queda fuera de la mezcla" -a 'Recorder' & disown
            continue
        fi
        AFIFO="$RUNTIME_DIR/audio${IDX}.fifo"
        mkfifo "$AFIFO"
        # node.autoconnect=false: si la app cierra su stream a mitad de la
        # grabación, que el tap muera en vez de que WirePlumber lo reenganche
        # al micrófono y siga grabando otra cosa.
        pw-record --target "$ASERIAL" -P '{ node.autoconnect = false }' \
            --rate 48000 --channels 2 --format s16 "$AFIFO" >/dev/null 2>&1 &
        PRODUCERS+=($!)
        FF_INPUTS+=(-f s16le -ar 48000 -ac 2 -thread_queue_size 1024 -i "$AFIFO")
        ;;
    *)
        continue
        ;;
    esac

    FILTER+="[${IDX}:a]volume=${AVOL}[a${IDX}];"
    AUDIO_LABELS+=("[a${IDX}]")
    IDX=$((IDX + 1))
done

AUDIO_OUT=""
if [[ ${#AUDIO_LABELS[@]} -eq 1 ]]; then
    FILTER+="${AUDIO_LABELS[0]}anull[aout];"
    AUDIO_OUT="[aout]"
elif [[ ${#AUDIO_LABELS[@]} -gt 1 ]]; then
    # normalize=0: si no, amix divide el volumen por la cantidad de entradas y
    # todo queda bajísimo.
    FILTER+="$(printf '%s' "${AUDIO_LABELS[@]}")amix=inputs=${#AUDIO_LABELS[@]}:duration=longest:normalize=0[aout];"
    AUDIO_OUT="[aout]"
fi

FILTER="${FILTER%;}" # sacar el ";" final

# ───────────────────────────────────────────────────────────────── arrancar

notify-send "Starting recording" "$SCENE_NAME → $(basename "$OUTFILE")" -a 'Recorder' & disown
set_recording_state true

# Marcador para que la próxima ejecución sepa que hay una grabación en curso
# (y para que pgrep encuentre a este ffmpeg y no a cualquier otro).
touch "$MARKER"

VIDEO_CODEC=(-c:v libx264 -preset "$PRESET" -pix_fmt yuv420p)
[[ "$ENCODER" == "nvenc" ]] && VIDEO_CODEC=(-c:v h264_nvenc -pix_fmt yuv420p)

FF_MAPS=(-map "$LAST")
[[ -n "$AUDIO_OUT" ]] && FF_MAPS+=(-map "$AUDIO_OUT" -c:a aac -b:a 192k)

ffmpeg -y "${FF_INPUTS[@]}" \
    -filter_complex "$FILTER" \
    "${FF_MAPS[@]}" \
    -r "$FPS" \
    "${VIDEO_CODEC[@]}" \
    -metadata comment="$MARKER" \
    "$OUTFILE" >"$RUNTIME_DIR/ffmpeg.log" 2>&1 &
FFMPEG_PID=$!

# El ffmpeg va primero: stop_recording lo corta con SIGINT antes que al resto.
{
    echo "$FFMPEG_PID"
    printf '%s\n' "${PRODUCERS[@]}"
} > "$PIDFILE"

# El script se queda vivo esperando a ffmpeg. Tiene que ser este shell y no un
# subshell: `wait` solo funciona sobre hijos propios, y desde un subshell falla
# al instante ("not a child of this shell") y desarmaba la grabación sola.
#
# La detección de "ya está grabando" no depende de este proceso: mira el
# marcador en la línea de comandos de ffmpeg (ver el pgrep de arriba).
wait "$FFMPEG_PID"
status=$?

# Si el marcador ya no está, la grabación se detuvo a propósito (stop_recording
# se encargó de todo). Si sigue estando, ffmpeg se murió solo: hay que limpiar.
if [[ -f "$MARKER" ]]; then
    notify-send "Recording failed" "ffmpeg terminó con error $status — mirá $RUNTIME_DIR/ffmpeg.log" -a 'Recorder' & disown
    for pid in "${PRODUCERS[@]}"; do
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
    done
    rm -f "$RUNTIME_DIR"/*.fifo "$MARKER" "$PIDFILE"
    set_recording_state false
fi
