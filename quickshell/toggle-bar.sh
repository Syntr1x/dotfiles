#!/bin/bash
# Toggle quickshell bar visibility (SUPER+W)
if qs ipc call bar toggle 2>/dev/null; then exit 0; fi
# fallback: restart daemon if IPC failed
if pgrep -x qs >/dev/null 2>&1 || pgrep -x quickshell >/dev/null 2>&1; then
  pkill -x qs 2>/dev/null; pkill -x quickshell 2>/dev/null; sleep 0.5
fi
nohup qs >/dev/null 2>&1 & disown
