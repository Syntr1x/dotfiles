#!/bin/bash

# This script will install the necessary packages and copy configs from the GitHub repo to your system.

# Function to install yay
install_yay() {
  echo "Checking if yay is installed..."
  # Check if yay is already installed
  if ! command -v yay &> /dev/null; then
    echo "yay not found, installing yay..."

    # Install necessary dependencies (with sudo)
    sudo pacman -S --needed --noconfirm base-devel git

    # Clone the yay repository
    git clone https://aur.archlinux.org/yay.git

    # Navigate into the yay directory
    cd yay

    # Create custom directories for building and installing packages
    mkdir -p $HOME/yay_build
    export BUILDDIR=$HOME/yay_build

    # Set custom package destination directory
    mkdir -p $HOME/yay_packages
    export PKGDEST=$HOME/yay_packages

    # Set custom source directory
    mkdir -p $HOME/yay_src
    export SRCDEST=$HOME/yay_src

    # Build and install yay (without sudo, run as normal user)
    makepkg -si --noconfirm

    # Go back to the previous directory
    cd ..
  else
    echo "yay is already installed."
  fi
}

# Function to install packages
install_packages() {
  echo "Checking and installing required packages..."

  # List of required packages
  REQUIRED_PKGS=("waybar" "rofi-wayland" "hyprland" "nano" "ghostty" "hyprpaper" "dolphin" "ark" "firefox")

  # Loop through the list and install only if not already installed or outdated
  for pkg in "${REQUIRED_PKGS[@]}"; do
    if pacman -Q "$pkg" &> /dev/null; then
      echo "$pkg is already installed and up to date."
    else
      echo "$pkg is not installed. Installing..."
      sudo pacman -S --noconfirm "$pkg"
    fi
  done

  # Install wlogout from the AUR using yay
  if yay -Q wlogout &> /dev/null; then
    echo "wlogout is already installed and up to date."
  else
    echo "wlogout is not installed. Installing..."
    yay -S --noconfirm wlogout
  fi
}

# Function to clone the GitHub repo and copy configs
copy_configs() {
  echo "Cloning the GitHub repository..."
  # Clone the repository into the user's home directory
  git clone https://github.com/Syntr1x/archconfig /home/$USER/archconfig

  # Get the actual user's home directory
  USER_HOME="/home/$USER"
  
  # Copy configs to the correct directories
  echo "Copying configuration files..."
  
  # Create the config directories if they don't exist
  mkdir -p $USER_HOME/.config/waybar
  sudo cp -r /home/$USER/archconfig/waybar $USER_HOME/.config/
  sudo cp -r /home/$USER/archconfig/hypr $USER_HOME/.config/
  
  # Ensure correct ownership of the scripts directory
  sudo chown -R $USER:$USER $USER_HOME/.config/hypr/scripts

  # Remove immutable flag (if set) on any files in the scripts folder
  sudo chattr -i $USER_HOME/.config/hypr/scripts/*

  # Make the scripts in the hypr directory executable
  chmod +x $USER_HOME/.config/hypr/scripts/*

  # Copy Rofi themes to the system-wide directory
  sudo cp -r /home/$USER/archconfig/Rofi-themes/rounded-common.rasi /usr/share/rofi/themes
  sudo cp -r /home/$USER/archconfig/Rofi-themes/rounded-dark-beige.rasi /usr/share/rofi/themes
}

# Make sure we run the script with sudo only for system package installations or copying to system directories
if [ "$(id -u)" -eq 0 ]; then
  echo "Please do not run this script as root. Run it as a normal user and use sudo when prompted."
  exit 1
fi

# Ensure that the script folder is writable and executable
chmod +x $0

# Install yay (without sudo, as a normal user)
install_yay

# Install packages
install_packages

# Copy configuration files
copy_configs

# Clean up
echo "Cleaning up..."
rm -rf /home/$USER/archconfig

echo "Installation complete. Please restart your session for the changes to take effect."
