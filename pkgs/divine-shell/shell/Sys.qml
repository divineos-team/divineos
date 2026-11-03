pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland

// The only file that talks to the system. Views bind to these plain properties
// and call these functions, so they never deal with missing devices or nulls.
Singleton {
    id: sys

    readonly property string logo: "file:///usr/share/icons/hicolor/scalable/apps/divineos.svg"
    readonly property string wallpaper: "file:///usr/share/backgrounds/divineos/default.png"

    // ── Appearance (persisted in ~/.local/state/quickshell/…/state.json) ──
    property alias darkMode: state.darkMode
    function setDarkMode(on) {
        state.darkMode = on;
        run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", on ? "prefer-dark" : "prefer-light"]);
    }

    Binding {
        target: Theme
        property: "dark"
        value: state.darkMode
    }

    FileView {
        path: Quickshell.statePath("state.json")
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }
        JsonAdapter {
            id: state
            property bool darkMode: true
            property bool dnd: false
            // divine-install only has a desktop entry on the live ISO; elsewhere it is skipped.
            property list<string> pinned: ["divine-install", "devine-files", "kitty", "devenv", "repostation", "devine-monitor", "devine-tweaks"]
        }
    }

    // ── Network (NetworkManager) ──
    readonly property var netDevices: Networking.devices.values
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property string wifiName: netDevices.find(d => d.type === DeviceType.Wifi)?.networks.values.find(n => n.connected)?.name ?? ""
    readonly property bool wired: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property string networkStatus: wifiName || (wired ? "Ethernet" : wifiOn ? "Not Connected" : "Off")
    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // ── Bluetooth ──
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btAvailable: btAdapter !== null
    readonly property bool btOn: btAdapter?.enabled ?? false
    readonly property string btDevice: Bluetooth.devices.values.find(d => d.connected)?.name ?? ""
    function toggleBluetooth() {
        if (btAdapter)
            btAdapter.enabled = !btAdapter.enabled;
    }

    // ── Airplane mode = every radio off ──
    readonly property bool airplane: !wifiOn && !btOn
    function toggleAirplane() {
        const on = !airplane;
        Networking.wifiEnabled = !on;
        if (btAdapter)
            btAdapter.enabled = !on;
    }

    // ── Audio (PipeWire) ──
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var source: Pipewire.defaultAudioSource?.audio ?? null
    readonly property real volume: sink?.volume ?? 0
    readonly property bool muted: sink?.muted ?? true
    readonly property bool micMuted: source?.muted ?? true
    function setVolume(v) {
        if (!sink)
            return;
        sink.muted = false;
        sink.volume = v;
    }
    function toggleMute() {
        if (sink)
            sink.muted = !sink.muted;
    }
    function toggleMic() {
        if (source)
            source.muted = !source.muted;
    }

    // ── Media (MPRIS): the playing player, else the first one ──
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    // ── Display brightness (brightnessctl). -1 = no backlight, slider hidden ──
    property real brightness: -1
    property real pendingBrightness: -1
    function refreshBrightness() {
        brightnessRead.running = true;
    }
    function setBrightness(v) {
        brightness = pendingBrightness = Math.max(0.01, Math.min(1, v));
        brightnessWrite.restart();
    }
    function stepBrightness(delta) { // brightness keys
        if (brightness >= 0)
            setBrightness(brightness + delta);
    }
    Process {
        id: brightnessRead
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        // "intel_backlight,backlight,48000,40%,120000"
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 5)
                    sys.brightness = parseInt(f[2]) / parseInt(f[4]);
            }
        }
    }
    Timer { // coalesce slider drags into one brightnessctl call per frame-ish
        id: brightnessWrite
        interval: 40
        onTriggered: sys.run(["brightnessctl", "-q", "-c", "backlight", "set", Math.round(sys.pendingBrightness * 100) + "%"])
    }

    // ── Notifications ──
    // The server keeps every notification until it's dismissed (Notification Center); banners
    // is the subset currently shown in the top-right corner.
    property alias dnd: state.dnd
    function setDnd(on) {
        state.dnd = on;
    }
    readonly property var notifications: notificationServer.trackedNotifications.values.slice().reverse() // newest first
    property var banners: []
    readonly property var receivedAt: ({}) // notification id → Date
    function hideBanner(n) {
        banners = banners.filter(b => b !== n);
        if (n.transient) // not meant for the Notification Center
            n.expire();
    }
    function dismissNotification(n) {
        banners = banners.filter(b => b !== n);
        n.dismiss();
    }
    function clearNotifications() {
        banners = [];
        for (const n of notificationServer.trackedNotifications.values.slice())
            n.dismiss();
    }
    // Clicking a notification runs its default action, if it has one.
    function activateNotification(n) {
        const a = Array.from(n.actions).find(a => a.identifier === "default");
        if (a)
            a.invoke();
        hideBanner(n);
    }
    function runNotificationAction(n, action) {
        action.invoke();
        hideBanner(n);
    }
    // An image or icon from a notification as an Image source ("" if none).
    function imageUrl(s) {
        return !s ? "" : s.startsWith("/") ? "file://" + s : s.includes("://") ? s : Quickshell.iconPath(s, true);
    }
    NotificationServer {
        id: notificationServer
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true;
            sys.receivedAt[n.id] = new Date();
            n.closed.connect(() => sys.banners = sys.banners.filter(b => b !== n));
            if (!n.lastGeneration && (!sys.dnd || n.urgency === NotificationUrgency.Critical))
                sys.banners = sys.banners.filter(b => b !== n).concat([n]);
        }
    }

    // ── Power ──
    readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery
    readonly property real battery: UPower.displayDevice.percentage
    readonly property bool charging: !UPower.onBattery
    readonly property int powerProfile: PowerProfiles.profile
    readonly property string powerProfileName: ["Power Saver", "Balanced", "Performance"][powerProfile]
    function cyclePowerProfile() {
        const next = (PowerProfiles.profile + 1) % 3;
        PowerProfiles.profile = next === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile ? PowerProfile.PowerSaver : next;
    }

    // ── Session ──
    function logout() {
        run(["hyprctl", "dispatch", "hl.dsp.exit()"]);
    }
    function reboot() {
        run(["systemctl", "reboot"]);
    }
    function poweroff() {
        run(["systemctl", "poweroff"]);
    }

    // ── Screenshots and screen recording (Print opens the capture bar) ──
    // mode: "screen" (the focused monitor), "window" (click one) or "region" (drag).
    // Shots go to ~/Pictures/Screenshots and the clipboard; recordings to ~/Videos/Screen Recordings.
    readonly property bool recording: recorder.running
    readonly property string pickArea: `case "$1" in
        screen) set -- -o "$2" ;;
        window) g=$(printf '%s\\n' "$2" | slurp -r) || exit 1; set -- -g "$g" ;;
        *) g=$(slurp) || exit 1; set -- -g "$g" ;;
    esac`
    // Windows on the shown workspaces, as slurp rectangles, for picking one.
    function windowRects() {
        return Hyprland.toplevels.values.filter(h => h.workspace?.active && h.lastIpcObject?.at).map(h => {
            const o = h.lastIpcObject;
            return `${o.at[0]},${o.at[1]} ${o.size[0]}x${o.size[1]}`;
        }).join("\n");
    }
    function areaArg(mode) {
        return mode === "screen" ? (Hyprland.focusedMonitor?.name ?? "") : mode === "window" ? windowRects() : "";
    }
    function capture(mode) {
        // The short sleep lets the bar (or Control Center) fade before the screen is read.
        run(["sh", "-c", `sleep 0.3; ${pickArea}
            d="$HOME/Pictures/Screenshots"; mkdir -p "$d"; f="$d/$(date +%F_%H-%M-%S).png"
            grim "$@" "$f" && wl-copy < "$f" && notify-send -a Screenshot -i "$f" "Screenshot saved" "Copied, and saved to Pictures/Screenshots."`, "sh", mode, areaArg(mode)]);
    }
    function record(mode) {
        if (recording)
            return;
        recorder.command = ["sh", "-c", `sleep 0.3; ${pickArea}
            d="$HOME/Videos/Screen Recordings"; mkdir -p "$d"
            exec wf-recorder "$@" -f "$d/$(date +%F_%H-%M-%S).mp4"`, "sh", mode, areaArg(mode)];
        recorder.running = true;
    }
    function stopRecording() {
        recorder.signal(2); // SIGINT: wf-recorder finishes the file and exits
    }
    function refreshWindows() { // window positions for picking one; Hyprland answers asynchronously
        Hyprland.refreshToplevels();
    }
    Process {
        id: recorder
        onExited: code => {
            if (code === 0)
                sys.run(["notify-send", "-a", "Screen Recording", "Recording saved", "Saved to Videos/Screen Recordings."]);
        }
    }

    // ── Windows & workspaces (Hyprland) ──
    readonly property string activeApp: {
        const t = ToplevelManager.activeToplevel;
        return t ? (DesktopEntries.heuristicLookup(t.appId)?.name ?? t.appId) : "divineOS";
    }
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w.id > 0)
    readonly property int focusedWorkspace: Hyprland.focusedWorkspace?.id ?? 1

    // ── Dock: pinned apps, then anything else with a window open ──
    readonly property var pinned: Array.from(state.pinned)
    readonly property var toplevels: ToplevelManager.toplevels.values
    // divine-shell's own windows share Quickshell's app id; tell them apart by title.
    readonly property var shellWindows: ({ "System Monitor": "devine-monitor", "Settings": "devine-tweaks" })
    function appKey(t) {
        if (t.appId === "org.quickshell")
            return shellWindows[t.title] ?? "";
        return DesktopEntries.heuristicLookup(t.appId)?.id ?? t.appId;
    }
    // Plain objects for the view. The focused app is kept apart (dockActive) so focus
    // changes don't rebuild the dock.
    readonly property var dockApps: {
        const items = new Map();
        for (const id of pinned) {
            const e = apps.find(a => a.id === id); // read via apps: rebuilds once entries load
            if (e)
                items.set(id, { id, name: e.name, icon: iconPath(e.icon), pinned: true, launchable: true, windows: 0 });
        }
        for (const t of toplevels) {
            const id = appKey(t);
            if (!id)
                continue;
            if (!items.has(id)) {
                const e = DesktopEntries.byId(id);
                items.set(id, { id, name: e?.name ?? id, icon: iconPath(e?.icon ?? id), pinned: false, launchable: !!e, windows: 0 });
            }
            items.get(id).windows++;
        }
        return Array.from(items.values());
    }
    readonly property string dockActive: ToplevelManager.activeToplevel ? appKey(ToplevelManager.activeToplevel) : ""
    function windowsOf(id) {
        return toplevels.filter(t => appKey(t) === id);
    }
    // Click: launch, focus, or step to the app's next window.
    function dockOpen(id) {
        const wins = windowsOf(id);
        if (!wins.length)
            return dockNewWindow(id);
        wins[(wins.indexOf(ToplevelManager.activeToplevel) + 1) % wins.length].activate();
    }
    function dockNewWindow(id) {
        DesktopEntries.byId(id)?.execute();
    }
    function dockQuit(id) {
        for (const t of windowsOf(id))
            t.close();
    }
    function dockTogglePin(id) {
        state.pinned = pinned.includes(id) ? pinned.filter(p => p !== id) : pinned.concat([id]);
    }

    // ── App switcher (Alt+Tab) and overview (Super+Tab) ──
    // Windows most recently focused first; ones not focused since the shell started follow.
    property var recent: []
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            const t = ToplevelManager.activeToplevel;
            if (t)
                sys.recent = [t].concat(sys.recent.filter(r => r !== t && sys.toplevels.includes(r)));
        }
    }
    // One entry per app; switching to it focuses its most recent window.
    readonly property var switcherApps: {
        const order = recent.filter(t => toplevels.includes(t)).concat(toplevels.filter(t => !recent.includes(t)));
        const items = new Map();
        for (const t of order) {
            const id = appKey(t);
            if (id && !items.has(id)) {
                const e = DesktopEntries.byId(id);
                items.set(id, { id, name: e?.name ?? id, icon: iconPath(e?.icon ?? id), window: t });
            }
        }
        return Array.from(items.values());
    }
    // Every window on a regular workspace, in workspace order.
    readonly property var overviewWindows: Hyprland.toplevels.values.filter(h => h.wayland && (h.workspace?.id ?? 0) > 0).sort((a, b) => a.workspace.id - b.workspace.id).map(h => {
        const id = appKey(h.wayland);
        const e = DesktopEntries.byId(id);
        return { title: h.wayland.title, name: e?.name ?? (id || h.wayland.appId), icon: iconPath(e?.icon ?? id), workspace: h.workspace.id, window: h.wayland };
    })
    function goToWorkspace(id) {
        workspaces.find(w => w.id === id)?.activate();
    }

    // ── Apps (launcher) ──
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)
    function iconPath(name) {
        return Quickshell.iconPath(name, "application-x-executable");
    }
    function copy(text) {
        Quickshell.clipboardText = text;
    }

    // ── Clipboard history (cliphist, fed by `wl-paste --watch cliphist store` in hyprland.lua) ──
    // Copies a password manager marks as secret never reach it (wl-paste sets CLIPBOARD_STATE).
    property var clipboardHistory: [] // [{ id, text }], newest first; images read "[[ binary data … ]]"
    function loadClipboard() {
        clipList.running = true;
    }
    function restoreClip(id) {
        run(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", id]);
    }
    function deleteClip(id) {
        clipboardHistory = clipboardHistory.filter(c => c.id !== id);
        run(["sh", "-c", 'echo "$1" | cliphist delete', "sh", id]);
    }
    Process {
        id: clipList
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: sys.clipboardHistory = text.split("\n").filter(l => l.includes("\t")).map(l => {
                const tab = l.indexOf("\t");
                return { id: l.slice(0, tab), text: l.slice(tab + 1) };
            })
        }
    }
    // ── Account: name and picture (~/.face for the lock screen, AccountsService for login) ──
    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string userName: Quickshell.env("USER") ?? ""
    property string fullName: userName // the passwd entry's full name, once read
    property int faceVersion: 0
    readonly property string face: `file://${home}/.face?v=${faceVersion}` // the query makes Images reload it
    // AccountsService copies the picture ($1; empty removes it) to /var/lib/AccountsService/icons,
    // where the login screen can read it. Your own picture needs no password.
    readonly property string accountIcon: 'u=$(busctl call org.freedesktop.Accounts /org/freedesktop/Accounts org.freedesktop.Accounts FindUserByName s "$USER" | cut -d\\" -f2) && busctl call org.freedesktop.Accounts "$u" org.freedesktop.Accounts.User SetIconFile s "$1"'
    function setFace(image) { // an ItemGrabResult: the picture as a square
        const png = home + "/.face.new.png";
        if (image.saveToFile(png))
            runFace('mv "$1" "$HOME/.face" && set -- "$HOME/.face" && ' + accountIcon, png);
    }
    function clearFace() {
        runFace('rm -f "$HOME/.face"; ' + accountIcon, "");
    }
    function runFace(script, arg) {
        faceProc.command = ["sh", "-c", script, "sh", arg];
        faceProc.running = true;
    }
    Process {
        id: faceProc
        onExited: sys.faceVersion++
    }
    Process {
        running: true
        command: ["getent", "passwd", sys.userName]
        stdout: StdioCollector {
            onStreamFinished: {
                const gecos = (text.split(":")[4] ?? "").split(",")[0];
                if (gecos)
                    sys.fullName = gecos;
            }
        }
    }

    // ── File search (launcher): names under ~, skipping hidden and git-ignored files (fd) ──
    property var fileResults: [] // absolute paths; folders end in "/"
    property string fileQuery: ""
    function searchFiles(q) {
        fileQuery = q;
        if (q.length < 2)
            fileResults = [];
        else
            fileSearch.running = true; // while one runs, its onExited starts the next
    }
    function openPath(path) {
        run(["gio", "open", path]);
    }
    Process {
        id: fileSearch
        property string ran: ""
        command: ["fd", "--fixed-strings", "--absolute-path", "--max-results", "40", "--", sys.fileQuery, sys.home]
        onStarted: ran = sys.fileQuery
        stdout: StdioCollector {
            onStreamFinished: {
                if (fileSearch.ran === sys.fileQuery)
                    sys.fileResults = text.split("\n").filter(l => l);
            }
        }
        onExited: {
            if (ran !== sys.fileQuery && sys.fileQuery.length >= 2)
                running = true;
        }
    }

    function run(command) {
        Quickshell.execDetached(command);
    }
}
