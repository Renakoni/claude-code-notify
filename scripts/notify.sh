#!/usr/bin/env sh

set -u

TYPE="finish"
CONFIG_PATH=""
LOG_PATH="${TMPDIR:-/tmp}/claude-code-notify.log"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --type|-Type|-type)
            shift
            TYPE="${1:-finish}"
            ;;
        --config|-ConfigPath|-config)
            shift
            CONFIG_PATH="${1:-}"
            ;;
        --log|-LogPath|-log)
            shift
            LOG_PATH="${1:-$LOG_PATH}"
            ;;
        permission|finish)
            TYPE="$1"
            ;;
    esac
    shift || break
done

case "$TYPE" in
    permission|finish) ;;
    *) TYPE="finish" ;;
esac

log() {
    timestamp="$(date '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || date)"
    printf '[%s] [%s] %s\n' "$timestamp" "$TYPE" "$1" >> "$LOG_PATH" 2>/dev/null || true
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)
repo_root=$(dirname -- "$script_dir")

if [ -z "$CONFIG_PATH" ]; then
    CONFIG_PATH="$repo_root/config/notifier.json"
fi

json_value() {
    key="$1"
    default="$2"

    if [ ! -f "$CONFIG_PATH" ]; then
        printf '%s' "$default"
        return
    fi

    if command_exists python3; then
        python3 - "$CONFIG_PATH" "$key" "$TYPE" "$default" <<'PY'
import json
import sys

path, key, event_type, default = sys.argv[1:]
try:
    with open(path, 'r', encoding='utf-8') as handle:
        data = json.load(handle)
    value = data
    for part in key.split('.'):
        if part == '$TYPE':
            part = event_type
        value = value[part]
    if isinstance(value, bool):
        print('true' if value else 'false')
    else:
        print(value)
except Exception:
    print(default)
PY
        return
    fi

    printf '%s' "$default"
}

bool_value() {
    value=$(json_value "$1" "$2")
    case "$value" in
        true|True|TRUE|1|yes|Yes|YES) printf 'true' ;;
        *) printf 'false' ;;
    esac
}

int_value() {
    value=$(json_value "$1" "$2")
    case "$value" in
        *[!0-9]*|'') value="$2" ;;
    esac
    if [ "$value" -lt 250 ] 2>/dev/null; then value=250; fi
    if [ "$value" -gt 4500 ] 2>/dev/null; then value=4500; fi
    printf '%s' "$value"
}

ms_to_seconds() {
    awk "BEGIN { printf \"%.3f\", $1 / 1000 }" 2>/dev/null || printf '1'
}

resolve_sound_path() {
    path_value="$1"

    case "$path_value" in
        ''|/*|[A-Za-z]:/*|[A-Za-z]:\\*) printf '%s' "$path_value" ;;
        *) printf '%s/%s' "$repo_root" "$path_value" ;;
    esac
}

wait_for_player() {
    pid="$1"
    max_ms="$2"
    elapsed=0

    while kill -0 "$pid" >/dev/null 2>&1; do
        if [ "$elapsed" -ge "$max_ms" ]; then
            kill "$pid" >/dev/null 2>&1 || true
            wait "$pid" 2>/dev/null || true
            return
        fi
        sleep 0.05
        elapsed=$((elapsed + 50))
    done

    wait "$pid" 2>/dev/null || true
}

play_terminal_bell() {
    printf '\a' >/dev/tty 2>/dev/null || printf '\a'
    log "played terminal bell fallback"
}

play_sound_linux() {
    sound_path="$1"
    max_ms="$2"

    if [ -n "$sound_path" ] && [ -f "$sound_path" ]; then
        if command_exists paplay; then
            paplay "$sound_path" >/dev/null 2>&1 &
            pid=$!
            wait_for_player "$pid" "$max_ms"
            log "played sound with paplay: $sound_path"
            return
        fi

        if command_exists aplay; then
            aplay -q "$sound_path" >/dev/null 2>&1 &
            pid=$!
            wait_for_player "$pid" "$max_ms"
            log "played sound with aplay: $sound_path"
            return
        fi

        if command_exists ffplay; then
            ffplay -nodisp -autoexit -t "$(ms_to_seconds "$max_ms")" "$sound_path" >/dev/null 2>&1
            log "played sound with ffplay: $sound_path"
            return
        fi

        if command_exists mpg123; then
            mpg123 -q "$sound_path" >/dev/null 2>&1 &
            pid=$!
            wait_for_player "$pid" "$max_ms"
            log "played sound with mpg123: $sound_path"
            return
        fi
    fi

    log "no Linux sound player available or sound missing; using terminal bell"
    play_terminal_bell
}

show_notification_linux() {
    title="$1"
    message="$2"

    if command_exists notify-send; then
        notify-send "$title" "$message" >/dev/null 2>&1 && log "desktop notification requested with notify-send" && return
        log "notify-send failed"
        return
    fi

    log "notify-send unavailable; desktop notification skipped"
}

log "started; pid=$$; cwd=$(pwd)"
log "config path: $CONFIG_PATH"

sound_enabled=$(bool_value 'soundEnabled' 'true')
notification_enabled=$(bool_value 'toastEnabled' 'false')
max_ms=$(int_value 'maxSoundMilliseconds' '3000')
sound_path=$(resolve_sound_path "$(json_value 'sounds.$TYPE' '')")
title_default="Claude Code finished"
message_default="Claude finished responding."
if [ "$TYPE" = "permission" ]; then
    title_default="Claude Code needs permission"
    message_default="A command is waiting for your approval."
fi
title=$(json_value 'toastTitles.$TYPE' "$title_default")
message=$(json_value 'toastMessages.$TYPE' "$message_default")

log "sound enabled: $sound_enabled; notification enabled: $notification_enabled; max sound ms: $max_ms"

os_name=$(uname -s 2>/dev/null || printf 'unknown')
case "$os_name" in
    Linux) platform="linux" ;;
    *) platform="unknown" ;;
esac
log "platform: $platform"

if [ "$notification_enabled" = "true" ]; then
    case "$platform" in
        linux) show_notification_linux "$title" "$message" ;;
        *) log "desktop notification unsupported on platform: $platform" ;;
    esac
fi

if [ "$sound_enabled" != "true" ]; then
    log "sound disabled"
    exit 0
fi

case "$platform" in
    linux) play_sound_linux "$sound_path" "$max_ms" ;;
    *) play_terminal_bell ;;
esac

exit 0
