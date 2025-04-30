#!/usr/bin/env bash

config="$HOME/.config/rofi/power-menu.rasi"

actions=$(echo -e "  Lock\n  Shutdown\n  Reboot\n  Suspend\n  Hibernate\n󰞘  Logout")

# Display logout menu
selected_option=$(echo -e "$actions" | rofi -dmenu -i -config "${config}" || pkill -x rofi)

pause_players() {
  # Get a list of controllable players
  # Use process substitution and readarray to handle player names with spaces
  readarray -t players < <(playerctl -l 2>/dev/null)

  # Check if any players were found
  if [ ${#players[@]} -eq 0 ]; then
    return
  fi

  # Loop through each player found
  for player_name in "${players[@]}"; do
    # Get the status of the specific player
    # Use || true to prevent script exit if player disappears between listing and status check
    status=$(playerctl -p "$player_name" status 2>/dev/null || echo "Error")

    if [ "$status" == "Playing" ]; then
      playerctl -p "$player_name" pause
    fi
  done
}

# Perform actions based on the selected option
case "$selected_option" in
*Lock)
  hyprlock
  ;;
*Shutdown)
  systemctl poweroff
  ;;
*Reboot)
  systemctl reboot
  ;;
*Suspend)
  pause_players
  hyprlock &
  disown && systemctl suspend
  ;;
*Hibernate)
  systemctl hibernate
  ;;
*Logout)
  hyprctl dispatch exit
  ;;
esac
