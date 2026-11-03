import QtQuick
import QtQuick.Layouts

// The Welcome guide's view: setting up (look, browser, codecs, drivers), what's on the desktop,
// the shortcuts, the apps, and where to go next. Welcome.qml supplies the data and acts on the
// signals.
Item {
    id: root

    property int page: 0
    property bool live: false // running from the install medium (divine-install is there)
    property bool showAtStartup: true
    property var apps: [] // { id, name, icon, about }
    property string accentName: "blue"
    property var installed: [] // which of the browsers and codecs are
    property string defaultBrowser: "" // its desktop entry
    property var drivers: [] // divine-drivers: { id, name, about, packages[], installed }
    property string busy: "" // a browser's package, "codecs" or "drivers", while it installs
    property string status: ""

    signal install
    signal applyTheme(var theme)
    signal getBrowser(string pkg, string desktop) // install if needed, then make it the default
    signal getCodecs
    signal installDrivers(var ids)
    signal openApp(string id)
    signal setShowAtStartup(bool on)

    readonly property var desktop: [
        { icon: Theme.icons.display, title: "Menu bar", text: "The divineOS mark opens the launcher. Next to it: the app in front and your workspaces. The clock opens notifications; the controls icon, the Control Center." },
        { icon: Theme.icons.window, title: "Dock", text: "Pinned apps and open windows. Click to open or switch; right-click for New Window, Keep in Dock and Quit." },
        { icon: Theme.icons.controls, title: "Control Center", text: "Wi-Fi, Bluetooth, power mode, dark mode, screenshots, airplane mode, microphone, brightness and volume." },
        { icon: Theme.icons.search, title: "Launcher", text: "Super+Space. Type to find apps and files, do sums, or search the clipboard history (Super+Shift+V)." },
        { icon: Theme.icons.selection, title: "Overview and workspaces", text: "Super+Tab shows every window. Super and a number switches workspace; add Shift to send the window there." },
        { icon: Theme.icons.bell, title: "Notifications", text: "Banners appear top right. The Notification Center (click the clock, or Super+N) keeps the rest." }
    ]
    readonly property var keys: [
        { keys: ["Super", "Space"], what: "Launcher" },
        { keys: ["Super", "Return"], what: "Terminal" },
        { keys: ["Super", "E"], what: "Files" },
        { keys: ["Super", "Q"], what: "Close the window" },
        { keys: ["Super", "V"], what: "Float or tile the window" },
        { keys: ["Super", "Tab"], what: "Overview" },
        { keys: ["Alt", "Tab"], what: "Switch apps" },
        { keys: ["Super", "1…9"], what: "Go to a workspace" },
        { keys: ["Super", "Shift", "1…9"], what: "Move the window to a workspace" },
        { keys: ["Super", "Arrows"], what: "Focus the next window that way" },
        { keys: ["Super", "Drag"], what: "Move a window (right button: resize)" },
        { keys: ["Super", "C"], what: "Control Center" },
        { keys: ["Super", "N"], what: "Notification Center" },
        { keys: ["Super", "Shift", "V"], what: "Clipboard history" },
        { keys: ["Print"], what: "Screenshot or record the screen" },
        { keys: ["Super", "M"], what: "System Monitor" },
        { keys: ["Super", ","], what: "Settings" },
        { keys: ["Super", "L"], what: "Lock" },
        { keys: ["Super", "Shift", "E"], what: "Log out" }
    ]

    implicitWidth: 880
    implicitHeight: 600

    component Card: Glass {
        default property alias rows: column.data
        Layout.fillWidth: true
        implicitHeight: column.implicitHeight + 28
        radius: 22
        ColumnLayout {
            id: column
            x: 20
            y: 14
            width: parent.width - 40
            spacing: 6
        }
    }

    component Pill: Rectangle {
        id: pill
        property string text
        property bool primary: true
        signal clicked
        implicitWidth: pillLabel.implicitWidth + 36
        implicitHeight: 34
        radius: height / 2
        color: primary ? Theme.accent : pillArea.containsMouse ? Theme.track : Theme.off
        scale: pillArea.pressed ? 0.96 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.001 } }
        Label { id: pillLabel; anchors.centerIn: parent; text: pill.text; font.weight: Font.DemiBold; color: pill.primary ? Theme.textOnAccent : Theme.text }
        MouseArea { id: pillArea; anchors.fill: parent; hoverEnabled: true; onClicked: pill.clicked() }
    }

    component Title: Label {
        font.pixelSize: 24
        font.weight: Font.Bold
        bottomPadding: 4
    }

    // ── Sidebar ──
    Column {
        id: sidebar
        x: 18
        y: 18
        width: 190
        spacing: 4

        Label { text: "Welcome"; font.pixelSize: 22; font.weight: Font.Bold; bottomPadding: 12; leftPadding: 8 }
        Repeater {
            model: [
                { icon: Theme.icons.check, label: "divineOS" },
                { icon: Theme.icons.settings, label: "Set Up" },
                { icon: Theme.icons.window, label: "The Desktop" },
                { icon: Theme.icons.controls, label: "Shortcuts" },
                { icon: Theme.icons.folder, label: "Apps" },
                { icon: Theme.icons.arrowRight, label: "Next Steps" }
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
                    Glyph { text: modelData.icon; font.pixelSize: 18; color: parent.parent.on ? Theme.textOnAccent : Theme.text }
                    Label { text: modelData.label; font.weight: Font.Medium; color: parent.parent.on ? Theme.textOnAccent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: navHover; anchors.fill: parent; hoverEnabled: true; onClicked: root.page = parent.index }
            }
        }
    }

    // Show at startup
    Item {
        anchors.left: parent.left
        anchors.leftMargin: 26
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        width: startup.implicitWidth
        height: startup.implicitHeight
        Row {
            id: startup
            spacing: 10
            Rectangle {
                width: 20
                height: 20
                radius: 6
                color: root.showAtStartup ? Theme.accent : Theme.off
                border.width: root.showAtStartup ? 0 : 1
                border.color: Theme.track
                Glyph { anchors.centerIn: parent; visible: root.showAtStartup; text: Theme.icons.check; font.pixelSize: 14; color: Theme.textOnAccent }
            }
            Label { text: "Show at startup"; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.setShowAtStartup(!root.showAtStartup)
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

        // divineOS
        ColumnLayout {
            spacing: 14
            Item { Layout.fillHeight: true }
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "file:///usr/share/icons/hicolor/scalable/apps/divineos.svg"
                sourceSize: Qt.size(96, 96)
            }
            Label { Layout.alignment: Qt.AlignHCenter; text: "Welcome to divineOS"; font.pixelSize: 30; font.weight: Font.Bold }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 500
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                dim: true
                font.pixelSize: 14
                text: "Arch Linux underneath, the divineDE desktop on top: Hyprland with liquid glass, tuned for speed. This guide shows you around."
            }
            Card {
                visible: root.live
                Layout.maximumWidth: 520
                Layout.alignment: Qt.AlignHCenter
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    Glyph { text: Theme.icons.download; font.pixelSize: 30; color: Theme.accent }
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Label { text: "You're trying divineOS"; font.weight: Font.DemiBold }
                        Label { width: parent.width; text: "It runs from the install medium, so nothing you do here is kept. Install it to keep it."; dim: true; font.pixelSize: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    }
                    Pill { text: "Install divineOS"; onClicked: root.install() }
                }
            }
            Pill {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                text: "Show Me Around"
                primary: !root.live
                onClicked: root.page = 1
            }
            Item { Layout.fillHeight: true }
        }

        WelcomeSetup { welcome: root }

        // The Desktop
        Flickable {
            clip: true
            contentHeight: desktopPage.implicitHeight
            ColumnLayout {
                id: desktopPage
                width: parent.width
                spacing: Theme.gap
                Title { text: "The Desktop" }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Theme.gap
                    rowSpacing: Theme.gap
                    Repeater {
                        model: root.desktop
                        Card {
                            required property var modelData
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            Row {
                                spacing: 10
                                Glyph { text: modelData.icon; font.pixelSize: 20; color: Theme.accent }
                                Label { text: modelData.title; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Label { Layout.fillWidth: true; text: modelData.text; dim: true; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                        }
                    }
                }
            }
        }

        // Shortcuts
        Flickable {
            clip: true
            contentHeight: keysPage.implicitHeight
            ColumnLayout {
                id: keysPage
                width: parent.width
                spacing: Theme.gap
                Title { text: "Shortcuts" }
                Label { text: "Super is the Windows key."; dim: true }
                Card {
                    Repeater {
                        model: root.keys
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 34
                            Label { Layout.fillWidth: true; text: modelData.what }
                            Row {
                                spacing: 4
                                Repeater {
                                    model: modelData.keys
                                    Rectangle {
                                        required property string modelData
                                        width: Math.max(28, cap.implicitWidth + 16)
                                        height: 26
                                        radius: 7
                                        color: Theme.off
                                        border.width: 1
                                        border.color: Theme.track
                                        Label { id: cap; anchors.centerIn: parent; text: modelData; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Apps
        Flickable {
            clip: true
            contentHeight: appsPage.implicitHeight
            ColumnLayout {
                id: appsPage
                width: parent.width
                spacing: Theme.gap
                Title { text: "Apps" }
                Card {
                    Repeater {
                        model: root.apps
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.minimumHeight: 58
                            spacing: 14
                            Image { source: modelData.icon; sourceSize: Qt.size(40, 40); Layout.preferredWidth: 40; Layout.preferredHeight: 40 }
                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Label { text: modelData.name; font.weight: Font.DemiBold }
                                Label { width: parent.width; text: modelData.about; dim: true; font.pixelSize: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                            }
                            Pill { text: "Open"; primary: false; onClicked: root.openApp(modelData.id) }
                        }
                    }
                }
            }
        }

        // Next Steps
        Flickable {
            clip: true
            contentHeight: nextPage.implicitHeight
            ColumnLayout {
                id: nextPage
                width: parent.width
                spacing: Theme.gap
                Title { text: "Next Steps" }
                Repeater {
                    model: [
                        { title: "Install software", text: "One command finds it in the Arch repos, the AUR or Debian:", code: "divine-pkg install firefox" },
                        { title: "Keep divineOS up to date", text: "Updates Arch packages, AUR packages and the Debian container together:", code: "divine-pkg update" },
                        { title: "Make it yours", text: "Settings (Super+,) has themes and layouts (macOS, Windows 11, Auto-Tiling), displays, network, printers and more. Right-click the dock to pin apps." },
                        { title: "Go deeper", text: "Window rules, keys and animations live in ~/.config/hypr/hyprland.lua. The Arch Wiki (wiki.archlinux.org) covers almost everything else." }
                    ]
                    Card {
                        required property var modelData
                        Label { text: modelData.title; font.weight: Font.DemiBold }
                        Label { Layout.fillWidth: true; text: modelData.text; dim: true; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                        Rectangle {
                            visible: !!modelData.code
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            implicitHeight: 34
                            radius: 10
                            color: Theme.off
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 12
                                text: modelData.code ?? ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: Theme.text
                            }
                        }
                    }
                }
            }
        }
    }
}
