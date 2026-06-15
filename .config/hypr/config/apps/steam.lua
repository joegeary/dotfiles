---@module 'hl'

-- Float Steam
hl.window_rule({
    name  = "float_steam",
    match = {
        class = "steam",
    },
    float = true
})

hl.window_rule({
    name  = "center_on",
    match = {
        title = "Steam",
    },
    center = true,
})

hl.window_rule({
    name  = "size_460_800",
    match = {
        title = "Friends List",
    },
    size = "460 800",
})
