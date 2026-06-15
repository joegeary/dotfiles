---@module 'hl'

-- Define terminal tag to style them uniformly
hl.window_rule({
    name  = "tag__terminal",
    match = {
        class = "(Alacritty|kitty|com.mitchellh.ghostty)",
    },
    tag = "+terminal"
})
