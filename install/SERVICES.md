# Service Setup

Post-install setup for services that are not just config files, and so cannot be
handled by `stow` alone. See [INSTALL_ARCH.md](INSTALL_ARCH.md) for the base OS install.

> [!IMPORTANT]
> Device IDs, tailnet addresses and hostnames in this document are placeholders.
> Substitute your own. Nothing here should ever be committed with real values.

## Contents

- [Tailscale](#tailscale)
- [Obsidian vault sync (Syncthing)](#obsidian-vault-sync-syncthing)
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

## Herdr

Terminal workspace manager for AI coding agents. The binary lives at
`~/.local/bin/herdr` and updates itself, so it is not in
[packages.lst](packages.lst):

```sh
herdr update                          # update in place
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
