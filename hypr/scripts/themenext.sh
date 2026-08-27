#!/bin/bash
# themenext.sh — cycle to next Hyprland theme (SUPER+N)
set -euo pipefail

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

if (( ${#themes[@]} != ${#wallpapers[@]} || ${#themes[@]} != ${#rofi_themes[@]} || ${#themes[@]} != ${#waybar_colors[@]} )); then
  echo "ERROR: theme arrays have mismatched lengths" >&2
  command -v notify-send >/dev/null 2>&1 && notify-send -u critical "Theme switch" "Config error: array length mismatch"
  exit 1
fi

notify() {
  local msg="$1"
  echo "$msg"
  command -v notify-send >/dev/null 2>&1 && notify-send "Theme switch" "$msg" || true
}

sed_escape() { printf '%s' "$1" | sed -e 's/[|&\\/]/\\&/g'; }

current_theme=""
if [[ -f "$theme_cfg" ]]; then
  current_theme=$(grep -E '^[[:space:]]*theme[[:space:]]*=' "$theme_cfg" | tail -n1 | cut -d= -f2 | xargs || true)
fi

current_idx=-1
for i in "${!themes[@]}"; do
  if [[ "${themes[$i]}" == "$current_theme" ]]; then
    current_idx=$i
    break
  fi
done

if [[ $current_idx -eq -1 ]]; then
  notify "Could not determine current theme ('$current_theme'). Cycling from index 0."
  current_idx=0
fi

next_idx=$(( (current_idx + 1) % ${#themes[@]} ))

esc_next=$(sed_escape "${themes[$next_idx]}")
wallpaper_next="${wallpapers[$next_idx]}"
rofi_next="$rofi_dir/${rofi_themes[$next_idx]}"
color_next="${waybar_colors[$next_idx]}"

if [[ ! -f "$wallpaper_dir/$wallpaper_next" ]]; then
  echo "WARNING: wallpaper not found: $wallpaper_dir/$wallpaper_next" >&2
fi

if [[ -f "$theme_cfg" ]]; then
  sed -i -E 's/^[[:space:]]*theme[[:space:]]*=/ #theme =/' "$theme_cfg" 2>/dev/null || true
  sed -i -E 's/^[[:space:]]*#theme[[:space:]]*=[[:space:]]*/#theme = /' "$theme_cfg" 2>/dev/null || true
  if grep -qE "^[[:space:]]*#theme[[:space:]]*=[[:space:]]*${esc_next}[[:space:]]*$" "$theme_cfg"; then
    sed -i -E "s|^[[:space:]]*#theme[[:space:]]*=[[:space:]]*${esc_next}[[:space:]]*$|theme = ${esc_next}|" "$theme_cfg"
  else
    echo "theme = ${themes[$next_idx]}" >> "$theme_cfg"
    echo "WARNING: theme '${themes[$next_idx]}' was not in ghostty/config, appended." >&2
  fi
else
  echo "WARNING: ghostty config not found: $theme_cfg" >&2
fi

tmp_wallpaper=$(mktemp)
{
  echo "splash = false"
  echo "wallpaper {"
  echo "    monitor = "
  echo "    path = $wallpaper_dir/$wallpaper_next"
  echo "    fit_mode = cover"
  echo "}"
} > "$tmp_wallpaper"
mv -f "$tmp_wallpaper" "$wallpaper_cfg"

if [[ -f "$sddm_cfg" ]]; then
  if [[ -w "$sddm_cfg" ]]; then
    esc_wp=$(sed_escape "$wallpaper_next")
    sed -i -E "s|^background[[:space:]]*=[[:space:]]*\".*\"|background = \"$esc_wp\"|" "$sddm_cfg" || echo "WARNING: failed to update $sddm_cfg" >&2
  else
    echo "NOTE: $sddm_cfg not writable, skipping SDDM wallpaper." >&2
  fi
fi

if [[ -f "$rofi_cfg" ]]; then
  sed -i -E '/^[[:space:]]*@theme/d' "$rofi_cfg" || true
  echo "@theme \"$rofi_next\"" >> "$rofi_cfg"
else
  echo "WARNING: rofi config not found: $rofi_cfg" >&2
fi

if [[ -f "$waybar_css" ]]; then
  esc_color=$(sed_escape "$color_next")
  sed -i -E "s/@define-color bordercolor .*/@define-color bordercolor ${esc_color};/" "$waybar_css" || echo "WARNING: failed to update waybar color" >&2
else
  echo "WARNING: waybar css not found: $waybar_css" >&2
fi

pkill waybar 2>/dev/null || true
sleep 0.5
if command -v waybar >/dev/null 2>&1; then
  nohup waybar >/dev/null 2>&1 & disown || true
fi

if [[ -x "$reload_script" ]]; then
  nohup "$reload_script" >/dev/null 2>&1 & disown || true
else
  if command -v hyprpaper >/dev/null 2>&1; then
    pkill hyprpaper 2>/dev/null || true
    sleep 0.5
    nohup hyprpaper >/dev/null 2>&1 & disown || true
  fi
fi

notify "Switched to ${theme_names[$next_idx]} (index $next_idx) — ${themes[$next_idx]}"
