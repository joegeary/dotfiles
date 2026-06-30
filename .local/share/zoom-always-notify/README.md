# Zoom Always-Notify

A tiny Chromium extension that makes **Zoom Team Chat fire desktop
notifications even when its window is focused** — which, on Hyprland/Wayland,
is the only way to reliably get notified.

## Why

Zoom's web app suppresses notifications when it thinks the tab is focused. On
Wayland, Chromium never reports a blur/visibility change when you switch
Hyprland workspaces ([crbug 365143359](https://issues.chromium.org/issues/365143359)),
so Zoom believes you're always looking at it and stays silent — you miss DMs.

This extension's content script (`force-unfocused.js`, injected into
`app.zoom.us` at `document_start` in the MAIN world) pins the focus/visibility
APIs Zoom checks:

- `document.hasFocus()` → always `false`
- `document.hidden` → always `true`
- `document.visibilityState` → always `"hidden"`
- window-level `focus` events are swallowed

So Zoom always concludes it's in the background and notifies. Realtime, no Zoom
Marketplace app, no account scopes.

> Earlier attempt: a WebSocket daemon (`zoom-chat-notifier`) hitting Zoom's
> event API. Abandoned because a user-level Zoom app only receives your *own
> outgoing* messages — never incoming ones — and the account-level
> (Server-to-Server) alternative would read all org Team Chat. This extension
> sidesteps all of that.

## Install

1. `chrome://extensions` → enable **Developer mode**
2. **Load unpacked** → select `~/.local/share/zoom-always-notify/`
3. Reload the Zoom tab/window so the script injects at page load.

**It applies to the PWA too.** The `zoom-pwa` launcher
(`chromium --app=https://app.zoom.us/wc/home`) runs in the same Default profile,
so the extension's content script injects in the app window automatically —
just relaunch the PWA after installing.

## Verify

In DevTools (`Ctrl+Shift+I`, works in the `--app` PWA window too) on the Zoom
page:

```js
document.hasFocus()       // false
document.visibilityState  // "hidden"
```

## Caveats

- Zoom always thinks it's hidden, so it may not auto-mark messages read while
  you're looking, and presence may lean "away" sooner. Narrow the overrides in
  `force-unfocused.js` if that's annoying.
- Unpacked dev-mode extensions don't auto-update, and Chromium may nag about
  developer-mode extensions on startup. Pack to a `.crx` if that gets old.
