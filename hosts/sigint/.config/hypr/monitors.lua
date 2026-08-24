-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Known wart of the vertical offset below, worth writing down because it cost a
-- long afternoon: Hyprland's XWayland advertises BOTH monitors at y=0 to X11
-- clients regardless of their real vertical offset (verified against
-- XRRGetMonitors, XRRGetCrtcInfo and XineramaQueryScreens, which agree with each
-- other and disagree with `hyprctl monitors`). XWayland's screen is also the
-- bounding box of all outputs, so a negative position here means X coordinates
-- differ from Hyprland's by that offset. Neither detail is worth giving up a
-- centered layout for: XWayland apps that misplace their own windows do so
-- because of their own geometry math, not because of this. See
-- ~/.local/bin/zoom-share-rescue, which measures the live offset rather than
-- assuming one.

-- Monitor A: DP-3 (Left, 2560x1440 @ 165Hz, Normal Orientation)
-- Positioned at the top-left (0x0)
hl.monitor({
  output = "DP-3",
  mode = "2560x1440@165",
  position = "0x0",
  scale = 1,
  transform = 0
})

-- Monitor B: HDMI-A-1 (Right, 1920x1080 @ 60Hz, Rotated 90deg CW)
-- Positioned immediately to the right of DP-3 (X=2560)
-- Y position is calculated (-305) to vertically center Monitor A relative to Monitor B's effective height after rotation
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@60",
    position = "2560x-305",
    scale    = 1,
    transform = 3,
})

-- --- Workspace Assignment ---

hl.workspace_rule({
    workspace = "1",
    monitor = "DP-3",
    default_name = "一",
})

hl.workspace_rule({
    workspace = "2",
    monitor = "HDMI-A-1",
    default_name = "二",
})

hl.workspace_rule({
    workspace = "3",
    monitor = "DP-3",
    default_name = "三",
})

hl.workspace_rule({
    workspace = "4",
    monitor = "HDMI-A-1",
    default_name = "四",
})

hl.workspace_rule({
    workspace = "5",
    monitor = "DP-3",
    default_name = "五",
})

hl.workspace_rule({
    workspace = "6",
    monitor = "HDMI-A-1",
    default_name = "六",
})

hl.workspace_rule({
    workspace = "7",
    monitor = "DP-3",
    default_name = "七",
})

hl.workspace_rule({
    workspace = "8",
    monitor = "HDMI-A-1",
    default_name = "八",
})

hl.workspace_rule({
    workspace = "9",
    monitor = "DP-3",
    default_name = "九",
})

hl.workspace_rule({
    workspace = "10",
    monitor = "HDMI-A-1",
    default_name = "十",
})

