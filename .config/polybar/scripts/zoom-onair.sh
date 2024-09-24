#!/bin/bash
#
# This script will change the Hue lights to red when on a Zoom meeting
#
# To configure this script, you need to create a "zoom-onair.config" file and export the following variables:
# ONAIR_HUE_API_IP    - IP address of your Hue hub accessible by the computer running this script
# ONAIR_HUE_API_USER  - Access token generated in the Hue application
# ONAIR_HUE_LIGHT_ID  - ID of the light or group that will be toggled red

source ~/.config/polybar/scripts/zoom-onair.config

ZOOM_WINDOW_TITLE="^Meeting$"
STATE_FILE="/tmp/onair_state.json"

set_onair() {
  hueadm -H $ONAIR_HUE_API_IP -U $ONAIR_HUE_API_USER light -j $ONAIR_HUE_LIGHT_ID >$STATE_FILE
  sleep 1
  echo '{"on":true, "bri": 200, "hue": 65309, "sat": 200 }' | hueadm -H $ONAIR_HUE_API_IP -U $ONAIR_HUE_API_USER light $ONAIR_HUE_LIGHT_ID -
  # toggle-headset --hsp
}

set_offair() {
  jq '{ on: .state.on, bri: .state.bri, hue: .state.hue, sat: .state.sat }' $STATE_FILE | hueadm -H $ONAIR_HUE_API_IP -U $ONAIR_HUE_API_USER light $ONAIR_HUE_LIGHT_ID -
  rm $STATE_FILE
  # toggle-headset --a2dp
}

start_meeting() {
  xdg-open "zoommtg://zoom.us/join?action=join&confno=6252930119&pwd=RlRxT1J4bEkzbmVlNXhBZ1h0QlVLQT09"
}

check() {
  if [ "$(xdotool search --name $ZOOM_WINDOW_TITLE)" ]; then
    if [ ! -e $STATE_FILE ]; then
      set_onair
    fi
    echo "Zoom %{F#ff0000} ON-AIR"
  else
    if [ -e $STATE_FILE ]; then
      set_offair
    fi
    echo "Zoom"
  fi
}

if ! command -v hueadm &>/dev/null; then
  echo "Error: hueadm not found - install as a global tool from npm"
  exit 1
fi

if [ -z "$ONAIR_HUE_API_IP" ] || [ -z "$ONAIR_HUE_API_USER" ] || [ -z "$ONAIR_HUE_LIGHT_ID" ]; then
  echo "Error: environment variables are not set"
  exit 1
fi

case "$1" in
on)
  set_onair
  ;;
off)
  set_offair
  ;;
reset)
  rm $STATE_FILE
  ;;
start)
  start_meeting
  ;;
check)
  check
  ;;
*)
  echo "Usage: $0 [options]$"
  echo "Options:"
  echo "    on        Sets lights to on-air mode"
  echo "    off       Restores lights back to original state"
  echo "    reset     Removes the state file"
  echo "    start     Starts a Zoom meeting"
  echo "    check     Checks for a running meeting and toggles on-air mode"
  exit 0
  ;;
esac
