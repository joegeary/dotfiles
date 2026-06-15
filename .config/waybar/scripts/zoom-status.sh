#!/bin/bash
#
# Script Name: zoom_hue_monitor.sh
# Description: Monitors for active Zoom meetings in Hyprland and controls a
#              Philips Hue light to indicate "On-Air" status using openhue-cli.
#              Intended for use with waybar (run every ~5 seconds).
# Requirements: bash, hyprctl, openhue-cli, jq
# Environment: ONAIR_HUE_LIGHT_ID=<your_hue_light_guid>

# Check if a screenshare is active using pipewire
# Returns 0 if active, 1 otherwise
is_meeting_active() {
  # Check PipeWire for active screen capture streams from xdg-desktop-portal
  pw-dump | jq -e '
        .[] |
        select(.type == "PipeWire:Interface:Node") |
        select(.info.props."media.class" == "Video/Source") |
        select(.info.props."node.name" // "" | test("portal"))
    ' >/dev/null 2>&1

  return $?
}

if is_meeting_active; then
  echo "{\"text\":\"󰊻\", \"tooltip\":\"Screenshare in progress\", \"class\":\"on-air\"}"
else
  echo "{\"text\":\"󰊻\", \"tooltip\":\"No screenshare detected\", \"class\":\"\"}"
fi

# --- Cleanup ---
# Lock is released automatically when fd 9 is closed upon script exit.
exit 0
