#!/bin/bash

install_Yay() {
  command -v yay &>/dev/null || { echo "Installing yay..."; sudo pacman -S --needed --noconfirm base-devel git && git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm && cd -; }
}

install_pacman_packages() {
  local REQUIRED_PKGS=("hyprland" "nano" "ghostty" "hyprpaper" "dolphin" "ark" "fastfetch" "btop" "networkmanager" "sddm" "pipewire" "pipewire-audio" "pipewire-alsa" "pipewire-pulse" "pipewire-libcamera" "wireplumber" "alsa-utils" "alsa-card-profiles" "sof-firmware" "rtkit" "quickshell" "flatpak" "libnotify" "kitty" "wget" "reflector" "dunst" "ttf-nerd-fonts-symbols" "ttf-firacode-nerd" "ttf-jetbrains-mono-nerd" "ttf-font-awesome" "python" "brightnessctl" "playerctl")
  for pkg in "${REQUIRED_PKGS[@]}"; do pacman -Q "$pkg" &>/dev/null || sudo pacman -S --needed --noconfirm "$pkg"; done
}

install_yay_packages() {
  local AUR_PKGS=("wlogout" "vesktop" "pwvucontrol" "phinger-cursors" "sddm-silent-theme")
  for pkg in "${AUR_PKGS[@]}"; do yay -Q "$pkg" &>/dev/null || yay -S --noconfirm "$pkg"; done
}

copy_configs() {
  rm -rf /home/$USER/tempconf
  git clone https://github.com/Syntr1x/dotfiles /home/$USER/tempconf

  sudo mkdir -p /usr/share/ghostty/themes
  sudo mkdir -p /usr/share/sddm/themes/silent/configs
  sudo mkdir -p /usr/share/sddm/themes/silent/backgrounds

  shopt -s dotglob
  sudo cp -r /home/$USER/tempconf/* /home/$USER/.config/ && sudo chown -R $USER:$USER /home/$USER/.config && find /home/$USER/.config/{hypr,quickshell} -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null
  shopt -u dotglob

  sudo cp /home/$USER/tempconf/Ghostty-themes/* /usr/share/ghostty/themes 2>/dev/null
  sudo cp /home/$USER/tempconf/.bashrc /home/$USER/
  sudo cp /home/$USER/tempconf/themeselector.desktop /usr/share/applications/
  sudo cp /home/$USER/tempconf/zen-browser.desktop /usr/share/applications/
  sudo sed -i "s|\$USER|$USER|g" /usr/share/applications/zen-browser.desktop
  sudo cp /home/$USER/tempconf/defaultsyn.conf /usr/share/sddm/themes/silent/configs/ 2>/dev/null
  sudo cp /home/$USER/tempconf/hypr/Wallpapers/* /usr/share/sddm/themes/silent/backgrounds/ 2>/dev/null
  sudo chown -R "$USER":"$USER" /usr/share/sddm/themes/silent/configs/
  sudo find ~/.config/{ghostty,hypr,quickshell} -type d -exec chown "$USER":"$USER" {} +
}

enable_network_manager() {
  sudo systemctl enable --now NetworkManager
}

silent_sddm() {
  if [ ! -d "/usr/share/sddm/themes/silent" ]; then
    echo "ERROR: sddm-silent-theme not found at /usr/share/sddm/themes/silent"
    exit 1
  fi

  sudo sed -i '/^ConfigFile=configs\/default.conf/{s/^/# /;i ConfigFile=configs/defaultsyn.conf
}' /usr/share/sddm/themes/silent/metadata.desktop 2>/dev/null

  sudo tee /etc/sddm.conf > /dev/null << 'EOF'
[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=silent
EOF
}

enable_sddm() {
  sudo systemctl enable sddm
}

enable_pipewire() {
  systemctl --user enable --now pipewire.socket pipewire.service wireplumber.service pipewire-pulse.socket pipewire-pulse.service
  systemctl --user restart pipewire pipewire-pulse wireplumber
}

install_Zen() {
  wget -O /tmp/zen.tar.xz https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-x86_64.tar.xz
  mkdir -p /home/$USER/zen-browser
  tar -xf /tmp/zen.tar.xz -C /home/$USER/zen-browser
  grep -qxF "export PATH=\$PATH:/home/$USER/zen-browser" /home/$USER/.bashrc || \
    echo "export PATH=\$PATH:/home/$USER/zen-browser" >> /home/$USER/.bashrc
  rm /tmp/zen.tar.xz
}

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
silent_sddm                   
enable_network_manager
enable_sddm
enable_pipewire
install_Zen
reflector_mirrorlist

# Run theme selection script
echo "Running theme selection script..."
qs -p "$HOME/.config/quickshell/themeselector/shell.qml"

# Stale pre-quickshell configs (upgrade installs): back up, don't nuke.
bk="/home/$USER/.config/backup-pre-quickshell-$(date +%Y%m%d-%H%M%S)"
for d in waybar rofi; do
  if [ -d "/home/$USER/.config/$d" ]; then
    mkdir -p "$bk" && mv "/home/$USER/.config/$d" "$bk/" && echo "Backed up old $d to $bk"
  fi
done
[ -d "$bk" ] && chown -R $USER:$USER "$bk" 2>/dev/null || true

echo "Cleaning up..."; sudo rm -rf /home/$USER/hyprconf.syn /home/$USER/tempconf /home/$USER/.config/install.sh /home/$USER/.config/README.md /home/$USER/.config/LICENSE /home/$USER/.config/QUICKSHELL.md /home/$USER/.config/Ghostty-themes /home/$USER/.config/themeselector.desktop /home/$USER/.config/zen-browser.desktop /home/$USER/.config/defaultsyn.conf
echo "Installation complete. Please reboot to start SDDM and your new session."
