import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel

// divineOS Settings view. Tweaks.qml supplies the data and acts on the signals.
Item {
    id: root

    property int page: 0
    property bool dark: true
    property string glass: "acrylic"
    property real motion: 1 // animation speed; 0 is off
    property string accentName: "blue"
    property string tint: "default"
    property string layout: "divine" // Desktop & Dock's preset: divine, macos, windows or tiling
    property string wallpaper: ""
    property string wallpapersFolder: "file:///usr/share/backgrounds/divineos"
    property var themes: ({ icons: [], cursors: [], fonts: [] }) // installed
    property string iconTheme: ""
    property string cursorTheme: ""
    property int cursorSize: 24
    property string font: "Inter"
    property string themeBusy: "" // the package being installed
    property string themeStatus: ""
    property var windows: ({ gaps: 14, rounding: 22, border: 1 })
    property int blurSize: 8
    property var dock: ({ size: 52, magnify: 1.55, autoHide: false })
    property var widgets: ({}) // the desktop widgets that are on: kind → { x, y }
    property var monitors: [] // { name, description, mode, scale, modes[], side }
    property var sinks: [] // { id, name, active }
    property var cards: [] // { name, description, active, profiles[{ id, description }] }
    property var sysctl: ({}) // { swappiness, cachePressure, congestion, watches }
    property string status: ""
    property string fullName: ""
    property string userName: ""
    property string face: "" // the current picture
    property string picturesFolder: ""
    property var keyboard: ({ layouts: [], options: "" }) // what Hyprland uses now
    property var layoutNames: [] // every XKB layout: { code, name }
    property var pointer: ({ speed: 0, flat: false, natural: false, leftHanded: false, tap: true, touchNatural: true, typing: true, swipe: 3 })
    property bool hasTouchpad: false
    property var startup: [] // Autostart.js entries: { file, name, icon, on, own }
    property var apps: [] // for adding one to Startup Apps: { id, name }
    property var vpns: [] // NetworkManager's: { name, type: vpn|wireguard, active }
    property var vpnFiles: [] // in ~/Downloads: { type: openvpn|wireguard, path, name }
    property string vpnStatus: ""
    property var printers: [] // Printers.js: { name, state, added, isDefault }
    property string printersStatus: ""
    property int powerProfile: 1 // 0 Power Saver, 1 Balanced, 2 Performance
    property bool hasPerformance: true
    property var idle: ({ lock: 300, screen: 0, suspend: 0 }) // seconds; 0 is never
    property var time: ({ timezone: "", ntp: true, synced: false })
    property var timezones: []
    property bool clock24: false
    property var weather: ({ on: true, place: null, picked: false, unit: "c" }) // place: { name, detail, lat, lon }
    property var places: [] // search results, like weather.place
    property var nightLight: ({ on: false, temp: 4000, schedule: null }) // schedule: { from: "21:00", to: "7:00" }
    property var users: [] // { name, fullName, admin, me }
    property string usersStatus: ""
    property var defaultApps: [] // { label, mimes[], current, apps[{ id, name }] }
    property var drivers: [] // divine-drivers: { id, name, about, packages[], installed }
    property bool driversBusy: false
    property string driversStatus: ""
    property var disks: [] // Disks.js: { path, name, size, removable, system, readOnly, parts[] }
    property var images: [] // .iso and .img files in ~/Downloads: { path, name, size }
    property bool diskBusy: false
    property real diskProgress: -1 // an image being written, 0–1; -1 when not
    property string disksStatus: ""
    property string rootFs: "" // the system's filesystem: Backup needs btrfs
    property var snapshots: [] // Backup.js: { name, date, tags, description }
    property bool backupBusy: false
    property string backupStatus: ""
    property string restored: "" // a snapshot restored, waiting for a restart

    readonly property var pages: [
        { id: "appearance", icon: Theme.icons.palette, label: "Appearance" },
        { id: "desktop", icon: Theme.icons.desktop, label: "Desktop & Dock" },
        { id: "displays", icon: Theme.icons.display, label: "Displays" },
        { id: "sound", icon: Theme.icons.speaker, label: "Sound" },
        { id: "network", icon: Theme.icons.wifi, label: "Network" },
        { id: "bluetooth", icon: Theme.icons.bluetooth, label: "Bluetooth" },
        { id: "printers", icon: Theme.icons.printer, label: "Printers" },
        { id: "keyboard", icon: Theme.icons.keyboard, label: "Keyboard" },
        { id: "mouse", icon: Theme.icons.mouse, label: "Mouse & Touchpad" },
        { id: "power", icon: Theme.icons.power, label: "Power" },
        { id: "time", icon: Theme.icons.clock, label: "Date & Time" },
        { id: "users", icon: Theme.icons.users, label: "Users" },
        { id: "apps", icon: Theme.icons.defaultApps, label: "Default Apps" },
        { id: "startup", icon: Theme.icons.startup, label: "Startup Apps" },
        { id: "drivers", icon: Theme.icons.chip, label: "Drivers" },
        { id: "disks", icon: Theme.icons.disk, label: "Disks" },
        { id: "backup", icon: Theme.icons.backup, label: "Backup" },
        { id: "performance", icon: Theme.icons.performance, label: "Performance" }
    ]
    function show(id) {
        page = Math.max(0, pages.findIndex(p => p.id === id));
    }

    readonly property var avatarStyles: [
        { glyph: String.fromCodePoint(0xF03E9), from: "#FF9F0A", to: "#FF375F" }, // paw
        { glyph: String.fromCodePoint(0xF14DE), from: "#5E5CE6", to: "#0A84FF" }, // rocket
        { glyph: String.fromCodePoint(0xF024A), from: "#FF375F", to: "#BF5AF2" }, // flower
        { glyph: String.fromCodePoint(0xF011B), from: "#FFD60A", to: "#FF9F0A" }, // cat
        { glyph: String.fromCodePoint(0xF0176), from: "#AC8E68", to: "#5E4B3C" }, // coffee
        { glyph: String.fromCodePoint(0xF04CE), from: "#64D2FF", to: "#5E5CE6" }, // star
        { glyph: String.fromCodePoint(0xF023A), from: "#30D158", to: "#0A84FF" }, // fish
        { glyph: String.fromCodePoint(0xF1055), from: "#30D158", to: "#1E7A3C" } // palm
    ]

    signal setPicture(var image) // an ItemGrabResult, 256 px square
    signal clearPicture
    signal setDark(bool on)
    signal setGlass(string style)
    signal setMotion(real speed)
    signal setAccent(string name, string color)
    signal applyTheme(var theme) // { dark, accent, tint, glass }
    signal setWallpaper(string url)
    signal setIconTheme(string name)
    signal setCursor(string name, int size)
    signal setFont(string family)
    signal installTheme(string pkg)
    signal setWindows(var windows)
    signal setBlur(int size)
    signal setDock(var change)
    signal applyPreset(var preset)
    signal setWidget(string kind, bool on)
    signal setMonitor(string name, var change) // { mode?, scale?, side? (left, right, above, below, mirror) }
    signal setVpn(string name, bool on)
    signal importVpn(string type, string path)
    signal removeVpn(string name)
    signal addPrinter(string name, string uri)
    signal removePrinter(string name)
    signal setDefaultPrinter(string name)
    signal testPrinter(string name)
    signal setSink(int id)
    signal setProfile(string card, string profile)
    signal applySysctl(var values)
    signal resetSysctl
    signal setLayouts(var layouts, string options)
    signal setPointer(var change) // any of pointer's keys
    signal addStartup(string app) // a desktop entry id
    signal setStartup(string file, bool on)
    signal removeStartup(string file)
    signal setPowerProfile(int profile)
    signal setIdle(var idle)
    signal setTimezone(string zone)
    signal setNtp(bool on)
    signal setClock24(bool on)
    signal setWeather(var change) // { on?, place? (null: from the time zone), unit? }
    signal searchPlaces(string name)
    signal setNightLight(bool on)
    signal setNightTemp(int kelvin)
    signal setNightSchedule(var schedule) // null: by hand
    signal addUser(string name, string fullName, string password, bool admin)
    signal deleteUser(string name)
    signal setAdmin(string name, bool admin)
    signal setDefaultApp(var mimes, string app)
    signal installDrivers(var ids)
    signal mountPart(string path, bool mount)
    signal eraseDisk(string disk, string fs, string label)
    signal formatPart(string part, string fs, string label)
    signal writeImage(string disk, string image, real size) // size 0: not known
    signal createSnapshot(string description)
    signal restoreSnapshot(string name)
    signal deleteSnapshot(string name)
    signal restart

    // Performance edits stay local until Apply.
    property var draft: ({})
    onSysctlChanged: draft = Object.assign({}, sysctl)
    function edit(key, value) {
        draft = Object.assign({}, draft, { [key]: value });
    }

    implicitWidth: 880
    implicitHeight: 680

    // A drawn account picture: a glyph on a gradient.
    component AvatarArt: Rectangle {
        id: art
        property var style
        gradient: Gradient {
            GradientStop { position: 0; color: art.style?.from ?? "transparent" }
            GradientStop { position: 1; color: art.style?.to ?? "transparent" }
        }
        Glyph { anchors.centerIn: parent; text: art.style?.glyph ?? ""; font.pixelSize: art.height * 0.55; color: "#ffffff" }
    }

    // A round choice in the picture grid, ringed on hover.
    component PictureTile: Item {
        id: tile
        signal picked
        width: 64
        height: 64
        Rectangle { anchors.fill: parent; anchors.margins: -4; radius: width / 2; color: "transparent"; border.width: 2; border.color: Theme.accent; visible: tileArea.containsMouse }
        MouseArea { id: tileArea; anchors.fill: parent; hoverEnabled: true; onClicked: tile.picked() }
    }

    // ── Sidebar (scrolls when the window is short) ──
    Flickable {
        id: sidebar
        x: 18
        y: 18
        width: 190
        height: parent.height - 36
        clip: true
        contentHeight: nav.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: nav
            width: parent.width
            spacing: 2

            Label { text: "Settings"; font.pixelSize: 22; font.weight: Font.Bold; bottomPadding: 12; leftPadding: 8 }
            Repeater {
                model: root.pages
                NavItem {
                    required property var modelData
                    required property int index
                    width: nav.width
                    height: 36
                    icon: modelData.icon
                    text: modelData.label
                    on: root.page === index
                    onClicked: root.page = index
                }
            }
        }
    }

    // ── Pages ──
    StackLayout {
        anchors.left: sidebar.right
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 18
        currentIndex: root.page

        AppearancePage { settings: root }
        DesktopPage { settings: root }

        // Displays
        Flickable {
            clip: true
            contentHeight: displays.implicitHeight
            ColumnLayout {
                id: displays
                width: parent.width
                spacing: Theme.gap
                NightLightCard { settings: root }
                Label { visible: root.monitors.length === 0; text: "No displays reported by Hyprland."; dim: true }
                Repeater {
                    model: root.monitors
                    SettingsCard {
                        id: monitorCard
                        required property var modelData
                        required property int index
                        SettingRow {
                            title: monitorCard.modelData.name
                            hint: monitorCard.modelData.description
                            Segmented {
                                options: [{ label: "Auto", value: "auto" }, { label: "100%", value: 1 }, { label: "125%", value: 1.25 }, { label: "150%", value: 1.5 }, { label: "200%", value: 2 }]
                                value: monitorCard.modelData.scale
                                onPicked: v => root.setMonitor(monitorCard.modelData.name, { scale: v })
                            }
                        }
                        SettingRow {
                            visible: monitorCard.index > 0
                            title: "Position"
                            hint: `Next to ${root.monitors[0]?.name ?? ""}, or showing the same picture.`
                            Segmented {
                                options: [{ label: "Left", value: "left" }, { label: "Right", value: "right" }, { label: "Above", value: "above" }, { label: "Below", value: "below" }, { label: "Mirror", value: "mirror" }]
                                value: monitorCard.modelData.side
                                onPicked: v => root.setMonitor(monitorCard.modelData.name, { side: v })
                            }
                        }
                        Label { text: "Resolution and refresh rate"; dim: true; font.pixelSize: 12; bottomPadding: 4 }
                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, 180)
                            Layout.bottomMargin: 8
                            clip: true
                            spacing: 2
                            model: monitorCard.modelData.modes
                            delegate: Choice {
                                required property string modelData
                                width: ListView.view.width
                                text: modelData.replace("@", "  ·  ") + " Hz"
                                on: modelData === monitorCard.modelData.mode
                                onPicked: root.setMonitor(monitorCard.modelData.name, { mode: modelData })
                            }
                        }
                    }
                }
            }
        }

        // Sound
        Flickable {
            clip: true
            contentHeight: sound.implicitHeight
            ColumnLayout {
                id: sound
                width: parent.width
                spacing: Theme.gap
                SettingsCard {
                    Label { text: "Output"; font.weight: Font.DemiBold; topPadding: 8; bottomPadding: 6 }
                    Repeater {
                        model: root.sinks
                        Choice {
                            required property var modelData
                            text: modelData.name
                            on: modelData.active
                            onPicked: root.setSink(modelData.id)
                        }
                    }
                    Item { implicitHeight: 8 }
                }
                Repeater {
                    model: root.cards
                    SettingsCard {
                        id: card
                        required property var modelData
                        Label { text: card.modelData.description; font.weight: Font.DemiBold; topPadding: 8 }
                        Label { text: "Profile"; dim: true; font.pixelSize: 12; bottomPadding: 6 }
                        Repeater {
                            model: card.modelData.profiles
                            Choice {
                                required property var modelData
                                text: modelData.description
                                on: modelData.id === card.modelData.active
                                onPicked: root.setProfile(card.modelData.name, modelData.id)
                            }
                        }
                        Item { implicitHeight: 8 }
                    }
                }
            }
        }

        NetworkSettings { settings: root }
        BluetoothSettings { settings: root }
        PrintersPage { settings: root }
        KeyboardPage { settings: root }
        MousePage { settings: root }
        PowerPage { settings: root }
        DateTimePage { settings: root }

        // Users: your account, then everyone's
        Flickable {
            clip: true
            contentHeight: account.implicitHeight
            ColumnLayout {
                id: account
                width: parent.width
                spacing: Theme.gap
                SettingsCard {
                    Row {
                        Layout.topMargin: 10
                        Layout.bottomMargin: 10
                        spacing: 18
                        Avatar { width: 84; height: 84; source: root.face; name: root.fullName }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Label { text: root.fullName; font.pixelSize: 20; font.weight: Font.Bold }
                            Label { text: root.userName; dim: true }
                        }
                    }
                }
                SettingsCard {
                    Label { Layout.topMargin: 10; text: "Picture"; font.weight: Font.DemiBold }
                    Label { text: "Shown on the lock and login screens. Photos come from ~/Pictures."; dim: true; font.pixelSize: 12 }
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 14
                        Layout.bottomMargin: 14
                        spacing: 14

                        PictureTile { // no picture: your initial
                            onPicked: root.clearPicture()
                            Avatar { anchors.fill: parent; name: root.fullName }
                        }
                        Repeater {
                            model: root.avatarStyles
                            PictureTile {
                                id: styleTile
                                required property var modelData
                                onPicked: root.render(modelData, "")
                                AvatarArt { anchors.fill: parent; radius: width / 2; style: styleTile.modelData }
                            }
                        }
                        Repeater {
                            model: photos
                            PictureTile {
                                id: photoTile
                                required property url fileUrl
                                required property int index
                                visible: index < 24
                                onPicked: root.render(null, fileUrl)
                                Avatar { anchors.fill: parent; source: photoTile.fileUrl }
                            }
                        }
                    }
                }
                UsersCard { settings: root }
            }
        }

        DefaultAppsPage { settings: root }
        StartupPage { settings: root }
        DriversPage { settings: root }
        DisksPage { settings: root }
        BackupPage { settings: root }

        // Performance
        Flickable {
            clip: true
            contentHeight: performance.implicitHeight
            ColumnLayout {
                id: performance
                width: parent.width
                spacing: Theme.gap
                GlassSlider {
                    Layout.fillWidth: true
                    title: `Swappiness · ${root.draft.swappiness ?? "—"}`
                    value: (root.draft.swappiness ?? 0) / 200
                    onMoved: v => root.edit("swappiness", Math.round(v * 200))
                }
                GlassSlider {
                    Layout.fillWidth: true
                    title: `File cache pressure · ${root.draft.cachePressure ?? "—"}`
                    value: (root.draft.cachePressure ?? 0) / 200
                    onMoved: v => root.edit("cachePressure", Math.round(v * 200))
                }
                SettingsCard {
                    SettingRow {
                        title: "TCP congestion control"
                        hint: "BBR keeps latency low on busy or lossy links."
                        Segmented {
                            options: [{ label: "BBR", value: "bbr" }, { label: "CUBIC", value: "cubic" }]
                            value: root.draft.congestion
                            onPicked: v => root.edit("congestion", v)
                        }
                    }
                    SettingRow {
                        title: "File watchers"
                        hint: "Editors, language servers and build tools watching big projects need many."
                        Segmented {
                            options: [{ label: "64K", value: 65536 }, { label: "512K", value: 524288 }, { label: "1M", value: 1048576 }]
                            value: root.draft.watches
                            onPicked: v => root.edit("watches", v)
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: root.status || "Applying asks for your password. Values persist across reboots."; dim: true; font.pixelSize: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    Segmented {
                        options: [{ label: "Reset", value: "reset" }, { label: "Apply", value: "apply" }]
                        value: "apply"
                        onPicked: v => v === "apply" ? root.applySysctl(root.draft) : root.resetSysctl()
                    }
                }
            }
        }
    }

    FolderListModel {
        id: photos
        folder: root.picturesFolder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Time
    }

    // The chosen picture as a 256 px square for setPicture; the screens round it themselves.
    // Clipped away rather than hidden: grabToImage can't capture an invisible item.
    Item {
        clip: true
        Item {
            id: renderer
            property var style: null
            property url photo
            width: 256
            height: 256
            AvatarArt { anchors.fill: parent; visible: !!renderer.style; style: renderer.style }
            Image {
                anchors.fill: parent
                visible: !renderer.style
                source: renderer.photo
                sourceSize: Qt.size(512, 512)
                fillMode: Image.PreserveAspectCrop
            }
        }
    }
    function render(style, photo) {
        renderer.style = style;
        renderer.photo = photo;
        renderer.grabToImage(image => root.setPicture(image));
    }
}
