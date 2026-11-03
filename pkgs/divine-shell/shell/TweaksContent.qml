import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel

// divineOS Settings view. Tweaks.qml supplies the data and acts on the signals.
Item {
    id: root

    property int page: 0
    property bool dark: true
    property string glass: "acrylic"
    property bool animations: true
    property var monitors: [] // { name, description, mode, scale, modes[] }
    property var sinks: [] // { id, name, active }
    property var cards: [] // { name, description, active, profiles[{ id, description }] }
    property var sysctl: ({}) // { swappiness, cachePressure, congestion, watches }
    property string status: ""
    property string fullName: ""
    property string userName: ""
    property string face: "" // the current picture
    property string picturesFolder: ""

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
    signal setAnimations(bool on)
    signal setMonitor(string name, var change)
    signal setSink(int id)
    signal setProfile(string card, string profile)
    signal applySysctl(var values)
    signal resetSysctl

    // Performance edits stay local until Apply.
    property var draft: ({})
    onSysctlChanged: draft = Object.assign({}, sysctl)
    function edit(key, value) {
        draft = Object.assign({}, draft, { [key]: value });
    }

    implicitWidth: 860
    implicitHeight: 600

    // A titled setting with its control on the right.
    component SettingRow: Item {
        id: setting
        property string title
        property string hint
        default property alias control: slot.data

        Layout.fillWidth: true
        implicitHeight: Math.max(texts.implicitHeight, slot.childrenRect.height) + 22

        Column {
            id: texts
            anchors.left: parent.left
            anchors.right: slot.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Label { width: parent.width; text: setting.title; font.weight: Font.DemiBold }
            Label { width: parent.width; visible: text !== ""; text: setting.hint; dim: true; font.pixelSize: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        }
        Item {
            id: slot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    // Glass card holding a column of rows.
    component Card: Glass {
        default property alias rows: column.data
        Layout.fillWidth: true
        implicitHeight: column.implicitHeight + 24
        radius: 22
        ColumnLayout {
            id: column
            x: 20
            y: 12
            width: parent.width - 40
            spacing: 0
        }
    }

    // A selectable row in a list (modes, outputs, profiles).
    component Choice: Rectangle {
        id: choice
        property string text
        property bool on
        signal picked

        Layout.fillWidth: true
        implicitHeight: 36
        radius: 12
        color: on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85) : hover.containsMouse ? Theme.off : "transparent"
        Label { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: choice.text; color: choice.on ? "#ffffff" : Theme.text }
        Glyph { visible: choice.on; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: Theme.icons.check; color: "#ffffff"; font.pixelSize: 16 }
        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: choice.picked() }
    }

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

    // ── Sidebar ──
    Column {
        id: sidebar
        x: 18
        y: 18
        width: 190
        spacing: 4

        Label { text: "Settings"; font.pixelSize: 22; font.weight: Font.Bold; bottomPadding: 12; leftPadding: 8 }
        Repeater {
            model: [
                { icon: Theme.icons.palette, label: "Appearance" },
                { icon: Theme.icons.display, label: "Displays" },
                { icon: Theme.icons.speaker, label: "Sound" },
                { icon: Theme.icons.performance, label: "Performance" },
                { icon: Theme.icons.account, label: "Account" }
            ]
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool on: root.page === index
                width: sidebar.width
                height: 40
                radius: 14
                color: on ? Theme.accent : navHover.containsMouse ? Theme.off : "transparent"
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    spacing: 10
                    Glyph { text: modelData.icon; font.pixelSize: 18; color: parent.parent.on ? "#ffffff" : Theme.text }
                    Label { text: modelData.label; font.weight: Font.Medium; color: parent.parent.on ? "#ffffff" : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: navHover; anchors.fill: parent; hoverEnabled: true; onClicked: root.page = parent.index }
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

        // Appearance
        Flickable {
            clip: true
            contentHeight: appearance.implicitHeight
            ColumnLayout {
                id: appearance
                width: parent.width
                spacing: Theme.gap
                Card {
                    SettingRow {
                        title: "Appearance"
                        hint: "Shell, GTK and Qt apps follow this."
                        Segmented { options: [{ label: "Dark", value: true }, { label: "Light", value: false }]; value: root.dark; onPicked: v => root.setDark(v) }
                    }
                    SettingRow {
                        title: "Glass"
                        hint: "Liquid refracts what's behind it. Frosted is a plain blur and lighter on the GPU. Off draws solid panels for the longest battery life."
                        Segmented {
                            options: [{ label: "Liquid", value: "acrylic" }, { label: "Frosted", value: "kawase" }, { label: "Off", value: "off" }]
                            value: root.glass
                            onPicked: v => root.setGlass(v)
                        }
                    }
                    SettingRow {
                        title: "Animations"
                        hint: "Spring motion for windows, panels and workspaces."
                        Segmented { options: [{ label: "On", value: true }, { label: "Off", value: false }]; value: root.animations; onPicked: v => root.setAnimations(v) }
                    }
                }
            }
        }

        // Displays
        Flickable {
            clip: true
            contentHeight: displays.implicitHeight
            ColumnLayout {
                id: displays
                width: parent.width
                spacing: Theme.gap
                Label { visible: root.monitors.length === 0; text: "No displays reported by Hyprland."; dim: true }
                Repeater {
                    model: root.monitors
                    Card {
                        id: monitorCard
                        required property var modelData
                        SettingRow {
                            title: monitorCard.modelData.name
                            hint: monitorCard.modelData.description
                            Segmented {
                                options: [{ label: "Auto", value: "auto" }, { label: "100%", value: 1 }, { label: "125%", value: 1.25 }, { label: "150%", value: 1.5 }, { label: "200%", value: 2 }]
                                value: monitorCard.modelData.scale
                                onPicked: v => root.setMonitor(monitorCard.modelData.name, { scale: v })
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
                Card {
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
                    Card {
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
                Card {
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

        // Account
        Flickable {
            clip: true
            contentHeight: account.implicitHeight
            ColumnLayout {
                id: account
                width: parent.width
                spacing: Theme.gap
                Card {
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
                Card {
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
