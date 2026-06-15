---@module 'hl'

-- See https://wiki.hyprland.org/Configuring/Monitors/

-- Monitor A: DP-3 (Left, 2560x1440 @ 165Hz, Normal Orientation)
-- Positioned at the top-left (0x0)
hl.monitor({
    output   = "DP-3",
    mode     = "2560x1440@165",
    position = "0x0",
    scale    = 1,
    transform = 0,
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

-- --- Fallback ---

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- --- Workspace Assignment ---

hl.workspace_rule({
    workspace = 1,
    monitor = "DP-3",
})

hl.workspace_rule({
    workspace = 2,
    monitor = "HDMI-A-1",
})

hl.workspace_rule({
    workspace = 3,
    monitor = "DP-3",
})

hl.workspace_rule({
    workspace = 4,
    monitor = "HDMI-A-1",
})

hl.workspace_rule({
    workspace = 5,
    monitor = "DP-3",
})

hl.workspace_rule({
    workspace = 6,
    monitor = "HDMI-A-1",
})

hl.workspace_rule({
    workspace = 7,
    monitor = "DP-3",
})

hl.workspace_rule({
    workspace = 8,
    monitor = "HDMI-A-1",
})

hl.workspace_rule({
    workspace = 9,
    monitor = "DP-3",
})

hl.workspace_rule({
    workspace = 10,
    monitor = "HDMI-A-1",
})
