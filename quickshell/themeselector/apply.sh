#!/bin/bash
# apply.sh — backend for Quickshell theme selector
# Usage: apply.sh <index 0-11>
# Applies full theme (ghostty + wallpaper + sddm + quickshell accent).
set -euo pipefail
idx="${1:?idx required 0-11}"

config_dir="$HOME/.config"
theme_cfg="$config_dir/ghostty/config"
wallpaper_cfg="$config_dir/hypr/hyprpaper.conf"
accent_cfg="$config_dir/quickshell/accent.conf"
wallpaper_dir="$config_dir/hypr/Wallpapers"
reload_script="$config_dir/hypr/scripts/reload-hyprpaper.sh"
sddm_cfg="/usr/share/sddm/themes/silent/configs/defaultsyn.conf"

themes=("syn-beige" "syn-Broadcast" "syn-mellow" "syn-Ocean" "IC_Orange_PPL" "Gruvbox" "syn-rose-pine" "syn-Tango" "Tomorrow" "syn-green" "traffic" "syn-mellow-darkmode")
theme_names=("Beige" "Dark" "Purple" "Blue" "Orange" "Gruvbox" "Kirby" "Moondrop" "Winter" "Green" "Destiny 2" "Purple(darkmode)")
wallpapers=("Flowers.png" "darkPlants.jpg" "pinkRose.jpg" "bluesky.jpg" "TrainPath.png" "Arch_retro.png" "kirby.jpg" "Moondrop_white.jpg" "winter.jpg" "leaves.jpg" "thats_it.jpg" "black_oled.jpg")
accent_colors=("#d8c8b3" "#888888" "#f0a0c0" "#a1cdf3" "#fed79d" "#d8c8b3" "#fdcbe6" "#FB443C" "#FDE094" "#8c9180" "#C0884B" "#f0a0c1")

if (( idx < 0 || idx >= ${#themes[@]} )); then echo "invalid idx $idx" >&2; exit 1; fi

sed_escape() { printf '%s' "$1" | sed -e 's/[|&\\/]/\\&/g'; }

esc=$(sed_escape "${themes[$idx]}")
wp="${wallpapers[$idx]}"
color="${accent_colors[$idx]}"

# ghostty
if [[ -f "$theme_cfg" ]]; then
  sed -i -E 's/^[[:space:]]*theme[[:space:]]*=/ #theme =/' "$theme_cfg" 2>/dev/null || true
  sed -i -E 's/^[[:space:]]*#theme[[:space:]]*=[[:space:]]*/#theme = /' "$theme_cfg" 2>/dev/null || true
  if grep -qE "^[[:space:]]*#theme[[:space:]]*=[[:space:]]*${esc}[[:space:]]*$" "$theme_cfg"; then
    sed -i -E "s|^[[:space:]]*#theme[[:space:]]*=[[:space:]]*${esc}[[:space:]]*$|theme = ${esc}|" "$theme_cfg"
  else
    echo "theme = ${themes[$idx]}" >> "$theme_cfg"
  fi
fi

# hyprpaper
tmp=$(mktemp)
{
  echo "splash = false"
  echo "wallpaper {"
  echo "    monitor = "
  echo "    path = $wallpaper_dir/$wp"
  echo "    fit_mode = cover"
  echo "}"
} > "$tmp"
mv -f "$tmp" "$wallpaper_cfg"

# sddm
if [[ -f "$sddm_cfg" && -w "$sddm_cfg" ]]; then
  esc_wp=$(sed_escape "$wp")
  sed -i -E "s|^background[[:space:]]*=[[:space:]]*\".*\"|background = \"$esc_wp\"|" "$sddm_cfg" || true
fi

# quickshell accent store
mkdir -p "$(dirname "$accent_cfg")"
printf '# quickshell accent — written by themeselector apply.sh, watched live. Do not edit by hand.\naccent=%s\n' "$color" > "$accent_cfg"

# reloads
if [[ -x "$reload_script" ]]; then
  nohup "$reload_script" >/dev/null 2>&1 & disown || true
else
  pkill hyprpaper 2>/dev/null || true; sleep 0.5; nohup hyprpaper >/dev/null 2>&1 & disown || true
fi

echo "Applied ${theme_names[$idx]} ($idx)"
command -v notify-send >/dev/null 2>&1 && notify-send "Theme" "Applied ${theme_names[$idx]}" || true
