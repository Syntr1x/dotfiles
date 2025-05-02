#!/bin/bash

# Path to the config files
theme_config_file="$HOME/.config/ghostty/config"
wallpaper_config_file="$HOME/.config/hypr/hyprpaper.conf"

# Define available themes and wallpapers
themes=("syn-beige" "syn-Broadcast" "syn-mellow" "syn-Ocean" )
wallpapers=("Flowers.png" "darkPlants.jpg" "pinkRose.jpg" "bluesky.jpg" )

# Function to set the selected theme
set_theme() {
    local theme=$1
    echo "Setting the theme to $theme..."

    # Comment out all theme lines first
    sudo sed -i 's/^theme =/#theme =/' "$theme_config_file"

    # Uncomment the line for the selected theme
    sudo sed -i "s/^#theme = $theme/theme = $theme/" "$theme_config_file"

    echo "Theme changed to $theme."
}

# Function to uncomment the selected wallpaper
uncomment_wallpaper() {
    local wallpaper=$1
    echo "Uncommenting the wallpaper: $wallpaper..."

    # Comment out all wallpaper lines first
    sudo sed -i 's/^\(preload =\|wallpaper =\|splash =\)/#\1/' "$wallpaper_config_file"

    # Uncomment the lines for the selected wallpaper
    sudo sed -i "/$wallpaper/s/^#//" "$wallpaper_config_file"

    echo "Wallpaper changed to $wallpaper."
}

# Display available themes
echo "Available themes:"
for i in "${!themes[@]}"; do
    echo "$((i+1)). ${themes[$i]}"
done

# Prompt user to select a theme
read -p "Enter the number corresponding to the theme you want to set: " theme_number

# Validate theme input
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

# Prompt user to select a wallpaper
read -p "Enter the number corresponding to the wallpaper you want to set: " wallpaper_number

# Validate wallpaper input
if [[ "$wallpaper_number" -ge 1 && "$wallpaper_number" -le "${#wallpapers[@]}" ]]; then
    selected_wallpaper=${wallpapers[$((wallpaper_number-1))]}
    uncomment_wallpaper "$selected_wallpaper"
else
    echo "Invalid wallpaper selection. Exiting."
    exit 1
fi

echo "Reloading Wallpaper"
nohup $HOME/.config/hypr/scripts/reload-hyprpaper.sh
echo "Theme and wallpaper have been successfully changed!"
