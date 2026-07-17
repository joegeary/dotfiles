---@module 'hl'

-- https://wiki.hyprland.org/Configuring/Binds/

--######################################

-- WINDOW TILING

--######################################

-- Close window
hl.bind("SUPER + Q", hl.dsp.window.close())

-- Tiling controls
hl.bind("SUPER + Y", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + SHIFT + Y", hl.dsp.window.pseudo())

-- dwindle
hl.bind("SUPER + SHIFT + F", hl.dsp.window.float())
hl.bind("SUPER + CTRL + F", hl.dsp.window.fullscreen())

-- Switch workspaces with SUPER + [0-9]
hl.bind("SUPER + code:10", hl.dsp.focus({ workspace = 1 }))
hl.bind("SUPER + code:11", hl.dsp.focus({ workspace = 2 }))
hl.bind("SUPER + code:12", hl.dsp.focus({ workspace = 3 }))
hl.bind("SUPER + code:13", hl.dsp.focus({ workspace = 4 }))
hl.bind("SUPER + code:14", hl.dsp.focus({ workspace = 5 }))
hl.bind("SUPER + code:15", hl.dsp.focus({ workspace = 6 }))
hl.bind("SUPER + code:16", hl.dsp.focus({ workspace = 7 }))
hl.bind("SUPER + code:17", hl.dsp.focus({ workspace = 8 }))
hl.bind("SUPER + code:18", hl.dsp.focus({ workspace = 9 }))
hl.bind("SUPER + code:19", hl.dsp.focus({ workspace = 10 }))

-- Move focus with SUPER + hjkl
hl.bind("SUPER + H", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "down" }))

-- Move active window to a workspace with SUPER + SHIFT + [0-9]
hl.bind("SUPER + SHIFT + code:10", hl.dsp.window.move({ workspace = 1 }))
hl.bind("SUPER + SHIFT + code:11", hl.dsp.window.move({ workspace = 2 }))
hl.bind("SUPER + SHIFT + code:12", hl.dsp.window.move({ workspace = 3 }))
hl.bind("SUPER + SHIFT + code:13", hl.dsp.window.move({ workspace = 4 }))
hl.bind("SUPER + SHIFT + code:14", hl.dsp.window.move({ workspace = 5 }))
hl.bind("SUPER + SHIFT + code:15", hl.dsp.window.move({ workspace = 6 }))
hl.bind("SUPER + SHIFT + code:16", hl.dsp.window.move({ workspace = 7 }))
hl.bind("SUPER + SHIFT + code:17", hl.dsp.window.move({ workspace = 8 }))
hl.bind("SUPER + SHIFT + code:18", hl.dsp.window.move({ workspace = 9 }))
hl.bind("SUPER + SHIFT + code:19", hl.dsp.window.move({ workspace = 10 }))

