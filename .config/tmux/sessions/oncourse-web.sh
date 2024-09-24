#!/bin/bash

session="oncourse-web"

if ! tmux has-session -t "$session" >/dev/null 2>&1; then
	path="$HOME/work/oncourse-web/"
	tmux new-session -d -s "$session" -c "$path" -n nvim "nvim"
	tmux new-window -c "$path" -n "shell" zsh
	tmux new-window -c "$path" -n "git" "lazygit"
	tmux select-window -t 1
fi

tmux attach-session -t "$session"
