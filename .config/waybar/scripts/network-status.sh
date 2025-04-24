#!/bin/bash

if nmcli con show 'OnCourse' | grep 'activated' &>/dev/null; then
  echo '{"text": "󰒄", "tooltip": "Connected to OnCourse VPN", "class":"vpn"}'
else
  echo '{"text": "󰛳", "tooltip": ""}'
fi
