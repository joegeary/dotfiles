---@module 'hl'

-- See https://wiki.hyprland.org/Configuring/Window-Rules/ for more

hl.window_rule({
    name  = "suppress-maximize-events",
    match = {
        class = ".*",
    },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-dragging",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

-- App-specific tweaks
local bitwarden = require("config.apps.bitwarden")
local browser = require("config.apps.browser")
local hyprshot = require("config.apps.hyprshot")
local localsend = require("config.apps.localsend")
local networkmanager = require("config.apps.networkmanager")
local pip = require("config.apps.pip")
local qemu = require("config.apps.qemu")
local runelite = require("config.apps.runelite")
local steam = require("config.apps.steam")
local system = require("config.apps.system")
local system = require("config.apps.system")
local terminals = require("config.apps.terminals")
local virtmanager = require("config.apps.virt-manager")
local zoom = require("config.apps.zoom")
