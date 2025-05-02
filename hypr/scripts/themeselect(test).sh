#!/bin/bash

# Path to the config files
theme_config_file="$HOME/.config/ghostty/config"
wallpaper_config_file="$HOME/.config/hypr/hyprpaper.conf"
rofi_config_file="$HOME/.config/rofi/config.rasi"

# Define available themes, wallpapers, and Rofi themes
themes=("syn-beige" "syn-Broadcast" "syn-mellow" "syn-Ocean")
wallpapers=("Flowers.png" "darkPlants.jpg" "pinkRose.jpg" "bluesky.jpg")
rofi_themes=("rounded-dark" "rounded-pink" "rounded-beige" "rounded-blue")

# Function to set the selected theme
set_theme() {
    local theme=$1
    echo "Setting the theme to $theme..."

    sudo sed -i 's/^theme =/#theme =/' "$theme_config_file"
    sudo sed -i "s/^#theme = $theme/theme = $theme/" "$theme_config_file"

    echo "Theme changed to $theme."
}

# Function to uncomment the selected wallpaper
uncomment_wallpaper() {
    local wallpaper=$1
    echo "Uncommenting the wallpaper: $wallpaper..."

    sudo sed -i 's/^preload =\|wallpaper =\|splash =/#\1/' "$wallpaper_config_file"
    sudo sed -i "/$wallpaper/s/^#//" "$wallpaper_config_file"

    echo "Wallpaper changed to $wallpaper."
}

# Function to set the selected Rofi theme
set_rofi_theme() {
    local rofi_theme=$1
    echo "Setting the Rofi theme to $rofi_theme..."

    sed -i '/^\s*@theme/ s,^,//,' "$rofi_config_file"
    echo -e "\n@theme \"$rofi_theme\"" >> "$rofi_config_file"

    echo "Rofi theme changed to $rofi_theme."
}

# Display available themes
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

# Display available wallpapers
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

# Display available Rofi themes
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

echo "Reloading Wallpaper..."
nohup $HOME/.config/hypr/scripts/reload-hyprpaper.sh &

echo "Theme, wallpaper, and Rofi theme have been successfully changed!"