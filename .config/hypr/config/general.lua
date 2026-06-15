---@module 'hl'

-- https://wiki.hyprland.org/Configuring/Variables/

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        gaps_workspaces = 50,
        border_size = 1,
        --rgba(0DB7D4FF)
        --rgba(31313600)
        resize_on_border = false,
        no_focus_fallback = true,
        allow_tearing = true,
        -- this just allows the `immediate` window rule to work
        layout = "dwindle",
        snap = {
            enabled = true,
            window_gap = 4,
            monitor_gap = 5,
            respect_gaps = true,
        },
        col = {
            active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
    },
})

hl.config({
    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = false,
        force_split = 2,
        -- always split on the right
    },
})

hl.config({
    decoration = {
        rounding = 4,
        dim_inactive = true,
        dim_strength = 0.025,
        dim_special = 0.07,
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
        shadow = {
            enabled = true,
            range = 2,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
    },
})

hl.config({
    animations = {
        enabled = true,
        -- Curves
        -- Configs
        -- windows
        -- layers
        -- fade
        -- workspaces
        --# specialWorkspace
    },
})

hl.config({
    input = {
        kb_layout = "us",
        numlock_by_default = true,
        repeat_delay = 250,
        repeat_rate = 35,
        follow_mouse = 1,
        off_window_axis_events = 2,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor = 0.5,
        },
    },
})

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        font_family = "JetBrainsMono Nerd Font",
        -- vfr = 1
        -- vrr = 1
        -- mouse_move_enables_dpms = true
        -- key_press_enables_dpms = true
        -- animate_manual_resizes = false
        -- animate_mouse_windowdragging = false
        -- enable_swallow = false
        -- swallow_regex = (foot|kitty|allacritty|Alacritty)
        -- new_window_takes_over_fullscreen = 2
        -- allow_session_lock_restore = true
        -- session_lock_xray = true
        -- initial_workspace_tracking = false
        focus_on_activate = true,
    },
})

hl.config({
    binds = {
        scroll_event_delay = 0,
        hide_special_on_workspace_change = true,
    },
})

-- cursor {

--     zoom_factor = 1

--     zoom_rigid = false

--     hotspot_padding = 1

-- }

-- <<--------------->>

-- <<--< Devices >-->>

-- <<--------------->>

-- $mouse = razor-basilisk-v3

--

-- # mouse

-- device {

--   name = $mouse-1

--   sensitivity = -0.75

-- }

-- device {

--   name = $mouse-2

--   sensitivity = -0.75

-- }

-- hl.plugin("hyprexpo", function()
--     --general 
--     columns = 3,
--     gaps_in = 50,
--     gaps_out = 25,
--     bg_col = "rgb(000000)",
--     workspace_method = "first 1",
--     --borders
--     border_color = "rgb(ffffff)",
--     border_color_current = "rgba(33ccffee) rgba(00ff99ee) 45deg",
--     border_color_focus = "rgba(ffdd44ee) rgba(22aaffee) 30deg",
--     border_color_hover = "rgba(ffffffee) rgba(999999ee) 30deg",
--     --labels
--     label_enable = 1,
--     label_bg_shape = "circle",
--     label_position = "center-center",
--     label_offset_x = 10,
--     label_offset_y = 10,
--     label_color_default = "rgb(ffffff)",
--     label_color_hover = "rgb(eeeeee)",
--     label_scale_hover = 1.0,
--     label_scale_focus = 1.0,
--     label_bg_enable = 1,
--     label_bg_color = "rgba(00000088)",
--     label_bg_rounding = 15,
--     -- label_padding = 1
--     label_font_size = 100,
--     label_font_family = "Sans",
--     label_font_bold = 1,
--     label_font_italic = 0,
--     label_text_underline = 0,
--     label_text_strikethrough = 0,
-- end)
