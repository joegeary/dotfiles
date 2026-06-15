---@module 'hl'

-- Floating windows
hl.window_rule({
    name  = "float_tag_floating_window",
    match = {
        tag = "floating-window",
    },
    float = true
})

hl.window_rule({
    name  = "tag__floating-window-classes",
    match = {
        class = "(org.gnome.Calculator|org.pulseaudio.pavucontrol|blueman-manager|org.omarchy.bluetui|org.omarchy.impala|org.omarchy.wiremix|org.omarchy.btop|org.omarchy.terminal|org.omarchy.bash|org.gnome.NautilusPreviewer|org.gnome.Evince|com.gabm.satty|Omarchy|About|TUI.float|imv|mpv)",
    },
    tag = "+floating-window"
})

hl.window_rule({
    name  = "tag__floating-window-titles",
    match = {
        title = "^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[C|c]hoose.*)",
    },
    tag = "+floating-window"
})

-- No transparency on media windows
hl.window_rule({
    name  = "opacity_media_no_transparency",
    match = {
        class = "^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$",
    },
    opacity = "1 1",
})

-- Popped window rounding
hl.window_rule({
    name  = "rounding_8",
    match = {
        tag = "pop",
    },
    rounding = 8,
})

-- Prevent idle while open
hl.window_rule({
    name  = "idle_inhibit_always",
    match = {
        tag = "noidle",
    },
    idle_inhibit = "always"
})
