# On-Air Hue

A background Noctalia plugin that turns a Philips Hue light **red** while your
camera (and optionally microphone) is in use, then **restores the light's
previous state** when the call ends. Optionally toggles Do Not Disturb.

This is the plugin replacement for the old `monitor-onair` systemd user
service. Detection is event-driven via PipeWire + a `/dev/video*` fd scan
(no polling of `pw-dump`).

## Requirements

- [`openhue`](https://www.openhue.io/) CLI installed and configured
  (`~/.openhue/config.yaml`)
- Noctalia ≥ 4.5.0

## How it works

- Detects the camera by which processes hold an open fd on a `/dev/video*`
  capture device, and the mic via PipeWire input streams.
- On going on-air: `openhue get light <id> --json` snapshots the current state
  (persisted to the cache dir so a shell restart mid-call can still restore),
  then sets the light to the configured red.
- On going off-air: restores brightness/color/on-off from the snapshot.

## Settings

| Setting | Default | Description |
|---|---|---|
| Hue light ID | _your light_ | Light UUID (`openhue get lights`) |
| Trigger on camera | `true` | Go on-air when a camera is active |
| Trigger on microphone | `false` | Also go on-air when the mic is active |
| Toggle Do Not Disturb | `true` | Silence notifications while on-air |
| On-air color X / Y | `0.54` / `0.32` | CIE xy (red) |
| On-air brightness | `100` | Brightness while on-air |

## Note

This plugin is tracked in dotfiles (it is not published to a Noctalia plugin
registry), via a `.gitignore` exception for `.config/noctalia/plugins/onair-hue/`.
