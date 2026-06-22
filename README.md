<h1 align="center">
    <a name="top" title="dotfiles">~/.&nbsp;📄</a><br/><sup><sub>Dotfiles</sub></sup>
</h1>

> [!WARNING]
> If you want to give these dotfiles a try, you should first fork this repository, review the code, and remove things you don’t want or need. Don’t blindly use my settings unless you know what that entails. Use at your own risk!

```mint
      ⠀⠀   🌸 System 🌸
 -----------------------------------

 ╭─ Distro  -> Arch Linux 
 ├─ Editor  -> NeoVim + VS Code
 ├─ Browser -> Firefox
 ├─ Shell   -> ZSH
 ├─ File Explorer -> Yazi
 ├─ Music Player -> Spotify
 ╰─ Resource Monitor -> Bpytop

 ╭─ Terminal -> Kitty
 ├─ Prompt   -> Starship
 ├─ Theme    -> Catppuccin-Macchiato
 ├─ Icons    -> Colloid-teal-dark 
 ├─ Font     -> JetBrainsMono Nerd Font
 ╰─ Hotel    -> Trivago

 ╭─ WM              -> Hyprland
 ├─ Shell           -> Noctalia (bar, notifications, launcher, OSD, wallpaper, lock screen, session menu)
 ╰─ Display Manager -> SDDM

                        
```

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
