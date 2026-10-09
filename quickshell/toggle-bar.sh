#!/bin/bash
# Toggle bar visibility (SUPER+W); restart it when IPC is unreachable.
QS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml"

if qs ipc --path "$QS_CONFIG" call bar toggle 2>/dev/null; then
    exit 0
fi

qs kill --path "$QS_CONFIG" 2>/dev/null
# qs kill returns immediately; wait for the old instance to exit before
# starting the next one (qs ipc show exits non-zero when nothing runs).
for ((i = 0; i < 50; i++)); do
    qs ipc --path "$QS_CONFIG" show >/dev/null 2>&1 || break
    sleep 0.1
done
nohup qs -p "$QS_CONFIG" >/dev/null 2>&1 & disown
