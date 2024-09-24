#!/bin/bash

function getStatus() {
	# Check if Bluetooth is powered on
	if ! bluetoothctl show | grep -q "Powered: yes"; then
		echo "%{F#66ffffff}"
	else
		# Check if any Bluetooth device is connected
		if bluetoothctl info | grep -q 'Connected: yes'; then
			DEVICE=$(bluetoothctl info | awk -F': ' '/Alias:/ { print $2 }')
			echo "%{F#2193ff} $DEVICE "
		else
			echo ""
		fi
	fi
}

function togglePower() {
	# Check if Bluetooth is powered on
	if [ $(bluetoothctl show | grep "Powered: yes" | wc -c) -eq 0 ]; then
		bluetoothctl power on
	else
		bluetoothctl power off
	fi
}

case "$1" in
toggle)
	togglePower
	;;
*)
	getStatus
	;;
esac
