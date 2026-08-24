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

# --- 4. Ghostty --------------------------------------------------------------
# Third time for this pattern. Omarchy ships ~/.config/ghostty/config as a plain
# file it keeps updating, so we leave it unmanaged and append a config-file
# include: ghostty loads an included file *after* the one naming it, so
# overrides.conf wins. The `?` marks it optional, so a box that has not stowed
# yet still gets a working terminal - which is what you would fix it from.
GHOSTTYCONF="$HOME/.config/ghostty/config"
if [[ -f $GHOSTTYCONF ]] && ! grep -q 'overrides.conf' "$GHOSTTYCONF"; then
  echo "==> Including overrides.conf from ~/.config/ghostty/config"
  printf '\n# Personal overrides, loaded last so they win. Managed in ~/dotfiles.\nconfig-file = ?"~/.config/ghostty/overrides.conf"\n' >>"$GHOSTTYCONF"
fi

# --- 4b. Screen sharing (xdph) ------------------------------------------------
# Same pattern again: Omarchy owns ~/.config/hypr/xdph.conf (it seeds it from
# /usr/share/omarchy/config/hypr/), so we append a delta rather than taking the
# file over. hyprlang merges a repeated category, so a second screencopy block
# is a clean way to add one key without rewriting Omarchy's.
#
# force_shm makes screencopy hand over SHM buffers instead of DMA-BUFs. Zoom
# asks for a DMA-BUF with an Intel modifier it cannot render on reconnect, so
# the first screenshare works and every one after it is a black screen. SHM
# sidesteps the DMA negotiation entirely. The tradeoff is that this applies to
# ALL screensharing and CPU-copies frames, so drop it if you ever need the GPU
# path for high-res capture in OBS.
XDPH_CONF="$HOME/.config/hypr/xdph.conf"
if [[ -f $XDPH_CONF ]] && ! grep -q 'force_shm' "$XDPH_CONF"; then
  echo "==> Adding force_shm to xdph.conf (fixes Zoom black screen on reshare)"
  cat >>"$XDPH_CONF" <<'EOF'

# Force SHM buffers for screencopy; fixes Zoom black screen on 2nd+ screenshare.
# See install/SERVICES.md. Remove if you need the GPU path for high-res capture.
screencopy {
    force_shm = 1
}
EOF
  echo "    restart the portal to pick it up, or just log out and back in:"
  echo "      systemctl --user restart xdg-desktop-portal-hyprland"
fi

# --- 5. Symlinks -------------------------------------------------------------
echo "==> Stowing home"
stow -d "$DOTFILES" -t "$HOME" home

if [[ -d "$DOTFILES/hosts/$HOST" ]]; then
  echo "==> Stowing host package: $HOST"
  stow -d "$DOTFILES/hosts" -t "$HOME" "$HOST"
else
  echo "==> No host package for '$HOST' (skipping)"
fi

# Omarchy ships a Zoom PWA desktop entry that shadows the native Zoom package's
# entry (same filename). Overwrite it with the native package's entry so the
# native app appears in launchers; the PWA is still available as "Zoom (PWA)"
# via the stowed Zoom-PWA.desktop.
OMARCHY_ZOOM="$HOME/.local/share/applications/Zoom.desktop"
NATIVE_ZOOM=/usr/share/applications/Zoom.desktop
if [[ -f $OMARCHY_ZOOM && ! -L $OMARCHY_ZOOM && -f $NATIVE_ZOOM ]]; then
  echo "==> Replacing omarchy Zoom PWA with native Zoom entry"
  cp "$NATIVE_ZOOM" "$OMARCHY_ZOOM"
fi

# --- 6. Claude Code settings --------------------------------------------------
# Deliberately copied, not stowed. Claude Code rewrites settings.json in place, so
# a symlink here gets replaced by a regular file and the repo silently stops
# tracking it - which is exactly what happened to the old repo's version. Copying
# only when absent means Claude Code owns the live file and this is the seed for a
# fresh machine.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [[ ! -f $CLAUDE_SETTINGS ]]; then
  echo "==> Seeding ~/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  install -m 644 "$DOTFILES/install/claude-settings.json" "$CLAUDE_SETTINGS"
