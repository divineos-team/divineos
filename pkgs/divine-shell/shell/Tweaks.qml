import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Autostart.js" as Autostart
import "Backup.js" as Backup
import "Disks.js" as Disks
import "Printers.js" as Printers

// divineOS Settings (devine-tweaks). Display, window, glass, motion, pointer and keyboard choices
// are written to ~/.config/hypr/tweaks.lua, which hyprland.lua loads last, and Power's to
// ~/.config/hypr/hypridle.conf. Accent, wallpaper, font and dock live in the shell (Sys); GTK
// apps get the same through GSettings. Root-only changes go through polkit-guarded helpers:
// /usr/lib/devine-tweaks/{apply-sysctl,manage-users} and /usr/lib/divine-pkg/pkg-helper (drivers).
// Time settings go through timedated, default apps through gio, Startup Apps through
// ~/.config/autostart (systemd starts those entries at sign-in), VPNs through nmcli, printers
// through CUPS (adding and removing through /usr/lib/devine-tweaks/printers), disks through
// udisks and /usr/lib/devine-tweaks/disks, snapshots through Timeshift (backup and snapshots).
// Toggle: Super+comma, or `devine-tweaks [PAGE]` (IPC).
FloatingWindow {
    id: win

    readonly property string helper: "/usr/lib/devine-tweaks/apply-sysctl"
    readonly property var sinkNodes: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    // Default Apps: what each choice opens; the first type lists the apps that can.
    readonly property var appKinds: [
        ["Web browser", ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"]],
        ["Email", ["x-scheme-handler/mailto"]],
        ["Files and folders", ["inode/directory"]],
        ["Text", ["text/plain"]],
        ["Pictures", ["image/png", "image/jpeg", "image/webp", "image/gif"]],
        ["Video", ["video/mp4", "video/x-matroska", "video/webm"]],
        ["Music", ["audio/mpeg", "audio/flac", "audio/ogg"]],
        ["PDF documents", ["application/pdf"]]
    ]
    // hyprland.lua's animations, for Motion to rescale: [leaf, speed, curve, style]
    readonly property var leaves: [
        ["global", 10, 'bezier = "default"', ""],
        ["windows", 4.79, 'spring = "glass"', ""],
        ["windowsIn", 4.1, 'spring = "glass"', "popin 87%"],
        ["windowsOut", 1.49, 'bezier = "easeOutQuint"', "popin 87%"],
        ["layersIn", 4, 'bezier = "easeOutQuint"', "fade"],
        ["layersOut", 1.5, 'bezier = "easeOutQuint"', "fade"],
        ["workspaces", 4, 'spring = "glass"', "slide"]
    ]
    readonly property var windows: state.windows ?? { gaps: 14, rounding: 22, border: 1 } // hyprland.lua's
    readonly property var pointer: Object.assign({ speed: 0, flat: false, natural: false, leftHanded: false, tap: true, touchNatural: true, typing: true, swipe: 3 }, state.pointer ?? {}) // Hyprland's and hyprland.lua's
    readonly property string autostart: Quickshell.env("HOME") + "/.config/autostart"
    readonly property string pageId: content.pages[content.page]?.id ?? ""
    onPageIdChanged: if (pageId === "backup" && content.rootFs === "btrfs") snapshotsProc.running = true

    function toggle() {
        visible = !visible;
        if (visible)
            refresh();
    }
    function applyTheme(theme) { // for Welcome
        content.applyTheme(theme);
    }
    function show(id) {
        content.show(id);
        visible = true;
        refresh();
    }
    function refresh() {
        monitorsProc.running = true;
        cardsProc.running = true;
        sysctlProc.running = true;
        keyboardProc.running = true;
        timeProc.running = true;
        usersProc.running = true;
        defaultsProc.running = true;
        driversProc.running = true;
        themesProc.running = true;
        startupProc.running = true;
        vpnProc.running = true;
        printersProc.running = true;
        rootFsProc.running = true;
        if (!content.layoutNames.length)
            layoutNamesProc.running = true;
        if (!content.timezones.length)
            zonesProc.running = true;
    }

    // Regenerate tweaks.lua from the saved choices, then let Hyprland pick it up.
    function writeHypr() {
        const q = JSON.stringify; // a JSON string is a valid Lua string for these values
        const lines = ["-- Written by divineOS Settings (devine-tweaks); edits here are overwritten.", "-- Put your own settings in hyprland.lua instead.", ""];
        for (const [name, m] of Object.entries(state.monitors))
            lines.push(`hl.monitor({ output = ${q(name)}, mode = ${q(m.mode)}, position = ${q(m.position)}, scale = ${typeof m.scale === "number" ? m.scale : q("auto")}${m.mirror ? `, mirror = ${q(m.mirror)}` : ""} })`);
        const w = state.windows; // null until Desktop & Dock changes them, so hyprland.lua's stand
        const general = w ? `general = { gaps_in = ${Math.round(w.gaps * 0.43)}, gaps_out = ${w.gaps}, border_size = ${w.border} }, ` : "";
        const rounding = w ? `rounding = ${w.rounding}, ` : "";
        const blur = state.glass === "off" ? "enabled = false" : `enabled = true, variant = ${q(state.glass)}` + (state.blurSize ? `, size = ${state.blurSize}` : "");
        const inputs = state.keyboard ? [`kb_layout = ${q(state.keyboard.layouts.join(","))}`, `kb_options = ${q(state.keyboard.options)}`] : [];
        const p = win.pointer;
        if (state.pointer)
            inputs.push(`sensitivity = ${p.speed}`, `accel_profile = ${q(p.flat ? "flat" : "adaptive")}`, `natural_scroll = ${p.natural}`, `left_handed = ${p.leftHanded}`, `touchpad = { natural_scroll = ${p.touchNatural}, tap_to_click = ${p.tap}, disable_while_typing = ${p.typing} }`);
        const input = inputs.length ? `, input = { ${inputs.join(", ")} }` : "";
        lines.push(`hl.config({ ${general}decoration = { ${rounding}blur = { ${blur} } }, animations = { enabled = ${state.animations} }${input} })`);
        // The macOS and Windows 11 layouts: windows float where they open instead of tiling.
        if (Sys.layout === "macos" || Sys.layout === "windows")
            lines.push(`hl.window_rule({ name = "divine-layout-float", match = { class = ".*" }, float = true })`);
        // hyprland.lua swipes workspaces with 3 fingers.
        if (p.swipe !== 3)
            lines.push(`hl.gesture({ fingers = 3, direction = "horizontal", action = "unset" })`);
        if (p.swipe === 4)
            lines.push(`hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })`);
        // Motion: the same curves and leaves, faster or slower. A spring speeds up by f with
        // f² the stiffness and f the damping (same bounce); a bezier's speed is its duration.
        const f = state.motion;
        if (state.animations && f !== 1) {
            lines.push(`hl.curve("glass", { type = "spring", mass = 1, stiffness = ${+(238.1191 * f * f).toFixed(4)}, damping = ${+(24.21279333 * f).toFixed(4)} })`);
            for (const [leaf, speed, curve, style] of win.leaves)
                lines.push(`hl.animation({ leaf = ${q(leaf)}, enabled = true, speed = ${+(speed / f).toFixed(2)}, ${curve}${style ? `, style = ${q(style)}` : ""} })`);
        }
        // Pointer and icons, for what starts after this (the next sign-in, for the shell).
        if (state.cursor)
            lines.push(`hl.env("XCURSOR_THEME", ${q(state.cursor.theme)})`, `hl.env("XCURSOR_SIZE", "${state.cursor.size}")`, `hl.env("HYPRCURSOR_SIZE", "${state.cursor.size}")`);
        if (state.iconTheme)
            lines.push(`hl.env("QS_ICON_THEME", ${q(state.iconTheme)})`);
        hyprFile.setText(lines.join("\n") + "\n");
        Quickshell.execDetached(["hyprctl", "reload"]);
        reread.restart();
    }

    // Regenerate hypridle.conf from Power's choices; idleFile restarts hypridle once it's saved.
    function writeIdle() {
        const qs = "qs -p /usr/share/divine-shell ipc call";
        const lines = ["# Written by divineOS Settings (Power); edits here are overwritten.", "# divine-shell draws the lock screen; this decides when.", "general {", `    lock_cmd = ${qs} lock lock`, "    before_sleep_cmd = loginctl lock-session", `    after_sleep_cmd = ${qs} screen on`, "    ignore_dbus_inhibit = false", "}"];
        const listener = (seconds, timeout, resume) => {
            if (seconds > 0)
                lines.push("", "listener {", `    timeout = ${seconds}`, `    on-timeout = ${timeout}`, ...(resume ? [`    on-resume = ${resume}`] : []), "}");
        };
        listener(state.idle.lock, "loginctl lock-session");
        listener(state.idle.screen, `${qs} screen off`, `${qs} screen on`);
        listener(state.idle.suspend, "systemctl suspend");
        idleFile.setText(lines.join("\n") + "\n");
    }

    function setMonitor(name, change) {
        const now = content.monitors.find(m => m.name === name);
        if (!now)
            return;
        const saved = state.monitors[name] ?? { mode: now.mode, scale: now.scale, position: now.position };
        if (change.side) { // beside the first display, in its logical (scaled) pixels
            const first = content.monitors[0], size = m => m.mode.split("@")[0].split("x").map(v => Math.round(v / m.realScale));
            const [fw, fh] = size(first), [w, h] = size(now);
            change.position = { left: `-${w}x0`, above: `0x-${h}`, below: `0x${fh}` }[change.side] ?? `${fw}x0`;
            change.mirror = change.side === "mirror" ? first.name : "";
        }
        state.monitors = Object.assign({}, state.monitors, { [name]: Object.assign({}, saved, change) });
        writeHypr();
    }

    function manageUsers(args, password) {
        if (usersOp.running)
            return;
        content.usersStatus = "";
        usersOp.password = password;
        usersOp.command = ["pkexec", "/usr/lib/devine-tweaks/manage-users"].concat(args);
        usersOp.running = true;
    }

    title: "Settings"
    visible: false
    onClosed: visible = false // closing from Hyprland (Super+Q) doesn't clear `visible` by itself
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    minimumSize: Qt.size(780, 580)
    color: Theme.glass

    FileView {
        path: Quickshell.statePath("tweaks.json")
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }
        JsonAdapter {
            id: state
            property string glass: "acrylic"
            property bool animations: true
            property real motion: 1 // animation speed when they're on
            property var windows: null // { gaps, rounding, border }; null keeps hyprland.lua's
            property int blurSize: 0 // 0 keeps hyprland.lua's
            property var cursor: null // { theme, size }
            property string iconTheme: ""
            property var monitors: ({}) // name → { mode, scale, position }
            property var keyboard: null // { layouts[], options }; null keeps hyprland.lua's
            property var pointer: null // Mouse & Touchpad's changes; null keeps hyprland.lua's
            property var idle: ({ lock: 300, screen: 0, suspend: 0 }) // seconds; hypridle.conf's defaults
        }
    }

    FileView {
        id: hyprFile // written only; absent until the first change
        path: Quickshell.env("HOME") + "/.config/hypr/tweaks.lua"
    }

    FileView {
        id: idleFile // replaces the hypridle.conf new accounts start with, once Power changes
        path: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
        onSaved: Quickshell.execDetached(["sh", "-c", "pkill -x hypridle; setsid -f hypridle >/dev/null 2>&1"])
    }

    Timer {
        id: reread // Hyprland applies the reload asynchronously
        interval: 800
        onTriggered: win.refresh()
    }

    Process {
        id: monitorsProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: content.monitors = JSON.parse(text).map(m => ({
                        name: m.name,
                        description: m.description,
                        mode: `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`,
                        scale: state.monitors[m.name]?.scale ?? m.scale,
                        realScale: m.scale,
                        position: `${m.x}x${m.y}`,
                        side: state.monitors[m.name]?.side ?? "right",
                        modes: m.availableModes.map(s => s.replace("Hz", ""))
                    }))
        }
    }

    Process {
        id: cardsProc
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: content.cards = JSON.parse(text || "[]").map(c => ({
                        name: c.name,
                        description: c.properties["device.description"] ?? c.name,
                        active: c.active_profile,
                        profiles: Object.entries(c.profiles).filter(([, p]) => p.available !== false).map(([id, p]) => ({ id, description: p.description }))
                    }))
        }
    }

    Process {
        id: sysctlProc
        command: ["sysctl", "-n", "vm.swappiness", "vm.vfs_cache_pressure", "net.ipv4.tcp_congestion_control", "fs.inotify.max_user_watches"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split("\n");
                content.sysctl = { swappiness: +v[0], cachePressure: +v[1], congestion: v[2], watches: +v[3] };
            }
        }
    }

    Process {
        id: applyProc
        onExited: code => {
            content.status = code === 0 ? "Applied." : "Not applied (cancelled, or the helper refused a value).";
            sysctlProc.running = true;
        }
    }

    // Keyboard: what the main keyboard uses now, and the names of every layout.
    Process {
        id: keyboardProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const devices = JSON.parse(text || "{}");
                content.hasTouchpad = (devices.mice ?? []).some(m => /touchpad|trackpad/i.test(m.name));
                const keyboards = devices.keyboards ?? [];
                const k = keyboards.find(k => k.main) ?? keyboards[0];
                if (k)
                    content.keyboard = { layouts: k.layout.split(",").filter(l => l), options: k.options ?? "" };
            }
        }
    }
    Process {
        id: layoutNamesProc // "  us              English (US)"
        command: ["sed", "-n", "/^! layout$/,/^$/p", "/usr/share/X11/xkb/rules/base.lst"]
        stdout: StdioCollector {
            onStreamFinished: content.layoutNames = text.split("\n").map(l => l.match(/^\s+(\S+)\s+(.+)$/)).filter(m => m).map(m => ({ code: m[1], name: m[2] })).sort((a, b) => a.name.localeCompare(b.name))
        }
    }

    // Date & Time, through timedated (it asks for a password itself).
    Process {
        id: timeProc
        command: ["timedatectl", "show", "-p", "Timezone", "-p", "NTP", "-p", "NTPSynchronized"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = Object.fromEntries(text.trim().split("\n").map(l => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)]));
                content.time = { timezone: v.Timezone ?? "", ntp: v.NTP === "yes", synced: v.NTPSynchronized === "yes" };
            }
        }
    }
    Process {
        id: zonesProc
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: content.timezones = text.split("\n").filter(z => z)
        }
    }
    Process {
        id: timeSet
        onExited: timeProc.running = true
    }

    // Users: accounts that can log in (uid 1000–59999, a real shell); wheel's members are admins.
    Process {
        id: usersProc
        command: ["sh", "-c", "getent passwd; echo '# wheel'; getent group wheel"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [passwd, wheel] = text.split("# wheel\n");
                const admins = (wheel ?? "").trim().split(":")[3]?.split(",") ?? [];
                content.users = passwd.split("\n").map(l => l.split(":")).filter(f => {
                    const uid = parseInt(f[2]);
                    return f.length >= 7 && uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(f[6]);
                }).map(f => ({ name: f[0], fullName: f[4].split(",")[0] || f[0], admin: admins.includes(f[0]), me: f[0] === Sys.userName })).sort((a, b) => b.me - a.me);
            }
        }
    }
    Process {
        id: usersOp
        property string password: "" // held only until the helper reads it
        property string why: ""
        stdinEnabled: true
        onStarted: {
            write(password + "\n");
            password = "";
            stdinEnabled = false; // closes stdin
        }
        stderr: SplitParser {
            onRead: line => usersOp.why = line.replace(/^manage-users: /, "")
        }
        onExited: code => {
            content.usersStatus = code === 0 ? "" : code === 126 || code === 127 ? "Cancelled." : `Not changed: ${why}.`;
            why = "";
            stdinEnabled = true;
            usersProc.running = true;
        }
    }

    // Default apps: `gio mime TYPE` names the default and the apps that can open TYPE.
    Process {
        id: defaultsProc
        command: ["sh", "-c", 'for t; do echo "== $t"; LC_ALL=C gio mime "$t"; done', "sh"].concat(win.appKinds.map(k => k[1][0]))
        stdout: StdioCollector {
            onStreamFinished: {
                const blocks = text.split(/^== /m);
                content.defaultApps = win.appKinds.map(([label, mimes]) => {
                    const block = blocks.find(b => b.startsWith(mimes[0] + "\n")) ?? "";
                    const current = (block.match(/: (\S+\.desktop)\s*$/m) ?? [])[1] ?? "";
                    const registered = block.split(/^Recommended/m)[0].split("\n").filter(l => l.startsWith("\t")).map(l => l.trim());
                    const apps = Array.from(new Set([current].concat(registered))).map(id => ({ id, name: Sys.apps.find(a => a.id + ".desktop" === id)?.name ?? "" })).filter(a => a.name);
                    return { label, mimes, current, apps };
                });
            }
        }
    }
    Process {
        id: defaultSet
        onExited: defaultsProc.running = true
    }

    // Startup Apps: every autostart entry, the system's first so the user's copies override them.
    Process {
        id: startupProc
        command: ["sh", "-c", 'for f in /etc/xdg/autostart/*.desktop "$1"/*.desktop; do [ -f "$f" ] && { echo "== $f"; cat "$f"; echo; }; done', "sh", win.autostart]
        stdout: StdioCollector {
            onStreamFinished: content.startup = Autostart.entries(text, "Hyprland").map(e => Object.assign(e, { icon: Sys.iconPath(e.icon) }))
        }
    }
    Process {
        id: startupOp
        onExited: startupProc.running = true
    }
    function startupScript(script, args) {
        startupOp.command = ["sh", "-c", 'mkdir -p "$1" && ' + script, "sh", win.autostart].concat(args);
        startupOp.running = true;
    }

    // Network: VPN connections, and VPN files in ~/Downloads not imported yet.
    Process {
        id: vpnProc
        command: ["sh", "-c", 'echo @@c; nmcli -t -e no -f NAME,TYPE,ACTIVE connection show; echo @@f; for f in "$HOME"/Downloads/*.conf "$HOME"/Downloads/*.ovpn; do case $f in *.ovpn) [ -f "$f" ] && echo "openvpn $f" ;; *) grep -Fqs "[Interface]" "$f" && echo "wireguard $f" ;; esac; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const vpns = [], files = [];
                let section = "";
                for (const line of text.split("\n")) {
                    if (line === "@@c" || line === "@@f") {
                        section = line[2];
                    } else if (section === "c" && line) { // NAME:TYPE:ACTIVE; the name may hold colons
                        const f = line.split(":"), active = f.pop(), type = f.pop();
                        if (type === "vpn" || type === "wireguard")
                            vpns.push({ name: f.join(":"), type, active: active === "yes" });
                    } else if (section === "f" && line) {
                        const path = line.slice(line.indexOf(" ") + 1);
                        files.push({ type: line.slice(0, line.indexOf(" ")), path, name: path.slice(path.lastIndexOf("/") + 1) });
                    }
                }
                content.vpns = vpns;
                content.vpnFiles = files;
            }
        }
    }
    Process {
        id: vpnOp
        property string last: ""
        stderr: SplitParser {
            onRead: line => vpnOp.last = line
        }
        onExited: code => {
            content.vpnStatus = code === 0 ? "" : vpnOp.last.replace(/^Error: /, "");
            vpnOp.last = "";
            vpnProc.running = true;
        }
    }
    function nmcli(args) {
        content.vpnStatus = "";
        vpnOp.command = ["nmcli"].concat(args);
        vpnOp.running = true;
    }

    // Printers: CUPS's queues and the driverless printers it found.
    Process {
        id: printersProc
        command: ["sh", "-c", "export LC_ALL=C; echo @@e; lpstat -e; echo @@p; lpstat -p; echo @@d; lpstat -d"]
        stdout: StdioCollector {
            onStreamFinished: content.printers = Printers.printers(text)
        }
    }
    Process {
        id: printersOp
        property string done: ""
        property string last: ""
        stderr: SplitParser {
            onRead: line => printersOp.last = line
        }
        onExited: code => {
            content.printersStatus = code === 0 ? printersOp.done : code === 126 || code === 127 ? "Cancelled." : `Didn't work: ${printersOp.last.replace(/^\w+: /, "")}`;
            printersOp.last = "";
            printersProc.running = true;
        }
    }
    function cups(command, done) {
        content.printersStatus = "";
        printersOp.done = done;
        printersOp.command = command;
        printersOp.running = true;
    }

    // Drivers: divine-drivers lists them; pkg-helper installs them as root.
    Process {
        id: driversProc
        command: ["divine-drivers"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    content.drivers = JSON.parse(text);
                } catch (e) {
                    content.drivers = [];
                }
            }
        }
    }
    Process {
        id: driversOp
        property string last: ""
        stdout: SplitParser {
            onRead: line => content.driversStatus = driversOp.last = line
        }
        stderr: SplitParser {
            onRead: line => content.driversStatus = driversOp.last = line
        }
        onExited: code => {
            content.driversStatus = code === 0 ? "Installed. Restart the computer to start using new graphics drivers." : code === 126 || code === 127 ? "Cancelled." : `Not installed: ${last}`;
            driversProc.running = true;
        }
    }

    // Disks: lsblk's drives (again every 2 s while the page shows: sticks come and go), the disc
    // images in Downloads, and mounting, erasing, formatting and writing.
    Process {
        id: disksProc
        command: ["lsblk", "-J", "-b", "-o", "NAME,PATH,SIZE,TYPE,TRAN,RM,HOTPLUG,RO,MODEL,LABEL,FSTYPE,MOUNTPOINTS"]
        stdout: StdioCollector {
            onStreamFinished: content.disks = Disks.disks(text)
        }
    }
    Process {
        id: imagesProc
        command: ["sh", "-c", 'for f in "$HOME"/Downloads/*.iso "$HOME"/Downloads/*.img; do [ -f "$f" ] && stat -c "%s %n" -- "$f"; done']
        stdout: StdioCollector {
            onStreamFinished: content.images = text.split("\n").filter(l => l).map(l => {
                const path = l.slice(l.indexOf(" ") + 1);
                return { path, name: path.slice(path.lastIndexOf("/") + 1), size: parseInt(l) };
            })
        }
    }
    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: win.visible && win.pageId === "disks"
        onRunningChanged: if (running) imagesProc.running = true
        onTriggered: disksProc.running = true
    }
    Process {
        id: diskOp
        property string done: ""
        property string last: ""
        property real total: 0 // the image's size, for progress
        // dd redraws its progress with carriage returns
        stderr: SplitParser {
            splitMarker: "\r"
            onRead: chunk => {
                const bytes = Disks.copied(chunk);
                if (bytes >= 0) {
                    content.diskProgress = diskOp.total > 0 ? Math.min(1, bytes / diskOp.total) : 0;
                    content.disksStatus = `Writing… ${Disks.size(bytes)}${diskOp.total > 0 ? " of " + Disks.size(diskOp.total) : ""}`;
                }
                for (const line of chunk.split("\n"))
                    if (line.trim() && !/^\d+\+\d+ records|bytes .*copied/.test(line))
                        diskOp.last = line.trim();
            }
        }
        onExited: code => {
            content.disksStatus = code === 0 ? diskOp.done : code === 126 || code === 127 ? "Cancelled." : `Didn't work: ${diskOp.last.replace(/^\w+: /, "")}`;
            content.diskProgress = -1;
            diskOp.last = "";
            disksProc.running = true;
        }
    }
    function diskRun(command, done, total) {
        content.disksStatus = command[0] === "pkexec" ? "Waiting for your password…" : "";
        diskOp.done = done;
        diskOp.total = total ?? 0;
        diskOp.command = command;
        diskOp.running = true;
    }

    // Backup: Timeshift's snapshots, when the system is on Btrfs. Listing needs root but no password.
    Process {
        id: rootFsProc
        command: ["findmnt", "-no", "FSTYPE", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                content.rootFs = text.trim();
                if (content.rootFs === "btrfs" && win.pageId === "backup")
                    snapshotsProc.running = true;
            }
        }
    }
    Process {
        id: snapshotsProc
        command: ["pkexec", "/usr/lib/devine-tweaks/snapshots"]
        stdout: StdioCollector {
            onStreamFinished: content.snapshots = Backup.snapshots(text)
        }
    }
    Process {
        id: backupOp
        property string done: ""
        property string last: ""
        property string restoring: ""
        stdout: SplitParser {
            onRead: line => backupOp.last = line
        }
        stderr: SplitParser {
            onRead: line => backupOp.last = line
        }
        onExited: code => {
            content.backupStatus = code === 0 ? backupOp.done : code === 126 || code === 127 ? "Cancelled." : `Didn't work: ${backupOp.last.replace(/^E: /, "")}`;
            if (code === 0 && backupOp.restoring)
                content.restored = backupOp.restoring;
            backupOp.last = backupOp.restoring = "";
            snapshotsProc.running = true;
        }
    }
    function backup(args, done) {
        content.backupStatus = "Waiting for your password…";
        backupOp.done = done;
        backupOp.restoring = args[0] === "restore" ? args[1] : "";
        backupOp.command = ["pkexec", "/usr/lib/devine-tweaks/backup"].concat(args);
        backupOp.running = true;
    }

    // Appearance: installed icon themes, pointers and fonts, and which ones GTK uses now.
    Process {
        id: themesProc
        command: ["sh", "-c", `for d in /usr/share/icons/*/ "$HOME"/.local/share/icons/*/ "$HOME"/.icons/*/; do
  n=$(basename "$d")
  [ -d "$d/cursors" ] && echo "cursors $n"
  [ "$n" != hicolor ] && grep -qs '^Directories=.' "$d/index.theme" && echo "icons $n"
done
fc-list : family | tr , '\\n' | sed 's/^/fonts /'
for k in icon-theme cursor-theme cursor-size; do echo "$k $(gsettings get org.gnome.desktop.interface $k)"; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = { icons: new Set(), cursors: new Set(), fonts: new Set() };
                const now = {};
                for (const line of text.split("\n")) {
                    const kind = line.slice(0, line.indexOf(" ")), value = line.slice(line.indexOf(" ") + 1).trim();
                    if (found[kind])
                        found[kind].add(value);
                    else if (kind)
                        now[kind] = value.replace(/^'|'$/g, "");
                }
                content.themes = { icons: [...found.icons].sort(), cursors: [...found.cursors].sort(), fonts: [...found.fonts] };
                content.iconTheme = now["icon-theme"] ?? "";
                content.cursorTheme = now["cursor-theme"] ?? "";
                content.cursorSize = parseInt(now["cursor-size"]) || 24;
            }
        }
    }
    Process {
        id: themeOp
        property string pkg: ""
        property string last: ""
        stdout: SplitParser {
            onRead: line => themeOp.last = line
        }
        stderr: SplitParser {
            onRead: line => themeOp.last = line
        }
        onExited: code => {
            content.themeStatus = code === 0 ? "" : code === 126 || code === 127 ? "Cancelled." : `Not installed: ${last}`;
            pkg = "";
            themesProc.running = true;
        }
    }

    IpcHandler {
        target: "tweaks"
        function toggle(): void {
            win.toggle();
        }
        function show(page: string): void {
            win.show(page);
        }
    }

    TweaksContent {
        id: content
        anchors.fill: parent

        dark: Sys.darkMode
        fullName: Sys.fullName
        userName: Sys.userName
        face: Sys.face
        picturesFolder: "file://" + Sys.home + "/Pictures"
        glass: state.glass
        motion: state.animations ? state.motion : 0
        accentName: Sys.accentName
        tint: Sys.tint
        layout: Sys.layout
        widgets: Sys.widgets
        onSetWidget: (kind, on) => Sys.setWidget(kind, on ? {} : null)
        wallpaper: Sys.wallpaper
        font: Sys.font
        themeBusy: themeOp.pkg
        windows: win.windows
        blurSize: state.blurSize || 8 // hyprland.lua's
        dock: ({ size: Sys.dockSize, magnify: Sys.dockMagnify, autoHide: Sys.dockAutoHide })
        sinks: win.sinkNodes.map(n => ({ id: n.id, name: n.description || n.nickname || n.name, active: n === Pipewire.defaultAudioSink }))
        powerProfile: Sys.powerProfile
        hasPerformance: Sys.hasPerformanceProfile
        idle: state.idle
        clock24: Sys.clock24
        weather: ({ on: Sys.weatherOn, place: Sys.weatherPlace, picked: Sys.weatherPicked, unit: Sys.fahrenheit ? "f" : "c" })
        places: Sys.placeResults
        nightLight: ({ on: Sys.nightLight, temp: Sys.nightTemp, schedule: Sys.nightSchedule })
        driversBusy: driversOp.running
        diskBusy: diskOp.running
        backupBusy: backupOp.running
        pointer: win.pointer
        apps: Sys.apps.map(a => ({ id: a.id, name: a.name }))

        onSetDark: on => Sys.setDarkMode(on)
        onSetPicture: image => Sys.setFace(image)
        onClearPicture: Sys.clearFace()
        onSetGlass: style => {
            state.glass = style;
            win.writeHypr();
        }
        onSetMotion: speed => {
            state.animations = speed > 0;
            if (speed > 0)
                state.motion = speed;
            win.writeHypr();
        }
        onSetAccent: (name, color) => Sys.setAccent(name, color)
        onApplyTheme: t => {
            Sys.setDarkMode(t.dark);
            Sys.setAccent(t.accent, "");
            Sys.setTint(t.tint);
            state.glass = t.glass;
            win.writeHypr();
        }
        onSetWallpaper: url => Sys.setWallpaper(url)
        onSetFont: family => Sys.setFont(family)
        onSetIconTheme: name => {
            state.iconTheme = name;
            iconTheme = name;
            Sys.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", name]);
            win.writeHypr();
        }
        onSetCursor: (name, size) => {
            state.cursor = { theme: name, size };
            cursorTheme = name;
            cursorSize = size;
            win.writeHypr(); // reloads Hyprland, hence setcursor's wait below
            Sys.run(["sh", "-c", 'gsettings set org.gnome.desktop.interface cursor-theme "$1"; gsettings set org.gnome.desktop.interface cursor-size "$2"; sleep 1; hyprctl setcursor "$1" "$2"', "sh", name, `${size}`]);
        }
        onInstallTheme: pkg => {
            themeStatus = "Waiting for your password…";
            themeOp.pkg = pkg;
            themeOp.command = ["pkexec", "/usr/lib/divine-pkg/pkg-helper", "install", pkg];
            themeOp.running = true;
        }
        onSetWindows: w => {
            state.windows = w;
            win.writeHypr();
        }
        onSetBlur: size => {
            state.blurSize = size;
            win.writeHypr();
        }
        onSetDock: change => Sys.setDock(change)
        onApplyPreset: p => {
            state.windows = p.windows;
            state.blurSize = p.blur;
            Sys.setDock(p.dock);
            Sys.setLayout(p.id);
            win.writeHypr();
        }
        onSetMonitor: (name, change) => win.setMonitor(name, change)
        onSetSink: id => Pipewire.preferredDefaultAudioSink = win.sinkNodes.find(n => n.id === id) ?? null
        onSetProfile: (card, profile) => {
            Quickshell.execDetached(["pactl", "set-card-profile", card, profile]);
            reread.restart();
        }
        onApplySysctl: v => {
            status = "Waiting for authorisation…";
            applyProc.command = ["pkexec", win.helper, `vm.swappiness=${v.swappiness}`, `vm.vfs_cache_pressure=${v.cachePressure}`, `net.ipv4.tcp_congestion_control=${v.congestion}`, `fs.inotify.max_user_watches=${v.watches}`];
            applyProc.running = true;
        }
        onResetSysctl: {
            status = "Waiting for authorisation…";
            applyProc.command = ["pkexec", win.helper, "--reset"];
            applyProc.running = true;
        }
        onSetLayouts: (layouts, options) => {
            state.keyboard = { layouts, options };
            win.writeHypr();
        }
        onSetVpn: (name, on) => win.nmcli(["connection", on ? "up" : "down", "id", name])
        onImportVpn: (type, path) => win.nmcli(["connection", "import", "type", type, "file", path])
        onRemoveVpn: name => win.nmcli(["connection", "delete", "id", name])
        onAddPrinter: (name, uri) => win.cups(["pkexec", "/usr/lib/devine-tweaks/printers", "add", name, uri], "Added.")
        onRemovePrinter: name => win.cups(["pkexec", "/usr/lib/devine-tweaks/printers", "remove", name], "")
        onSetDefaultPrinter: name => win.cups(["lpoptions", "-d", name], "")
        onTestPrinter: name => win.cups(["lp", "-d", name, "/usr/share/cups/data/testprint"], "Test page sent.")
        onSetPointer: change => {
            state.pointer = Object.assign({}, win.pointer, change);
            win.writeHypr();
        }
        // An app's own entry, copied from where its launcher lives.
        onAddStartup: app => win.startupScript('IFS=:; for d in ${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do [ -f "$d/applications/$2.desktop" ] && exec cp "$d/applications/$2.desktop" "$1/"; done', [app])
        // Off is Hidden=true in the user's copy (made from the system's if needed); on removes it.
        onSetStartup: (file, on) => win.startupScript('f="$1/$2"; [ -f "$f" ] || cp "/etc/xdg/autostart/$2" "$f" || exit; sed -i "/^Hidden=/d;/^X-GNOME-Autostart-enabled=/d" "$f"; [ "$3" = on ] || sed -i "0,/^\\[Desktop Entry\\]/s//&\\nHidden=true/" "$f"', [file, on ? "on" : "off"])
        onRemoveStartup: file => win.startupScript('rm -f "$1/$2"', [file])
        onSetPowerProfile: profile => Sys.setPowerProfile(profile)
        onSetIdle: idle => {
            state.idle = idle;
            win.writeIdle();
        }
        onSetTimezone: zone => {
            timeSet.command = ["timedatectl", "set-timezone", zone];
            timeSet.running = true;
        }
        onSetNtp: on => {
            timeSet.command = ["timedatectl", "set-ntp", on ? "true" : "false"];
            timeSet.running = true;
        }
        onSetClock24: on => Sys.setClock24(on)
        onSetWeather: change => Sys.setWeather(change)
        onSearchPlaces: name => Sys.searchPlaces(name)
        onSetNightLight: on => Sys.setNightLight(on)
        onSetNightTemp: kelvin => Sys.setNightTemp(kelvin)
        onSetNightSchedule: schedule => Sys.setNightSchedule(schedule)
        onAddUser: (name, fullName, password, admin) => win.manageUsers(["add", name, fullName, admin ? "admin" : "standard"], password)
        onDeleteUser: name => win.manageUsers(["delete", name], "")
        onSetAdmin: (name, admin) => win.manageUsers(["admin", name, admin ? "yes" : "no"], "")
        onSetDefaultApp: (mimes, app) => {
            defaultSet.command = ["sh", "-c", 'app=$1; shift; for t; do gio mime "$t" "$app" >/dev/null; done', "sh", app].concat(mimes);
            defaultSet.running = true;
        }
        onMountPart: (path, mount) => win.diskRun(["udisksctl", mount ? "mount" : "unmount", "-b", path], mount ? "Mounted." : "Unmounted.")
        onEraseDisk: (disk, fs, label) => win.diskRun(["pkexec", "/usr/lib/devine-tweaks/disks", "erase", disk, fs, label], "Erased.")
        onFormatPart: (part, fs, label) => win.diskRun(["pkexec", "/usr/lib/devine-tweaks/disks", "format", part, fs, label], "Formatted.")
        onWriteImage: (disk, image, size) => win.diskRun(["pkexec", "/usr/lib/devine-tweaks/disks", "write", disk, image], "Written. The drive can be unplugged.", size)
        onCreateSnapshot: description => win.backup(["create", description], "Snapshot made.")
        onRestoreSnapshot: name => win.backup(["restore", name], "")
        onDeleteSnapshot: name => win.backup(["delete", name], "Deleted.")
        onRestart: Quickshell.execDetached(["systemctl", "reboot"])
        onInstallDrivers: ids => {
            driversStatus = "Waiting for your password…";
            driversOp.command = ["pkexec", "/usr/lib/divine-pkg/pkg-helper", "drivers"].concat(ids);
            driversOp.running = true;
        }
    }
}
