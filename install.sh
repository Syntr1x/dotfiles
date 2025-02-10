#!/bin/bash

# This script will install the necessary packages and copy configs from the GitHub repo to your system.

# Function to install packages
install_packages() {
  echo "Installing required packages..."
  sudo pacman -S --noconfirm waybar rofi-wayland hyprland nano ghostty hyprpaper dolphin ark
}

# Function to clone the GitHub repo and copy configs
copy_configs() {
  echo "Cloning the GitHub repository..."
  # Clone the repository into the user's home directory
  git clone https://github.com/Syntr1x/archconfig /home/$SUDO_USER/archconfig

  # Get the actual user's home directory
  USER_HOME="/home/$SUDO_USER"
  
  # Copy configs to the correct directories
  echo "Copying configuration files..."
  
  # Create the config directories if they don't exist
  mkdir -p $USER_HOME/.config/waybar
  sudo cp -r /home/$SUDO_USER/archconfig/waybar $USER_HOME/.config/
  sudo cp -r /home/$SUDO_USER/archconfig/hypr $USER_HOME/.config/
  
  # Make the scripts in the hypr directory executable
  chmod +x $USER_HOME/.config/hypr/scripts/*

  # Copy Rofi themes to the system-wide directory
  sudo cp -r /home/$SUDO_USER/archconfig/Rofi-themes/rounded-common.rasi /usr/share/rofi/themes
  sudo cp -r /home/$SUDO_USER/archconfig/Rofi-themes/rounded-dark-beige.rasi /usr/share/rofi/themes
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
rm -rf /home/$SUDO_USER/archconfig

echo "Installation complete. Please restart your session for the changes to take effect."
