#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Define your GitHub repo URL and the local directory where it will be cloned
REPO_URL="https://github.com/Syntr1x/archconfig.git"
CLONE_DIR="$HOME/archconfig"

# Install dependencies (corrected rofi-wayland and removed feh)
PACKAGES=("hyprland" "waybar" "rofi-wayland")  # Add other packages if needed

# Clone the repository
echo "Cloning repository from GitHub..."
if [ ! -d "$CLONE_DIR" ]; then
    git clone "$REPO_URL" "$CLONE_DIR"
else
    echo "Repository already cloned."
fi

# Install necessary packages
echo "Installing system packages..."
for pkg in "${PACKAGES[@]}"; do
    if ! command_exists "$pkg"; then
        sudo pacman -S --noconfirm "$pkg"
    else
        echo "$pkg is already installed."
    fi
done

# Copy configurations to the appropriate directories
echo "Copying configuration files..."

# Copy hyprland configs
if [ -d "$CLONE_DIR/hypr" ]; then
    echo "Copying Hyprland configs..."
    cp -r "$CLONE_DIR/hypr/*" "$HOME/.config/hypr/"
fi

# Copy waybar configs
if [ -d "$CLONE_DIR/waybar" ]; then
    echo "Copying Waybar configs..."
    cp -r "$CLONE_DIR/waybar/*" "$HOME/.config/waybar/"
fi

# Copy rofi-wayland themes to /usr/share/rofi/themes
if [ -d "$CLONE_DIR/Rofi-themes" ]; then
    echo "Copying Rofi themes to /usr/share/rofi/themes..."
    sudo cp -r "$CLONE_DIR/Rofi-themes/*" "/usr/share/rofi/themes/"
fi

# Copy wallpapers (If you want them stored in a specific directory)
if [ -d "$CLONE_DIR/wallpapers" ]; then
    echo "Copying wallpapers..."
    cp -r "$CLONE_DIR/wallpapers/*" "$HOME/Pictures/"
fi

echo "Installation complete!"
