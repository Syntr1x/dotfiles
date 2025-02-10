#!/bin/bash

# This script will install the necessary packages and copy configs from the GitHub repo to your system.

# Function to install packages
install_packages() {
  echo "Installing required packages..."
  sudo pacman -S --noconfirm waybar rofi-wayland hyprland nano kitty hyprpaper
}

# Function to clone the GitHub repo and copy configs
copy_configs() {
  echo "Cloning the GitHub repository..."
  # Clone the repository into the user's home directory
  git clone https://github.com/Syntr1x/archconfig ~/archconfig

  # Copy configs to the correct directories
  echo "Copying configuration files..."
  # Adjust these paths based on your configuration files in the repo
  cp -r ~/archconfig/.config/waybar ~/.config/waybar
  cp -r ~/archconfig/.config/rofi /usr/share/rofi/themes
  cp -r ~/archconfig/.config/hyprland ~/.config/hyprland
  cp -r ~/archconfig/.config/hyprpaper ~/.config/hypr/hyprpaper
  cp ~/archconfig/.bashrc ~/.bashrc  # Example, add other necessary files
}

# Make sure we run the script with sudo
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

# Install packages
install_packages

# Copy configuration files
copy_configs

# Clean up
echo "Cleaning up..."
rm -rf ~/archconfig

echo "Installation complete. Please restart your session for the changes to take effect."

