#!/usr/bin/env bash

rofi \
	-modi "emoji:rofimoji --action copy --clipboarder xclip" \
	-show emoji \
	-config "$HOME/.config/rofi/emoji/style.rasi"
