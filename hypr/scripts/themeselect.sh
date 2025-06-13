#!/bin/bash

# ----------- CONFIGURABLE FILE PATHS -----------
theme_config_file="$HOME/.config/ghostty/config"
wallpaper_config_file="$HOME/.config/hypr/hyprpaper.conf"
rofi_config_file="$HOME/.config/rofi/config.rasi"

# ----------- THEMES -----------
themes=("syn-beige" "syn-Broadcast" "syn-mellow" "syn-Ocean" "IC_Orange_PPL")
wallpapers=("Flowers.png" "darkPlants.jpg" "pinkRose.jpg" "bluesky.jpg" "TrainPath.png")
rofi_themes=(
    "/usr/share/rofi/themes/rounded-beige.rasi"
    "/usr/share/rofi/themes/rounded-dark.rasi"
    "/usr/share/rofi/themes/rounded-pink.rasi"
    "/usr/share/rofi/themes/rounded-blue.rasi"
    "/usr/share/rofi/themes/rounded-orange.rasi"
)

# ----------- STYLE VARIABLES -----------
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'
BOLD='\033[1m'

# ----------- FUNCTIONS -----------

set_theme() {
    local theme=$1
    echo -e "${CYAN}→ Setting terminal theme to ${theme}...${RESET}"

    sudo -E sed -i 's/^theme =/#theme =/' "$theme_config_file"
    sudo -E sed -i "s/^#theme = $theme/theme = $theme/" "$theme_config_file"

    echo -e "${GREEN}✓ Terminal theme changed to $theme.${RESET}"
}

uncomment_wallpaper() {
    local wallpaper=$1
    echo -e "${CYAN}→ Setting wallpaper to: ${wallpaper}...${RESET}"

    sudo -E sed -i -E 's/^(preload|wallpaper|splash) =/#\1 =/' "$wallpaper_config_file"
    sudo -E sed -i "/$wallpaper/s/^#//" "$wallpaper_config_file"

    echo -e "${GREEN}✓ Wallpaper changed to $wallpaper.${RESET}"
}

set_rofi_theme() {
    local rofi_theme=$1
    echo -e "${CYAN}→ Applying Rofi theme: ${rofi_theme}...${RESET}"

    if [[ ! -f "$rofi_config_file" ]]; then
        echo -e "${RED}✗ Rofi config not found: $rofi_config_file${RESET}"
        return 1
    fi

    sudo -E sed -i '/^\s*@theme/d' "$rofi_config_file"
    echo "@theme \"$rofi_theme\"" | sudo -E tee -a "$rofi_config_file" > /dev/null

    echo -e "${GREEN}✓ Rofi theme applied.${RESET}"
}

reload_wallpaper() {
    echo -e "${CYAN}→ Reloading wallpaper...${RESET}"
    if [[ -x "$HOME/.config/hypr/scripts/reload-hyprpaper.sh" ]]; then
        nohup "$HOME/.config/hypr/scripts/reload-hyprpaper.sh" >/dev/null 2>&1 &
        sleep 1
    else
        echo -e "${YELLOW}⚠️  Warning: reload-hyprpaper.sh not found or not executable.${RESET}"
    fi
}

# ----------- MAIN PROGRAM -----------

echo -e "${BOLD}Theme Selector${RESET}"
echo "-------------------------------------"

read -p "🎨 Apply full systemwide theme (theme, wallpaper, Rofi)? (y/n): " apply_all
if [[ "$apply_all" =~ ^[Yy]$ ]]; then
    echo -e "\n${BOLD}Available system themes:${RESET}"
    for i in "${!themes[@]}"; do
        echo -e "${YELLOW}$((i+1)).${RESET} ${themes[$i]}"
    done

    read -p "Select a theme [1-${#themes[@]}]: " theme_index
    if [[ "$theme_index" -ge 1 && "$theme_index" -le "${#themes[@]}" ]]; then
        index=$((theme_index-1))
        set_theme "${themes[$index]}"
        uncomment_wallpaper "${wallpapers[$index]}"
        set_rofi_theme "${rofi_themes[$index]}"
        reload_wallpaper
        echo -e "${GREEN}✅ Full system theme applied successfully.${RESET}"
        exit 0
    else
        echo -e "${RED}✗ Invalid selection. Exiting.${RESET}"
        exit 1
    fi
fi

# ---- Individual Selection ----

echo -e "\n${BOLD}Select Terminal Theme:${RESET}"
for i in "${!themes[@]}"; do
    echo -e "${YELLOW}$((i+1)).${RESET} ${themes[$i]}"
done
read -p "Enter your choice: " theme_number
if [[ "$theme_number" -ge 1 && "$theme_number" -le "${#themes[@]}" ]]; then
    set_theme "${themes[$((theme_number-1))]}"
else
    echo -e "${RED}✗ Invalid theme selection. Exiting.${RESET}"
    exit 1
fi

echo -e "\n${BOLD}Select Wallpaper:${RESET}"
for i in "${!wallpapers[@]}"; do
    echo -e "${YELLOW}$((i+1)).${RESET} ${wallpapers[$i]}"
done
read -p "Enter your choice: " wallpaper_number
if [[ "$wallpaper_number" -ge 1 && "$wallpaper_number" -le "${#wallpapers[@]}" ]]; then
    uncomment_wallpaper "${wallpapers[$((wallpaper_number-1))]}"
else
    echo -e "${RED}✗ Invalid wallpaper selection. Exiting.${RESET}"
    exit 1
fi

echo -e "\n${BOLD}Select Rofi Theme:${RESET}"
for i in "${!rofi_themes[@]}"; do
    echo -e "${YELLOW}$((i+1)).${RESET} ${rofi_themes[$i]}"
done
read -p "Enter your choice: " rofi_theme_number
if [[ "$rofi_theme_number" -ge 1 && "$rofi_theme_number" -le "${#rofi_themes[@]}" ]]; then
    set_rofi_theme "${rofi_themes[$((rofi_theme_number-1))]}"
else
    echo -e "${YELLOW}⚠️  Skipping Rofi theme change.${RESET}"
fi

reload_wallpaper
echo -e "\n${GREEN}✅ All changes applied successfully!${RESET}"
