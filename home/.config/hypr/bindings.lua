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

-- Omarchy spends SUPER + CTRL + *Z on its cursor magnifier, which only zooms in
-- and resets with no zoom out. Leave those keys unbound.
hl.unbind("SUPER + CTRL + Z")        -- was "Zoom in"
hl.unbind("SUPER + CTRL + ALT + Z")  -- was "Reset zoom"
