pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
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
import "Dock.js" as Dock
import "NightLight.js" as NightLight
import "Weather.js" as Weather

// The only file that talks to the system. Views bind to these plain properties
// and call these functions, so they never deal with missing devices or nulls.
Singleton {
    id: sys

    readonly property string logo: "file:///usr/share/icons/hicolor/scalable/apps/divineos.svg"
    readonly property string defaultWallpaper: "file:///usr/share/backgrounds/divineos/default.png"

    // ── Appearance (persisted in ~/.local/state/quickshell/…/state.json) ──
    property alias darkMode: state.darkMode
    function setDarkMode(on) {
        state.darkMode = on;
        run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", on ? "prefer-dark" : "prefer-light"]);
    }

    readonly property string wallpaper: state.wallpaper || defaultWallpaper
    function setWallpaper(url) {
        state.wallpaper = url === defaultWallpaper ? "" : url;
    }

    // A Theme.accents id, or "wallpaper" for the colour Settings picked from it (accentColor).
    property alias accentName: state.accent
    readonly property color accent: Theme.accents.find(a => a.id === state.accent)?.color ?? state.accentColor
    function setAccent(name, color) {
        state.accent = name;
        if (color)
            state.accentColor = color;
        // GTK 4 apps take the nearest of GNOME's accent colours.
        const c = Qt.color(Theme.accents.find(a => a.id === name)?.color ?? state.accentColor);
        const gnome = Theme.accents.find(a => a.id === name)?.gnome ?? (c.hsvSaturation < 0.3 ? "slate" : Theme.accents.filter(a => a.id !== "graphite").reduce((best, a) => {
            const d = h => Math.min(Math.abs(h - c.hsvHue), 1 - Math.abs(h - c.hsvHue));
            return d(Qt.color(a.color).hsvHue) < d(Qt.color(best.color).hsvHue) ? a : best;
        }).gnome);
        run(["gsettings", "set", "org.gnome.desktop.interface", "accent-color", gnome]);
    }

    property alias font: state.font
    function setFont(family) {
        state.font = family;
        run(["gsettings", "set", "org.gnome.desktop.interface", "font-name", family + " 11"]);
    }

    Binding {
        target: Theme
        property: "dark"
        value: state.darkMode
    }
    Binding {
        target: Theme
        property: "accent"
        value: sys.accent
    }
    Binding {
        target: Theme
        property: "font"
        value: state.font
    }
    Binding {
        target: Theme
        property: "tint"
        value: state.tint
    }
    property alias tint: state.tint // Theme.tintColors; set with a theme preset (Settings > Appearance)
    function setTint(tint) {
        state.tint = tint;
    }

    // ── Layout (Settings > Desktop & Dock): divine, macos, windows (a taskbar instead of the
    // menu bar and dock) or tiling. Tweaks writes the window rules that go with it. ──
    property alias layout: state.layout
    function setLayout(layout) {
        state.layout = layout;
    }

    // ── Desktop widgets (Settings > Desktop & Dock): kind → { x, y, text? } for the ones on ──
    property alias widgets: state.widgets
    readonly property var widgetPlaces: ({ clock: { x: 40, y: 64 }, system: { x: 40, y: 206 }, note: { x: 40, y: 342, text: "" }, media: { x: 290, y: 64 } })
    function setWidget(kind, change) { // null turns it off
        const all = Object.assign({}, state.widgets);
        if (change === null)
            delete all[kind];
        else
            all[kind] = Object.assign({}, all[kind] ?? widgetPlaces[kind], change);
        state.widgets = all;
    }

    // ── Dock (Settings > Desktop & Dock) ──
    property alias dockSize: state.dockSize
    property alias dockMagnify: state.dockMagnify
    property alias dockAutoHide: state.dockAutoHide
    function setDock(change) { // { size?, magnify?, autoHide? }
        if (change.size !== undefined)
            state.dockSize = change.size;
        if (change.magnify !== undefined)
            state.dockMagnify = change.magnify;
        if (change.autoHide !== undefined)
            state.dockAutoHide = change.autoHide;
    }

    FileView {
        path: Quickshell.statePath("state.json")
        onAdapterUpdated: writeAdapter()
        onLoaded: sys.started()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            sys.started();
        }
        JsonAdapter {
            id: state
            property bool darkMode: true
            property bool dnd: false
            property bool clock24: false // Settings > Date & Time
            property string accent: "blue"
            property string accentColor: "#0A84FF"
            property string wallpaper: "" // a file:// URL; empty is the default
            property string font: "Inter"
            property string tint: "default"
            property string layout: "divine"
            property var widgets: ({ clock: { x: 40, y: 64 } })
            property int dockSize: 52 // icon size at rest, px
            property real dockMagnify: 1.55 // the icon under the pointer over one at rest; 1 is off
            property bool dockAutoHide: false
            property bool weatherOn: true
            property var weatherPlace: null // { name, detail, lat, lon }; null follows the time zone
            property string weatherUnit: "" // "c" or "f"; empty goes by the locale
            property int nightTemp: 4000 // Kelvin; lower is warmer
            property var nightSchedule: null // { from: "21:00", to: "7:00" }; null is by hand
            property bool nightManual: false // on or off by hand, without a schedule
            // divine-install only has a desktop entry on the live ISO; elsewhere it is skipped.
            property list<string> pinned: ["divine-install", "devine-files", "kitty", "devenv", "devine-store", "repostation", "devine-monitor", "devine-tweaks"]
        }
    }

    // Once the saved settings are read: what runs on them from the start.
    function started() {
        writeNightLight(); // (re)starts hyprsunset on the saved schedule
        refreshWeather();
        windowGeometry.restart();
    }

    // ── Network (NetworkManager) ──
    readonly property var netDevices: Networking.devices.values
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var wifiDevice: netDevices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property string wifiName: wifiDevice?.networks.values.find(n => n.connected)?.name ?? ""
    // Networks in range for Control Center: the joined one, then saved ones, then by signal.
    readonly property var wifiNetworks: (wifiDevice?.networks.values ?? []).slice().sort((a, b) => b.connected - a.connected || b.known - a.known || b.signalStrength - a.signalStrength)
    function setWifiScanning(on) { // while the Wi-Fi list is open
        if (wifiDevice)
            wifiDevice.scannerEnabled = on;
    }
    function wifiLocked(network) {
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }
    function wifiNeedsPassword(network) { // the ones a password alone joins
        return !network.known && [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security);
    }
    function joinWifi(network, password) {
        if (password)
            network.connectWithPsk(password);
        else
            network.connect();
    }
    readonly property bool wired: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool hasWired: netDevices.some(d => d.type === DeviceType.Wired)
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
    // Control Center's list: paired devices, then named ones nearby (found while it is open).
    readonly property var btPaired: Bluetooth.devices.values.filter(d => d.paired)
    readonly property var btNearby: Bluetooth.devices.values.filter(d => !d.paired && d.deviceName)
    function setBtScanning(on) {
        if (btAdapter && btAdapter.enabled)
            btAdapter.discovering = on;
    }
    // Connect or disconnect a paired device; pair a new one, then trust and connect it.
    property var btPairing: null
    function useBtDevice(device) {
        if (device.paired) {
            device.connected = !device.connected;
        } else {
            btPairing = device;
            device.pair();
        }
    }
    Connections {
        target: sys.btPairing
        function onPairedChanged() {
            if (!sys.btPairing.paired)
                return;
            sys.btPairing.trusted = true;
            sys.btPairing.connect();
            sys.btPairing = null;
        }
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
    readonly property real micVolume: source?.volume ?? 0
    // Speakers, headphones and microphones (not apps' streams) for Control Center's Sound list.
    readonly property var audioDevices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var outputs: audioDevices.filter(n => n.isSink)
    readonly property var inputs: audioDevices.filter(n => !n.isSink)
    readonly property var output: Pipewire.defaultAudioSink
    readonly property var input: Pipewire.defaultAudioSource
    function audioName(node) {
        return node.description || node.nickname || node.name;
    }
    function setOutput(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }
    function setInput(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }
    function setMicVolume(v) {
        if (!source)
            return;
        source.muted = false;
        source.volume = v;
    }
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

    // ── Weather (Open-Meteo): the menu bar, the Notification Center, Settings > Date & Time ──
    // The place is the one picked in Settings, else the city the time zone is named after.
    property alias weatherOn: state.weatherOn
    readonly property var weatherPlace: state.weatherPlace ?? zonePlace
    readonly property bool weatherPicked: state.weatherPlace !== null
    readonly property bool fahrenheit: state.weatherUnit ? state.weatherUnit === "f" : Qt.locale().measurementSystem === Locale.ImperialUSSystem
    property var zonePlace: null
    property var weather: null // Weather.fromForecast(), or null until there is one
    function setWeather(change) { // { on?, place? (null: the time zone's), unit? }
        if (change.on !== undefined)
            state.weatherOn = change.on;
        if (change.place !== undefined)
            state.weatherPlace = change.place;
        if (change.unit !== undefined)
            state.weatherUnit = change.unit;
        weather = null;
        refreshWeather();
    }
    function refreshWeather() {
        if (!state.weatherOn)
            return;
        if (weatherPlace) {
            forecastProc.command = ["curl", "-sf", "--max-time", "20", Weather.forecastUrl(weatherPlace.lat, weatherPlace.lon, fahrenheit)];
            forecastProc.running = true;
        } else {
            zoneProc.running = true;
        }
    }
    Timer {
        interval: 30 * 60 * 1000
        running: state.weatherOn
        repeat: true
        onTriggered: sys.refreshWeather()
    }
    Process {
        id: zoneProc
        command: ["timedatectl", "show", "-p", "Timezone", "--value"]
        stdout: StdioCollector {
            onStreamFinished: {
                const city = Weather.zoneCity(text);
                if (!city)
                    return;
                zoneSearch.command = ["curl", "-sf", "--max-time", "20", Weather.searchUrl(city)];
                zoneSearch.running = true;
            }
        }
    }
    Process {
        id: zoneSearch
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    sys.zonePlace = Weather.places(JSON.parse(text))[0] ?? null;
                } catch (e) {
                    return;
                }
                if (sys.zonePlace)
                    sys.refreshWeather();
            }
        }
    }
    property var placeResults: [] // Weather.places() for the last search (Settings > Date & Time)
    function searchPlaces(name) {
        placeResults = [];
        if (name.trim().length < 2)
            return;
        placesProc.command = ["curl", "-sf", "--max-time", "20", Weather.searchUrl(name.trim())];
        placesProc.running = true;
    }
    Process {
        id: placesProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    sys.placeResults = Weather.places(JSON.parse(text));
                } catch (e) {}
            }
        }
    }
    Process {
        id: forecastProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    sys.weather = Weather.fromForecast(JSON.parse(text));
                } catch (e) {} // offline: keep the last forecast
            }
        }
    }

    // ── Night Light (hyprsunset): warmer colours by hand or on a schedule ──
    // ~/.config/hypr/hyprsunset.conf holds the schedule; each switch calls back
    // (`ipc call nightlight sync`) so nightLight follows. By hand, hyprctl talks to hyprsunset.
    property bool nightLight: false // what the screen shows now
    property alias nightTemp: state.nightTemp
    property alias nightSchedule: state.nightSchedule
    function setNightLight(on) { // with a schedule, until its next switch
        nightLight = on;
        if (!state.nightSchedule)
            state.nightManual = on;
        applyNightLight();
    }
    function setNightTemp(kelvin) {
        state.nightTemp = kelvin;
        writeNightLight();
    }
    function setNightSchedule(schedule) {
        state.nightSchedule = schedule;
        writeNightLight();
    }
    function syncNightLight() {
        nightLight = state.nightSchedule ? NightLight.inWindow(state.nightSchedule, new Date()) : state.nightManual;
        applyNightLight();
    }
    function applyNightLight() {
        run(["hyprctl", "hyprsunset"].concat(nightLight ? ["temperature", `${state.nightTemp}`] : ["identity"]));
    }
    function writeNightLight() {
        nightFile.setText(NightLight.conf(state.nightSchedule, state.nightTemp, "qs -p /usr/share/divine-shell ipc call nightlight sync"));
    }
    FileView {
        id: nightFile
        path: Quickshell.env("HOME") + "/.config/hypr/hyprsunset.conf"
        onSaved: {
            sys.run(["sh", "-c", "pkill -x hyprsunset; setsid -f hyprsunset >/dev/null 2>&1"]);
            nightStart.restart();
        }
    }
    Timer {
        id: nightStart // hyprsunset takes a moment to open its socket
        interval: 1500
        onTriggered: sys.syncNightLight()
    }

    // ── Clock ──
    property alias clock24: state.clock24
    function setClock24(on) {
        state.clock24 = on;
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
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile
    function setPowerProfile(profile) {
        PowerProfiles.profile = profile;
    }
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
    signal shotTaken(string path) // Markup shows its thumbnail
    function capture(mode) {
        // The short sleep lets the bar (or Control Center) fade before the screen is read.
        shooter.command = ["sh", "-c", `sleep 0.3; ${pickArea}
            d="$HOME/Pictures/Screenshots"; mkdir -p "$d"; f="$d/$(date +%F_%H-%M-%S).png"
            grim "$@" "$f" && wl-copy < "$f" && echo "$f"`, "sh", mode, areaArg(mode)];
        shooter.running = true;
    }
    Process {
        id: shooter
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) sys.shotTaken(text.trim())
        }
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
    readonly property var shellWindows: ({ "System Monitor": "devine-monitor", "Settings": "devine-tweaks", "Store": "devine-store" })
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
    function dockMovePin(id, target) { // dragged onto target's place
        state.pinned = Dock.movePin(pinned, id, target);
    }

    // Auto-hide dodges windows: the dock stays up unless a window on the screen's shown workspace
    // reaches into its strip (px from the bottom). Hyprland gives window geometry on request, so
    // it's re-read as windows open, close, move between workspaces, float or go fullscreen.
    // ponytail: height only, and not while a floating window is dragged; compare x and refresh
    // on a timer while the pointer is down if that matters.
    function dockCovered(screen, strip) {
        const top = screen.y + screen.height - strip;
        return (Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values ?? []).some(t => {
            const o = t.lastIpcObject;
            return o?.at !== undefined && o.at[1] + o.size[1] > top;
        });
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen", "workspacev2", "activewindowv2"].includes(event.name))
                windowGeometry.restart();
        }
    }
    Timer {
        id: windowGeometry
        interval: 150
        onTriggered: Hyprland.refreshToplevels()
    }

    // The dock's stacks: Downloads, newest first, and the Trash.
    readonly property string downloadsDir: home + "/Downloads"
    readonly property string trashDir: home + "/.local/share/Trash/files"
    readonly property var downloads: { // the 12 newest: { name, path, dir }
        const m = downloadsModel;
        return m.status !== FolderListModel.Ready ? [] : Array.from({ length: Math.min(12, m.count) }, (_, i) => ({ name: m.get(i, "fileName"), path: m.get(i, "filePath"), dir: m.get(i, "fileIsDir") }));
    }
    readonly property bool trashFull: trashModel.count > 0
    function emptyTrash() {
        run(["gio", "trash", "--empty"]);
    }
    FolderListModel {
        id: downloadsModel
        folder: "file://" + sys.downloadsDir
        sortField: FolderListModel.Time // newest first
        showDirsFirst: false
    }
    FolderListModel {
        id: trashModel
        folder: "file://" + sys.trashDir
        showHidden: true
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
    function iconPath(name, fallback) {
        return Quickshell.iconPath(name, fallback ?? "application-x-executable");
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
        run(["sh", "-c", 'echo "$1" | cliphist delete; rm -f "$2/$1"', "sh", id, clipThumbs]);
    }
    // Copied pictures are decoded once into the runtime folder (tmpfs, yours only) for the
    // launcher's previews; Qt reads the format from the bytes.
    readonly property string clipThumbs: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/divine-clips"
    property int clipThumbsVersion: 0 // bumped when new previews are written, so Images reload
    function clipThumb(id) {
        return `file://${clipThumbs}/${id}?v=${clipThumbsVersion}`;
    }
    Process {
        id: clipList
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                sys.clipboardHistory = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const tab = l.indexOf("\t");
                    return { id: l.slice(0, tab), text: l.slice(tab + 1) };
                });
                const images = sys.clipboardHistory.filter(c => /^\[\[ binary data .* \d+x\d+ \]\]$/.test(c.text)).slice(0, 40).map(c => c.id);
                if (!images.length)
                    return;
                clipDecode.command = ["sh", "-c", 'd=$1; shift; mkdir -p -m 700 "$d" && for id; do [ -s "$d/$id" ] || cliphist decode "$id" > "$d/$id"; done', "sh", sys.clipThumbs].concat(images);
                clipDecode.running = true;
            }
        }
    }
    Process {
        id: clipDecode
        onExited: sys.clipThumbsVersion++
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
