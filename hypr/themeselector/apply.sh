#!/bin/bash
# apply.sh — backend for Quickshell theme selector
# Usage: apply.sh <index 0-11> [border y/n]
# Applies full theme (ghostty + wallpaper + sddm + rofi + waybar) like themeselect.sh full mode
set -euo pipefail
idx="${1:?idx required 0-11}"
border="${2:-y}"

config_dir="$HOME/.config"
theme_cfg="$config_dir/ghostty/config"
wallpaper_cfg="$config_dir/hypr/hyprpaper.conf"
rofi_cfg="$config_dir/rofi/config.rasi"
waybar_css="$config_dir/waybar/style.css"
wallpaper_dir="$config_dir/hypr/Wallpapers"
rofi_dir="/usr/share/rofi/themes"
reload_script="$config_dir/hypr/scripts/reload-hyprpaper.sh"
sddm_cfg="/usr/share/sddm/themes/silent/configs/defaultsyn.conf"

themes=("syn-beige" "syn-Broadcast" "syn-mellow" "syn-Ocean" "IC_Orange_PPL" "Gruvbox" "syn-rose-pine" "syn-Tango" "Tomorrow" "syn-green" "traffic" "syn-mellow-darkmode")
theme_names=("Beige" "Dark" "Purple" "Blue" "Orange" "Gruvbox" "Kirby" "Moondrop" "Winter" "Green" "Destiny 2" "Purple(darkmode)")
wallpapers=("Flowers.png" "darkPlants.jpg" "pinkRose.jpg" "bluesky.jpg" "TrainPath.png" "Arch_retro.png" "kirby.jpg" "Moondrop_white.jpg" "winter.jpg" "leaves.jpg" "thats_it.jpg" "black_oled.jpg")
rofi_themes=(
  "rounded-beige.rasi"
  "rounded-dark.rasi"
  "rounded-pink.rasi"
  "rounded-blue.rasi"
  "rounded-orange.rasi"
  "rounded-retro.rasi"
  "rounded-kirby.rasi"
  "rounded-white.rasi"
  "rounded-winter.rasi"
  "rounded-green.rasi"
  "rounded-destiny.rasi"
  "rounded-pink-darkmode.rasi"
)
waybar_colors=("#d8c8b3" "#888888" "#f0a0c0" "#a1cdf3" "#fed79d" "#d8c8b3" "#fdcbe6" "#FB443C" "#FDE094" "#8c9180" "#C0884B" "#f0a0c1")

if (( idx < 0 || idx >= ${#themes[@]} )); then echo "invalid idx $idx" >&2; exit 1; fi

sed_escape() { printf '%s' "$1" | sed -e 's/[|&\\/]/\\&/g'; }

esc=$(sed_escape "${themes[$idx]}")
wp="${wallpapers[$idx]}"
rofi_next="${rofi_themes[$idx]}"
color="${waybar_colors[$idx]}"

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

# rofi
if [[ -f "$rofi_cfg" ]]; then
  sed -i -E '/^[[:space:]]*@theme/d' "$rofi_cfg" || true
  echo "@theme \"$rofi_next\"" >> "$rofi_cfg"
fi

# waybar
if [[ -f "$waybar_css" ]]; then
  esc_c=$(sed_escape "$color")
  sed -i -E "s/@define-color bordercolor .*/@define-color bordercolor ${esc_c};/" "$waybar_css" || true
  if [[ "$border" =~ ^[Yy]$ ]]; then
    sed -i -e 's|background-color: rgba(23,23,23,0);|background-color: rgba(23,23,23,0.5);|' -e 's|^[[:space:]]*/\*border: 2px solid @bordercolor;\*/|border: 2px solid @bordercolor;|' "$waybar_css" || true
  else
    sed -i -e 's|background-color: rgba(23,23,23,0.5);|background-color: rgba(23,23,23,0);|' -e 's|^[[:space:]]*border: 2px solid @bordercolor;|/*border: 2px solid @bordercolor;*/|' "$waybar_css" || true
  fi
fi

# reloads
pkill waybar 2>/dev/null || true
sleep 0.5
command -v waybar >/dev/null 2>&1 && nohup waybar >/dev/null 2>&1 & disown || true
if [[ -x "$reload_script" ]]; then
  nohup "$reload_script" >/dev/null 2>&1 & disown || true
else
  pkill hyprpaper 2>/dev/null || true; sleep 0.5; nohup hyprpaper >/dev/null 2>&1 & disown || true
fi

echo "Applied ${theme_names[$idx]} ($idx) border=$border"
command -v notify-send >/dev/null 2>&1 && notify-send "Theme" "Applied ${theme_names[$idx]}" || true
