#!/bin/bash

session="devops"

if ! tmux has-session -t "$session" >/dev/null 2>&1; then
	path="$HOME/work/devops/"
	tmux new-session -d -s "$session" -c "$path" -n nvim "nvim"
	tmux new-window -c "$path" -n "shell" zsh
	tmux new-window -c "$path" -n "git" "lazygit"
	tmux select-window -t 1
fi

tmux attach-session -t "$session"
