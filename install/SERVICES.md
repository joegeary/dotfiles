# Service Setup

Post-install setup for services that are not just config files, and so cannot be
handled by `stow` alone. See [INSTALL_ARCH.md](INSTALL_ARCH.md) for the base OS install.

> [!IMPORTANT]
> Device IDs, tailnet addresses and hostnames in this document are placeholders.
> Substitute your own. Nothing here should ever be committed with real values.

## Contents

- [Tailscale](#tailscale)
- [Obsidian vault sync (Syncthing)](#obsidian-vault-sync-syncthing)
- [Todo list sync (Syncthing)](#todo-list-sync-syncthing)
- [GNOME keyring auto-unlock](#gnome-keyring-auto-unlock)
- [Bluetooth headset (mic and output)](#bluetooth-headset-mic-and-output)
- [Dynamic DNS](#dynamic-dns)
- [Omarchy shell plugins](#omarchy-shell-plugins)
- [Inbound SSH](#inbound-ssh)
- [Herdr](#herdr)
- [Zoom black screen on the second screenshare](#zoom-black-screen-on-the-second-screenshare)
- [Zoom screen-share toolbar](#zoom-screen-share-toolbar)
- [Zoom notifications stealing focus](#zoom-notifications-stealing-focus)
- [AI agent instructions](#ai-agent-instructions)
- [macOS VM](#macos-vm)

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

## Todo list sync (Syncthing)

Syncs `~/.todo/todo.txt`, the todo.txt file that [tuxedo](https://github.com/webstonehq/tuxedo)
reads (`tuxedo-git` in [packages.lst](packages.lst)), across the same three
devices as the vault. It rides the existing peer mesh, so there is no new device
pairing, only a new folder to add on each device.

The folder ID is `todo` and must match on every device. It is a single small
text file, so there are no ignore patterns to manage.

### Linux setup (joining machine)

Because the devices are already paired for the vault, the simplest path is to let
one machine share the folder and accept it on the other. On the machine that
already has the folder:

```sh
syncthing cli config folders todo devices add --device-id <peer-id>
```

Then on the joining machine, open the Web GUI (`http://localhost:8384`). A banner
appears: *"Device <name> wants to share folder 'Todo' (todo)."* Click **Add**,
which pre-fills the folder ID, set the path to `~/.todo`, and save. No device IDs
to type. Set versioning under the folder's **Advanced > File Versioning** tab.

The fully scripted equivalent, if you would rather not touch the GUI:

```sh
syncthing cli config folders add --id todo --label "Todo" --path ~/.todo

# share back with the other two devices (IDs from `syncthing cli show system`)
syncthing cli config folders todo devices add --device-id <peer-1-id>
syncthing cli config folders todo devices add --device-id <peer-2-id>
```

Either way, enable the same 30 day staggered versioning as the vault, as a safety
net under the conflict behaviour noted below. The CLI cannot set the params, so
this goes through the REST API:

```sh
syncthing cli config folders todo versioning type set staggered

CFG=~/.local/state/syncthing/config.xml
APIKEY=$(grep -oP '(?<=<apikey>)[^<]+' "$CFG")
curl -s -H "X-API-Key: $APIKEY" localhost:8384/rest/config/folders/todo \
  | python3 -c "import json,sys; f=json.load(sys.stdin); f['versioning']={'type':'staggered','params':{'cleanInterval':'3600','maxAge':'2592000'},'cleanupIntervalS':3600,'fsPath':'','fsType':'basic'}; print(json.dumps(f))" \
  | curl -s -X PUT -H "X-API-Key: $APIKEY" -H "Content-Type: application/json" \
      -d @- localhost:8384/rest/config/folders/todo
```

> [!NOTE]
> If `~/.todo` already holds a `todo.txt` on the joining machine, an identical
> file merges silently, but a differing one produces a `*.sync-conflict-*` copy
> rather than merging. On a fresh machine, leave `~/.todo` empty and let the
> first sync populate it.

### Android setup

Add a folder with ID `todo` in Syncthing-Fork, using the directory picker for
its path, type **Send & Receive**, shared with both Linux devices. Leave **File
Versioning** set to None, as with the vault. The phone cannot run tuxedo, but any
todo.txt app can read the synced file.

### Conflicts

todo.txt is one file, so simultaneous edits on two offline devices do not merge.
Syncthing keeps both and writes a `*.sync-conflict-<date>-<device>.txt` beside
the winner. Keep the one you want and delete the other:

```sh
find ~/.todo -name '*sync-conflict*'
```

## GNOME keyring auto-unlock

Anything that stores a password in the Secret Service (browsers, the `gh` CLI,
Bitwarden, the [DDNS updater](#dynamic-dns)) depends on the keyring being
unlocked.

Neither `gnome-keyring` nor `libsecret` (for `secret-tool`) needs an entry in
[packages.lst](packages.lst). Omarchy installs both.

### How Omarchy expects it to work

On an encrypted install there are two separate steps at boot, and only the first
one asks for anything:

1. The disk passphrase at the Plymouth prompt. It unlocks the LUKS volume and
   nothing else.
2. SDDM **autologin** (`/etc/pam.d/sddm-autologin`). It logs you in without a
   password, so there is no password for `pam_gnome_keyring` to unlock with.

Omarchy handles that by keeping secrets in a keyring with **no password**.
`/usr/share/omarchy/install/user/default-keyring.sh` creates `Default_keyring`
without one and points the `default` alias at it. Full disk encryption protects
it at rest. Omarchy's `install/login/sddm.sh` also deletes the
`pam_gnome_keyring.so` auth line from `/etc/pam.d/sddm` on purpose, so a password
login can't create a competing encrypted `login` keyring.

The rule that follows: **every keyring that holds secrets must have an empty
password.** A keyring with a password can never auto-unlock under autologin. The
symptom is an "Authentication required: The login keyring did not get unlocked
when you logged into your computer" dialog after every boot, and this in the
journal:

```sh
journalctl -b | grep gkr-pam      # "couldn't unlock the login keyring"
```

> [!WARNING]
> An earlier version of this section treated Omarchy's setup as two defects. It
> added the `pam_gnome_keyring.so` auth line to `/etc/pam.d/sddm` and repointed
> the `default` alias at the password protected `login` keyring. Under autologin
> that produced the unlock dialog on every boot from August 2026 on. Do not
> redo either change.

Switching to systemd's LUKS unlock (`sd-encrypt` plus `pam_systemd_loadkey`) so
the disk passphrase also unlocks a password protected keyring was considered and
rejected. It replaces Omarchy's `encrypt` hook and kernel command line, and
Omarchy's update migrations rewrite `/etc/default/limine` and rebuild the boot
image assuming its own setup, so it would be at odds with every future update.

### Removing a keyring password

Use Seahorse ("Passwords and Keys"). It is only needed for this, so it is not in
`packages.lst`.

```sh
sudo pacman -S seahorse
```

Right-click the keyring, choose **Change Password**, enter the current password,
leave the new one blank, and accept the warning about storing it unencrypted.
The secrets stay where they are.

> [!CAUTION]
> Do not script this through `busctl` with
> `org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface.ChangeWithPrompt`.
> It segfaulted `gnome-keyring-daemon` 50.0 on this machine. systemd restarted
> it and no secrets were lost, but use Seahorse.

### Verifying

Every collection should report `b false` right after login, without any dialog:

```sh
busctl --user call org.freedesktop.secrets /org/freedesktop/secrets \
  org.freedesktop.Secret.Service ReadAlias s default

for c in login Default_5fkeyring; do
  busctl --user get-property org.freedesktop.secrets \
    /org/freedesktop/secrets/collection/$c \
    org.freedesktop.Secret.Collection Locked
done
```

Note the D-Bus path escaping: `_` becomes `_5f`.

### Current state on this machine

- `login` (13 secrets) and `Default_keyring` (6 secrets) both have their
  passwords removed. The `default` alias still points at `login`, left over from
  the old fix. That is harmless now that both are passwordless, so it was left
  alone rather than moving secrets between keyrings.
- `/etc/pam.d/sddm` still carries the extra auth line from the old fix. It never
  runs under autologin, but to match Omarchy again, restore the backup taken
  before the change (it differs by exactly that one line):

  ```sh
  sudo cp /etc/pam.d/sddm.bak-20260816 /etc/pam.d/sddm
  ```

## Bluetooth headset (mic and output)

A Bluetooth headset can run high fidelity stereo playback (A2DP) *or* its
microphone (the HSP/HFP "headset" profile), never both at once. The mic profile
is mono and narrowband, so turning the mic on drops playback to phone-call
quality. That is a hard limit of the Bluetooth audio profiles, not a fault to
fix - so the goal is only to make the switch automatic and get you talking *and*
hearing on the headset, not to have good-sounding music *and* the mic together.

A working call needs **both** the mic and the output pinned to the headset. They
are two separate WirePlumber defaults (source and sink) with two separate pins,
and each has the same "dangling phantom default" failure mode. Pinning only one
leaves half the call dead: pin only the source and the app talks but you hear
nothing; pin only the sink and you hear but no one hears you.

WirePlumber does that switch on its own: it stays in A2DP for music and flips to
HFP the moment an app opens the headset's mic, then flips back when the app lets
go. That behaviour is one setting, `bluez5.autoswitch-profile = true`, in a
stowed drop-in:

```
home/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf
```

The same file lists the `hfp_hf`/`hsp_hs` roles under `bluez5.auto-connect`, so
the mic link is established on connect. Without them an app cannot switch to the
mic and the headset is not seen as an input at all until a full reconnect.

> [!IMPORTANT]
> This drop-in previously lived only on the machine, never in the repo, so a
> rebuild lost it and the auto-switch silently stopped. It is stowed now. If the
> headset mic ever "isn't working" after a rebuild, confirm this file is present
> and symlinked before anything else.

### Pinning the headset as the default mic - the part stow cannot do

Auto-switching only fires when an app opens the *headset's* mic. Apps open
whatever the system default source is, and when nothing is pinned WirePlumber
chooses that default by a priority score - a contest the headset never wins.
Measured priorities on this machine:

| Source | `priority.session` |
|--------|--------------------|
| C922 webcam mic | 2109 |
| Scarlett Solo | 2100 |
| **WH-CH700N headset** | **2010** |
| Onboard analog | 2009 |

So a fresh session auto-selects the webcam as the mic, every app grabs that, and
the headset mic is never opened - so the auto-switch never has a reason to fire
and the headset looks like it "has no mic". The fix is to pin the headset as the
configured default source explicitly. **The Omarchy Bluetooth widget cannot do
this** - there is no default-mic setting in it. It is `wpctl` only:

```sh
# The node id changes every boot, so read it fresh. Either eyeball it:
wpctl status            # under Sources, note the id next to "WH-CH700N"
wpctl set-default <id>

# ...or do it by name in one shot (substitute your headset's description):
id=$(pw-dump | python3 -c "import json,sys; print(next(o['id'] for o in json.load(sys.stdin) if (o.get('info',{}).get('props') or {}).get('node.description')=='WH-CH700N'))")
wpctl set-default "$id"
```

That writes `default.configured.audio.source` into
`~/.local/state/wireplumber/default-nodes`. It is keyed by the device's node name
(`bluez_input.<MAC>`), so it survives reboots and Bluetooth
disconnect/reconnect - but it is **user state, not a config file, so it cannot be
stowed and a rebuild loses it.** Redo the one command above, once, on each fresh
install with the headset connected. That single command is the whole manual step;
everything else is in the repo.

The pin is **per headset**. Each Bluetooth mic is its own device with its own
address, so bookmarking the Sony does nothing for a second headset - run the same
command once for each, while that one is connected. WirePlumber keeps them as a
fallback stack and uses whichever is currently connected:

```
default.configured.audio.source   = bluez_input.<pixel-buds-mac>   # first choice
default.configured.audio.source.0 = bluez_input.<sony-mac>         # fallback
```

So once each headset has been pinned a single time, swapping between them just
works - no re-pinning on every switch. Only a headset that has *never* been
pinned, with the others disconnected, drops back to the priority score (the dead
webcam), which is exactly the trap the pins exist to avoid. The auto-switch
drop-in already covers every Bluetooth device (`~bluez_card.*`), so a new headset
needs no config change, only its one-time pin.

> [!NOTE]
> Why this bites harder than it should: the C922 webcam's own mic is dead - it
> streams digital silence at the hardware level with every ALSA control correct
> (`Mic Capture Switch` on, gain maxed, stream running) - yet it still outranks
> every other mic. So until the headset is pinned, every app auto-selects a dead
> mic and no amount of Bluetooth fiddling helps. If that webcam is ever replaced,
> the new one takes the top priority slot again, so the pin keeps earning its
> keep.

### Pinning the headset as the default output - the same trap on the other side

Everything above is about the mic. The **output** needs the exact same treatment,
and skipping it is what makes a call go silent even when the mic works perfectly:
the app captures your voice from the headset, but its playback lands on whatever
the default *sink* happens to be. If that default is a Bluetooth device that is
not connected right now, output falls down the stack to the next sink - which on
this machine is the Scarlett Solo, and the Scarlett is normally **muted**. Net
result: full mic, zero sound, and nothing in the Bluetooth widget hints at why.

That is not hypothetical - it is exactly how this broke. The **Pixel Buds** had
been pinned as the default sink, they were disconnected, and every call's audio
silently drained into the muted Scarlett. Pin the headset as the default sink,
the same one-shot `wpctl` way as the source:

```sh
# eyeball it: under Sinks in `wpctl status`, note the id next to "WH-CH700N"
wpctl status
wpctl set-default <sink-id>

# ...or by name in one shot (same node the mic pin uses, just the output side):
id=$(pw-dump | python3 -c "import json,sys; print(next(o['id'] for o in json.load(sys.stdin) if (o.get('info',{}).get('props') or {}).get('node.description')=='WH-CH700N' and 'Sink' in (o.get('info',{}).get('props') or {}).get('media.class','')))")
wpctl set-default "$id"
```

That writes `default.configured.audio.sink` into the same `default-nodes` state
file. It is the identical deal as the source pin: **user state, not stowable**,
redo it once per fresh install, and it is **per headset** with a fallback stack.

The one extra wrinkle over the mic side: a sink pin has to be a device that is
actually *connected* when it matters. A pinned-but-absent Bluetooth sink (the
Pixel Buds) does not gracefully fall back to another Bluetooth headset that *is*
connected - it drops to the next wired sink, which here is the muted Scarlett. So
if you keep more than one Bluetooth output around, pin the one you actually wear
for calls **last** (so it lands as the primary `default.configured.audio.sink`),
and treat a call that is silent-but-otherwise-fine as this exact symptom: check
`wpctl status` for a `*` sink that is not the headset, and re-pin.

### Verifying

```sh
# what apps will grab as the mic - want the headset's bluez_input node
wpctl inspect @DEFAULT_AUDIO_SOURCE@ | grep node.name

# what apps will play into - want the headset's bluez_output node, NOT a phantom
wpctl inspect @DEFAULT_AUDIO_SINK@ | grep node.name

# auto-switch setting is live (find the bluez_card id in `wpctl status` first)
wpctl inspect <bluez_card-id> | grep autoswitch    # want: bluez5.autoswitch-profile = true

# prove the mic actually captures - peak/rms must be non-zero while talking
pw-record --target @DEFAULT_AUDIO_SOURCE@ /tmp/mic.wav   # ctrl-c after a few seconds, then play it back
```

### Zoom: use "Same as system" for both devices

In Zoom's Settings > Audio, set both Speaker and Microphone to **Same as system**,
not to the headset by name. Every A2DP/HFP switch replaces the headset's
PipeWire nodes, and a device picked by name stays bound to the old node, so the
second test or call goes silent. "Same as system" follows the default, which the
pins above keep on the headset.

The first few seconds of a call or mic test are silent while the headset
switches from A2DP to HFP. That delay is the profile switch, not a fault.

### Adapter firmware

The USB adapter is a Broadcom BCM20702A1 (`0a5c:21e8`). It needs the patch file
`brcm/BCM20702A1-0a5c-21e8.hcd`, or the HFP mic does not work. Confirm it loads
on every boot:

```sh
journalctl -k -b | grep "BCM20702A1 'brcm/"     # want: ... '.hcd' Patch
```

`packages.lst` lists `broadcom-bt-firmware-git` for this, but on this machine the
package is not installed. The working file was copied in by hand on 2026-08-17
and no package owns it (`pacman -Qo` finds nothing). A rebuild has to install the
package, or the patch is lost.

### Keep the adapter on the CPU's USB controller

The B550 board has two USB host controllers: the AMD 500 Series chipset
controller and the CPU's own Matisse controller. On the chipset controller, the
adapter hard-locked a CPU core inside the Bluetooth driver while it was tearing
down a call link (`Workqueue: events btusb_work`, stuck in `xhci_urb_dequeue`).
Every other core then stalled behind it, and the desktop froze for about 25
seconds. The kernel logged it on 2026-08-22 and on 2026-10-06, the second time
right as the headset reconnected. The same chipset controller also loses power on
every resume from suspend (`xHC error in resume ... Reinit`).

The adapter now sits in the port the keyboard used, which is on the CPU
controller. The keyboard moved to the chipset controller, where it does no harm.
Check which controller it is on:

```sh
readlink -f /sys/class/bluetooth/hci0/device    # note the 0000:xx:00.x controller
lspci -s <xx:00.x>                              # want "Matisse USB 3.0 Host Controller"
```

If it reports "500 Series Chipset USB 3.1 XHCI Controller", move it to a port
next to the Scarlett or the keyboard and check again.

### Calls die after the first one: kernel and WirePlumber are pinned

**Symptom:** the first call after boot works. Afterwards the headset mic and
speaker are dead in every app until a reboot or a headset reconnect.

**Log signature:** an HFP transport failure. HFP transports end in `/fdNN`;
A2DP ones contain `/sepN/`.

```sh
journalctl -b | grep 'Failure in Bluetooth audio transport'
# bad:  .../dev_<MAC>/fd80     (HFP call link)
```

PipeWire 1.6.8 counts these failures per transport and does not reset the count
after a successful call, so once it reaches its retry limit every later attempt
fails until the headset reconnects. The upstream fix is "bluez5: reset the
transport error count on a successful acquire". It is not in Arch's PipeWire as
of 2026-10-06.

> [!NOTE]
> `Bluetooth: hci0: SCO packet for unknown connection handle 6` in the kernel log
> is **harmless**. This adapter keeps sending a few audio packets after every
> call link closes. It appears at the end of every call, including on days when
> every call worked. Do not chase it.

The failures started on 2026-09-29, the first reboot after the 2026-09-16 update.
That reboot made `linux-omarchy` 7.2.5 and WirePlumber 0.5.17 live at the same
time. PipeWire (1.6.8) and BlueZ (5.87) had not changed since install. Tested on
2026-10-06:

| Kernel | WirePlumber | Zoom | Result |
|--------|-------------|------|--------|
| `linux-omarchy` 7.2.5 | 0.5.17 | 7.2.1 | fails |
| `linux` 7.1.9 | 0.5.17 | 7.2.1 | fails |
| `linux` 7.1.9 | 0.5.17 | 7.1.5 | fails |
| `linux` 7.1.8 | 0.5.15 | 7.1.5, then 7.2.1 | **much better**: a full meeting and the mic tests worked, one HFP failure logged (12:56:56) |

Ruled out along the way: the Zoom version (7.1.5 also crashed its webview and
segfaulted on quit, so stay on current Zoom), disabling mSBC (same failures, only
worse call quality), and the Omarchy kernel's build options (its Bluetooth and
USB config matches stock Arch 7.2.3, so if the kernel is at fault the bug is
upstream, not in Omarchy's build).

**Current state:** booted on stock `linux` 7.1.8 with WirePlumber 0.5.15, held
back in `/etc/pacman.conf`:

```
IgnorePkg = linux wireplumber libwireplumber
```

Both came from the Arch Linux Archive:

```sh
sudo pacman -U \
  https://archive.archlinux.org/packages/w/wireplumber/wireplumber-0.5.15-1-x86_64.pkg.tar.zst \
  https://archive.archlinux.org/packages/l/libwireplumber/libwireplumber-0.5.15-1-x86_64.pkg.tar.zst \
  https://archive.archlinux.org/packages/l/linux/linux-7.1.8.arch1-3-x86_64.pkg.tar.zst
```

> [!IMPORTANT]
> Limine's `BOOT_ORDER` puts `linux-omarchy` first, so the **default boot entry
> is still the 7.2.5 Omarchy kernel**. Pick plain `linux` in the boot menu on
> every boot until this is resolved. `uname -r` should print `7.1.8-arch1-3`.

The pinned kernel gets no security updates, so this is meant to be short-lived.

On the first boot of this setup, Zoom showed no mic input even though PipeWire
was delivering the headset audio to Zoom's input stream (verified by recording
Zoom's stream monitor port). After a reboot it worked. The cause is unknown.

**Still open:**

1. Confirm the pinned setup really fixes it. Watch for `/fdNN` transport
   failures, and check that the next call after one still works. If calls die
   again after a failure, the pins are not the fix, and the PipeWire error count
   fix is what is needed.
2. Find which of the two caused it. Boot the default `linux-omarchy` entry while
   WirePlumber stays at 0.5.15, then do two calls back to back. If both work,
   WirePlumber 0.5.17 is the culprit: drop `linux` from `IgnorePkg` and go back
   to the Omarchy kernel. If the second fails, the kernel is.
3. Report the culprit upstream with the logs, then lift the pin once a fixed
   release lands.
4. To lift it: remove the `IgnorePkg` line, run `sudo pacman -Syu`, reboot, do
   two calls back to back, and check that no `/fdNN` transport failures were
   logged.

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

A third root-owned piece *does* live in the repo, because it holds no secrets:
`install/50-sws-split-dns.sh`, installed to `/etc/ppp/ip-up.d/` by `install.sh`.
openfortivpn hands `ppp0`'s corporate DNS servers to systemd-resolved but sets no
routing domain and leaves the link a default resolver. Two things break: every
`*.sws.local` lookup hits resolved's mDNS special-casing for `.local` (disabled
here) and fails, and every *other* lookup also leaks to the corporate resolver.
The `pppd` ip-up hook fixes both by claiming just `sws.local`, `10.x` reverse, and
the `oncoursesystems.com` zone for the tunnel and dropping it as a default route -
so only those go over the VPN:

```sh
resolvectl domain ppp0 sws.local '~10.in-addr.arpa' '~oncoursesystems.com'  # what goes over the tunnel
resolvectl default-route ppp0 false                                          # not a catch-all resolver
```

`~oncoursesystems.com` is routing-only: `oncoursesystems.com` is a split-horizon
zone, and the internal view (notably `devel.k8s.oncoursesystems.com` and
`prod.k8s.oncoursesystems.com`, which point at the `10.7.1.200` / `10.10.137.200`
Kubernetes control-plane VIPs) is served only by the corporate resolver. Without
this route those names fall through to public DNS and resolve to Cloudflare-proxied
IPs that never answer on the API port 6443, so `kubectl` just times out.

Verify after connecting (should return an internal 10.x address):

```sh
resolvectl query oc-kermit.sws.local
resolvectl query devel.k8s.oncoursesystems.com   # want: 10.7.1.200
resolvectl status ppp0        # want: DNS Domain: sws.local ~10.in-addr.arpa ~oncoursesystems.com; Default Route: no
```

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

## Zoom black screen on the second screenshare

First screenshare in a Zoom session works, every one after it is a black screen
for the viewers. Zoom asks screencopy for a DMA-BUF with an Intel modifier it
cannot render on reconnect, so it gets a buffer it renders as nothing.

Fixed by forcing SHM buffers in `~/.config/hypr/xdph.conf`:

```
screencopy {
    force_shm = 1
}
```

Omarchy seeds that file from `/usr/share/omarchy/config/hypr/xdph.conf`, so
`install.sh` appends this as a second `screencopy` block rather than taking the
file over; hyprlang merges repeated categories, verified against xdph's own log.
The tradeoff is real: it applies to **all** screensharing and CPU-copies every
frame, so remove it if you ever need the GPU path for high-res capture in OBS.

xdph only reads its config at startup, so the change needs either a fresh login
or:

```bash
systemctl --user restart xdg-desktop-portal-hyprland
```

> [!WARNING]
> That restart is not free. Desktop apps make synchronous DBus calls to the
> portal, so anything that asks it a question while it is down blocks until the
> ~25-30s activation timeout. Restarting it can freeze the session for half a
> minute. Prefer logging out.

## Zoom screen-share toolbar

Start a screen share and the meeting window collapses to a small floating
share-control toolbar. Running Zoom under native Wayland (`xwayland=false`, set
by `install.sh`) makes this an ordinary managed window: it comes up titled
`as_toolbar`, tiling into the layout and oversized, so `hypr/bindings.lua`
floats it and pins it to its natural size.

```lua
o.window({ class = "^(Zoom)$", initial_title = "^(as_toolbar)$" }, {
  float = true,
  size = { 772, 87 },
})
```

Under the old XWayland setup this was a long-running sore. Zoom declared the bar
override-redirect, so Hyprland rendered it but never hit-tested it and clicks
fell through, and it landed off-screen from a Zoom positioning bug. It took a
`zoom-share-rescue` helper (its own `SUPER + Z` / `SUPER + SHIFT + Z` binds) plus
`ydotool` and a flat-accel device rule to make it usable. Native Wayland drops
every bit of that; the helper, the binds, the `ydotool` package and the device
rule are all gone. Other transient Zoom surfaces (reactions picker, dialogs)
float themselves under Wayland and need no rule.

## Zoom notifications stealing focus

On any notification (meeting reminder, chat ping, audio-device change) Zoom
fires a window activation request. Omarchy sets `focus_on_activate = true`
globally, so Hyprland obeys it and hops the active workspace over to Zoom,
yanking you out of whatever you were doing. Scoping the option off for Zoom in
`hypr/bindings.lua` stops it, the same pattern Omarchy uses for Telegram:

```lua
o.window({ class = "^(Zoom)$" }, {
  focus_on_activate = false,
})
```

That alone leaves Zoom silent, because native Wayland Zoom cannot draw its own
floating notification toasts the way the XWayland build did. It has to emit
desktop notifications instead, which are off by default, so `install.sh` sets
`waylandDesktopNotifications=true` in `zoomus.conf`. Alerts then render as
ordinary Hyprland toasts through the omarchy shell, without stealing focus. Zoom
rewrites that file on exit, so the change only sticks while Zoom is closed.

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

## macOS VM

A macOS Sequoia VM in Docker, using the [dockur/macos](https://github.com/dockur/macos)
image. It is the macOS sibling of Omarchy's `omarchy-windows-vm`, but needs no
root: the user is in the `docker` group. Its config is
`.config/macos-vm/compose.yml` and the `macos-vm` command drives it:

```sh
macos-vm start     # start the VM and share the web viewer over the tailnet
macos-vm stop      # remove that share and shut the VM down
macos-vm status    # container state, share state and URLs
macos-vm logs      # follow the container logs
macos-vm open      # open the web viewer locally
```

The VM is reached through its noVNC web viewer. Docker publishes it on
`127.0.0.1:8007` only, never on the LAN. Port 8006 belongs to the Windows VM.
`start` adds a `tailscale serve` mapping, so other tailnet devices reach it at
`https://<host>.<tailnet>.ts.net:8007`. `stop` removes only that mapping and
leaves any other serve config alone. VNC on 5900 is not published at all.

The viewer sits behind nginx basic auth (`PROTECT=Y`) using the same username
and password as the Windows VM. `start` reads them from
`~/.config/windows/credentials`, the private copy `omarchy-windows-vm install`
writes, and refuses to start without them. Nothing is stored in this repo.
Create the macOS account during setup with that same username and password,
and one login covers both VMs and both web viewers.

> [!CAUTION]
> Never write runtime files or secrets under `~/.config/macos-vm`. Stow folds it
> into a symlink to this repo, and this repo is public.

The disk image lives in `~/.macos`. The 128G disk is sparse, so it only uses
what the guest writes.

### First boot install

1. Choose Disk Utility.
2. Erase the largest disk, "Apple Inc. VirtIO Block Media", as APFS.
3. Quit Disk Utility and choose Reinstall macOS.

On AMD the guest must not get more than 8G of RAM during the install, so
`RAM_SIZE` is `8G`. It can go higher in `compose.yml` once macOS is installed.

### Sharing files

`~/macOS` on the host is shared with the guest. Mount it inside macOS with:

```sh
sudo -S mount_9p shared
```
