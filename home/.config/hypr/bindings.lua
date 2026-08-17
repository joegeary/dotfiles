-- Personal keybinding overrides, loaded after Omarchy's defaults.
-- Unbind before rebinding. List current bindings:
--   omarchy menu keybindings --print

hl.unbind("SUPER + W")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

hl.unbind("SUPER + P")
o.bind("SUPER + P", "Screenshot", "omarchy-capture-screenshot")
