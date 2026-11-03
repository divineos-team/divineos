-- divineDE compositor defaults (Hyprland 0.57+ Lua config).
-- Option reference: https://wiki.hypr.land/configuring/

local terminal = "kitty"
local mod      = "SUPER"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 }) -- 100%; Settings → Displays changes it

-- VMware: Hyprland can't import GPU buffers from VMware's vmwgfx driver and disconnects every
-- GPU-rendered app ("invalid arguments for wl_surface.attach", hyprwm/Hyprland discussion
-- #12966). There, apps render on the CPU instead. Hyprland keeps the GPU, which is why this
-- prefixes commands rather than using hl.env (that reaches Hyprland itself).
local vmware = pcall(function()
    local f = assert(io.open("/sys/class/dmi/id/sys_vendor"))
    local vendor = f:read("*l")
    f:close()
    assert(vendor == "VMware, Inc.")
end)
local app = vmware and "env LIBGL_ALWAYS_SOFTWARE=1 " or "" -- prefix for commands that open windows

hl.on("hyprland.start", function()
    -- apps launched from the dock and launcher inherit the shell's environment
    hl.exec_cmd(app .. "qs -p /usr/share/divine-shell") -- wallpaper, menu bar, Control Center, launcher
    -- the polkit password dialog runs as a user service, so it gets the variable from systemd
    hl.exec_cmd((vmware and "systemctl --user set-environment LIBGL_ALWAYS_SOFTWARE=1; " or "")
        .. "systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hypridle") -- locks after 5 idle minutes and before sleep (hypridle.conf)
    hl.exec_cmd("wl-paste --watch cliphist store") -- clipboard history (Super+Shift+V)
    -- Settings > Startup Apps: systemd starts ~/.config/autostart and /etc/xdg/autostart entries
    hl.exec_cmd("systemctl --user start xdg-desktop-autostart.target")
end)

hl.env("XCURSOR_THEME", "divineOS") -- divine-cursors
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-------------------------------------------------------------------------------
-- Look: liquid glass. Every translucent surface (windows, launcher, and later
-- the divineDE shell) is refracted by the compositor's acrylic lens, so apps
-- only need a transparent background to become glass.
-------------------------------------------------------------------------------
hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 14,
        border_size = 1,
        col = {
            active_border   = "rgba(ffffff59)",
            inactive_border = "rgba(ffffff1a)",
        },
        layout = "dwindle",
    },

    decoration = {
        rounding       = 22,
        rounding_power = 4, -- >2 approaches Apple-style continuous corners

        shadow = {
            enabled      = true,
            range        = 30,
            render_power = 3,
            color        = 0x40000000,
        },

        blur = {
            enabled    = true,
            variant    = "acrylic",
            size       = 8,
            passes     = 3,
            vibrancy   = 0.25,
            noise      = 0.01,
            contrast   = 1.0,
            brightness = 1.0,
            popups     = true,
            acrylic = {
                refraction = 24,    -- lens displacement at the edge, px
                bulb       = 48,    -- width of the curved rim, px
                clarity    = 0.82,
                aberration = 0.02,  -- chromatic split along the rim
                tint       = 0x14EEF5FF,
            },
        },
    },

    animations = { enabled = true },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        touchpad     = { natural_scroll = true },
    },

    dwindle = { preserve_split = true },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },
})

-- Touchpad: swipe between workspaces (Settings > Mouse & Touchpad changes the fingers).
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Motion: springs for windows, quick fades for overlays.
hl.curve("glass",        { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })

hl.animation({ leaf = "global",     enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "windows",    enabled = true, speed = 4.79, spring = "glass" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4.1,  spring = "glass",        style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "layersIn",   enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",  enabled = true, speed = 1.5,  bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4,    spring = "glass",        style = "slide" })

-- Settings, the Store, System Monitor, Welcome, Mark Up and the installer float instead of tiling.
hl.window_rule({
    name  = "divine-utility-windows",
    match = { title = "^(System Monitor|Settings|Store|Welcome|Mark Up|Install divineOS)$" },
    float = true,
})

-- divine-shell glass panels: blur only where tiles are drawn, pop in like macOS.
hl.layer_rule({
    match        = { namespace = "^divine-(cc|launcher|dock|taskbar|widgets|nc|notifications|osd|switcher|overview|capture)$" },
    blur         = true,
    ignore_alpha = 0.15,
    animation    = "popin 90%",
})

-------------------------------------------------------------------------------
-- Keys
-------------------------------------------------------------------------------
hl.bind(mod .. " + Return",    hl.dsp.exec_cmd(app .. terminal))
hl.bind(mod .. " + E",         hl.dsp.exec_cmd(app .. "devine-files"))
hl.bind(mod .. " + space",     hl.dsp.global("divine:launcher"))
hl.bind(mod .. " + C",         hl.dsp.global("divine:control-center"))
hl.bind(mod .. " + M",         hl.dsp.global("divine:monitor"))
hl.bind(mod .. " + comma",     hl.dsp.global("divine:tweaks"))
hl.bind(mod .. " + N",         hl.dsp.global("divine:notifications"))
hl.bind(mod .. " + L",         hl.dsp.global("divine:lock"))
hl.bind(mod .. " + Q",         hl.dsp.window.close())
hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + V", hl.dsp.global("divine:clipboard"))
hl.bind(mod .. " + Tab",       hl.dsp.global("divine:overview"))
hl.bind("Print",               hl.dsp.global("divine:capture"))
-- App switcher: Alt+Tab steps through apps, letting go of Alt switches.
hl.bind("ALT + Tab",         hl.dsp.global("divine:switcher"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.global("divine:switcher-back"))
hl.bind("ALT + Alt_L",       hl.dsp.global("divine:switcher-commit"), { release = true })
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))

hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.global("divine:brightness-up"),                             { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("divine:brightness-down"),                           { locked = true, repeating = true })

-- Choices made in Settings (displays, windows, glass, motion, pointer, keyboard). Loaded last so they win; the
-- file doesn't exist until the first change, hence pcall.
pcall(require, "tweaks")
