# dotfiles

Personal configuration for [Omarchy](https://omarchy.org) machines, managed with
[GNU stow](https://www.gnu.org/software/stow/).

Rebuilt from scratch on Omarchy 4.0. The pre-Omarchy-4 history (Hyprland +
Noctalia + a much larger config surface) is preserved on the
`archive/pre-omarchy4` branch.

## Philosophy

Omarchy already ships a curated desktop, shell, editor, and terminal stack. This
repo holds **only the delta** on top of that — never a fork of what Omarchy
provides. Concretely:

- Hyprland: only the override files Omarchy sources, never the base config.
- zsh: `omarchy-zsh` owns `~/.zshrc`; our customizations live in
  `~/.config/zsh/local.zsh`, sourced by a one-line hook.
- Neovim: stock Omarchy LazyVim, unmodified.
- Anything Omarchy installs by default is not listed in `packages.lst`.

Everything installed on the machine is recorded in `install/packages.lst` (with a
reason) or `install/SERVICES.md`, so the repo alone is enough to rebuild a box.

## Install

```sh
git clone https://github.com/joegeary/dotfiles.git ~/dotfiles
~/dotfiles/install/install.sh
```

The script installs packages, sets up zsh, and creates all symlinks. Then read
[install/SERVICES.md](install/SERVICES.md) for the setup that symlinks cannot
express (Tailscale, Syncthing, DDNS, printing).

## Layout

| Path | Purpose |
|------|---------|
| `home/` | stow package symlinked into `~` — shared by every machine |
| `hosts/<hostname>/` | per-machine stow package (monitor layout, etc.) |
| `install/` | bootstrap script, package list, service runbook |
| `os-migration/` | inventory + scripts from the pre-Omarchy-4 migration |

## Usage

```sh
stow -d ~/dotfiles -t ~ home            # shared config
stow -d ~/dotfiles/hosts -t ~ "$(hostname)"   # this machine's config

stow -D -d ~/dotfiles -t ~ home         # unstow
```

Adding a new machine means creating `hosts/<hostname>/` and stowing it. Stow
packages must be direct children of the stow dir, hence the `-d hosts` form.

> [!WARNING]
> This repo is public and contains no secrets. Credentials, keys, tokens, and
> internal hostnames are deliberately kept out of it and restored by hand.
