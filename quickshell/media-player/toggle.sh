#!/bin/bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# NOTE: [q]uickshell bracket trick so pgrep/pkill never match this script itself.
PATTERN="[q]uickshell.*media-player/shell.qml"
if pgrep -f "$PATTERN" > /dev/null; then
    pkill -f "$PATTERN"
else
    nohup quickshell -p "$HERE/shell.qml" > /dev/null 2>&1 &
fi
