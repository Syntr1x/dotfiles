#!/bin/bash

# ------------ CONFIG ------------
config_dir="$HOME/.config"
theme_cfg="$config_dir/ghostty/config"
wallpaper_cfg="$config_dir/hypr/hyprpaper.conf"
rofi_cfg="$config_dir/rofi/config.rasi"
waybar_css="$config_dir/waybar/style.css"
wallpaper_dir="$config_dir/hypr/Wallpapers"
reload_script="$config_dir/hypr/scripts/reload-hyprpaper.sh"

themes=("syn-beige" "syn-Broadcast" "syn-mellow" "syn-Ocean" "IC_Orange_PPL" "GruvboxDarkHard")
wallpapers=("Flowers.png" "darkPlants.jpg" "pinkRose.jpg" "bluesky.jpg" "TrainPath.png" "Arch_retro.png")
rofi_themes=(
  "/usr/share/rofi/themes/rounded-beige.rasi"
  "/usr/share/rofi/themes/rounded-dark.rasi"
  "/usr/share/rofi/themes/rounded-pink.rasi"
  "/usr/share/rofi/themes/rounded-blue.rasi"
  "/usr/share/rofi/themes/rounded-orange.rasi"
  "/usr/share/rofi/themes/rounded-retro.rasi"
)
waybar_colors=("#d8c8b3" "#888888" "#f0a0c0" "#a1cdf3" "#fed79d" "#d8c8b3")

# ------------ STYLE ------------
BOLD=$(tput bold)
RESET=$(tput sgr0)
GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)

# ------------ HELPERS ------------
print_header() {
  echo -e "${CYAN}${BOLD}\n╔═══════════════════════════════════════╗"
  echo -e "║            THEME SELECTOR             ║"
  echo -e "╚═══════════════════════════════════════╝${RESET}"
}

display_current_settings() {
  local current_theme=$(grep '^theme =' "$theme_cfg" | cut -d= -f2 | xargs)
  local current_rofi=$(grep '@theme' "$rofi_cfg" | tail -1 | cut -d'"' -f2)
  local current_wallpaper=$(grep -v '^#' "$wallpaper_cfg" | grep wallpaper | cut -d, -f2 | xargs)
  local current_waybar=$(awk '/@define-color bordercolor/ {gsub(/;/,"",$3); print $3; exit}' "$waybar_css")
  echo -e "${YELLOW}Current Theme:${RESET} ${current_theme:-Not set}"
  echo -e "${YELLOW}Rofi Theme:${RESET} ${current_rofi:-Not set}"
  echo -e "${YELLOW}Wallpaper:${RESET} ${current_wallpaper:-Not set}"
  echo -e "${YELLOW}Waybar Color:${RESET} ${current_waybar:-Not set}"
}

print_menu() {
  local -n arr=$1
  local title=$2
  echo -e "${CYAN}\n───── $title ─────${RESET}"
  for i in "${!arr[@]}"; do
    color=$(( (i % 2 == 0) ? 6 : 3 ))
    printf "\033[1;%sm%2d. %s\033[0m\n" "$color" "$((i+1))" "${arr[i]}"
  done
}

