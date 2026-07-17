# https://wiki.hyprland.org/Configuring/Environment-variables/

# Better screen sharing support 
hl.env("XDG_CURRENT_DESKTOP","Hyprland")
hl.env("XDG_SESSION_TYPE","wayland")
hl.env("XDG_SESSION_DESKTOP","Hyprland")

# Force all apps to use Wayland
hl.env("GDK_BACKEND","wayland,x11,*")
hl.env("QT_QPA_PLATFORM","wayland")
hl.env("SDL_VIDEODRIVER","wayland")
hl.env("MOZ_ENABLE_WAYLAND","1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT","wayland")
hl.env("OZONE_PLATFORM","wayland")
hl.env("XDG_SESSION_TYPE","wayland")

# cursor
hl.env("HYPRCURSOR_THEME","macOS")
hl.env("HYPRCURSOR_SIZE","24")
hl.env("XCURSOR_THEME","macOS")
hl.env("XCURSOR_SIZE","24")
hl.env("QT_CURSOR_THEME","macOS")
hl.env("QT_CURSOR_SIZE","24")

# GDK
# hl.env("GDK_BACKEND","wayland")
# hl.env("GDK_SCALE","1")

# misc
# hl.env("bitdepth","10")
# hl.env("MOZ_ENABLE_WAYLAND","1")
# hl.env("SLURP_ARGS"," -d -b 00000066 -c ff0000 -F "Atkinson Hyperlegible"")

