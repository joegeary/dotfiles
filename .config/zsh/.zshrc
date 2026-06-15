source ~/.config/zsh/general
source ~/.config/zsh/env
source ~/.config/zsh/plugins
source ~/.config/zsh/completion
source ~/.config/zsh/aliases
source ~/.config/zsh/keybindings
source ~/.config/zsh/functions

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"
eval "$(starship init zsh)"
eval "$(direnv hook zsh)"
source <(kubectl completion zsh)
eval "$(atuin init zsh)"
eval "$(mise activate zsh)"
# fnm (Node) — placed after mise so it wins PATH for `node`; --use-on-cd
# auto-switches per directory via .node-version/.nvmrc/package.json engines.
eval "$(fnm env --use-on-cd --shell zsh)"
if command -v thefuck &> /dev/null; then
  eval "$(thefuck --alias)" 
fi

show_fetch

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
