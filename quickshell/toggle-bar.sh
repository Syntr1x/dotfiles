#!/bin/bash
# Toggle bar visibility (SUPER+W); restart it when IPC is unreachable.
QS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml"

if qs ipc --path "$QS_CONFIG" call bar toggle 2>/dev/null; then
    exit 0
fi

qs kill --path "$QS_CONFIG" 2>/dev/null
sleep 0.3
nohup qs -p "$QS_CONFIG" >/dev/null 2>&1 & disown
