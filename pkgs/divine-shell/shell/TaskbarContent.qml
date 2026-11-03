import QtQuick

// The Windows 11 layout's taskbar, in place of the menu bar and dock: Start and the dock's apps
// in the middle; the tray, quick settings and the clock on the right. Start opens the
// launcher. Clicking an app opens it, focuses it or steps to its next window; middle-click
// opens a new window.
Rectangle {
    id: bar

    property date now: new Date()
    property bool controlCenterOpen: false
    signal launcherRequested
    signal controlCenterRequested
    signal notificationCenterRequested

    implicitHeight: 48
    color: Theme.glass

    // A tile that lights under the pointer.
    component Tile: Rectangle {
        property bool lit: false
        readonly property bool hovered: area.containsMouse
        signal tapped(int button)
        height: 40
        radius: 6
        color: lit || hovered ? Theme.off : "transparent"
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => parent.tapped(mouse.button)
        }
    }

    Rectangle { width: parent.width; height: 1; color: Theme.rim }

    Row {
        anchors.centerIn: parent
        spacing: 4

        Tile {
            width: 40
            onTapped: bar.launcherRequested()
            Image { anchors.centerIn: parent; width: 24; height: 24; sourceSize: Qt.size(48, 48); source: Sys.logo }
        }
        Repeater {
            model: Sys.dockApps
            Tile {
                id: app
                required property var modelData
                readonly property bool active: modelData.id === Sys.dockActive
                width: 40
                lit: active
                onTapped: button => button === Qt.MiddleButton ? Sys.dockNewWindow(modelData.id) : Sys.dockOpen(modelData.id)
                Image { anchors.centerIn: parent; width: 26; height: 26; sourceSize: Qt.size(52, 52); source: app.modelData.icon }
                Rectangle { // open windows: a short line, longer for the focused app
                    visible: app.modelData.windows > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: app.active ? 16 : 6
                    height: 3
                    radius: 1.5
                    color: app.active ? Theme.accent : Theme.textDim
                    Behavior on width { NumberAnimation { duration: 150 } }
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Tray { anchors.verticalCenter: parent.verticalCenter; rightPadding: 6 }
        Tile { // quick settings: the network, volume and battery
            width: status.width + 20
            lit: bar.controlCenterOpen
            onTapped: bar.controlCenterRequested()
            Row {
                id: status
                anchors.centerIn: parent
                spacing: 10
                Glyph { text: Sys.wifiName ? Theme.icons.wifi : Sys.wired ? Theme.icons.ethernet : Theme.icons.wifiOff; font.pixelSize: 16 }
                Glyph { text: Sys.muted ? Theme.icons.volumeOff : Sys.volume > 0.66 ? Theme.icons.volumeHigh : Sys.volume > 0.33 ? Theme.icons.volumeMedium : Theme.icons.volumeLow; font.pixelSize: 16 }
                Glyph { visible: Sys.hasBattery; text: Sys.charging ? Theme.icons.batteryCharging : Theme.batteryIcon(Sys.battery); font.pixelSize: 16 }
            }
        }
        Tile { // the clock: the Notification Center
            width: clock.width + 20
            onTapped: bar.notificationCenterRequested()
            Column {
                id: clock
                anchors.centerIn: parent
                Label { anchors.right: parent.right; text: Qt.formatDateTime(bar.now, Sys.clock24 ? "H:mm" : "h:mm AP"); font.pixelSize: 12 }
                Label { anchors.right: parent.right; text: Qt.formatDate(bar.now, Qt.locale().dateFormat(Locale.ShortFormat)); font.pixelSize: 12 }
            }
        }
    }
}
