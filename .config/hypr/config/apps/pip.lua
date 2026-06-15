---@module 'hl'

-- Picture-in-picture overlays
hl.window_rule({
    name  = "tag__pip",
    match = {
        title = "(Picture.?in.?[Pp]icture)",
    },
    tag = "+pip"
})

hl.window_rule({
    name  = "float_pip",
    match = {
        tag = "pip",
    },
    float = true
})
