---@module 'hl'

hl.window_rule({
    name  = "bitwarden_noscreenshare",
    match = {
        class = "^(Bitwarden)$",
    },
    no_screen_share = true,
})
