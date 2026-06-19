#!/usr/bin/env sh

set -eu

LOG_PATH="${TMPDIR:-/tmp}/claude-code-notify.log"
CONFIG_PATH=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --log|-LogPath|-log)
            shift
            LOG_PATH="${1:-$LOG_PATH}"
            ;;
        --config|-ConfigPath|-config)
            shift
            CONFIG_PATH="${1:-}"
            ;;
    esac
    shift || break
done

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(dirname -- "$script_dir")
notify_script="$repo_root/scripts/notify.sh"

echo "Claude Code Notify POSIX smoke test"
echo "Notify script: $notify_script"
echo "Log path: $LOG_PATH"
if [ -n "$CONFIG_PATH" ]; then
    echo "Config path: $CONFIG_PATH"
fi
echo ""

for type in permission finish; do
    echo "Testing notification type: $type"
    if [ -n "$CONFIG_PATH" ]; then
        sh "$notify_script" --type "$type" --log "$LOG_PATH" --config "$CONFIG_PATH"
    else
        sh "$notify_script" --type "$type" --log "$LOG_PATH"
    fi
done

echo ""
echo "Smoke test finished. Recent log lines:"
if [ -f "$LOG_PATH" ]; then
    tail -n 20 "$LOG_PATH"
else
    echo "Log file was not created."
fi
