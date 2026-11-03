import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// divineOS Settings (devine-tweaks). Display, glass and animation choices are written to
// ~/.config/hypr/tweaks.lua, which hyprland.lua loads last; kernel settings go through the
// polkit-guarded helper /usr/lib/devine-tweaks/apply-sysctl.
// Toggle: Super+comma, or `devine-tweaks` (IPC).
FloatingWindow {
    id: win

    readonly property string helper: "/usr/lib/devine-tweaks/apply-sysctl"
    readonly property var sinkNodes: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    function toggle() {
        visible = !visible;
        if (visible)
            refresh();
    }
    function refresh() {
        monitorsProc.running = true;
        cardsProc.running = true;
        sysctlProc.running = true;
    }

    // Regenerate tweaks.lua from the saved choices, then let Hyprland pick it up.
    function writeHypr() {
        const q = JSON.stringify; // a JSON string is a valid Lua string for these values
        const lines = ["-- Written by divineOS Settings (devine-tweaks); edits here are overwritten.", "-- Put your own settings in hyprland.lua instead.", ""];
        for (const [name, m] of Object.entries(state.monitors))
            lines.push(`hl.monitor({ output = ${q(name)}, mode = ${q(m.mode)}, position = ${q(m.position)}, scale = ${typeof m.scale === "number" ? m.scale : q("auto")} })`);
        const blur = state.glass === "off" ? "enabled = false" : `enabled = true, variant = ${q(state.glass)}`;
        lines.push(`hl.config({ decoration = { blur = { ${blur} } }, animations = { enabled = ${state.animations} } })`);
        hyprFile.setText(lines.join("\n") + "\n");
        Quickshell.execDetached(["hyprctl", "reload"]);
        reread.restart();
    }

    function setMonitor(name, change) {
        const now = content.monitors.find(m => m.name === name);
        if (!now)
            return;
        const saved = state.monitors[name] ?? { mode: now.mode, scale: now.scale, position: now.position };
        state.monitors = Object.assign({}, state.monitors, { [name]: Object.assign({}, saved, change) });
        writeHypr();
    }

    title: "Settings"
    visible: false
    onClosed: visible = false // closing from Hyprland (Super+Q) doesn't clear `visible` by itself
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    minimumSize: Qt.size(760, 520)
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
            property var monitors: ({}) // name → { mode, scale, position }
        }
    }

    FileView {
        id: hyprFile // written only; absent until the first change
        path: Quickshell.env("HOME") + "/.config/hypr/tweaks.lua"
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
                        position: `${m.x}x${m.y}`,
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

    IpcHandler {
        target: "tweaks"
        function toggle(): void {
            win.toggle();
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
        animations: state.animations
        sinks: win.sinkNodes.map(n => ({ id: n.id, name: n.description || n.nickname || n.name, active: n === Pipewire.defaultAudioSink }))

        onSetDark: on => Sys.setDarkMode(on)
        onSetPicture: image => Sys.setFace(image)
        onClearPicture: Sys.clearFace()
        onSetGlass: style => {
            state.glass = style;
            win.writeHypr();
        }
        onSetAnimations: on => {
            state.animations = on;
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
    }
}
