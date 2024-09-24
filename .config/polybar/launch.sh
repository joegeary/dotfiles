#!/usr/bin/env bash

# Terminate already running bar instances
# If all your bars have ipc enabled, you can use
polybar-msg cmd quit
# Otherwise you can use the nuclear option:
# killall -q polybar

# Launch bar1 and bar2
echo "---" | tee -a /tmp/polybar-top-main.log /tml/polybar-top-right.log
polybar top-main 2>&1 | tee -a /tmp/polybar-top-main.log &
disown
polybar top-right 2>&1 | tee -a /tmp/polybar-top-right.log &
disown

echo "Bars launched..."
