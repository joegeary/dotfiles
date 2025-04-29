#!/usr/bin/env bash

srcDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
if ! source "${srcDir}/global.sh"; then
  echo "Error: unable to source global.sh..."
  exit 1
fi

handle_error() {
  print_log -sec "CHAOTIC-AUR" -err "error" "$1"
  exit 1
}

if ! pacman-key -l | grep 3056513887B78AEB >/dev/null; then
  print_log -sec "CHAOTIC-AUR" -stat "update" "installing pacman key"
  pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || {
    handle_error "failed to install the key"
  }
  pacman-key --lsign-key 3056513887B78AEB || {
    handle_error "failed to sign the key"
  }
else
  print_log -sec "CHAOTIC-AUR" -stat "skipped" "pacman key already exists"
fi

if ! pacman -Qq chaotic-keyring 2>/dev/null; then
  print_log -sec "CHAOTIC-AUR" -stat "update" "installing keyring"
  pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' || {
    handle_error "failed to download the keyring"
  }
else
  print_log -sec "CHAOTIC-AUR" -stat "skipped" "keyring already exists"
fi

if ! pacman -Qq chaotic-mirrorlist 2>/dev/null; then
  print_log -sec "CHAOTIC-AUR" -stat "update" "downloading the mirrorlist"
  pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || {
    handle_error "failed to download the mirrorlist"
  }
else
  print_log -sec "CHAOTIC-AUR" -stat "skipped" "mirrorlist already exists"
fi

print_log -sec "CHAOTIC-AUR" -stat "modify" "appending Chaotic AUR"
echo -e "\r\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >>/etc/pacman.conf
