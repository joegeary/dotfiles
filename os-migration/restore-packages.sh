#!/usr/bin/env bash
# Run AFTER installing Omarchy v4 to see what packages you had before that the
# fresh install does NOT ship. Compares the old inventory (committed in this
# repo) against the fresh system, then optionally installs the delta.
set -euo pipefail
cd "$(dirname "$0")"

echo "== Native (repo) packages you had that omarchy v4 does NOT install =="
comm -23 <(sort pkg-native-names.txt) <(pacman -Qqen | sort) | tee delta-native-to-install.txt
echo
echo "== AUR packages you had that are not present now =="
comm -23 <(sort pkg-aur-names.txt) <(pacman -Qqem | sort) | tee delta-aur-to-install.txt
echo
echo "Review the two delta-*.txt files above."
echo "To install native delta:   sudo pacman -S --needed - < delta-native-to-install.txt"
echo "To install AUR delta:      yay -S --needed - < delta-aur-to-install.txt"
echo "(Nothing was installed automatically.)"
