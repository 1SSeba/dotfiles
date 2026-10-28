#!/usr/bin/env bash

CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"

CUSTOM_PATH=$(jq -r ".screenRecord.savePath" "$CONFIG_FILE" 2>/dev/null)
CONFIG_FRAMERATE=$(jq -r ".screenRecord.frameRate // 0" "$CONFIG_FILE" 2>/dev/null)
CONFIG_ENCODER=$(jq -r ".screenRecord.encoder // \"software\"" "$CONFIG_FILE" 2>/dev/null)
CONFIG_PRESET=$(jq -r ".screenRecord.x264Preset // \"veryfast\"" "$CONFIG_FILE" 2>/dev/null)
CONFIG_AUDIO_SOURCE=$(jq -r ".screenRecord.audioSource // \"\"" "$CONFIG_FILE" 2>/dev/null)

RECORDING_DIR=""

if [[ -n "$CUSTOM_PATH" ]]; then
    RECORDING_DIR="$CUSTOM_PATH"
else
    RECORDING_DIR="$HOME/Videos" # Use default path
fi

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}
getaudiooutput() {
    if [[ -n "$CONFIG_AUDIO_SOURCE" ]]; then
        echo "$CONFIG_AUDIO_SOURCE"
    else
        pactl list sources | grep 'Name' | grep 'monitor' | cut -d ' ' -f2
    fi
}
getactivemonitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}

# Arma los flags de codec/framerate según Config.options.screenRecord. NVENC
# necesita ffmpeg >=... y un driver NVIDIA >=610 para andar: si falla, el
# caller debe reintentar con software (ver run_wf_recorder).
encoder_flags() {
    local flags=()
    if [[ "$CONFIG_FRAMERATE" != "0" && "$CONFIG_FRAMERATE" != "null" ]]; then
        flags+=(-r "$CONFIG_FRAMERATE")
    fi
    if [[ "$CONFIG_ENCODER" == "nvenc" ]]; then
        flags+=(-c h264_nvenc)
    else
        flags+=(-p "preset=$CONFIG_PRESET" -p "tune=zerolatency")
    fi
    printf '%s\n' "${flags[@]}"
}

# Corre wf-recorder con los flags de la config; si el encoder de hardware
# falla al abrir (driver viejo, etc.), avisa y reintenta en software en vez
# de dejar la grabación rota en silencio.
run_wf_recorder() {
    local log
    log=$(mktemp)
    wf-recorder "$@" $(encoder_flags) 2>"$log"
    local status=$?
    if [[ $status -ne 0 && "$CONFIG_ENCODER" == "nvenc" ]]; then
        notify-send "Recording" "El encoder de hardware (NVENC) falló, reintentando por software" -a 'Recorder' & disown
        CONFIG_ENCODER="software"
        wf-recorder "$@" $(encoder_flags)
        status=$?
    fi
    rm -f "$log"
    return $status
}

# Refleja en states.json si hay una grabación en curso, para que la barra y el
# indicador flotante (Persistent.states.record.enable/startEpoch) puedan
# mostrar el ícono de "detener" y el tiempo transcurrido.
set_recording_state() {
    local state=$1
    local STATE_FILE="$HOME/.local/state/quickshell/states.json"
    local tmp
    local epoch=0
    [[ "$state" == "true" ]] && epoch=$(date +%s)
    tmp=$(mktemp)
    jq ".record.enable = $state | .record.startEpoch = $epoch" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

mkdir -p "$RECORDING_DIR"
cd "$RECORDING_DIR" || exit

# parse --region <value> without modifying $@ so other flags like --fullscreen still work
ARGS=("$@")
MANUAL_REGION=""
SOUND_FLAG=0
FULLSCREEN_FLAG=0
for ((i=0;i<${#ARGS[@]};i++)); do
    if [[ "${ARGS[i]}" == "--region" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            MANUAL_REGION="${ARGS[i+1]}"
        else
            notify-send "Recording cancelled" "No region specified for --region" -a 'Recorder' & disown
            exit 1
        fi
    elif [[ "${ARGS[i]}" == "--sound" ]]; then
        SOUND_FLAG=1
    elif [[ "${ARGS[i]}" == "--fullscreen" ]]; then
        FULLSCREEN_FLAG=1
    fi
done

if pgrep wf-recorder > /dev/null; then
    notify-send "Recording Stopped" "Stopped" -a 'Recorder' &
    pkill wf-recorder &
    set_recording_state false
else
    if [[ $FULLSCREEN_FLAG -eq 1 ]]; then
        notify-send "Starting recording" 'recording_'"$(getdate)"'.mp4' -a 'Recorder' & disown
        set_recording_state true
        if [[ $SOUND_FLAG -eq 1 ]]; then
            run_wf_recorder -o "$(getactivemonitor)" --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' --audio="$(getaudiooutput)"
        else
            run_wf_recorder -o "$(getactivemonitor)" --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4'
        fi
    else
        # If a manual region was provided via --region, use it; otherwise run slurp as before.
        if [[ -n "$MANUAL_REGION" ]]; then
            region="$MANUAL_REGION"
        else
            if ! region="$(slurp 2>&1)"; then
                notify-send "Recording cancelled" "Selection was cancelled" -a 'Recorder' & disown
                exit 1
            fi
        fi

        notify-send "Starting recording" 'recording_'"$(getdate)"'.mp4' -a 'Recorder' & disown
        set_recording_state true
        if [[ $SOUND_FLAG -eq 1 ]]; then
            run_wf_recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' --geometry "$region" --audio="$(getaudiooutput)"
        else
            run_wf_recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' --geometry "$region"
        fi
    fi
    set_recording_state false
fi