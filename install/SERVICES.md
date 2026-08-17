# Service Setup

Post-install setup for services that are not just config files, and so cannot be
handled by `stow` alone. See [INSTALL_ARCH.md](INSTALL_ARCH.md) for the base OS install.

> [!IMPORTANT]
> Device IDs, tailnet addresses and hostnames in this document are placeholders.
> Substitute your own. Nothing here should ever be committed with real values.

## Contents

- [Tailscale](#tailscale)
- [Obsidian vault sync (Syncthing)](#obsidian-vault-sync-syncthing)
- [GNOME keyring auto-unlock](#gnome-keyring-auto-unlock)
- [Dynamic DNS](#dynamic-dns)
- [Omarchy shell plugins](#omarchy-shell-plugins)
- [Inbound SSH](#inbound-ssh)
- [Herdr](#herdr)
- [AI agent instructions](#ai-agent-instructions)

## Tailscale

Provides stable addressing between machines regardless of network, which
everything else here depends on. Package is in [packages.lst](packages.lst).

```sh
sudo systemctl enable --now tailscaled
sudo tailscale up
```

Verify all devices are visible and prefer direct connections over relays:

```sh
tailscale status          # "direct" is good, "relay" means DERP fallback
tailscale ping <device>   # confirms the path
```

Tailnet policy (ACLs, MagicDNS, exit nodes) is managed in the admin console, not
in this repo.

## Obsidian vault sync (Syncthing)

Syncs an Obsidian vault between two Linux machines and an Android phone, peer to
peer over the tailnet, with no server component and no third party hosting.

### Why this approach

The vault was previously synced with the obsidian-git plugin, which cannot sync
from Android. Alternatives considered and rejected:

| Option | Why not |
|--------|---------|
| Obsidian Sync (paid) | Notes stored on Obsidian's infrastructure |
| CouchDB + Self-hosted LiveSync | Requires an always-on host. The desktop is not always on, so the phone and laptop could not reconcile with each other while it slept |
| Same, exposed via Cloudflare Tunnel | Cloudflare terminates TLS, so it can read note content in transit. Tailscale already solves ingress without a third party |
| WebDAV or S3 + remotely-save plugin | Same always-on host problem, on a less maintained plugin |
| git in Termux on Android | Android shared storage corrupts git objects without workarounds, and resolving conflicts from a phone shell is unpleasant |

Syncthing wins on the deciding constraint: it is a true mesh, so any two devices
that are both awake converge directly, with no hub to wait on.

### Architecture

```
  desktop  <---->  laptop
      \             /          all links direct over the tailnet
       \           /           (WireGuard, no relays, no discovery servers)
        \         /
          phone
```

Two independent layers, deliberately kept from touching each other:

- **Syncthing** replicates the vault's working tree to every device.
- **git** (obsidian-git plugin) keeps commit history, on the desktop only.
  Syncthing is told to ignore `.git`, so the repo never replicates and there is
  only ever one git writer.

### Linux setup (both machines)

Install `syncthing` (in [packages.lst](packages.lst)), then:

```sh
systemctl --user enable --now syncthing.service
```

Lock it down so traffic stays on the tailnet. Local discovery stays on so
machines on the same LAN connect directly:

```sh
syncthing cli config options global-ann-enabled set false   # no discovery servers
syncthing cli config options relays-enabled set false       # no relay fallback
syncthing cli config options natenabled set false           # no port mapping
syncthing cli config options uraccepted set -- -1           # decline usage reporting
```

Add the vault folder. The folder ID must match on every device, it is what links
the shares together:

```sh
syncthing cli config folders add \
  --id secondbrain --label "Second Brain" --path ~/notes/secondbrain
```

Add each peer, pinning its tailnet address so connections cannot take another
path. Keep `dynamic` first so LAN discovery still works:

```sh
syncthing cli config devices add \
  --device-id AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH \
  --name <peer-hostname> \
  --addresses dynamic --addresses tcp://100.x.y.z:22000

syncthing cli config folders secondbrain devices add \
  --device-id AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH
```

Print this machine's own device ID to give to the others:

```sh
syncthing cli show system | grep -oP '(?<="myID": ")[^"]+'
```

Enable 30 day staggered file versioning as a second safety net under git. The
CLI cannot set the params, so this goes through the REST API:

```sh
syncthing cli config folders secondbrain versioning type set staggered

CFG=~/.local/state/syncthing/config.xml
APIKEY=$(grep -oP '(?<=<apikey>)[^<]+' "$CFG")
curl -s -H "X-API-Key: $APIKEY" localhost:8384/rest/config/folders/secondbrain \
  | python3 -c "import json,sys; f=json.load(sys.stdin); f['versioning']={'type':'staggered','params':{'cleanInterval':'3600','maxAge':'2592000'},'cleanupIntervalS':3600,'fsPath':'','fsType':'basic'}; print(json.dumps(f))" \
  | curl -s -X PUT -H "X-API-Key: $APIKEY" -H "Content-Type: application/json" \
      -d @- localhost:8384/rest/config/folders/secondbrain
```

> [!WARNING]
> Syncthing's config directory (`~/.local/state/syncthing/`) holds the API key
> and the device's private key. Never stow or commit it. Each device generates
> its own identity, so there is nothing there worth sharing anyway.

### Android setup

The official Syncthing app was removed from the Play Store in December 2024. Use
**Syncthing-Fork** by Catfriend1, from F-Droid.

1. Grant **All files access** (Settings > Apps > Syncthing-Fork > Permissions >
   Files). Without it Syncthing cannot see outside its own sandbox.
2. Allow **notifications**. Android 13+ blocks them by default, which silently
   suppresses the device pairing prompts.
3. Disable global discovery, relaying and NAT traversal, matching the Linux
   config above.
4. Set **Run Conditions** to Wi-Fi only, and exempt the app from battery
   optimization so Android does not kill the sync.
5. Add the folder with ID `secondbrain`, using the directory picker to create the
   target under `Documents/`. Type stays **Send & Receive**. Share it with both
   Linux devices.
6. Set the ignore patterns (below) **before** the first sync completes.
7. Leave **File Versioning** set to None. The Linux machines handle versioning.
8. In Obsidian, use *Open folder as vault* and point it at that directory.

### The two ignore files

These do different jobs and both matter.

`.stignore` in the vault root controls what **Syncthing** replicates. It is
per device and never syncs, so it must be created on each device:

```
.git
.stversions
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.trash
.DS_Store
```

On Android, add `.obsidian/plugins` as well, so desktop plugins are not pushed
to the phone. Note that ignore patterns only prevent future syncing, they do not
delete what already arrived.

`.gitignore` in the vault root controls what **git** commits:

```
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.stignore
.stversions/
.trash/
.DS_Store
```

> [!CAUTION]
> Git reads ignore rules from `.gitignore` and nothing else. A file named
> `.gitconfig` in a repo root is not an ignore file, and its contents are
> silently ignored. This bit this vault: per device workspace state committed for
> months, and once Syncthing was added, `.stversions/` backup copies began
> getting committed into the repo they were backing up.

### Verifying

```sh
# peers connected, and over the expected addresses
syncthing cli show connections | python3 -m json.tool | grep -E '"address"|"connected"'

# folder health
CFG=~/.local/state/syncthing/config.xml
APIKEY=$(grep -oP '(?<=<apikey>)[^<]+' "$CFG")
curl -s -H "X-API-Key: $APIKEY" "localhost:8384/rest/db/status?folder=secondbrain" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['state'], d['localFiles'], 'errors:', d['errors'])"

# how far a given peer has caught up
curl -s -H "X-API-Key: $APIKEY" \
  "localhost:8384/rest/db/completion?folder=secondbrain&device=<DEVICE-ID>" \
  | python3 -m json.tool
```

Conflicting edits produce a `*.sync-conflict-<date>-<device>.md` file next to the
winner rather than merging. Keep the version you want, delete the other. Find
them with:

```sh
find ~/notes/secondbrain -name '*sync-conflict*' -not -path '*/.git/*'
```

### Troubleshooting

**`reading length: EOF` repeating in the logs.** The peer completed a TLS
handshake then hung up, meaning it does not have this device in its own list yet.
Pairing is mutual. Accept the request on the other device.

**No pairing prompt on Android.** Notifications are blocked. Open the app's
**Web GUI** from the menu, where pending device and folder requests appear as
banners, then fix the notification permission.

**"Folder path missing" on Android.** The path was entered as a relative path.
Use the directory picker rather than typing, and confirm All files access is
granted.

**The Directory field is read only.** A folder's path is fixed at creation.
Remove the folder and re-add it, reusing the same folder ID. Nothing on the
other devices is affected.

**Vault is on the phone but the desktop shows a plugin error.** The enabled
plugin list (`.obsidian/community-plugins.json`) syncs even when plugin files do
not, so each device tries to load plugins it does not have and skips them
harmlessly. Do not disable a plugin from the phone or laptop to silence it, that
edits the shared list and disables it everywhere. Add
`.obsidian/community-plugins.json` to `.stignore` instead.

## GNOME keyring auto-unlock

Anything that stores a password in the Secret Service - browsers, the `gh` CLI,
Bitwarden, the [DDNS updater](#dynamic-dns) - depends on the keyring being
unlocked. Two separate defects stop that from happening on a stock install, and
both are silent: things appear to work until a password prompt shows up, or an
unattended timer fails because nothing is there to answer one.

Neither `gnome-keyring` nor `libsecret` (for `secret-tool`) needs an entry in
[packages.lst](packages.lst) - Omarchy installs both.

### 1. PAM never captures the login password

Arch's `/etc/pam.d/sddm` ships the `session` line for `pam_gnome_keyring.so` but
**not** the `auth` line. The session line asks the daemon to start; only the auth
line hands it the password typed at the greeter. Without it there is nothing to
unlock with, so `login.keyring` stays locked for the whole session no matter what
the passwords are.

Back the file up, then add the auth line directly after `auth include system-login`:

```sh
sudo cp /etc/pam.d/sddm /etc/pam.d/sddm.bak-$(date +%Y%m%d)
```

```
auth        include     system-login
-auth       optional    pam_gnome_keyring.so
```

The leading `-` means "skip quietly if the module is missing" and matches how the
existing session line is written. Takes effect at the next login, not before.

> [!NOTE]
> This only auto-unlocks when the login password and the keyring password match.
> A keyring carried over from another machine keeps *its* password, so if the two
> differ you get one unlock prompt per session instead of silent failure. Change
> the keyring password to match rather than re-creating it, or every secret in it
> is lost.

### 2. New secrets land in a keyring that never auto-unlocks

`pam_gnome_keyring` unlocks exactly one keyring, `login`. But a fresh install
creates `Default_keyring` and points the `default` alias at it, and the alias is
what receives every newly stored secret. The result is a locked keyring
accumulating live credentials.

The symptom is easy to misread, because `secret-tool search` looks in *every*
collection and happily returns attributes from locked ones. Check the alias and
the lock state directly instead:

```sh
busctl --user call org.freedesktop.secrets /org/freedesktop/secrets \
  org.freedesktop.Secret.Service ReadAlias s default        # want .../collection/login

busctl --user get-property org.freedesktop.secrets \
  /org/freedesktop/secrets/collection/login \
  org.freedesktop.Secret.Collection Locked                  # want: b false
```

Repoint the alias through D-Bus rather than editing
`~/.local/share/keyrings/default` by hand - the daemon reads that file only at
startup, so `SetAlias` is what applies immediately (it writes the file too):

```sh
busctl --user call org.freedesktop.secrets /org/freedesktop/secrets \
  org.freedesktop.Secret.Service SetAlias so \
  default /org/freedesktop/secrets/collection/login
```

> [!CAUTION]
> Repointing the alias does not move secrets already written to the old keyring.
> Enumerate it before assuming it is empty, because a locked collection can
> report zero items:
>
> ```sh
> busctl --user get-property org.freedesktop.secrets \
>   /org/freedesktop/secrets/collection/Default_5fkeyring \
>   org.freedesktop.Secret.Collection Items
> ```
>
> Note the D-Bus path escaping: `_` becomes `_5f`. Anything found there has to be
> re-created in `login` (usually by re-authenticating the app) or it stays
> unreachable.

## Dynamic DNS

Keeps a DnsMadeEasy A record pointed at this machine's public IP, which is
dynamic. **Remote access depends on it** - when the ISP hands out a new address
and the record goes stale, there is no way back in until it is fixed locally.

The updater is a small shell script maintained in its own repository, with its
own `install-linux.sh`. Prefer that installer over placing files by hand: it is
idempotent, writes the systemd units with absolute paths, and finishes with a
verification run.

Requires the [keyring section above](#gnome-keyring-auto-unlock) to be working
first. The password lives in the Secret Service under the service name
`ddns-dnsmadeeasy` and is never written to disk; the installer stores it there,
and the updater reads it back on each run. Also needs `curl` and `secret-tool`.

```sh
cd <ddns-repo>/linux
./install-linux.sh --username <dnsmadeeasy-user> --recordid <record-id> \
                   --interval-minutes 15
```

Omit `--password` and it prompts with echo off, which keeps the secret out of
`ps` and out of shell history. It lays down:

| Path | Contents |
|------|----------|
| `~/.local/state/ddns/ddns.sh`, `ddns_lib.sh` | The updater (mode 700) |
| `~/.local/state/ddns/ddns.config` | Record ID, endpoint URLs, last-seen IP, status (mode 600) - **no credentials** |
| `~/.local/state/ddns/ddns.log` | Append-only run log |
| `~/.config/systemd/user/ddns.{service,timer}` | 15 minute schedule, `Persistent=true` |

The config file is state as well as configuration: the script writes `PublicIP`,
`LastUpdate`, `LastVerify` and `Status` back into it. Carrying it to a new
machine preserves that history, and the installer merges rather than overwrites.

Every run re-pushes the record even when the IP has not changed, so a record
edited out of band self-corrects rather than staying wrong until the next real
IP change.

### Lingering

A `--user` timer only runs while a user session exists, so without lingering the
updater stops the moment you log out:

```sh
sudo loginctl enable-linger "$USER"
```

> [!IMPORTANT]
> Lingering and keyring auto-unlock pull in opposite directions. A lingering
> session started at boot has no PAM login behind it, so the keyring is still
> locked and the updater cannot read its password until someone logs in
> graphically. `Persistent=true` covers the gap by firing the missed run once the
> timer is live again. Lingering keeps it running *after* logout, which is the
> case that matters; it does not make the machine work from cold boot with nobody
> logged in.

### Verifying

```sh
systemctl --user list-timers ddns.timer --all   # NEXT/LAST populated
systemctl --user show ddns.service -p Result    # want: Result=success
grep -E '^(Status|LastVerify)=' ~/.local/state/ddns/ddns.config
tail -3 ~/.local/state/ddns/ddns.log
```

`Status=Ok` plus a fresh `LastVerify` means a full round trip succeeded. To check
without touching the live record:

```sh
~/.local/state/ddns/ddns.sh --dry-run
```

That still reads the keyring and fetches the public IP, so it is the fastest way
to tell a credential problem from a network one.

## Omarchy shell plugins

Bar widgets live as git clones in `~/.config/omarchy/plugins/<id>/`, so `stow`
cannot express them. [install.sh](install.sh) adds them instead, and also
re-applies the set of first-party widgets that are deliberately switched off, so
a rebuilt bar looks like this one rather than stock.

| Plugin id | Upstream | What it does |
|-----------|----------|--------------|
| `mrpbennett.fortivpn` | `mrpbennett/qs-fortivpn` | Fortinet SSL-VPN with FortiToken 2FA, from the bar |
| `joegeary.on-air` | `joegeary/omarchy-on-air` | Turns smart lights red and shows an indicator while in a meeting |
| `io.github.ilyazar.syncthing` | `ilyaZar/omarchy-syncthing` | Sync health and service control for [Syncthing](#obsidian-vault-sync-syncthing) |

Disabled first-party widgets: `active-window`, `dropbox`, `media`,
`microphone`, `spacer`.

Useful commands:

```sh
omarchy-plugin-list --json    # ids, versions, enabled state, firstParty flag
omarchy-plugin-update <id>
omarchy-plugin-enable <id>    # --section/--index/--before/--after place it
omarchy-plugin-disable <id>
```

> [!NOTE]
> `omarchy-plugin-add` has no existing-install check, so re-running it over a
> working plugin re-clones it. `install.sh` guards on the target directory
> instead of relying on the command to no-op.

### FortiVPN: the parts install.sh cannot do

The plugin needs two root-owned pieces that hold credentials, so they are set up
by hand and never live in this repo:

1. **A passwordless helper**, so the widget can bring the tunnel up without a
   sudo prompt. The plugin ships the installer:

   ```sh
   sudo ~/.config/omarchy/plugins/mrpbennett.fortivpn/scripts/install-passwordless-helper.sh
   ```

   That installs `/usr/local/libexec/omarchy-fortivpn-helper` and a `visudo -cf`
   validated `/etc/sudoers.d/omarchy-fortivpn` (mode 440) granting NOPASSWD on
   just that helper's `start`/`stop`/`reset` verbs.

2. **The gateway config** at `/etc/openfortivpn/omarchy.conf`, `root:root` mode
   600, written through the bar widget rather than by hand. Each field is patched
   individually over the helper's **stdin**, so the password never appears in
   `ps` and one edit cannot clobber another field.

The `openfortivpn` package is in [packages.lst](packages.lst). Note it is the
open implementation, not Fortinet's own FortiClient.

Connecting spawns a transient unit rather than a bare background process, which
is also how you check it:

```sh
systemctl is-active omarchy-fortivpn.service
journalctl -u omarchy-fortivpn.service -n 20
```

> [!IMPORTANT]
> The FortiToken OTP is a 30-60s code and is never stored, but it *is* visible in
> the `openfortivpn` process argv for the life of the session. There is no way to
> hand the binary a fresh one-time code non-interactively without that. Fine on a
> personal desktop, worth knowing on a shared box.

## Inbound SSH

Enabled so the desktop can be driven remotely from the laptop, mainly to run
[Herdr](#herdr) sessions. Reached over the tailnet, not the open LAN.

Three pieces, and **all three are required** - the middle one is the easy one to
miss, because without it `sshd` starts, listens, and every connection is silently
dropped with no log entry on this side.

### 1. Host keys

Restore the machine's previous host keys rather than letting a rebuild present
new ones, so clients that already have it in `known_hosts` do not report a
changed host key. Back up the fresh install's own set first:

```sh
sudo mkdir -p /etc/ssh/host-keys-freshinstall
sudo cp -a /etc/ssh/ssh_host_* /etc/ssh/host-keys-freshinstall/
# then restore, private keys 600 and .pub 644
```

### 2. The firewall rule

`ufw` is active with `DEFAULT_INPUT_POLICY="DROP"`, so SSH needs an explicit
allow. Scope it to the tailnet interface rather than opening the port on every
network the machine joins:

```sh
sudo ufw allow in on tailscale0 to any port 22 proto tcp comment 'ssh over tailnet'
sudo ufw --force reload
sudo ufw status verbose
```

Add `sudo ufw allow 22/tcp` as well only if SSH from the local LAN is wanted.

### 3. sshd itself

The hardening drop-in at `/etc/ssh/sshd_config.d/10-hardening.conf` sets
`PasswordAuthentication no`, `PermitRootLogin no`, and 30s client keepalives.
Validate before enabling, since a bad drop-in stops sshd from starting:

```sh
sudo sshd -t
sudo systemctl enable --now sshd
ss -lntp | grep ':22 '
```

> [!IMPORTANT]
> With password auth off, `ssh-copy-id` cannot bootstrap a new client - it needs
> one password login to work. Either append the client's public key to
> `~/.ssh/authorized_keys` directly, or comment the `PasswordAuthentication` line,
> `systemctl reload sshd`, run `ssh-copy-id`, then restore it and reload again.
> The comment at the top of the drop-in describes that staged order.

Rollback is two commands:

```sh
sudo systemctl disable --now sshd
sudo ufw delete allow in on tailscale0 to any port 22 proto tcp
```

## Herdr

Terminal workspace manager for AI coding agents. Reached over
[SSH](#inbound-ssh) from the laptop, which is the main reason inbound SSH is
enabled on this machine at all.

> [!NOTE]
> This used to be a self-updating binary at `~/.local/bin/herdr`. It is a package
> at `/usr/bin/herdr` now and updates with the system, so `herdr update` is no
> longer the way to upgrade it. It still needs no [packages.lst](packages.lst)
> entry, because Omarchy installs it.

```sh
herdr channel set <stable|preview>    # switch release channel
```

### What is tracked

Only `.config/herdr/config.toml`, which holds durable preferences (theme,
toast delivery, sound, onboarding state). Everything else in that directory is
runtime and is excluded in [.gitignore](../.gitignore):

| File | Why excluded |
|------|--------------|
| `herdr.sock`, `herdr-client.sock` | Live unix sockets, git cannot store them |
| `herdr-server.log`, `herdr-client.log` | Logs, and the server log reaches megabytes |
| `session.json` | Live pane and tab layout, rewritten constantly, and it records working directory paths |
| `release-notes.json` | Cached from the update check |
| `.plugins.lock` | Runtime lock |

### Stow linking

Unlike most config in this repo, `~/.config/herdr` is **not** a directory level
symlink. The running server keeps live sockets in that directory, so it must
stay a real directory, with only `config.toml` symlinked into it:

```sh
ln -s ../../dotfiles/.config/herdr/config.toml ~/.config/herdr/config.toml
```

> [!CAUTION]
> Applications that save config by writing a temp file and renaming it will
> **replace the symlink with a regular file**, silently detaching it from this
> repo. Changes then stop being tracked and drift accumulates unnoticed. This
> already happened to `~/.claude/settings.json`. Check periodically:
>
> For a single file, `ls -l <path>` should show an arrow pointing into
> `~/dotfiles`. To audit every tracked file at once, resolve each one and check
> that it still lands inside the repo. This is correct for both file level and
> directory level symlinks:
>
> ```sh
> git -C ~/dotfiles ls-files | while read -r f; do
>   [ -e "$HOME/$f" ] || continue
>   case "$(readlink -f "$HOME/$f")" in
>     "$HOME/dotfiles/"*) ;;
>     *) echo "detached: ~/$f" ;;
>   esac
> done
> ```

## AI agent instructions

[AGENTS.md](../AGENTS.md) is the single source of global instructions for every
AI coding agent, covering both working guidelines and voice.

Two symlinks point at it, and both are created by `stow .`:

| Link | Consumer |
|------|----------|
| `~/AGENTS.md` | Agents that read the `AGENTS.md` convention |
| `~/.claude/CLAUDE.md` | Claude Code |

The second is a symlink committed **inside** the repo (`.claude/CLAUDE.md ->
../AGENTS.md`) rather than a manual link created after the fact, so a fresh
machine gets it from `stow .` with no extra step. Edit `AGENTS.md` only, never
the links.

### Status line

`.claude/statusline.sh` is wired up via the `statusLine` key in
`.claude/settings.json`. Two lines, each stretched to the terminal width:

```
Model: Opus 5 | ⎇ main | (+12,-4)             cwd: /home/joe/dotfiles
Ctx: 456.4k | Ctx Used: 46.0%            Session: 7.0% | Weekly: 66.0%
```

Everything except the git segments comes from the JSON payload Claude Code
writes to the script's stdin. Plan usage is read from that payload's
`rate_limits`, which is the real server-side number, so nothing is estimated
and nothing is fetched over the network.

Requires `jq`, which Omarchy already installs. No node, no npm package, no cache
files, no network.

It began as the `ccstatusline` npm package, then as a vendored copy of
[Gui-Gou/claude-statusline-burnrate](https://github.com/Gui-Gou/claude-statusline-burnrate).
Both are gone: a status line is not worth a dependency. The current script is a
deliberate reimplementation of the `ccstatusline` layout, verified
byte-for-byte against it before that package was removed, which is why its
header documents small details like padding with U+00A0 instead of spaces
(Claude Code collapses runs of ordinary spaces) and reproducing JavaScript's
`toFixed` rounding. Those details are the reason it looks right; changing them
changes the output.
