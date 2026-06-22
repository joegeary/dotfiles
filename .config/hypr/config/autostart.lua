---@module 'hl'

-- https://wiki.hyprland.org/Configuring/Keywords/#executing
-- https://wiki.hyprland.org/Hypr-Ecosystem/xdg-desktop-portal-hyprland/

-- fuck bluetooth
-- exec-once = rfkill block bluetooth; bluetoothctl power off

-- Autostart
hl.on("hyprland.start", function()
    -- core components 
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- bring up graphical-session.target so xdg-desktop-portal can start
    -- (the portal units have Requisite=graphical-session.target; without this,
    --  screensharing fails: Firefox NotAllowedError, Chrome tab-only capture)
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- noctalia shell: bar, notifications, OSD, idle, lock, wallpaper, launcher
    hl.exec_cmd("qs -c noctalia-shell")

    -- hyprland plugins
    hl.exec_cmd("pypr") 

    -- keyring daemon
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")

    -- polkit authentication daemon (native hyprland agent)
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

    -- automounter for removable media
    hl.exec_cmd("udiskie --file-manager=yazi")

    -- cursor
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme macOS")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")
    hl.exec_cmd("hyprctl setcursor catppuccin-macchiato-lavendar-curs 24")

    -- clipboard
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- system tray applets
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("blueman-applet")
    
    --hl.exec_cmd("gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal kitty")
end)

-- Exec (run every reload)
hl.on("config.reloaded", function()
    -- disable startup animation
    hl.exec_cmd("sleep 1 && hyprctl keyword animations:enabled true")

    -- GTK
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme catppuccin-mocha")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Tela-circle-dracula")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
end)
