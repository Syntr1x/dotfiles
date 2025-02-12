#!/bin/bash

# This script will install the necessary packages and copy configs from the GitHub repo to your system.

# Function to install yay
install_yay() {
  echo "Checking if yay is installed..."
  if ! command -v yay &> /dev/null; then
    echo "yay not found, installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git
    cd yay
    mkdir -p $HOME/yay_build
    export BUILDDIR=$HOME/yay_build
    mkdir -p $HOME/yay_packages
    export PKGDEST=$HOME/yay_packages
    mkdir -p $HOME/yay_src
    export SRCDEST=$HOME/yay_src
    makepkg -si --noconfirm
    cd ..
  else
    echo "yay is already installed."
  fi
}

# Function to install packages
install_packages() {
  echo "Checking and installing required packages..."
  REQUIRED_PKGS=("waybar" "rofi-wayland" "hyprland" "nano" "ghostty" "hyprpaper" "dolphin" "ark" "firefox" "fastfetch" "btop")
  for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! pacman -Q "$pkg" &> /dev/null; then
      echo "$pkg is not installed. Installing..."
      sudo pacman -S --noconfirm "$pkg"
    else
      echo "$pkg is already installed and up to date."
    fi
  done

  if ! yay -Q wlogout &> /dev/null; then
    echo "wlogout is not installed. Installing..."
    yay -S --noconfirm wlogout
  else
    echo "wlogout is already installed and up to date."
  fi
}

# Function to clone the GitHub repo and copy configs
copy_configs() {
  echo "Cloning the GitHub repository..."
  git clone https://github.com/Syntr1x/archconfig /home/$USER/archconfig

  USER_HOME="/home/$USER"
  echo "Copying configuration files..."
  mkdir -p $USER_HOME/.config/waybar
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
install_yay
install_packages
copy_configs

echo "Cleaning up..."
rm -rf /home/$USER/archconfig

echo "Installation complete. Please restart your session for the changes to take effect."