#!/usr/bin/env bash

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

# Lock the screen then suspend
hyprlock &
disown && systemctl suspend
