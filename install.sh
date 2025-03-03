#!/bin/bash

# Install yay if not already installed
installYay() {
  command -v yay &>/dev/null || { echo "Installing yay..."; sudo pacman -S --needed --noconfirm base-devel git && git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm && cd -; }
}

# Install required pacman packages
install_pacman_packages() {
  local REQUIRED_PKGS=("waybar" "rofi-wayland" "hyprland" "nano" "ghostty" "hyprpaper" "dolphin" "ark" "chromium" "fastfetch" "btop" "steam" "ttf-nerd-fonts-symbols" "ttf-font-awesome" "networkmanager" "flatpak")
  for pkg in "${REQUIRED_PKGS[@]}"; do pacman -Q "$pkg" &>/dev/null || sudo pacman -S --noconfirm "$pkg"; done
}

# Install required yay (AUR) packages
install_yay_packages() {
  local AUR_PKGS=("wlogout" "vesktop" "pwvucontrol")
  for pkg in "${AUR_PKGS[@]}"; do yay -Q "$pkg" &>/dev/null || yay -S --noconfirm "$pkg"; done
}

# Clone repo and copy configs
copy_configs() {
  git clone https://github.com/Syntr1x/hyprconf.syn /home/$USER/tempconf
  sudo cp -r /home/$USER/tempconf/* /home/$USER/.config/ && sudo chown -R $USER:$USER /home/$USER/.config/hypr/scripts && sudo chattr -i /home/$USER/.config/hypr/scripts/* && chmod +x /home/$USER/.config/hypr/scripts/*
  sudo cp /home/$USER/tempconf/Rofi-themes/*.rasi /usr/share/rofi/themes
}

# Enable NetworkManager
enable_network_manager() {
  sudo systemctl enable --now NetworkManager
}

# Install browser via Flathub
install_browser() {
  flatpak install -y flathub app.zen_browser.zen
}

# Install SDDM Astronaut theme if chosen
install_sddm_astronaut_theme() {
  read -p "Install SDDM Astronaut theme? (y/n): " choice
  [[ "$choice" =~ ^[yY](es)?$ ]] && { sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"; sudo systemctl enable sddm --now; } || echo "Skipping SDDM Astronaut theme installation."
}

# Main script
if [ "$(id -u)" -eq 0 ]; then echo "Do not run as root. Use sudo when prompted."; exit 1; fi
chmod +x $0
installYay
install_pacman_packages
install_yay_packages
copy_configs
enable_network_manager
install_browser
install_sddm_astronaut_theme
echo "Cleaning up..."; rm -rf /home/$USER/hyprconf.syn /home/$USER/tempconf /home/$USER/.config/install.sh /home/$USER/.config/README.md /home/$USER/.config/LICENSE
echo "Installation complete. Please restart your session."
