#!/usr/bin/env bash

rofi \
	-modi "clipboard:greenclip print" \
	-show clipboard \
	-run-command '{cmd}' \
	-config "$HOME/.config/rofi/clipboard/style.rasi"
