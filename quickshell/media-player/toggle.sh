#!/bin/bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Escape the config path for pgrep's regex.
PATTERN="$(printf '%s' "$HERE/shell.qml" | sed -e 's/\\/\\\\/g' -e 's/[.^$*+?(){|}]/\\&/g' -e 's/\[/\\[/g' -e 's/\]/\\]/g')"

if pgrep -f -- "$PATTERN" >/dev/null 2>&1; then
    pkill -f -- "$PATTERN"
else
    nohup qs -p "$HERE/shell.qml" >/dev/null 2>&1 & disown
fi
