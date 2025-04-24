#!/bin/bash
#
# Script Name: zoom_hue_monitor.sh
# Description: Monitors for active Zoom meetings in Hyprland and controls a
#              Philips Hue light to indicate "On-Air" status using openhue-cli.
#              Intended for use with waybar (run every ~5 seconds).
# Requirements: bash, hyprctl, openhue-cli, jq
# Environment: ONAIR_HUE_LIGHT_ID=<your_hue_light_guid>

ONAIR_HUE_LIGHT_ID="6219820b-8c9d-4729-8547-474717c340c3"

# --- Configuration ---
# Ensure the Hue Light ID environment variable is set
if [[ -z "$ONAIR_HUE_LIGHT_ID" ]]; then
  echo "{\"text\":\"󰊻\", \"tooltip\":\"Set the ONAIR_HUE_LIGHT_ID environment variable\", \"class\":\"error\"}"
  exit 1
fi

# Check for required commands
for cmd in hyprctl openhue jq; do
  if ! command -v $cmd &>/dev/null; then
    echo "{\"text\":\"󰊻\", \"tooltip\":\"Please install $cmd\", \"class\":\"error\"}"
    exit 1
  fi
done

# Temporary files for state management
# Using /dev/shm (tmpfs) for potentially faster access if available
STATE_DIR="~/.local/state"
if [ ! -d "$STATE_DIR" ] || [ ! -w "$STATE_DIR" ]; then
  STATE_DIR="/tmp" # Fallback to /tmp if /dev/shm isn't usable
fi
STATUS_FILE="${STATE_DIR}/onair_status_${ONAIR_HUE_LIGHT_ID}.flag"
STATE_FILE="${STATE_DIR}/onair_state_${ONAIR_HUE_LIGHT_ID}.json"

# On-Air settings
ON_AIR_COLOR_X=0.54 # Red
ON_AIR_COLOR_Y=0.32
ON_AIR_BRIGHTNESS=100 # Full brightness

# --- Helper Functions ---

# Check if a Zoom meeting is active by looking for windows with class "zoom"
# Returns 0 if active, 1 otherwise
is_meeting_active() {
  hyprctl clients -j | jq -e '.[] | select(.class=="zoom" and .title=="Meeting")' &>/dev/null
  return $?
}

# Get the current state of the light as JSON
# Returns 0 on success, 1 on failure
get_light_state() {
  openhue get light "$ONAIR_HUE_LIGHT_ID" --json
  return $?
}

# Save the current light state to the state file
# Returns 0 on success, 1 on failure
save_light_state() {
  local state_json
  state_json=$(get_light_state)
  local exit_code=$?
  if [[ $exit_code -ne 0 || -z "$state_json" ]]; then
    echo "Error: Failed to get light state for $ONAIR_HUE_LIGHT_ID." >&2
    return 1 # Indicate failure
  fi
  # Validate JSON before saving
  if ! echo "$state_json" | jq -e . >/dev/null; then
    echo "Error: Invalid JSON received from openhue." >&2
    return 1
  fi
  echo "$state_json" >"$STATE_FILE"
  return 0 # Indicate success
}

# Set the light to "On-Air" mode
# Returns 0 on success, 1 on failure
set_on_air_mode() {
  echo "Setting light $ONAIR_HUE_LIGHT_ID to On-Air mode (Color: ${ON_AIR_COLOR}, Brightness: ${ON_AIR_BRIGHTNESS})." >&2 # Log to stderr
  openhue set light "$ONAIR_HUE_LIGHT_ID" --on -x "$ON_AIR_COLOR_X" -y "$ON_AIR_COLOR_Y" --brightness "$ON_AIR_BRIGHTNESS"
  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    touch "$STATUS_FILE" # Mark as active
    return 0
  else
    echo "Error: Failed to set light $ONAIR_HUE_LIGHT_ID to On-Air mode." >&2
    return 1
  fi
}

