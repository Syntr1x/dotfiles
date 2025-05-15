#!/bin/bash

# Paths to the config files
theme_config_file="$HOME/.config/ghostty/config"
wallpaper_config_file="$HOME/.config/hypr/hyprpaper.conf"
rofi_config_file="$HOME/.config/rofi/config.rasi"

# Define available options
themes=("syn-beige" "syn-Broadcast" "syn-mellow" "syn-Ocean" "IC_Orange_PPL")
wallpapers=("Flowers.png" "darkPlants.jpg" "pinkRose.jpg" "bluesky.jpg" "TrainPath.png")
rofi_themes=(
    "/usr/share/rofi/themes/rounded-beige.rasi"
    "/usr/share/rofi/themes/rounded-dark.rasi"
    "/usr/share/rofi/themes/rounded-pink.rasi"
    "/usr/share/rofi/themes/rounded-blue.rasi"
    "/usr/share/rofi/themes/rounded-orange.rasi"
)

# Function to set the selected terminal theme
set_theme() {
    local theme=$1
    echo "Setting the theme to $theme..."

    sudo -E sed -i 's/^theme =/#theme =/' "$theme_config_file"
    sudo -E sed -i "s/^#theme = $theme/theme = $theme/" "$theme_config_file"

    echo "Theme changed to $theme."
}

# Function to set the wallpaper
uncomment_wallpaper() {
    local wallpaper=$1
    echo "Setting wallpaper to: $wallpaper..."

    sudo -E sed -i -E 's/^(preload|wallpaper|splash) =/#\1 =/' "$wallpaper_config_file"
    sudo -E sed -i "/$wallpaper/s/^#//" "$wallpaper_config_file"

    echo "Wallpaper changed to $wallpaper."
}

# Function to set the Rofi theme
set_rofi_theme() {
    local rofi_theme=$1
    echo "Setting Rofi theme to $rofi_theme..."

    if [[ ! -f "$rofi_config_file" ]]; then
        echo "Rofi config not found: $rofi_config_file"
        return 1
    fi

    sudo -E sed -i '/^\s*@theme/d' "$rofi_config_file"
    echo "@theme \"$rofi_theme\"" | sudo -E tee -a "$rofi_config_file" > /dev/null

    echo "Rofi theme changed to $rofi_theme."
}

# Function to reload wallpaper
reload_wallpaper() {
    echo "Reloading wallpaper..."
    if [[ -x "$HOME/.config/hypr/scripts/reload-hyprpaper.sh" ]]; then
        nohup "$HOME/.config/hypr/scripts/reload-hyprpaper.sh" >/dev/null 2>&1 &
        sleep 1
    else
        echo "Warning: reload-hyprpaper.sh not found or not executable."
    fi
}

# --- Systemwide theme shortcut ---
read -p "Do you want to apply a full systemwide theme (theme, wallpaper, Rofi)? (y/n): " apply_all
if [[ "$apply_all" =~ ^[Yy]$ ]]; then
    echo "Available system themes:"
    for i in "${!themes[@]}"; do
        echo "$((i+1)). ${themes[$i]}"
    done

    read -p "Enter the number corresponding to the systemwide theme you want to apply: " theme_index
    if [[ "$theme_index" -ge 1 && "$theme_index" -le "${#themes[@]}" ]]; then
        index=$((theme_index-1))
        set_theme "${themes[$index]}"
        uncomment_wallpaper "${wallpapers[$index]}"
        set_rofi_theme "${rofi_themes[$index]}"
        reload_wallpaper

        echo "✅ Systemwide theme applied successfully."
        exit 0
    else
        echo "Invalid selection. Exiting."
        exit 1
    fi
fi

# --- Theme selection ---
echo "Available themes:"
for i in "${!themes[@]}"; do
    echo "$((i+1)). ${themes[$i]}"
done

read -p "Enter the number corresponding to the theme you want to set: " theme_number
if [[ "$theme_number" -ge 1 && "$theme_number" -le "${#themes[@]}" ]]; then
    selected_theme=${themes[$((theme_number-1))]}
    set_theme "$selected_theme"
else
    echo "Invalid theme selection. Exiting."
    exit 1
fi

# --- Wallpaper selection ---
echo "Available wallpapers:"
for i in "${!wallpapers[@]}"; do
    echo "$((i+1)). ${wallpapers[$i]}"
done

read -p "Enter the number corresponding to the wallpaper you want to set: " wallpaper_number
if [[ "$wallpaper_number" -ge 1 && "$wallpaper_number" -le "${#wallpapers[@]}" ]]; then
    selected_wallpaper=${wallpapers[$((wallpaper_number-1))]}
    uncomment_wallpaper "$selected_wallpaper"
else
    echo "Invalid wallpaper selection. Exiting."
    exit 1
fi

# --- Rofi theme selection ---
echo "Available Rofi themes:"
for i in "${!rofi_themes[@]}"; do
    echo "$((i+1)). ${rofi_themes[$i]}"
done

read -p "Enter the number corresponding to the Rofi theme you want to set: " rofi_theme_number
if [[ "$rofi_theme_number" -ge 1 && "$rofi_theme_number" -le "${#rofi_themes[@]}" ]]; then
    selected_rofi_theme=${rofi_themes[$((rofi_theme_number-1))]}
    set_rofi_theme "$selected_rofi_theme"
else
    echo "Invalid Rofi theme selection. Skipping Rofi theme change."
fi

reload_wallpaper
echo "✅ Theme, wallpaper, and Rofi theme have been successfully changed!"
