-- Personal keybinding overrides, loaded after Omarchy's defaults.
-- Unbind before rebinding. List current bindings:
--   omarchy menu keybindings --print

hl.unbind("SUPER + W")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

hl.unbind("SUPER + P")
o.bind("SUPER + P", "Screenshot", "omarchy-capture-screenshot")

-- --- Zoom window rules ------------------------------------------------------
-- Native Wayland Zoom (zoomus.conf xwayland=false). Its share-control toolbar
-- comes up as a managed window titled "as_toolbar" that tiles into the layout
-- instead of floating over the share, so float it. It also opens oversized, so
-- pin it to the toolbar's natural dimensions. Every other transient Zoom surface
-- (reactions picker, dialogs) floats itself under Wayland, so unlike the old
-- XWayland setup none of them need a rule.
o.window({ class = "^(Zoom)$", initial_title = "^(as_toolbar)$" }, {
  float = true,
  size = { 772, 87 },
})

-- Omarchy sets focus_on_activate = true globally (looknfeel.lua), so any window's
-- activation request is honored, even hopping workspaces to reach it. On every
-- notification Zoom fires such a request, dragging you onto its workspace mid-task.
-- Overriding it off for Zoom alone stops the focus/workspace steal while leaving
-- every other app's activation behavior intact (same pattern omarchy uses for
-- Telegram in default/hypr/apps/telegram.lua).
o.window({ class = "^(Zoom)$" }, {
  focus_on_activate = false,
})

-- --- OpenLogi Actions Ring --------------------------------------------------
-- The haptic panel's radial menu is a plain xdg toplevel (app_id
-- openlogi-action-ring). OpenLogi asks to open it centred on the cursor, but a
-- Wayland toplevel cannot place itself, so Hyprland tiled it and the ring drew
-- in a corner of the tile. Float it at its natural 360x360 and centre it on the
-- cursor here instead. Keep keyboard focus on the app underneath: ring actions
-- like Copy and Paste send their shortcut to whatever is focused, so neither
-- opening the ring nor hovering a slot may take focus. The panel is drawn on a
-- transparent surface, so strip the frame, effects and default opacity too.
o.window({ class = "^(openlogi-action-ring)$" }, {
  tag = "-default-opacity",
  float = true,
  pin = true,
  size = { 360, 360 },
  move = { "(cursor_x-(window_w*0.5))", "(cursor_y-(window_h*0.5))" },
  no_initial_focus = true,
  no_follow_mouse = true,
  border_size = 0,
  no_shadow = true,
  no_blur = true,
  no_anim = true,
})

-- --- Android Emulator -------------------------------------------------------
-- The emulator (XWayland, class Emulator) opens a phone-shaped window plus a
-- separate side toolbar it positions itself. Tiled, both get stretched into the
-- layout and the toolbar detaches from the phone, so float them.
o.window({ class = "^(Emulator)$" }, {
  float = true,
})

-- --- Remote Desktop Manager keyboard passthrough ----------------------------
-- RDM runs under XWayland (its launcher forces GDK_BACKEND=x11), so it cannot
-- ask Hyprland to inhibit shortcuts the way a native RDP client would. Every
-- Omarchy bind therefore fires on top of the remote session, and the session
-- only sees half of each chord. Hyprland forwards a bind's modifier press to
-- the window before eating the key, so ALT + TAB or SUPER + 1 hand Windows an
-- Alt or Win key-down, then move focus away before the key-up arrives. Windows
-- keeps that modifier held and every later keystroke turns into Alt+key or
-- Win+key. CTRL + ALT + DELETE is worse: it closes every Linux window.
-- While RDM has focus, switch to a submap holding only the toggle and the
-- SUPER + <number> and SUPER + SHIFT + <number> workspace binds, so the remote
-- session gets the rest of the keyboard. Focusing any other window (mouse
-- click, workspace switch, or the toggle followed by a normal bind) restores
-- the usual binds.
local remote_desktop_class = "RemoteDesktopManager"
local remote_submap = "remote"

local function is_remote_desktop(window)
  return window ~= nil and window.class == remote_desktop_class
end

local function in_default_submap()
  local current = hl.get_current_submap()
  return current == "" or current == "default"
end

-- The session already received the Win press that Hyprland forwards ahead of
-- SUPER + <number>. Switching workspace takes focus away before the key-up, and
-- moving the window keeps focus, so Windows would read the later key-up as a
-- Start menu tap. Release Win inside the session first. The Ctrl tap in
-- between keeps Windows from reading a lone Win press and release as "open the
-- Start menu".
local function release_win_in_remote_session()
  hl.dispatch(hl.dsp.send_key_state({ mods = "", key = "Control_L", state = "down" }))
  hl.dispatch(hl.dsp.send_key_state({ mods = "", key = "Control_L", state = "up" }))
  hl.dispatch(hl.dsp.send_key_state({ mods = "", key = "Super_L", state = "up" }))
end

hl.define_submap(remote_submap, function()
  hl.bind("CTRL + ALT + HOME", hl.dsp.submap("reset"), { description = "Release keyboard from remote session" })

  for workspace = 1, 10 do
    hl.bind("SUPER + code:" .. tostring(workspace + 9), function()
      release_win_in_remote_session()
      hl.dispatch(hl.dsp.focus({ workspace = tostring(workspace) }))
    end, { description = "Switch to workspace " .. workspace })

    hl.bind("SUPER + SHIFT + code:" .. tostring(workspace + 9), function()
      release_win_in_remote_session()
      hl.dispatch(hl.dsp.window.move({ workspace = tostring(workspace) }))
    end, { description = "Move window to workspace " .. workspace })
  end
end)

o.bind("CTRL + ALT + HOME", "Pass keyboard to remote session", function()
  if is_remote_desktop(hl.get_active_window()) then
    hl.dispatch(hl.dsp.submap(remote_submap))
  end
end)

hl.on("window.active", function(window)
  if is_remote_desktop(window) then
    if in_default_submap() then
      hl.dispatch(hl.dsp.submap(remote_submap))
    end
  elseif hl.get_current_submap() == remote_submap then
    hl.dispatch(hl.dsp.submap("reset"))
  end
end)

-- Omarchy spends SUPER + CTRL + *Z on its cursor magnifier, which only zooms in
-- and resets with no zoom out. Leave those keys unbound.
hl.unbind("SUPER + CTRL + Z")        -- was "Zoom in"
hl.unbind("SUPER + CTRL + ALT + Z")  -- was "Reset zoom"
