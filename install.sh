#!/bin/bash

# This script will install the necessary packages and copy configs from the GitHub repo to your system.

# Function to install yay
_installYay() {
  if ! command -v yay &> /dev/null; then
    echo "yay not found, installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm && cd -
    echo ":: yay installed."
  else
    echo "yay already installed."
  fi
}

# Function to install pacman packages
install_pacman_packages() {
  REQUIRED_PKGS=("waybar" "rofi-wayland" "hyprland" "nano" "ghostty" "hyprpaper" "dolphin" "ark" "chromium" "fastfetch" "btop" "steam" "ttf-nerd-fonts-symbols" "ttf-font-awesome" "networkmanager")
  for pkg in "${REQUIRED_PKGS[@]}"; do
    pacman -Q "$pkg" &> /dev/null || { echo "$pkg not found. Installing..."; sudo pacman -S --noconfirm "$pkg"; }
  done
}

# Function to install yay (AUR) packages
install_yay_packages() {
  AUR_PKGS=("wlogout" "vesktop" "pwvucontrol")
  for pkg in "${AUR_PKGS[@]}"; do
    yay -Q "$pkg" &> /dev/null || { echo "$pkg not found. Installing..."; yay -S --noconfirm "$pkg"; }
  done
}

# Function to clone the GitHub repo and copy configs
copy_configs() {
  git clone https://github.com/Syntr1x/archconfig /home/$USER/archconfig
  sudo cp -r /home/$USER/archconfig/* /home/$USER/.config/
  sudo chown -R $USER:$USER /home/$USER/.config/hypr/scripts && sudo chattr -i /home/$USER/.config/hypr/scripts/* && chmod +x /home/$USER/.config/hypr/scripts/*
  sudo cp -r /home/$USER/archconfig/Rofi-themes/*.rasi /usr/share/rofi/themes
}

# Function to enable and start NetworkManager
enable_network_manager() {
  echo "Enabling and starting NetworkManager..."
  sudo systemctl enable NetworkManager.service
  sudo systemctl start NetworkManager.service
}
if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run as root. Use sudo when prompted."
  exit 1
fi

chmod +x $0
_installYay
install_pacman_packages
install_yay_packages
copy_configs

echo "Cleaning up..."
rm -rf /home/$USER/hyprconf.syn

echo "Installation complete. Please restart your session for the changes to take effect."
