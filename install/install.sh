#!/usr/bin/env bash
# Bootstrap an Omarchy machine from this repo. Safe to re-run.
#
# Assumes a stock Omarchy 4 install (which already provides pacman config, yay,
# hyprland, and the base shell/terminal stack). This script only layers on the
# packages, symlinks, and shell hook that this repo owns.
#
# Service setup that symlinks cannot express lives in SERVICES.md.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$(hostnamectl --static 2>/dev/null || hostname)"

# --- 1. Packages -------------------------------------------------------------
# yay handles both repo and AUR packages, and prompts for sudo itself.
mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$DOTFILES/install/packages.lst" | awk '{print $1}')
if ((${#pkgs[@]})); then
  echo "==> Installing ${#pkgs[@]} packages"
  yay -S --needed "${pkgs[@]}"
fi

# --- 2. Shell ----------------------------------------------------------------
# omarchy-zsh owns ~/.zshrc and ~/.bashrc, so we never stow them. We only append
# a hook sourcing our own customizations, and re-add it if the package resets.
if ! grep -q omarchy-zsh "$HOME/.zshrc" 2>/dev/null; then
  echo "==> Setting up zsh"
  omarchy-setup-zsh
fi

HOOK='[[ -f ~/.config/zsh/local.zsh ]] && source ~/.config/zsh/local.zsh'
if ! grep -qF "$HOOK" "$HOME/.zshrc"; then
  echo "==> Adding local.zsh hook to ~/.zshrc"
  printf '\n%s\n' "$HOOK" >>"$HOME/.zshrc"
fi

# --- 3. Symlinks -------------------------------------------------------------
echo "==> Stowing home"
stow -d "$DOTFILES" -t "$HOME" home

if [[ -d "$DOTFILES/hosts/$HOST" ]]; then
  echo "==> Stowing host package: $HOST"
  stow -d "$DOTFILES/hosts" -t "$HOME" "$HOST"
else
  echo "==> No host package for '$HOST' (skipping)"
fi

echo
echo "Done. Open a new terminal for zsh to take effect."
echo "See install/SERVICES.md for setup that stow cannot do."
