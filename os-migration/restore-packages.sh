#!/usr/bin/env bash
# Run AFTER installing Omarchy to see which packages from the old inventory the
# fresh install does not already satisfy. Prints a reviewed candidate list; it
# never installs anything.
#
# This does the three-way check the 4.0 migration had to learn the hard way.
# Diffing package *names* is not enough, and each dimension missed something
# real:
#
#   name      - `herdr`, `ufw` and `libsecret` were added to a package list
#               that Omarchy already ships them in.
#   provides  - `ttf-jetbrains-mono-nerd` looked missing, but Omarchy's
#               `-basic` package Provides it, so `-S --needed` silently
#               no-ops and the choice never takes effect.
#   conflicts - `tealdeer` conflicts with Omarchy's `tldr` and aborted an
#               entire 13-package transaction.
#
# Note also that `pacman -Qi` install *reason* cannot tell platform packages
# from your own: Omarchy's installer runs pacman, so its packages also report
# "Explicitly installed". Install timestamps in /var/log/pacman.log are the
# reliable discriminator - anything in the original install window is platform.
set -euo pipefail
cd "$(dirname "$0")"

OMARCHY_LISTS=(/usr/share/omarchy/install/*.packages)

# `pacman -T` is the whole trick: it reports only what is NOT satisfied, and it
# resolves `provides`, so a package already supplied under another name never
# shows up as missing. Plain name diffing cannot do this.
unsatisfied() {
  (($#)) || return 0
  pacman -T "$@" 2>/dev/null || true
}

# Is this name shipped by Omarchy itself? If so it is platform, not yours, and
# it does not belong in your package list even when it looks missing.
from_omarchy() {
  [[ -e ${OMARCHY_LISTS[0]} ]] || return 1
  grep -qxF "$1" "${OMARCHY_LISTS[@]}" 2>/dev/null
}

# Anything installed that this package would force out. Only meaningful for
# repo packages; AUR metadata needs `yay -Si`, which is slower and optional.
conflicts_with_installed() {
  local pkg=$1 c
  for c in $(pacman -Si "$pkg" 2>/dev/null |
    awk -F': ' '/^Conflicts With/{print $2; exit}'); do
    [[ $c == None ]] && continue
    c=${c%%[<>=]*}
    pacman -Qq "$c" &>/dev/null && printf '%s ' "$c"
  done
  # Explicit, because the loop's last test failing is the normal case and
  # would otherwise take the whole script down under `set -e`.
  return 0
}

report() {
  local label=$1 list=$2 pkg conf
  echo "== $label =="
  mapfile -t candidates < <(sort -u "$list")
  mapfile -t missing < <(unsatisfied "${candidates[@]}")

  if ((${#missing[@]} == 0)); then
    echo "  nothing missing - the fresh install already satisfies all of them"
    echo
    return
  fi

  for pkg in "${missing[@]}"; do
    if from_omarchy "$pkg"; then
      # Listed by Omarchy but not installed: a deliberate removal, or an
      # optional entry. Either way it is the platform's to manage, not yours.
      printf '  %-40s SKIP - shipped by Omarchy\n' "$pkg"
      continue
    fi
    conf=$(conflicts_with_installed "$pkg")
    if [[ -n $conf ]]; then
      printf '  %-40s CONFLICTS with installed: %s\n' "$pkg" "$conf"
    else
      printf '  %-40s candidate\n' "$pkg"
    fi
  done
  echo
}

report "Native (repo) packages not satisfied by this install" pkg-native-names.txt
report "AUR packages not satisfied by this install" pkg-aur-names.txt

cat <<'EOF'
Nothing was installed. Review every "candidate" line before acting - the point
of the exercise is curation, not restoring the old package set wholesale. The
4.0 migration started from 164 apparently-missing packages and installed 47.

Anything you do install goes into install/packages.lst with a reason, at the
time you install it, so the repo can still rebuild the machine.
EOF