# Restore the light's previous state from the state file
# Returns 0 on success, 1 on failure
restore_previous_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: Cannot restore state, state file $STATE_FILE not found." >&2
    # Fallback: Try to turn the light off
    echo "Attempting to turn off light $ONAIR_HUE_LIGHT_ID as a fallback." >&2
    openhue set light "$ONAIR_HUE_LIGHT_ID" --off
    rm -f "$STATUS_FILE" # Clear status anyway
    return 1
  fi

  local state_json
  state_json=$(cat "$STATE_FILE")

  # Extract values using jq, providing defaults/null if keys don't exist
  local was_on=$(echo "$state_json" | jq -r '.HueData.on.on // "false"')
  local brightness=$(echo "$state_json" | jq -r '.HueData.dimming.brightness // 100')
  local color_x=$(echo "$state_json" | jq -r '.HueData.color.xy.x // ""')
  local color_y=$(echo "$state_json" | jq -r '.HueData.color.xy.y // ""')
  local color_gamut_type=$(echo "$state_json" | jq -r '.HueData.color.gamut_type // ""') # Check if color is supported

  local restore_cmd_args=("$ONAIR_HUE_LIGHT_ID")

  if [[ "$was_on" == "true" ]]; then
    restore_cmd_args+=(--on --brightness "$brightness")
    # Only add color if the light supports color (has gamut and xy)
    if [[ -n "$color_x" && -n "$color_y" && -n "$color_gamut_type" && "$color_gamut_type" != "null" ]]; then
      restore_cmd_args+=(-x "${color_x}")
      restore_cmd_args+=(-y "${color_y}")
    fi
  else
    restore_cmd_args+=(--off)
  fi

  # Execute the restore command using array to handle arguments safely
  echo "Restoring previous state for light $ONAIR_HUE_LIGHT_ID. with args ${restore_cmd_args[@]}" >&2 # Log to stderr
  openhue set light "${restore_cmd_args[@]}"
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    rm -f "$STATUS_FILE" # Mark as inactive
    rm -f "$STATE_FILE"  # Clean up state file
    return 0
  else
    echo "Error: Failed to restore previous state for light $ONAIR_HUE_LIGHT_ID." >&2
    # Don't remove status/state files on failure, might retry next time
    return 1
  fi
}

# --- Main Execution Flow ---

output_json="" # Variable to hold JSON output for waybar

if is_meeting_active; then
  # --- Meeting is Active ---
  if [[ ! -f "$STATUS_FILE" ]]; then
    # "On-Air" mode is not active, need to activate it
    echo "Zoom meeting detected. Activating On-Air mode." >&2
    if save_light_state; then # Try to save current state first
      if set_on_air_mode; then
        output_json="{\"text\":\"󰊻\", \"tooltip\":\"Zoom meeting in progress - Light set to Red\", \"class\":\"on-air\"}"
      else
        output_json="{\"text\":\"󰊻\", \"tooltip\":\"Zoom meeting detected but failed to set light\", \"class\":\"error\"}"
      fi
    else
      echo "Could not save light state. Aborting On-Air activation." >&2
      output_json="{\"text\":\"󰊻\", \"tooltip\":\"Zoom meeting detected but failed to save light state\", \"class\":\"error\"}"
      # Optional: Exit with error code? For waybar, just showing error text might be better.
      # exit 1
    fi
  else
    # Already in "On-Air" mode, just report status
    output_json="{\"text\":\"󰊻\", \"tooltip\":\"Zoom meeting in progress\", \"class\":\"on-air\"}"
  fi
else
  # --- No Meeting is Active ---
  if [[ -f "$STATUS_FILE" ]]; then
    # "On-Air" mode is active, need to deactivate it and restore state
    echo "Zoom meeting ended. Deactivating On-Air mode and restoring state." >&2
    if restore_previous_state; then
      output_json="{\"text\":\"󰊻\", \"tooltip\":\"No Zoom meeting detected - Light restored\", \"class\":\"\"}"
    else
      # Restoration failed, keep showing "ON AIR" but with error indication
      output_json="{\"text\":\"󰊻\", \"tooltip\":\"Zoom meeting ended but failed to restore light state\", \"class\":\"error\"}"
    fi
  else
    # Not in a meeting and "On-Air" mode is not active, normal state
    output_json="{\"text\":\"󰊻\", \"tooltip\":\"No Zoom meeting detected\", \"class\":\"\"}"
  fi
fi

# --- Output for Waybar ---
echo "$output_json"

# --- Cleanup ---
# Lock is released automatically when fd 9 is closed upon script exit.
exit 0
