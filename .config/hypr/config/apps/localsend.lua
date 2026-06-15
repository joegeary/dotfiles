---@module 'hl'

-- Float LocalSend and fzf file picker
hl.window_rule({
    name  = "float_localsend",
    match = {
        class= "(Share|localsend)",
    },
    float = true
})
