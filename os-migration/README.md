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
| `restore-packages.sh` | after install | Reports which of your old packages the fresh install does not already satisfy, checking name, `provides` and `conflicts`. Prints candidates; installs nothing. |

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
| `config-dirs-NOT-in-dotfiles.txt` | `~/.config` dirs your dotfiles don't track |

`crontab.txt` was captured but came back empty, so it is not committed - all
scheduling was already systemd timers. Check `systemctl --user list-timers`
instead of looking for a crontab.

## Order of operations

### Before wipe
1. `git -C ~/dotfiles push` - puts this inventory + all dotfiles on GitHub.
2. Plug in external drive (400G+ free).
3. `./backup-everything.sh /run/media/joe/YOUR_DRIVE` - full system copy (~1-3 hrs).

### After Omarchy install
1. `git clone https://github.com/joegeary/dotfiles.git ~/dotfiles` then
   `~/dotfiles/install/install.sh`. It installs `stow` and `omarchy-zsh` itself
   in its first step, so there is no bootstrap order to get right.
2. `./restore-packages.sh` - prints candidates the fresh install does not
   already satisfy.
3. **Review every candidate and install them a few at a time.** Do not bulk
   install the delta; that is what produces a bloated machine. The 4.0
   migration started from 164 apparently-missing packages and installed 47.
   Each one you keep goes into `install/packages.lst` with a reason, at the
   time you install it.
4. Re-enable services from `services-*-enabled.txt` (skip ones Omarchy owns),
   then work through `install/SERVICES.md` for what symlinks cannot express.
5. Restore anything else you need by copying it out of the full backup:
   secrets (`.ssh`, `.gnupg`, `.local/share/keyrings`, `.local/state/syncthing`),
   documents, project repos, app state. It's all in the backup - grab as needed.
   **Restore to the original path.** Do not reorganise on the way in, and do not
   bring an app back just because its data is in the backup.

## What the 4.0 migration learned

Worth reading before the next one - each of these cost real time.

- **Curate, don't restore.** 164 packages looked missing; 47 were actually
  wanted. Most of the rest was the old desktop stack that Omarchy now provides,
  the old machine's boot/hardware drivers, or toolchains `mise` supplies.
- **Three-way package check, always: name, `provides`, `conflicts`.** Each
  dimension caught a different mistake, and `restore-packages.sh` now does all
  three. Name alone had packages listed that Omarchy already ships.
- **`pacman -Qi` install reason cannot identify platform packages.** Omarchy's
  installer runs pacman, so its packages also read "Explicitly installed" with
  "Required By: None". Use install timestamps in `/var/log/pacman.log`; anything
  from the original install window is platform.
- **Layer on Omarchy's config files, never fork them.** Where Omarchy owns a
  file it keeps updating (`~/.zshrc`, `~/.config/git/config`,
  `~/.config/ghostty/config`), leave it unmanaged and append a one-line include
  pointing at a stowed override, with `install.sh` re-adding it. Files that are
  byte-identical to stock should stay unmanaged entirely.
- **Check what the compositor actually computed** before tuning display scaling.
  `GDK_SCALE` and a monitor `scale` can both be in play, and a per-monitor
  `hl.monitor` entry silently overrides the catch-all one above it - read
  `hyprctl monitors`, don't infer from the config.
- **A locked keyring collection reports zero items**, which reads exactly like
  an empty one. Unlock before concluding anything is missing.

## Notes on the backup
- `-aAXH` preserves permissions, ACLs, xattrs, and hardlinks - a faithful copy.
- It's a plain browsable folder. Restore = copy files back out. No image to mount.
- Don't restore `/etc` wholesale onto v4 (it's OS-owned) - cherry-pick your own
  edits from the backup's `etc/` if you need them (fstab, VPN configs, etc.).
