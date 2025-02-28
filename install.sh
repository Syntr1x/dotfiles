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
  REQUIRED_PKGS=("waybar" "rofi-wayland" "hyprland" "nano" "ghostty" "hyprpaper" "dolphin" "ark" "chromium" "fastfetch" "btop" "steam" "ttf-nerd-fonts-symbols" "ttf-font-awesome" "networkmanager" "flatpak")
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
  git clone https://github.com/Syntr1x/hyprconf.syn /home/$USER/tempconf
  sudo cp -r /home/$USER/tempconf/* /home/$USER/.config/
  sudo chown -R $USER:$USER /home/$USER/.config/hypr/scripts && sudo chattr -i /home/$USER/.config/hypr/scripts/* && chmod +x /home/$USER/.config/hypr/scripts/*
  sudo cp -r /home/$USER/tempconf/Rofi-themes/*.rasi /usr/share/rofi/themes
}

# Function to enable and start NetworkManager
enable_network_manager() {
  echo "Enabling and starting NetworkManager..."
  sudo systemctl enable NetworkManager
  sudo systemctl start NetworkManager
}
# install browser via Flathub
install_browser() {
  echo "Installing Zen Browser via Flathub..."
  flatpak install flathub app.zen_browser.zen
}
# Install the SDDM Astronaut theme
install_sddm_astronaut_theme() {
  echo "Installing SDDM Astronaut Theme by Keyitdev (https://github.com/Keyitdev/sddm-astronaut-theme/tree/master)..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"
}
# Ask the user if they want to install the SDDM Astronaut theme
ask_install_sddm_theme() {
  read -p "Do you want to install the SDDM Astronaut theme? (y/n): " choice
  case "$choice" in
    y|Y|yes|Yes)
      install_sddm_astronaut_theme
      ;;
    n|N|no|No)
      echo "Skipping SDDM Astronaut theme installation."
      ;;
    *)
      echo "Invalid input. Skipping SDDM Astronaut theme installation."
      ;;
  esac
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
enable_network_manager
install_browser
install_sddm_astronaut_theme
ask_install_sddm_theme

echo "Cleaning up..."
rm -rf /home/$USER/hyprconf.syn /home/$USER/tempconf /home/$USER/.config/install.sh /home/$USER/.config/README.md /home/$USER/.config/LICENSE
echo "Installation complete. Please restart your session for the changes to take effect."
