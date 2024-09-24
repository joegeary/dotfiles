source ~/.config/zsh/general
source ~/.config/zsh/plugins
source ~/.config/zsh/completion
source ~/.config/zsh/aliases
source ~/.config/zsh/env
source ~/.config/zsh/keybindings

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"
eval "$(starship init zsh)"
eval "$(direnv hook zsh)"
source <(kubectl completion zsh)
eval "$(atuin init zsh)"
eval "$(gh copilot alias -- zsh)"
if command -v thefuck &> /dev/null; then 
  eval "$(thefuck --alias)" 
fi

neofetch
