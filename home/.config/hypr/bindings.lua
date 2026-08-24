-- Personal keybinding overrides, loaded after Omarchy's defaults.
-- Unbind before rebinding. List current bindings:
--   omarchy menu keybindings --print

hl.unbind("SUPER + W")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

hl.unbind("SUPER + P")
o.bind("SUPER + P", "Screenshot", "omarchy-capture-screenshot")

-- --- Zoom window rules ------------------------------------------------------
-- Carried over from the pre-Omarchy config, where they were worked out against
-- this same app. All of these target *managed* windows, which is why ordinary
-- window rules work on them, unlike the screen-share toolbar below.

-- Fixes the audio/mic change message tiling itself into the layout instead of
-- floating as a popover. The main and meeting windows carry an initial_title of
-- "Zoom Workplace"/"Meeting", so matching initial_title "zoom" hits just these
-- transient message reminders.
o.window({ class = "^(zoom)$", initial_title = "^(zoom)$" }, {
  float = true,
  no_initial_focus = true,
})

-- Fixes the annotate toolbar tiling itself into the layout and stealing focus.
o.window({ class = "^(zoom)$", initial_title = "^(annotate_toolbar)$" }, {
  float = true,
  no_focus = true,
  no_initial_focus = true,
  no_blur = true,
})

-- Fixes disappearing windows like emoji and giphy pickers. Deliberately not
-- scoped to class zoom: that is how it was proven to work before, and
-- "(menu window)" is distinctive enough not to catch anything else.
o.window({ initial_title = "(menu window)" }, { stay_focused = true })

-- Stops the main window grabbing focus the moment it appears.
o.window({ title = "^(Zoom Workplace)$" }, { no_initial_focus = true })

-- Reclaim SUPER + *Z for Zoom. Omarchy spends them on the cursor magnifier,
-- which only zooms in and resets, with no zoom out.
hl.unbind("SUPER + CTRL + Z")        -- was "Zoom in"
hl.unbind("SUPER + CTRL + ALT + Z")  -- was "Reset zoom"

-- Zoom's screen-share toolbar is an override-redirect window that Hyprland
-- renders but never hit-tests, so clicks fall through to whatever is underneath
-- and the bar is dead wherever any other window sits below it. Nothing repairs
-- that from outside the compositor: not window rules, not hyprctl, not
-- synthetic clicks. So there are two escapes, and both get a key.
--
-- Toggle gets rid of it, for when the meeting window is up and the bar is purely
-- in the way. Full writeup in install/SERVICES.md.
o.bind("SUPER + Z", "Toggle Zoom share toolbar", "zoom-share-rescue toggle")

-- Align makes it usable instead: it butts the self-view's bottom edge against
-- the bar's top edge, which lets the pointer enter the bar already held by a
-- Zoom surface, the one approach that reliably lands a click. Needed once per
-- share, because Zoom re-places the self-view from scratch every time.
o.bind("SUPER + SHIFT + Z", "Align Zoom share toolbar", "zoom-share-rescue align")

-- ydotoold's virtual pointer is relative-only (EV_REL, no EV_ABS), so
-- `ydotool mousemove --absolute` is emulated with one large relative delta.
-- Under libinput's default adaptive curve that delta gets accelerated, and since
-- large jumps saturate the curve the pointer reliably lands at about double the
-- requested coordinate. A flat profile makes the mapping 1:1, which is what
-- ~/.local/bin/zoom-share-rescue needs to click Zoom's screen-share toolbar (see
-- install/SERVICES.md). Scoped to this device so real mice keep their accel.
--
-- Lives in this file only because it is the sole hypr config Omarchy loads that
-- this repo owns; hyprland.lua and input.lua are Omarchy's and get overwritten.
hl.device({
  name = "ydotoold-virtual-device-1",
  accel_profile = "flat",
  sensitivity = 0,
})
