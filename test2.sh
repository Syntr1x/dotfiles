#!/bin/bash

# Path to the config file
config_file="$HOME/.config/hypr/ghostty/config"

# Define available themes
themes=("syn-mellow" "syn-beige" "syn-Broadcast")

# Function to set the selected theme
set_theme() {
    local theme=$1
    echo "Setting the theme to $theme..."

    # Comment out all theme lines first
    sed -i 's/^theme =/#theme =/' "$config_file"
    
    # Uncomment the line for the selected theme
    sed -i "s/^#theme = $theme/theme = $theme/" "$config_file"
    
    echo "Theme changed to $theme."
}

# Display available themes
echo "Available themes:"
for i in "${!themes[@]}"; do
    echo "$((i+1)). ${themes[$i]}"
done

# Prompt user to select a theme
read -p "Enter the number corresponding to the theme you want to set: " theme_number

# Validate input
if [[ "$theme_number" -ge 1 && "$theme_number" -le "${#themes[@]}" ]]; then
    selected_theme=${themes[$((theme_number-1))]}
    set_theme "$selected_theme"
else
    echo "Invalid selection. Exiting."
    exit 1
fi