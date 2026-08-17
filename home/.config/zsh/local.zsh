# Personal zsh customizations, sourced from the end of ~/.zshrc.
#
# omarchy-zsh owns ~/.zshrc and already provides history, the completion
# system, fzf widgets, syntax highlighting, starship, mise and zoxide.
# Only add things here that Omarchy does not already do.

# --- Environment ---
export PAGER=less
export LESS="-R -M -i -j5"
export SPROMPT="zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]?"
export WORDCHARS=${WORDCHARS//[\/]/}    # treat / as a word separator
export GPG_TTY=$(tty)                   # required for gpg commit signing
export PATH="$HOME/.dotnet/tools:$PATH"

# Machine-local vars and secrets. Never committed; restored by hand.
[[ -f ~/.zprofile ]] && source ~/.zprofile

# --- Plugins not shipped by omarchy-zsh ---
# Grey inline suggestion from history as you type.
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# --- Keybindings (Omarchy binds the arrows; these cover Home/End/Delete) ---
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[[3~" delete-char

# --- Aliases ---
alias l='eza -l  --icons --color --classify=auto'
alias ll='eza -la --icons --classify=auto'
alias ld='eza -lD --icons --classify=auto'

alias diff='diff --color=auto'
alias grep='grep --color=auto'
alias chmod='chmod --preserve-root -v'
alias chown='chown --preserve-root -v'

alias c='clear'          # overrides omarchy-zsh's c=opencode
alias ka='killall'
alias k='kubectl'

alias cc='claude'
alias ccc='claude --continue'
alias ccd='claude --dangerously-skip-permissions'
alias ccr='claude --resume'

# --- Functions ---
# Function to kill a process via a fzf menu
function pkill() {
  ps aux |
  fzf --height 40% \
      --layout=reverse \
      --header-lines=1 \
      --prompt="Select process to kill: " \
      --preview 'echo {}' \
      --preview-window up:3:hidden:wrap \
      --bind 'F2:toggle-preview' |
  awk '{print $2}' |
  xargs -r bash -c '
    if ! kill "$1" 2>/dev/null; then
      echo "Regular kill failed, attempting with sudo..."
      sudo kill "$1" || echo "Failed to kill process $1" >&2
    fi
  ' --
}

# cpr - create a git worktree for a pull request
# Usage: cpr <PR_NUMBER> [<REMOTE>]
# Example: cpr 1234 origin
# If no remote is specified, it defaults to 'origin'.
# Note: This command fetches the branch associated with the PR and creates a worktree in the current directory.
# The worktree will be named after the branch.
# Ensure you have the GitHub CLI installed and authenticated with `gh auth login`.
cpr() {
  pr="$1"
  remote="${2:-origin}"
  branch=$(gh pr view "$pr" --json headRefName -q .headRefName)
  git fetch "$remote" "$branch"
  git worktree add "../$branch" "$branch"
  cd "../$branch" || return
  echo "Switched to new worktree for PR #$pr: $branch"
}
