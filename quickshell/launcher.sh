#!/bin/bash
# One-shot launcher (SUPER+R). -n keeps a second SUPER+R from stacking another.
QS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/launcher/shell.qml"
exec qs -n -p "$QS_CONFIG"