-- Swap active window with the one next to it with SUPER + SHIFT + hjkl
hl.bind("SUPER + SHIFT + H", hl.dsp.window.swap({ direction = "left" }))
hl.bind("SUPER + SHIFT + L", hl.dsp.window.swap({ direction = "right" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.swap({ direction = "up" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.swap({ direction = "down" }))

-- Cycle through applications on active workspace
hl.bind("SUPER + Tab", hl.dsp.window.cycle_next())
-- TODO: manual review (unknown dispatcher: Reveal active window on top)
-- hl.bind("SUPER + Tab", hl.dsp.Reveal active window on top("bringactivetotop"))

-- Resize active window
-- TODO: manual review (unknown dispatcher: Expand window left)
-- hl.bind("SUPER + minus", hl.dsp.Expand window left("resizeactive", "-100 0"))
-- TODO: manual review (unknown dispatcher: Shrink window left)
-- hl.bind("SUPER + equal", hl.dsp.Shrink window left("resizeactive", "100 0"))
-- TODO: manual review (unknown dispatcher: Shrink window up)
-- hl.bind("SUPER + SHIFT + minus", hl.dsp.Shrink window up("resizeactive", "0 -100"))
-- TODO: manual review (unknown dispatcher: Expand window down)
-- hl.bind("SUPER + SHIFT + equal", hl.dsp.Expand window down("resizeactive", "0 100"))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

--######################################
-- MEDIA KEYS
--######################################

-- Noctalia owns the OSD and targets the focused monitor itself
local noct = "qs -c noctalia-shell ipc call"

-- Laptop multimedia keys for volume and LCD brightness (with OSD)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(noct .. " volume increase"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(noct .. " volume decrease"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(noct .. " volume muteOutput"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(noct .. " volume muteInput"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(noct .. " brightness increase"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noct .. " brightness decrease"), { locked = true })

-- Media controls (Noctalia talks to MPRIS players)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(noct .. " media next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(noct .. " media playPause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(noct .. " media playPause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(noct .. " media previous"), { locked = true })

--######################################
-- UTILITIES
--######################################

-- Menus (Noctalia)
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(noct .. " launcher toggle"))
hl.bind("SUPER + ALT + SPACE", hl.dsp.exec_cmd(noct .. " controlCenter toggle"))
hl.bind("SUPER + GRAVE", hl.dsp.exec_cmd(noct .. " sessionMenu toggle"))
hl.bind("SUPER + PERIOD", hl.dsp.exec_cmd(noct .. " launcher emoji"))
hl.bind("SUPER + V", hl.dsp.exec_cmd(noct .. " launcher clipboard"))

-- Lock screen (Noctalia)
hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd(noct .. " lockScreen lock"))

-- Notifications (Noctalia)
hl.bind("SUPER + COMMA", hl.dsp.exec_cmd(noct .. " notifications dismissOldest"))
hl.bind("SUPER + SHIFT + COMMA", hl.dsp.exec_cmd(noct .. " notifications dismissAll"))
hl.bind("SUPER + CTRL + COMMA", hl.dsp.exec_cmd(noct .. " notifications toggleDND"))
hl.bind("SUPER + I", hl.dsp.exec_cmd('w="$(hyprctl -j activewindow)"; notify-send "Window" "$w"; wl-copy "$w"'))

-- Toggle nightlight (Noctalia)
hl.bind("SUPER + CTRL + N", hl.dsp.exec_cmd(noct .. " nightLight toggle"))

-- Screen Capture
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("pkill hyprpicker || hyprpicker -an"))
hl.bind("SUPER + P", hl.dsp.exec_cmd("$HOME/.local/bin/screenshot s"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("$HOME/.local/bin/screenshot m"))
hl.bind("SUPER + CTRL + P", hl.dsp.exec_cmd("$HOME/.local/bin/screenshot p"))
hl.bind("SUPER + O", hl.dsp.exec_cmd("$HOME/.local/bin/screenshot sc"))

-- Screen Recording
hl.bind("SUPER + ALT + P", hl.dsp.exec_cmd("$HOME/.local/bin/screenrecord"))
hl.bind("SUPER + CTRL + ALT + P", hl.dsp.exec_cmd("$HOME/.local/bin/screenrecord output"))

-- Plugins
hl.bind("SUPER + D", hl.dsp.exec_cmd("wayscriber --daemon-toggle"))
--pkill -SIGUSR1 wayscriber
-- bindd = SUPER CTRL, TAB, Hyprexpo plugin, hyprexpo:expo, toggle

--######################################
-- APPLICATIONS
--######################################

local pypr = pypr
local term = "kitty"
local browser = "firefox"

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + SHIFT + RETURN", hl.dsp.exec_cmd("kitty -e tmux"))
hl.bind("SUPER + C", hl.dsp.exec_cmd("gnome-calculator"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("kitty -e yazi"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("firefox --private-window"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("pypr toggle tuxedo"))
hl.bind("SUPER + T", hl.dsp.exec_cmd("pypr toggle taskmon"))
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("pypr toggle gpumon"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("obsidian"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("spotify"))
hl.bind("SUPER + slash", hl.dsp.exec_cmd("bitwarden-desktop"))

--######################################
-- AUTO-CLICKER
--######################################
-- SUPER + =        : "jump & stay" mode   (press again to pause)
-- SUPER + SHIFT + =: "jump, click, return" mode (press again to pause)
-- SUPER + CTRL + = : re-capture the click spot from the current cursor position
-- Hitting the other mode key while running switches modes live.
local clicker = "$HOME/.local/bin/auto-clicker"
hl.bind("SUPER + EQUAL", hl.dsp.exec_cmd(clicker .. " stay"))
hl.bind("SUPER + SHIFT + EQUAL", hl.dsp.exec_cmd(clicker .. " return"))
hl.bind("SUPER + CTRL + EQUAL", hl.dsp.exec_cmd(clicker .. " set-spot --delay 0"))
