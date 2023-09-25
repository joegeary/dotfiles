<h1 align="center">
    <a name="top" title="dotfiles">~/.&nbsp;📄</a><br/>Cross-platform, cross-shell dotfiles<br/> <sup><sub>powered by  <a href="https://www.chezmoi.io/">chezmoi</a> 🏠</sub></sup>
</h1>

Universal command set and colorful shell configurations for Bash, Zsh and Powershell, compatible with Linux, Windows and MacOS, all managed easily using [chezmoi](https://github.com/twpayne/chezmoi).


## Getting started

You can install chezmoi and the dotfiles on a new, empty machine with a single command:

```bash
# curl
$ sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply joegeary

# wget
sh -c "$(wget -qO- get.chezmoi.io)" -- init --apply joegeary
```

As well as the `curl | sh` installation, you can [install chezmoi with your favorite package manager.](https://www.chezmoi.io/install/)

Update your dotfiles by running:

```bash
$ chezmoi update
```