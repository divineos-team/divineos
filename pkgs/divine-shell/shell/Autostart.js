.pragma library

// Settings > Startup Apps: the XDG autostart entries systemd's xdg-autostart-generator starts
// (hyprland.lua starts xdg-desktop-autostart.target). ~/.config/autostart/NAME.desktop
// overrides /etc/xdg/autostart/NAME.desktop. Checked by ../test-js.mjs.

// The [Desktop Entry] keys of a .desktop file (unlocalised; first one wins).
function fields(text) {
    const keys = {};
    let main = false;
    for (const line of text.split("\n")) {
        if (line.startsWith("["))
            main = line.trim() === "[Desktop Entry]";
        else if (main && line.includes("=")) {
            const key = line.slice(0, line.indexOf("=")).trim();
            if (!(key in keys))
                keys[key] = line.slice(line.indexOf("=") + 1).trim();
        }
    }
    return keys;
}

// "== PATH\n<file>" blocks → [{ file, name, icon, on, own }] by name: what this desktop
// (XDG_CURRENT_DESKTOP) would start. `own` entries exist only in ~/.config/autostart.
function entries(text, desktop) {
    const system = new Set(), byFile = {};
    for (const block of text.split(/^== /m).slice(1)) {
        const path = block.slice(0, block.indexOf("\n")).trim();
        const file = path.slice(path.lastIndexOf("/") + 1);
        const user = !path.startsWith("/etc/");
        if (!user)
            system.add(file);
        if (user || !byFile[file]) // the user's copy wins
            byFile[file] = fields(block.slice(block.indexOf("\n") + 1));
    }
    const lists = (value, name) => (value ?? "").split(";").includes(name);
    return Object.entries(byFile).filter(([, f]) => f.Type === "Application" && f.NoDisplay !== "true" && (!f.OnlyShowIn || lists(f.OnlyShowIn, desktop)) && !lists(f.NotShowIn, desktop)).map(([file, f]) => ({
        file,
        name: f.Name ?? file.replace(/\.desktop$/, ""),
        icon: f.Icon ?? "",
        on: f.Hidden !== "true" && f["X-GNOME-Autostart-enabled"] !== "false",
        own: !system.has(file)
    })).sort((a, b) => a.name.localeCompare(b.name));
}
