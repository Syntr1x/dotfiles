#!/bin/bash

# ----------- CONFIGURABLE FILE PATHS -----------
theme_config_file="$HOME/.config/ghostty/config"
wallpaper_config_file="$HOME/.config/hypr/hyprpaper.conf"
rofi_config_file="$HOME/.config/rofi/config.rasi"
waybar_style_file="$HOME/.config/waybar/style.css"   
wallpaper_dir="$HOME/.config/hypr/Wallpapers"

# ----------- THEMES -----------
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
waybar_colors=(
    "#d8c8b3"
    "#888888"
    "#f0a0c0"
    "#a1cdf3"
    "#fed79d"
    "#d8c8b3"
)

# ----------- STYLE VARIABLES USING TPUT -----------
BOLD=$(tput bold)
RESET=$(tput sgr0)
GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)

# ----------- FUNCTIONS -----------

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════╗"
    echo "║            THEME SELECTOR             ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${RESET}"
}

print_section() {
    echo -e "${CYAN}\n───── $1 ─────${RESET}"
}

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

set_waybar_color() {
    local color="$1"
    echo -e "${CYAN}→ Updating Waybar border color to ${color}...${RESET}"
    if [[ -f "$waybar_style_file" ]]; then
        sed -i 's/@define-color bordercolor .*/@define-color bordercolor '"$color"';/' "$waybar_style_file"
        echo -e "${GREEN}✓ Waybar color updated.${RESET}"
        echo -e "${CYAN}→ Reloading Waybar...${RESET}"
        pkill -SIGUSR2 waybar && echo -e "${GREEN}✓ Waybar reloaded.${RESET}" || echo -e "${RED}✗ Failed to reload Waybar.${RESET}"
    else
        echo -e "${RED}✗ Waybar style.css not found at: $waybar_style_file${RESET}"
    fi
}

toggle_waybar_border() {
    local enable="$1"

    echo -e "${CYAN}→ Setting Waybar border and background to ${enable^^}...${RESET}"

    if [[ ! -f "$waybar_style_file" ]]; then
        echo -e "${RED}✗ style.css not found at $waybar_style_file${RESET}"
        return 1
    fi

    if [[ "$enable" == "y" || "$enable" == "Y" ]]; then
        # Enable visible background and border
        sed -i 's|background-color: rgba(23,23,23,0);|background-color: rgba(23,23,23,0.5);|' "$waybar_style_file"
        sed -i 's|^\([[:space:]]*\)/\*border: 1px solid @bordercolor;\*/|\1border: 1px solid @bordercolor;|' "$waybar_style_file"
        echo -e "${GREEN}✓ Waybar border/background enabled.${RESET}"
        border_enabled=true
    else
        # Disable background and comment out border
        sed -i 's|background-color: rgba(23,23,23,0.5);|background-color: rgba(23,23,23,0);|' "$waybar_style_file"
        sed -i 's|^\([[:space:]]*\)border: 1px solid @bordercolor;|\1/*border: 1px solid @bordercolor;*/|' "$waybar_style_file"
        echo -e "${GREEN}✓ Waybar border/background disabled.${RESET}"
        border_enabled=false
    fi

    restart_waybar
    $border_enabled && return 0 || return 2

}

