#!/bin/bash

# This script will install the necessary packages and copy configs from the GitHub repo to your system.

# Function to install yay
_installYay() {
  echo "Checking if yay is installed..."
  if ! command -v yay &> /dev/null; then
    echo "yay not found, installing yay..."
    # Ensure base-devel is installed
    sudo pacman -S --needed --noconfirm base-devel git
    
    # Get the absolute path of the script to avoid confusion
    SCRIPT=$(realpath "$0")
    temp_path=$(dirname "$SCRIPT")
    
    # Clone yay from AUR and build it
    git clone https://aur.archlinux.org/yay.git $temp_path/yay
    cd $temp_path/yay
    makepkg -si --noconfirm
    cd $temp_path
    
    echo ":: yay has been installed successfully."
  else
    echo "yay is already installed."
  fi
}

# Function to install packages
install_packages() {
  echo "Checking and installing required packages..."
  REQUIRED_PKGS=("waybar" "rofi-wayland" "hyprland" "nano" "ghostty" "hyprpaper" "dolphin" "ark" "firefox" "fastfetch" "btop" "steam")
  
  # Install pacman packages
  for pkg in "${REQUIRED_PKGS[@]}"; do
    pacman -Q "$pkg" &> /dev/null || { echo "$pkg not found. Installing..."; sudo pacman -S --noconfirm "$pkg"; }
  done

  # Install yay packages (wlogout and vesktop)
  for pkg in "wlogout" "vesktop" "pwvucontrol"; do
    yay -Q "$pkg" &> /dev/null || { echo "$pkg not found. Installing..."; yay -S --noconfirm "$pkg"; }
  done
}

# Function to clone the GitHub repo and copy configs
copy_configs() {
  echo "Cloning the GitHub repository..."
  git clone https://github.com/Syntr1x/archconfig /home/$USER/archconfig

  USER_HOME="/home/$USER"
  echo "Copying configuration files"
  sudo cp -r /home/$USER/archconfig/waybar $USER_HOME/.config/
  sudo cp -r /home/$USER/archconfig/hypr $USER_HOME/.config/
  sudo cp -r /home/$USER/archconfig/ghostty $USER_HOME/.config/
  sudo cp -r /home/$USER/archconfig/rofi $USER_HOME/.config/
  sudo chown -R $USER:$USER $USER_HOME/.config/hypr/scripts
  sudo chattr -i $USER_HOME/.config/hypr/scripts/*
  chmod +x $USER_HOME/.config/hypr/scripts/*
  sudo cp -r /home/$USER/archconfig/Rofi-themes/rounded-common.rasi /usr/share/rofi/themes
  sudo cp -r /home/$USER/archconfig/Rofi-themes/rounded-dark-beige.rasi /usr/share/rofi/themes
}

if [ "$(id -u)" -eq 0 ]; then
  echo "Please do not run this script as root. Run it as a normal user and use sudo when prompted."
  exit 1
fi

chmod +x $0
_installYay
install_packages
copy_configs

echo "Cleaning up..."
rm -rf /home/$USER/archconfig

echo "Installation complete. Please restart your session for the changes to take effect."
