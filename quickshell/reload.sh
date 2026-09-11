#!/bin/bash
# Reload quickshell configs (SUPER+SHIFT+B).
pkill -x qs 2>/dev/null; pkill -x quickshell 2>/dev/null
sleep 0.5
nohup qs >/dev/null 2>&1 & disown
echo "quickshell restarted"
