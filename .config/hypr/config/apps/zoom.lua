--@module 'hl'

-- # zoom - what a pain in the ass of an app

-- windowrule = float, class:(zoom), title:^(Meeting)$ # start meeting in a floating window

hl.window_rule({
    name  = "no_initial_focus_on",
    match = {
        title = "^(Zoom Workplace)$",
    },
    no_initial_focus = true
})

-- fixes disappearing windows like emoji, giphy
hl.window_rule({
    name  = "stay_focused_on",
    match = {
        initial_title = "(menu window)",
    },
    stay_focused = true
})

-- fixes disappearing menus
-- windowrule = noinitialfocus, class:(zoom), initialTitle: (zoom_linux_float_message_reminder) # fixes notifications from stealing focus
