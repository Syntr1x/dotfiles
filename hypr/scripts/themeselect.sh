#!/bin/bash

# Paths to the config files
theme_config_file="$HOME/.config/ghostty/config"
wallpaper_config_file="$HOME/.config/hypr/hyprpaper.conf"
rofi_config_file="$HOME/.config/rofi/config.rasi"

# Define available options
themes=("syn-beige" "syn-Broadcast" "syn-mellow" "syn-Ocean")
wallpapers=("Flowers.png" "darkPlants.jpg" "pinkRose.jpg" "bluesky.jpg")
rofi_themes=("/usr/share/rofi/themes/rounded-beige.rasi" "/usr/share/rofi/themes/rounded-dark.rasi" "/usr/share/rofi/themes/rounded-pink.rasi" "/usr/share/rofi/themes/rounded-blue.rasi")

# Function to set the selected terminal theme
set_theme() {
    local theme=$1
    echo "Setting the theme to $theme..."

    # Comment out all theme lines first
    sed -i 's/^theme =/#theme =/' "$theme_config_file"

    # Uncomment the selected theme line
    sed -i "s/^#theme = $theme/theme = $theme/" "$theme_config_file"

    echo "Theme changed to $theme."
}

# Function to set the wallpaper
uncomment_wallpaper() {
    local wallpaper=$1
    echo "Setting wallpaper to: $wallpaper..."

    # Comment all relevant lines
    sed -i -E 's/^(preload|wallpaper|splash) =/#\1 =/' "$wallpaper_config_file"

    # Uncomment only the selected wallpaper line
    sed -i "/$wallpaper/s/^#//" "$wallpaper_config_file"

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

    # Remove any existing @theme lines
    sed -i '/^\s*@theme/d' "$rofi_config_file"

    # Add the new @theme line at the end
    echo "@theme \"$rofi_theme\"" >> "$rofi_config_file"

    echo "Rofi theme changed to $rofi_theme."
}

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

# --- Reload Wallpaper ---
echo "Reloading wallpaper..."
if [[ -x "$HOME/.config/hypr/scripts/reload-hyprpaper.sh" ]]; then
    nohup "$HOME/.config/hypr/scripts/reload-hyprpaper.sh" >/dev/null 2>&1 &
else
    echo "Warning: reload-hyprpaper.sh not found or not executable."
fi

echo "✅ Theme, wallpaper, and Rofi theme have been successfully changed!"
