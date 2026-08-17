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

# --- 3. Git --------------------------------------------------------------
# Same pattern as the shell: Omarchy's ~/.config/git/config stays unmanaged
# because it holds this machine's mise-pinned gh credential path and the user
# identity. We append an include so our overrides load last and win.
GITCONF="$HOME/.config/git/config"
if [[ -f $GITCONF ]] && ! grep -q 'overrides.gitconfig' "$GITCONF"; then
  echo "==> Including overrides.gitconfig from ~/.config/git/config"
  printf '\n[include]\n\tpath = ~/.config/git/overrides.gitconfig\n' >>"$GITCONF"
fi

# --- 4. Symlinks -------------------------------------------------------------
echo "==> Stowing home"
stow -d "$DOTFILES" -t "$HOME" home

if [[ -d "$DOTFILES/hosts/$HOST" ]]; then
  echo "==> Stowing host package: $HOST"
  stow -d "$DOTFILES/hosts" -t "$HOME" "$HOST"
else
  echo "==> No host package for '$HOST' (skipping)"
fi

# --- 5. Binaries with no Arch package ----------------------------------------
# monarchmoney-cli ships as a GitHub release binary and is not in the repos or the
# AUR, so packages.lst cannot express it. Fetched rather than committed: a 14M
# binary does not belong in a dotfiles repo. Non-fatal, since a rebuild should not
# stop over one optional CLI.
install_monarch() {
  # The linux_amd64 assets are .apk/.deb/.rpm packages; the raw binary is only in
  # the tarball, so match that name exactly rather than the first "linux" hit.
  local repo=thedavidweng/monarchmoney-cli asset=monarch_linux_x86_64.tar.gz
  local tmp url
  tmp=$(mktemp -d) || return 1
  trap 'rm -rf "$tmp"' RETURN

  url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
    | grep -oE "\"browser_download_url\": *\"[^\"]*$asset\"" | head -1 | cut -d'"' -f4) || return 1
  [[ -n $url ]] || return 1

  curl -fsSL "$url" -o "$tmp/$asset" || return 1
  # Verify before executing anything: checksums.txt covers every asset.
  if curl -fsSL "${url%/*}/checksums.txt" -o "$tmp/checksums.txt"; then
    (cd "$tmp" && grep " $asset\$" checksums.txt | sha256sum -c --status) || {
      echo "    checksum mismatch, refusing to install" >&2; return 1; }
  else
    echo "    warning: checksums.txt unavailable, skipping verification" >&2
  fi

  tar -xzf "$tmp/$asset" -C "$tmp" monarch || return 1
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$tmp/monarch" "$HOME/.local/bin/monarch"
}

if [[ ! -x "$HOME/.local/bin/monarch" ]]; then
  echo "==> Fetching monarchmoney-cli"
  install_monarch || echo "    failed; install by hand from thedavidweng/monarchmoney-cli" >&2
fi

# --- 6. Omarchy shell plugins ------------------------------------------------
# Third-party bar plugins are git clones under ~/.config/omarchy/plugins, so they
# cannot be stowed. Guarded on the target directory rather than trusting
# `omarchy plugin add` to be idempotent: it has no existing-install check and
# would re-clone over a working plugin.
if command -v omarchy-plugin-add >/dev/null; then
  declare -A OMARCHY_PLUGINS=(
    [mrpbennett.fortivpn]=https://github.com/mrpbennett/qs-fortivpn.git
    [joegeary.on-air]=https://github.com/joegeary/omarchy-on-air
    [io.github.ilyazar.syncthing]=https://github.com/ilyaZar/omarchy-syncthing.git
  )
  for id in "${!OMARCHY_PLUGINS[@]}"; do
    [[ -d "$HOME/.config/omarchy/plugins/$id" ]] && continue
    echo "==> Adding omarchy plugin $id"
    omarchy-plugin-add "${OMARCHY_PLUGINS[$id]}" --enable --yes
  done

  # First-party widgets deliberately switched off, so a rebuilt bar matches.
  for id in omarchy.active-window omarchy.dropbox omarchy.media \
            omarchy.microphone omarchy.spacer; do
    omarchy-plugin-disable "$id" >/dev/null 2>&1 || true
  done
fi

# --- 7. Post-link steps ------------------------------------------------------
# bat will not use the bundled custom theme until its cache is rebuilt.
if command -v bat >/dev/null; then
  echo "==> Rebuilding bat cache"
  bat cache --build >/dev/null
fi

echo
echo "Done. Open a new terminal for zsh to take effect."
echo "See install/SERVICES.md for setup that stow cannot do."
