# Read by every zsh invocation, including non-interactive ones that skip
# .zshrc (editor tasks, scripts, anything spawning `zsh -c`). omarchy-zsh only
# activates mise in interactive shells, so without this a non-interactive
# launch falls back to the SDK-less /usr/share/dotnet.
export PATH="$HOME/.local/share/mise/shims:$PATH"
