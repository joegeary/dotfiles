# zoom-chat-notifier

Desktop notifications for **Zoom Team Chat** that fire on *every* incoming
message — regardless of whether the Zoom web app is focused, sitting on another
Hyprland workspace, or even open at all.

## Why this exists

Zoom's web app deliberately **suppresses notifications when it thinks the tab is
focused** (so it doesn't double-buzz you). On Wayland, Chromium never reports
that its window lost focus when you switch Hyprland workspaces
([crbug 365143359](https://issues.chromium.org/issues/365143359)), so Zoom
stays silent and you miss DMs. Running it as a PWA or in Firefox doesn't help —
it's Zoom's own focus logic, not the browser's.

The fix sidesteps the browser entirely: a small daemon holds a WebSocket to
Zoom's event API and fires `notify-send` on every `chat_message.sent` event.
No browser, no focus state, no missed chats.

## Pieces

| Path | What it is | Tracked? |
|---|---|---|
| `~/.local/bin/zoom-chat-notifier` | the daemon | ✅ dotfiles |
| `~/.config/systemd/user/zoom-chat-notifier.service` | systemd user unit | ✅ dotfiles |
| `~/.config/zoom-chat-notifier/env.example` | config template | ✅ dotfiles |
| `~/.config/zoom-chat-notifier/env` | **your secrets** | 🔒 gitignored |
| `~/.config/zoom-chat-notifier/token.json` | OAuth refresh token from `--authorize` | 🔒 gitignored |
| `~/.local/share/zoom-chat-notifier/venv` | python venv (`websockets`, `requests`) | local, not tracked |

---

## 1. Create the Zoom app

Go to [marketplace.zoom.us](https://marketplace.zoom.us) → **Develop → Build App**.

Two app types work. **General (user-managed OAuth)** is recommended — it needs no
account admin and scopes events to *just you*. **Server-to-Server OAuth** needs
admin and delivers the whole account's chat (a firehose you'd have to filter).
The rest of this doc assumes a **General app**.

1. **Build App → General App.**
2. **App Credentials**: copy the **Client ID** and **Client Secret**.
3. **Scopes**: add the Team Chat read scopes:
   - `team_chat:read:list_user_messages`
   - `team_chat:read:user_message`
4. **OAuth** (Redirect URL): see [§3](#3-authorize-the-cloudflared-dance) — Zoom
   rejects `localhost`, so this gets filled in during auth.
5. **Event Subscriptions**: turn on → **Add Event Subscription** →
   delivery method **WebSocket** → add event type
   **Chat Message → "Chat Message Sent"** → **Save**. Copy the generated
   **Subscription ID** (the bare id, e.g. `UkOzFTImT7u5dg3fZHi4_w` — *not* the
   full `wss://…` URL, though the daemon tolerates either).

---

## 2. Configure

```bash
cp ~/.config/zoom-chat-notifier/env.example ~/.config/zoom-chat-notifier/env
chmod 600 ~/.config/zoom-chat-notifier/env
$EDITOR ~/.config/zoom-chat-notifier/env
```

| Var | Notes |
|---|---|
| `ZOOM_AUTH_MODE` | `oauth` for a General app, `s2s` for Server-to-Server |
| `ZOOM_CLIENT_ID` / `ZOOM_CLIENT_SECRET` | from App Credentials |
| `ZOOM_SUBSCRIPTION_ID` | from Event Subscriptions |
| `ZOOM_REDIRECT_URI` | the `https://…/callback` from §3 (oauth only) |
| `ZOOM_MY_EMAIL` | your address — your own outgoing messages are skipped |
| `ZOOM_NOTIFY_ICON` | optional icon name/path for the popup |
| `ZOOM_DEBUG` | set to `1` to log raw event JSON (for tuning/troubleshooting) |

The daemon loads this file itself, so you don't need to `source` it for manual
runs; systemd loads it via `EnvironmentFile=`.

---

## 3. Authorize (the cloudflared dance)

> Only needed for `oauth` mode, and only **once** — afterwards the daemon
> authenticates the WebSocket with a `client_credentials` app token and never
> needs a redirect again.

**The problem:** Zoom now rejects `http://` *and* `localhost`/`127.0.0.1`
redirect URLs with `Invalid redirect (4700)`. The OAuth consent flow needs a
real public `https` URL to bounce the auth code through. We only need it to
exist for one authorization, so a throwaway Cloudflare quick tunnel does the
job (`cloudflared` is already installed).

```bash
# 1. Start a throwaway public tunnel; leave it running. Copy the
#    https://<random>.trycloudflare.com URL it prints.
cloudflared tunnel --url http://localhost:8723
```

Nothing has to actually listen on :8723 — the tunnel just gives Zoom a public
`https` domain to accept. The callback page will 502; we read the code out of
the browser's address bar.

```
# 2. In the Zoom app's OAuth section, set BOTH the Redirect URL and the
#    OAuth Allow List entry to:
#        https://<random>.trycloudflare.com/callback
#    Save.

# 3. Point your env at the exact same URL:
sed -i 's|^ZOOM_REDIRECT_URI=.*|ZOOM_REDIRECT_URI=https://<random>.trycloudflare.com/callback|' \
    ~/.config/zoom-chat-notifier/env
```

```bash
# 4. Run the one-time authorize. It opens the consent page; after you approve,
#    the browser lands on a cloudflare 502 page (expected) whose address bar
#    holds ?code=... — paste that whole URL (or just the code) at the prompt.
~/.local/share/zoom-chat-notifier/venv/bin/python ~/.local/bin/zoom-chat-notifier --authorize
```

You should see `authorized -- refresh token saved`. **You can now kill the
tunnel for good.** The authorization persists (it's what lets the app see your
chat events); the daemon never needs the redirect again.

---

## 4. Run it

```bash
systemctl --user enable --now zoom-chat-notifier   # start + autostart with session
systemctl --user status  zoom-chat-notifier
journalctl --user -u zoom-chat-notifier -f         # follow logs
```

Service management:

```bash
systemctl --user restart zoom-chat-notifier   # after editing env or the script
systemctl --user stop    zoom-chat-notifier
systemctl --user disable zoom-chat-notifier   # stop autostarting
```

---

## 5. Test

Run it in the foreground with debug to watch raw events:

```bash
ZOOM_DEBUG=1 ~/.local/share/zoom-chat-notifier/venv/bin/python ~/.local/bin/zoom-chat-notifier
```

A healthy start logs `connecting to Zoom websocket` then `connected`, and then
stays quiet (the connection is held open with 30s heartbeats). When a chat
arrives you'll see a `RAW EVENT:` dump, a `chat from <name>: '<text>'` line, and
a desktop popup.

**Note:** messages *you* send are intentionally suppressed (the
`ZOOM_MY_EMAIL` echo filter), so messaging yourself won't pop. To test solo,
temporarily blank `ZOOM_MY_EMAIL` and restart — otherwise have someone DM you.

Confirm the notification pipe itself works independently:

```bash
notify-send "test" "does this pop?"
```

---

## 6. Troubleshoot

| Symptom | Cause | Fix |
|---|---|---|
| `KeyError('ZOOM_CLIENT_ID')` | env not loaded | Run via the venv python (auto-loads the env file) or `set -a; source ~/.config/zoom-chat-notifier/env; set +a` first. Check the file exists and is populated. |
| `build_connection … "success":false,"content":"Invalid Token"` then `1000 Bye` | Wrong token type on the WebSocket | The WS needs a **`client_credentials`** app token (carries `marketplace:write:websocket_connection`), *not* a user refresh-token. The daemon already does this; if you hacked it, restore `grant_type=client_credentials`. |
| `Invalid redirect … (4700)` when saving the app | Zoom rejects `http://` and `localhost`/`127.0.0.1` | Use a public `https` URL via cloudflared — see §3. |
| Connects, immediately `1000 Bye` | usually a bad/expired token, or a second connection stealing the same `subscriptionId` | Make sure only one instance runs (`systemctl --user status`), and that the token request returns 200. |
| Connected but no popups on incoming chats | events not flowing, or notif daemon issue | Confirm with `ZOOM_DEBUG=1` whether `RAW EVENT:` lines appear. If yes → check `notify-send` works. If no → re-check the event subscription has "Chat Message Sent" and the app is authorized (`--authorize`). |
| Token request returns 4xx | bad client id/secret, or app not activated | Re-copy credentials; ensure the app is activated in the Marketplace. |
| Channel messages format oddly | `channel_name` field assumption | Grab a channel `RAW EVENT:` with `ZOOM_DEBUG=1` and adjust `handle_event()` in the daemon. |

### Key gotchas (learned the hard way)

- **WebSocket token ≠ user token.** Even for a user-managed General app, the WS
  connection authenticates with the `client_credentials` grant
  (`Authorization: Basic base64(client_id:client_secret)`), per
  [Zoom's WebSocket docs](https://developers.zoom.us/docs/api/websockets/). The
  user-OAuth authorization is separate — it grants the app access to *your*
  events; it does not authenticate the socket.
- **Redirect URLs must be public `https`.** `localhost` is rejected outright now.
- **`subscriptionId` is the bare id**, not the full `wss://…` URL (daemon
  tolerates both, but the env should hold the bare id).
