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

-- fixes the annotate toolbar tiling itself into the layout and stealing focus
hl.window_rule({
    name  = "zoom_annotate_toolbar_no_steal",
    match = {
        class         = "^(zoom)$",
        initial_title = "^(annotate_toolbar)$",
    },
    float            = true,
    no_focus         = true,
    no_initial_focus = true,
    no_blur          = true,
})

-- fixes the audio/mic change message tiling itself into the layout instead of
-- floating as a popover. the main window and meeting window carry an
-- initial_title of "Zoom Workplace"/"Meeting", so matching initial_title "zoom"
-- targets just these transient message reminders.
hl.window_rule({
    name  = "zoom_message_reminder_float",
    match = {
        class         = "^(zoom)$",
        initial_title = "^(zoom)$",
    },
    float            = true,
    no_initial_focus = true,
})
