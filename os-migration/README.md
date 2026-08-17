# Omarchy v4 (Quattro) Migration Runbook

Captured 2026-08-14 from the current Arch/Omarchy install before wiping for
[Omarchy v4.0.0](https://github.com/basecamp/omarchy/releases/tag/v4.0.0).

## The plan in one sentence
Copy the **whole system** to an external drive before the wipe, then after
installing v4 use the package inventory here to auto-figure out what to reinstall.

## Two scripts

| Script | When | What |
|--------|------|------|
| `backup-everything.sh DEST` | before wipe | Copies the entire filesystem (/, /home, /etc, everything) to DEST. Nothing selective - if you ever need a file, it's in here. |
| `restore-packages.sh` | after install | Diffs your old package list against fresh v4, prints exactly what to reinstall. |

Whole system is ~357G. **Backup drive needs ~400G+ free.**

## Inventory files (committed to git, survive the wipe)
| File | Purpose |
|------|---------|
| `pkg-explicit-all.txt` | Every explicitly-installed package + version |
| `pkg-native-names.txt` | Repo package names (225) - for diffing |
| `pkg-aur-names.txt` | Explicit AUR package names (26) |
| `pkg-aur-versioned.txt` | All 60 foreign pkgs incl. AUR deps (reference) |
| `services-system-enabled.txt` | Enabled system systemd units (26) |
| `services-user-enabled.txt` | Enabled user systemd units |
| `crontab.txt` | User crontab |
| `config-dirs-NOT-in-dotfiles.txt` | `~/.config` dirs your dotfiles don't track |

## Order of operations

### Before wipe
1. `git -C ~/dotfiles push` - puts this inventory + all dotfiles on GitHub.
2. Plug in external drive (400G+ free).
3. `./backup-everything.sh /run/media/joe/YOUR_DRIVE` - full system copy (~1-3 hrs).

### After Omarchy v4 install
1. Clone dotfiles, apply them (however your repo bootstraps - stow/symlink).
2. `./restore-packages.sh` - prints which of your old packages v4 doesn't ship.
3. Install the delta:
   `sudo pacman -S --needed - < delta-native-to-install.txt`
   `yay -S --needed - < delta-aur-to-install.txt`
4. Re-enable services from `services-*-enabled.txt` (skip ones v4 already owns).
5. Restore anything else you need by copying it out of the full backup:
   secrets (`.ssh`, `.gnupg`, `.config/sops`, `.local/share/keyrings`),
   documents, project repos, app state. It's all in the backup - grab as needed.

## Notes on the backup
- `-aAXH` preserves permissions, ACLs, xattrs, and hardlinks - a faithful copy.
- It's a plain browsable folder. Restore = copy files back out. No image to mount.
- Don't restore `/etc` wholesale onto v4 (it's OS-owned) - cherry-pick your own
  edits from the backup's `etc/` if you need them (fstab, VPN configs, etc.).
