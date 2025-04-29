#!/usr/bin/env bash

srcDir="$(dirname "$(realpath "$0")")"
# shellcheck disable=SC1091
if ! source "${srcDir}/global.sh"; then
  echo "Error: unable to source global.sh..."
  exit 1
fi

# pacman setup

if [ -f /etc/pacman.conf ] && [ ! -f /etc/pacman.conf.bak-dotfiles ]; then
  print_log -sec "PACMAN" -stat "modify" "adding extra spice to pacman..."

  # shellcheck disable=SC2154
  sudo cp /etc/pacman.conf /etc/pacman.conf.bak-dotfiles
  sudo sed -i "/^#Color/c\Color\nILoveCandy
    /^#VerbosePkgLists/c\VerbosePkgLists
    /^#ParallelDownloads/c\ParallelDownloads = 5" /etc/pacman.conf

  print_log -sec "PACMAN" -stat "update" "packages..."
  sudo pacman -Syyu
  sudo pacman -Fy
else
  print_log -sec "PACMAN" -stat "skipped" "pacman is already configured..."
fi

# setup Chaotic AUR repository

if grep -q '\[chaotic-aur\]' /etc/pacman.conf; then
  print_log -sec "CHAOTIC-AUR" -stat "skipped" "Chaotic AUR entry found in pacman.conf..."
else
  sudo pacman-key --init
  sudo "${srcDir}/chaotic_aur.sh"
fi

# install AUR Helper

if [[ -z "yay" ]]; then
  print_log -sec "YAY" -stat "update" "Installing YAY AUR helper..."
  sudo pacman -S --needed git base-devel
  git clone https://aur.archlinux.org/yay.git ~/yay
  cd ~/yay
  makepkg -si
  cd -
  rm -rf ~/yay
else
  print_log -sec "YAY" -stat "skipped" "YAY AUR helper already installed..."
fi

# install packages

"${srcDir}/install_packages.sh" "${srcDir}/packages.lst"

## TODO
# setup gnu stow
# bat cache --build
