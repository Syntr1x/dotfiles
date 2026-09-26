#!/bin/bash
# Restart only the bar config (SUPER+SHIFT+B): --path leaves the one-shot configs alone.
QS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml"

qs kill --path "$QS_CONFIG" 2>/dev/null
sleep 0.3
nohup qs -p "$QS_CONFIG" >/dev/null 2>&1 & disown
echo "quickshell bar restarted"
