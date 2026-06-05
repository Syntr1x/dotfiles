#!/bin/bash

# Install yay if not already installed
install_Yay() {
  command -v yay &>/dev/null || { echo "Installing yay..."; sudo pacman -S --needed --noconfirm base-devel git && git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm && cd -; }
}

# Install required pacman packages
install_pacman_packages() {
  local REQUIRED_PKGS=("waybar" "rofi" "hyprland" "nano" "ghostty" "hyprpaper" "dolphin" "ark" "fastfetch" "btop" "ttf-nerd-fonts-symbols" "ttf-font-awesome" "ttf-firacode-nerd" "ttf-jetbrains-mono-nerd" "networkmanager" "flatpak" "kitty" "wget" "reflector" "dunst")
  for pkg in "${REQUIRED_PKGS[@]}"; do pacman -Q "$pkg" &>/dev/null || sudo pacman -S --noconfirm "$pkg"; done
}

# Install required yay (AUR) packages
install_yay_packages() {
  local AUR_PKGS=("wlogout" "vesktop" "pwvucontrol" "phinger-cursors" "sddm-silent-theme")
  for pkg in "${AUR_PKGS[@]}"; do yay -Q "$pkg" &>/dev/null || yay -S --noconfirm "$pkg"; done
}

# Clone repo and copy configs
copy_configs() {
  git clone https://github.com/Syntr1x/dotfiles /home/$USER/tempconf
  sudo cp -r /home/$USER/tempconf/* /home/$USER/.config/ && sudo chown -R $USER:$USER /home/$USER/.config/hypr/scripts && sudo chattr -i /home/$USER/.config/hypr/scripts/* && chmod +x /home/$USER/.config/hypr/scripts/*
  sudo cp /home/$USER/tempconf/Rofi-themes/*.rasi /usr/share/rofi/themes
  sudo cp /home/$USER/tempconf/Ghostty-themes/* /usr/share/ghostty/themes
  sudo cp /home/$USER/tempconf/.bashrc /home/$USER/
  sudo cp /home/$USER/tempconf/themeselector.desktop /usr/share/applications/
  sudo cp /home/$USER/tempcong/dunstrc /etc/dunst/
  sudo cp /home/$USER/tempconf/defaultsyn.conf /usr/share/sddm/themes/silent/configs/
  sudo cp /home/$USER/tempconf/hypr/Wallpapers/* /usr/share/sddm/themes/silent/backgrounds/
  sudo chown -R "$USER":"$USER" ~/.config/rofi
}
# Enable NetworkManager
enable_network_manager() {
  sudo systemctl enable --now NetworkManager
}
# Enable Sddm
enable_sddm() {
  sudo systemctl enable --now sddm
}
# Silent SDDM theme config
silent_sddm() {
  sudo sed -i '/^ConfigFile=configs\/default.conf/{s/^/# /;i ConfigFile=configs/defaultsyn.conf
}' /usr/share/sddm/themes/silent/metadata.desktop
   sudo tee /etc/sddm.conf > /dev/null << 'EOF'
[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=silent
EOF
}
# install browser
install_Zen() {
  wget https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-x86_64.tar.xz && tar -xf zen.linux-x86_64.tar.xz && rm zen.linux-x86_64.tar.xz
}
# Update pacman mirrorlist
reflector_mirrorlist() {
  read -p "Update mirrorlist with reflector? (y/n): " c
  [[ "$c" =~ ^[yY]$ ]] && read -p "Enter country code (e.g. DE): " cc && sudo reflector -p https --sort rate -c "$cc" --verbose --save /etc/pacman.d/mirrorlist
}
# Main script
if [ "$(id -u)" -eq 0 ]; then echo "Do not run as root. Use sudo when prompted."; exit 1; fi
install_Yay
install_pacman_packages
install_yay_packages
copy_configs
enable_network_manager
enable_sddm
silent_sddm
install_Zen
reflector_mirrorlist

# Run theme selection script 
echo "Running theme selection script..."
/home/$USER/.config/hypr/scripts/themeselect.sh

echo "Cleaning up..."; sudo rm -rf /home/$USER/hyprconf.syn /home/$USER/tempconf /home/$USER/.config/install.sh /home/$USER/.config/README.md /home/$USER/.config/LICENSE /home/$USER/.config/Ghostty-themes /home/$USER/.config/Rofi-themes /home/$USER/.config/themeselector.desktop
echo "Installation complete. Please restart your session."