fi

# --- 7. mise-managed toolchains ----------------------------------------------
# mise itself comes from Omarchy, but its pins live in this repo
# (home/.config/mise/config.toml) and nothing installs them automatically. Without
# this, a rebuilt box has mise and no dotnet, java, node, gh or python.
if command -v mise >/dev/null && [[ -f "$HOME/.config/mise/config.toml" ]]; then
  echo "==> Installing mise toolchains"
  mise install || echo "!! mise install failed" >&2
fi

# --- 8. Binaries with no Arch package ----------------------------------------
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

# --- 9. Omarchy shell plugins ------------------------------------------------
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

# --- 10. FortiVPN split-DNS hook ---------------------------------------------
# openfortivpn registers ppp0's corporate DNS servers with systemd-resolved but
# leaves the link a catch-all resolver with no routing domain, so *.sws.local
# hits resolved's mDNS special-casing for .local and never resolves. This pppd
# ip-up hook claims sws.local + 10.x reverse + oncoursesystems.com for the tunnel
# and drops it as a default route - split DNS. Unlike the VPN's credential-bearing pieces (see
# SERVICES.md) it holds no secrets, so the repo owns it. Root-owned, hence copied
# with sudo rather than stowed; guarded on content so a no-op re-run stays quiet.
PPP_HOOK=/etc/ppp/ip-up.d/50-sws-split-dns.sh
if ! cmp -s "$DOTFILES/install/50-sws-split-dns.sh" "$PPP_HOOK"; then
  echo "==> Installing FortiVPN split-DNS hook"
  sudo install -m 755 "$DOTFILES/install/50-sws-split-dns.sh" "$PPP_HOOK"
fi

# Two keys make the split-DNS hook above work without hardcoding any resolvers:
#   pppd-use-peerdns=1  pppd learns ppp0's servers from the tunnel and the stock
#                       00-dns.sh hook applies them - servers stay dynamic.
#   set-dns=0           openfortivpn's own DNS push runs *after* the ip-up hooks
#                       and resets ppp0's search domains, wiping the split-DNS
#                       setup on every connect. Off, the ordering is clean:
#                       00-dns.sh sets servers, then 50-sws adds the domains.
# The conf is root-owned mode 600, managed by the fortivpn Omarchy plugin, which
# only rewrites host/port/username/password/trusted-cert - so these keys survive
# its writes. sed -i / tee -a keep the file's owner and mode intact (plugin
# requires 600 root). Only act once the VPN is configured.
FORTIVPN_CONF=/etc/openfortivpn/omarchy.conf
if sudo test -f "$FORTIVPN_CONF"; then
  set_fortivpn_key() {
    key=$1 val=$2
    if sudo grep -qE "^[[:space:]]*$key[[:space:]]*=" "$FORTIVPN_CONF"; then
      if ! sudo grep -qE "^[[:space:]]*$key[[:space:]]*=[[:space:]]*$val[[:space:]]*\$" "$FORTIVPN_CONF"; then
        echo "==> Setting openfortivpn $key = $val"
        sudo sed -i -E "s/^[[:space:]]*$key[[:space:]]*=.*/$key = $val/" "$FORTIVPN_CONF"
      fi
    else
      echo "==> Setting openfortivpn $key = $val"
      printf '%s = %s\n' "$key" "$val" | sudo tee -a "$FORTIVPN_CONF" >/dev/null
    fi
  }
  set_fortivpn_key set-dns 0
  set_fortivpn_key pppd-use-peerdns 1
fi

# --- 11. Post-link steps ------------------------------------------------------
# bat will not use the bundled custom theme until its cache is rebuilt.
if command -v bat >/dev/null; then
  echo "==> Rebuilding bat cache"
  bat cache --build >/dev/null
fi

echo
echo "Done. Open a new terminal for zsh to take effect."
echo "See install/SERVICES.md for setup that stow cannot do."
