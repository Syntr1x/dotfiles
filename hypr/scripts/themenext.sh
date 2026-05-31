#!/bin/bash

config_dir="$HOME/.config"
theme_cfg="$config_dir/ghostty/config"
wallpaper_cfg="$config_dir/hypr/hyprpaper.conf"
rofi_cfg="$config_dir/rofi/config.rasi"
waybar_css="$config_dir/waybar/style.css"
wallpaper_dir="$config_dir/hypr/Wallpapers"
reload_script="$config_dir/hypr/scripts/reload-hyprpaper.sh"

themes=("syn-beige" "syn-Broadcast" "syn-mellow" "syn-Ocean" "IC_Orange_PPL" "Gruvbox" "syn-rose-pine" "syn-Tango" "Tomorrow" "syn-green" "traffic")
theme_names=("Beige" "Dark" "Purple" "Blue" "Orange" "Gruvbox" "Kirby" "Moondrop" "Winter" "Green" "Destiny 2")
wallpapers=("Flowers.png" "darkPlants.jpg" "pinkRose.jpg" "bluesky.jpg" "TrainPath.png" "Arch_retro.png" "kirby.jpg" "Moondrop_white.jpg" "winter.jpg" "leaves.jpg" "thats_it.jpg")
rofi_themes=(
  "/usr/share/rofi/themes/rounded-beige.rasi"
  "/usr/share/rofi/themes/rounded-dark.rasi"
  "/usr/share/rofi/themes/rounded-pink.rasi"
  "/usr/share/rofi/themes/rounded-blue.rasi"
  "/usr/share/rofi/themes/rounded-orange.rasi"
  "/usr/share/rofi/themes/rounded-retro.rasi"
  "/usr/share/rofi/themes/rounded-kirby.rasi"
  "/usr/share/rofi/themes/rounded-white.rasi"
  "/usr/share/rofi/themes/rounded-winter.rasi"
  "/usr/share/rofi/themes/rounded-green.rasi"
  "/usr/share/rofi/themes/rounded-destiny.rasi"
)
waybar_colors=("#d8c8b3" "#888888" "#f0a0c0" "#a1cdf3" "#fed79d" "#d8c8b3" "#fdcbe6" "#888888" "#888888" "#8c9180" "#C0884B")

current_theme=$(grep '^theme =' "$theme_cfg" | cut -d= -f2 | xargs)

current_idx=-1
for i in "${!themes[@]}"; do
  if [[ "${themes[$i]}" == "$current_theme" ]]; then
    current_idx=$i
    break
  fi
done

if [[ $current_idx -eq -1 ]]; then
  echo "Could not determine current theme. Defaulting to index 0."
  current_idx=0
fi

next_idx=$(( (current_idx + 1) % ${#themes[@]} ))

sed -i 's/^theme =/#theme =/' "$theme_cfg"
sed -i "s/^#theme = ${themes[$next_idx]}/theme = ${themes[$next_idx]}/" "$theme_cfg"

{
  echo "splash = false"
  echo "wallpaper {"
  echo "    monitor = "
  echo "    path = ~/.config/hypr/Wallpapers/${wallpapers[$next_idx]}"
  echo "    fit_mode = cover"
  echo "}"
} | tee "$wallpaper_cfg" >/dev/null

sed -i '/^\s*@theme/d' "$rofi_cfg"
echo "@theme \"${rofi_themes[$next_idx]}\"" | tee -a "$rofi_cfg" >/dev/null

sed -i \
  -e 's|background-color: rgba(23,23,23,0);|background-color: rgba(23,23,23,0.5);|' \
  -e 's|^[[:space:]]*/\*border: 2px solid @bordercolor;\*/|border: 2px solid @bordercolor;|' \
  "$waybar_css"

sed -i "s/@define-color bordercolor .*/@define-color bordercolor ${waybar_colors[$next_idx]};/" "$waybar_css"

pkill waybar 2>/dev/null; sleep 0.5; nohup waybar >/dev/null 2>&1 &

[[ -x "$reload_script" ]] && nohup "$reload_script" >/dev/null 2>&1 &

echo "Switched theme to ${theme_names[$next_idx]} (index $next_idx)"
