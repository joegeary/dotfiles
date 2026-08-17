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

# --- Shell integrations not shipped by omarchy-zsh ---
# omarchy-zsh already initializes fzf, zoxide, starship and mise. It does not
# initialize these, and each one has restored state that does nothing without
# its hook, so leaving them out quietly wastes the restore.
#
# kubectl deliberately has no line here: /usr/share/zsh/site-functions/_kubectl
# is already on fpath, so `source <(kubectl completion zsh)` would cost ~56ms
# at every startup to duplicate what the completion system has for free.

# atuin takes over Ctrl-R and Up, replacing omarchy-zsh's fzf-history-widget.
# That override is the point: it is what the 16,660-command history and the
# vim-insert keymap in atuin's config are for. It also exports $ATUIN_SESSION,
# without which `atuin search` errors out. Works because this file is sourced
# from the end of ~/.zshrc, after omarchy-zsh has bound its own widgets.
command -v atuin >/dev/null && eval "$(atuin init zsh)"

# Per-directory env; the 13 restored entries in ~/.local/share/direnv/allow
# are inert without this.
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# worktrunk, for the per-project worktree templates in ~/.config/worktrunk.
command -v wt >/dev/null && eval "$(command wt config shell init zsh)"

# thefuck costs ~105ms to initialize, about as much as the whole rest of the
# shell, so it is loaded on first use rather than at every startup.
if command -v thefuck >/dev/null; then
  fuck() {
    unfunction fuck
    eval "$(thefuck --alias)"
    eval fuck "$@"
  }
fi

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

# repo - fuzzy-pick a git repo under ~/dev, enter it, fetch, and show its stats.
# Both of these need onefetch (git repo stats; complementary to fastfetch's
# machine stats), which is in install/packages.lst. Defined only when it is
# present, so a machine without it gets no half-working command.
if command -v onefetch >/dev/null; then
  # fastfetch outside a repo, onefetch inside one.
  show_fetch() {
    if [[ -d .git ]]; then onefetch; else fastfetch; fi
  }

  repo() {
    # --prune stops fd descending into a repo once its .git is found; the awk
    # drops any path under an already-seen repo, so nested checkouts and
    # worktrees do not each show up as separate entries.
    local selected=$(fd '^\.git$' "${HOME}/dev" --type=directory --type=file --hidden --prune 2>/dev/null \
      | sed "s|/\.git/\?$||" \
      | sort \
      | awk '{
          for (p in seen) if (index($0, p "/") == 1) next
          seen[$0] = 1
          print
        }' \
      | sed "s|^${HOME}/dev/||" \
      | fzf --preview "onefetch ${HOME}/dev/{}" --preview-window up)

    [[ -z "$selected" ]] && { echo "Repository not found"; return 1; }

    cd "${HOME}/dev/$selected" || return 1
    if [[ -d .git ]]; then
      echo "Fetching origin"
      git fetch origin
      onefetch
    fi
  }
fi
