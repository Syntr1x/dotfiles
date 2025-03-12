#!/bin/bash

# Path to the hyprpaper.conf file
config_file="$HOME/.config/hypr/hyprpaper.conf"

# Define available wallpapers
wallpapers=("Flowers.png" "darkPlants.jpg" "pinkRose.jpg")

# Function to uncomment the selected wallpaper
uncomment_wallpaper() {
    local wallpaper=$1
    echo "Uncommenting the wallpaper: $wallpaper..."
    
    # Comment out all wallpaper lines first
    sed -i 's/^\(preload =\|wallpaper =\|splash =\)/#\1/' "$config_file"
    
    # Uncomment the lines for the selected wallpaper
    sed -i "/$wallpaper/s/^#//" "$config_file"
    
    echo "Wallpaper changed to $wallpaper."
}

# Display available wallpapers
echo "Available wallpapers:"
for i in "${!wallpapers[@]}"; do
    echo "$((i+1)). ${wallpapers[$i]}"
done

# Prompt user to select a wallpaper
read -p "Enter the number corresponding to the wallpaper you want to set: " wallpaper_number

# Validate input
if [[ "$wallpaper_number" -ge 1 && "$wallpaper_number" -le "${#wallpapers[@]}" ]]; then
    selected_wallpaper=${wallpapers[$((wallpaper_number-1))]}
    uncomment_wallpaper "$selected_wallpaper"
else
    echo "Invalid selection. Exiting."
    exit 1
fi