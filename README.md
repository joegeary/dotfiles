<h1 align="center">
    <a name="top" title="dotfiles">~/.&nbsp;📄</a><br/><sup><sub>Dotfiles</sub></sup>
</h1>

> [!WARNING]
> If you want to give these dotfiles a try, you should first fork this repository, review the code, and remove things you don’t want or need. Don’t blindly use my settings unless you know what that entails. Use at your own risk!

## Requirements

### System

OS - Arch Linux
Desktop - i3 Window Manager (polybar, rofi, dunst, swaylock, wlogout)
Terminal - Kitty
Shell - zsh w/ starship prompt

### Tools

Configuration is included for:

- btop
- dunst
- i3
- k9s
- kitty
- lazydocker
- lazygit
- neofetch
- neovim
- picom
- polybar
- ranger
- rofi
- starship
- swaylock
- tmux
- wlogout
- zsh

### Additional Tools

These tools are also required in order to use the dotfiles to its full capacity

- fzf
- newsboat
- playerctl
- zoxide

## Installation

First, clone the repository into your $HOME directory using git

```sh
git clone git@github.com/joegeary/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Then use GNU stow to create the symlinks

```sh
stow .
```

## Usage

Make changes in the ~/dotfiles directory and then run `stow .` in order to sync the changes to the home directory. Changes can then be committed to the git repository.
