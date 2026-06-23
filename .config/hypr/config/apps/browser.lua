---@module 'hl'

-- Browser types
hl.window_rule({
    name  = "tag_chromium",
    match = {
        class = "([cC]hrom(e|ium)|[bB]rave-browser|Microsoft-edge|Vivaldi-stable)",
    },
    tag = "+chromium-based-browser"
})

hl.window_rule({
    name  = "tag__firefox",
    match = {
        class = "([fF]irefox|zen|librewolf)",
    },
    tag = "+firefox-based-browser"
})

-- Force chromium-based browsers into a tile to deal with --app bug
hl.window_rule({
    name  = "tile_on",
    match = {
        tag = "chromium-based-browser",
    },
    tile = true
})

-- Only a subtle opacity change, but not for video sites
hl.window_rule({
    name  = "opacity_chromium",
    match = {
        tag = "chromium-based-browser",
    },
    opacity = "1 1",
})

hl.window_rule({
    name  = "opacity_firefox",
    match = {
        tag = "firefox-based-browser",
    },
    opacity = "1 1",
})

-- Some video sites should never have opacity applied to them
hl.window_rule({
    name  = "opacity_1_0_1_0",
    match = {
        initial_title = "((?i)(?:[a-z0-9-]+\\.)*youtube\\.com_/|app\\.zoom\\.us_/wc/home)",
    },
    opacity = "1.0 1.0",
})