restart_waybar() {
    echo -e "${CYAN}→ Restarting Waybar...${RESET}"
    pkill waybar  # Send SIGTERM to Waybar

    # Wait up to 5 seconds for Waybar to fully quit
    for i in {1..10}; do
        if pgrep waybar >/dev/null; then
            sleep 0.5
        else
            break
        fi
    done

    # Now start waybar fresh, detached properly
    nohup waybar >/dev/null 2>&1 &
    disown
    echo -e "${GREEN}✓ Waybar restarted.${RESET}"
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

preview_wallpapers_grid() {
    clear
    local cols=3
    local cell_width=50
    local cell_height=25

    for i in "${!wallpapers[@]}"; do
        file="${wallpapers[$i]}"
        path="$wallpaper_dir/$file"
        col=$(( i % cols ))
        row=$(( i / cols ))
        x=$(( col * cell_width ))
        y=$(( row * cell_height ))

        if [[ -f "$path" ]]; then
            kitty +kitten icat --place "${cell_width}x${cell_height}@${x}x${y}" "$path"
        else
            echo -e "${RED}✗ Missing: $path${RESET}"
        fi
    done

    echo
    for i in "${!wallpapers[@]}"; do
        printf "${CYAN}%2d.${RESET} %-20s  " "$((i+1))" "${wallpapers[$i]}"
        (( (i + 1) % cols == 0 )) && echo
    done
    echo
}

# ----------- MAIN PROGRAM -----------

clear
print_header

current_theme=$(grep '^theme =' "$theme_config_file" | cut -d '=' -f2 | xargs)
current_rofi_theme=$(grep '@theme' "$rofi_config_file" | tail -n 1 | cut -d '"' -f2)
current_wallpaper=$(grep -v '^#' "$wallpaper_config_file" | grep wallpaper | head -1 | sed 's/.*= *,*//')
current_waybar_color=$(awk '/@define-color bordercolor/ {gsub(/;/,"",$3); print $3; exit}' "$waybar_style_file" 2>/dev/null)

echo -e "${YELLOW}Current Theme:${RESET} ${current_theme:-Not set}"
echo -e "${YELLOW}Current Rofi Theme:${RESET} ${current_rofi_theme:-Not set}"
echo -e "${YELLOW}Wallpaper Config:${RESET} ${current_wallpaper:-Not set}"
echo -e "${YELLOW}Waybar Border Color:${RESET} ${current_waybar_color:-Not set}"

read -rp $'\nApply full systemwide theme? (theme, wallpaper, Rofi, Waybar) [y/n]: ' apply_all
sudo_warning_printed=false

print_sudo_warning() {
    if ! $sudo_warning_printed; then
        echo -e "${YELLOW}• You may be prompted for your password.${RESET}"
        sudo_warning_printed=true
    fi
}

if [[ "$apply_all" =~ ^[Yy]$ ]]; then
    print_section "Available System Themes"
    for i in "${!themes[@]}"; do
        color=$(( (i % 2 == 0) ? 6 : 3 ))
        printf "\033[1;%sm%2d. %s\033[0m\n" "$color" "$((i+1))" "${themes[$i]}"
    done

    read -rp "Select a theme [1-${#themes[@]}]: " theme_index
    if [[ "$theme_index" -ge 1 && "$theme_index" -le "${#themes[@]}" ]]; then
        index=$((theme_index - 1))
        print_sudo_warning
        set_theme "${themes[$index]}"
        uncomment_wallpaper "${wallpapers[$index]}"
        set_rofi_theme "${rofi_themes[$index]}"
        read -rp $'\nEnable Waybar border/background? [y/n]: ' toggle_border
        toggle_waybar_border "$toggle_border"
        if [[ $? -eq 2 ]]; then
            echo -e "${YELLOW}→ Waybar border/background disabled — skipping color change.${RESET}"
        else
            set_waybar_color "${waybar_colors[$index]}"
        fi
        restart_waybar
        reload_wallpaper
        echo -e "${GREEN}✅ Full system theme applied successfully.${RESET}"
        exit 0
    else
        echo -e "${RED}✗ Invalid selection. Exiting.${RESET}"
        exit 1
    fi
fi

# ---- Individual Selection ----
print_section "Terminal Themes"
for i in "${!themes[@]}"; do
    color=$(( (i % 2 == 0) ? 6 : 3 ))
    printf "\033[1;%sm%2d. %s\033[0m\n" "$color" "$((i+1))" "${themes[$i]}"
done
read -rp "Enter your choice: " theme_number
if [[ "$theme_number" -ge 1 && "$theme_number" -le "${#themes[@]}" ]]; then
    print_sudo_warning
    set_theme "${themes[$((theme_number-1))]}"
else
    echo -e "${RED}✗ Invalid theme selection. Exiting.${RESET}"
    exit 1
fi

print_section "Wallpapers (grid preview)"
preview_wallpapers_grid
echo -e "${YELLOW}↑ Above are the wallpaper previews.${RESET}"
read -rp "Press Enter to clear previews and choose one..." _
kitty +kitten icat --clear
clear

print_section "Select a Wallpaper"
for i in "${!wallpapers[@]}"; do
    color=$(( (i % 2 == 0) ? 6 : 3 ))
    printf "\033[1;%sm%2d. %s\033[0m\n" "$color" "$((i+1))" "${wallpapers[$i]}"
done

read -rp "Enter your choice: " wallpaper_number
if [[ "$wallpaper_number" -ge 1 && "$wallpaper_number" -le "${#wallpapers[@]}" ]]; then
    uncomment_wallpaper "${wallpapers[$((wallpaper_number-1))]}"
else
    echo -e "${RED}✗ Invalid wallpaper selection. Exiting.${RESET}"
    exit 1
fi

print_section "Rofi Themes"
for i in "${!rofi_themes[@]}"; do
    color=$(( (i % 2 == 0) ? 6 : 3 ))
    printf "\033[1;%sm%2d. %s\033[0m\n" "$color" "$((i+1))" "${rofi_themes[$i]}"
done
read -rp "Enter your choice: " rofi_theme_number
if [[ "$rofi_theme_number" -ge 1 && "$rofi_theme_number" -le "${#rofi_themes[@]}" ]]; then
    set_rofi_theme "${rofi_themes[$((rofi_theme_number-1))]}"
else
    echo -e "${YELLOW}Skipping Rofi theme change.${RESET}"
fi

read -rp $'\nEnable Waybar border/background? [y/n]: ' toggle_border
toggle_waybar_border "$toggle_border"

if [[ $? -eq 2 ]]; then
    echo -e "${YELLOW}→ Waybar border/background disabled — skipping color selection.${RESET}"
else
    print_section "Waybar Colors"
    for i in "${!waybar_colors[@]}"; do
        color=$(( (i % 2 == 0) ? 6 : 3 ))
        printf "\033[1;%sm%2d. %s\033[0m\n" "$color" "$((i+1))" "${waybar_colors[$i]}"
    done

    read -rp "Enter your choice: " waybar_number
    if [[ "$waybar_number" -ge 1 && "$waybar_number" -le "${#waybar_colors[@]}" ]]; then
        set_waybar_color "${waybar_colors[$((waybar_number-1))]}"
    else
        echo -e "${YELLOW}Skipping Waybar color change.${RESET}"
    fi
fi

reload_wallpaper
echo -e "\n${GREEN}✅ All changes applied successfully!${RESET}"