get_selection() {
  local prompt="$1"
  local -n array="$2"
  read -rp "$prompt [1-${#array[@]}]: " idx
  (( idx >= 1 && idx <= ${#array[@]} )) || return 1
  echo $((idx - 1))
}

# ------------ SETTERS ------------
set_theme() {
  sudo sed -i 's/^theme =/#theme =/' "$theme_cfg"
  sudo sed -i "s/^#theme = ${themes[$1]}/theme = ${themes[$1]}/" "$theme_cfg"
  echo -e "${GREEN}✓ Theme set to ${themes[$1]}${RESET}"
}

set_wallpaper() {
  sudo sed -i -E 's/^(preload|wallpaper|splash) =/#\1 =/' "$wallpaper_cfg"
  sudo sed -i "/${wallpapers[$1]}/s/^#//" "$wallpaper_cfg"
  echo -e "${GREEN}✓ Wallpaper set to ${wallpapers[$1]}${RESET}"
}

set_rofi() {
  sed -i '/^\s*@theme/d' "$rofi_cfg"
  echo "@theme \"${rofi_themes[$1]}\"" | sudo tee -a "$rofi_cfg" >/dev/null
  echo -e "${GREEN}✓ Rofi theme applied.${RESET}"
}

set_waybar_color() {
  sudo sed -i "s/@define-color bordercolor .*/@define-color bordercolor ${waybar_colors[$1]};/" "$waybar_css"
  echo -e "${GREEN}✓ Waybar border color set.${RESET}"
}

toggle_waybar_border() {
  if [[ $1 =~ ^[Yy]$ ]]; then
    sudo sed -i 's|background-color: rgba(23,23,23,0);|background-color: rgba(23,23,23,0.5);|' "$waybar_css"
    sudo sed -i 's|/\*border: 1px.*\*/|border: 1px solid @bordercolor;|' "$waybar_css"
    return 0
  else
    sudo sed -i 's|background-color: rgba(23,23,23,0.5);|background-color: rgba(23,23,23,0);|' "$waybar_css"
    sudo sed -i 's|^\(.*\)border: 1px solid @bordercolor;|\1/*border: 1px solid @bordercolor;*/|' "$waybar_css"
    return 1
  fi
}

restart_waybar() {
  pkill waybar && sleep 1 && nohup waybar >/dev/null 2>&1 &
  echo -e "${GREEN}✓ Waybar restarted.${RESET}"
}

reload_wallpaper() {
  [[ -x "$reload_script" ]] && nohup "$reload_script" >/dev/null 2>&1 &
  echo -e "${GREEN}✓ Wallpaper reloaded.${RESET}"
}

preview_wallpapers_grid() {
  clear; cols=3; w=50; h=25
  for i in "${!wallpapers[@]}"; do
    x=$(( (i % cols) * w ))
    y=$(( (i / cols) * h ))
    kitty +kitten icat --place "${w}x${h}@${x}x${y}" "$wallpaper_dir/${wallpapers[$i]}"
  done
  echo; for i in "${!wallpapers[@]}"; do
    printf "${CYAN}%2d.${RESET} %-20s  " "$((i+1))" "${wallpapers[$i]}"
    (( (i + 1) % cols == 0 )) && echo
  done; echo
}

# ------------ MAIN ------------
clear
print_header
display_current_settings

read -rp $'\nApply full theme (wallpaper, rofi, waybar)? [y/n]: ' apply_all
if [[ "$apply_all" =~ ^[Yy]$ ]]; then
  print_menu themes "System Themes"
  idx=$(get_selection "Choose theme" themes) || { echo -e "${RED}✗ Invalid selection.${RESET}"; exit 1; }
  set_theme "$idx"
  set_wallpaper "$idx"
  set_rofi "$idx"

  read -rp "Enable Waybar border/background? [y/n]: " border
  if toggle_waybar_border "$border"; then
    set_waybar_color "$idx"
  else
    echo -e "${YELLOW}→ Waybar border/background disabled — skipping color.${RESET}"
  fi

  restart_waybar
  reload_wallpaper
  echo -e "${GREEN}✅ Full theme applied.${RESET}"
  exit 0
fi

# ---- Individual Mode ----
print_menu themes "Terminal Themes"
idx=$(get_selection "Choose theme" themes) && set_theme "$idx"

print_menu wallpapers "Wallpaper Grid Preview"
preview_wallpapers_grid
read -rp "Press enter to clear preview..." && kitty +kitten icat --clear && clear
idx=$(get_selection "Choose wallpaper" wallpapers) && set_wallpaper "$idx"

print_menu rofi_themes "Rofi Themes"
idx=$(get_selection "Choose Rofi theme" rofi_themes) && set_rofi "$idx"

read -rp "Enable Waybar border/background? [y/n]: " border
if toggle_waybar_border "$border"; then
  print_menu waybar_colors "Waybar Colors"
  idx=$(get_selection "Choose Waybar color" waybar_colors) && set_waybar_color "$idx"
else
  echo -e "${YELLOW}→ Waybar border/background disabled — skipping color.${RESET}"
fi

restart_waybar
reload_wallpaper
echo -e "\n${GREEN}✅ All changes applied.${RESET}"
