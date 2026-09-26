#!/bin/bash
# Toggle the media popup.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Match by config path: argv[0] may be "qs" or "quickshell".
# Escape order matters: backslashes first, [ and ] separately
# ("[." inside one bracket expression misparses on GNU sed).
PATTERN="$(printf '%s' "$HERE/shell.qml" | sed -e 's/\\/\\\\/g' -e 's/[.^$*+?(){|}]/\\&/g' -e 's/\[/\\[/g' -e 's/\]/\\]/g')"

if pgrep -f -- "$PATTERN" >/dev/null 2>&1; then
    pkill -f -- "$PATTERN"
else
    nohup qs -p "$HERE/shell.qml" >/dev/null 2>&1 & disown
fi
