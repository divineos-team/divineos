import QtQuick
import QtQuick.Effects

// The menu bar: logo, active app and workspaces on the left; status and clock on the right.
// Transparent like macOS 26: it sits straight on the wallpaper.
Item {
    id: bar

    property bool controlCenterOpen: false
    property date now: new Date()
    property int updates: 0
    signal launcherRequested
    signal controlCenterRequested
    signal notificationCenterRequested
    signal updatesRequested

    implicitHeight: 32

    component BarText: Label {
        color: Theme.barText
        font.pixelSize: 13
        font.weight: Font.Medium
    }
    component BarGlyph: Glyph {
        color: Theme.barText
        font.pixelSize: 17
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18

        Image {
            source: Sys.logo
            width: 18
            height: 18
            sourceSize: Qt.size(36, 36)
            anchors.verticalCenter: parent.verticalCenter
            layer.enabled: true
            layer.effect: MultiEffect { // monochrome mark, like the Apple menu
                brightness: Theme.barText.hslLightness > 0.5 ? 1 : -1
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: bar.launcherRequested()
            }
        }

        BarText {
            text: Sys.activeApp
            font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: Sys.workspaces
                Rectangle {
                    required property var modelData
                    readonly property bool focused: modelData.id === Sys.focusedWorkspace
                    width: focused ? 18 : 7
                    height: 7
                    radius: 3.5
                    color: Theme.barText
                    opacity: focused ? 0.9 : 0.35
                    Behavior on width { SpringAnimation { spring: 5; damping: 0.4 } }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        onClicked: parent.modelData.activate()
                    }
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Tray {
            anchors.verticalCenter: parent.verticalCenter
        }

        // Updates waiting: click for the Store's Updates tab.
        Row {
            visible: bar.updates > 0
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            BarGlyph { text: Theme.icons.download }
            BarText { text: bar.updates; anchors.verticalCenter: parent.verticalCenter }
            TapHandler { // a MouseArea can't fill a Row
                margin: 6
                onTapped: bar.updatesRequested()
            }
        }
        Row {
            visible: Sys.hasBattery
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            BarText { text: Math.round(Sys.battery * 100) + "%"; anchors.verticalCenter: parent.verticalCenter }
            BarGlyph { text: Sys.charging ? Theme.icons.batteryCharging : Theme.batteryIcon(Sys.battery) }
        }
        BarGlyph {
            text: Sys.wired && !Sys.wifiName ? Theme.icons.ethernet : Sys.wifiOn ? Theme.icons.wifi : Theme.icons.wifiOff
            anchors.verticalCenter: parent.verticalCenter
        }
        BarGlyph {
            visible: Sys.btAvailable
            text: !Sys.btOn ? Theme.icons.bluetoothOff : Sys.btDevice ? Theme.icons.bluetoothConnected : Theme.icons.bluetooth
            anchors.verticalCenter: parent.verticalCenter
        }
        BarGlyph {
            text: Sys.muted ? Theme.icons.volumeOff : Sys.volume > 0.66 ? Theme.icons.volumeHigh : Sys.volume > 0.33 ? Theme.icons.volumeMedium : Theme.icons.volumeLow
            anchors.verticalCenter: parent.verticalCenter
        }

        // Control Center toggle: a glass pill while the panel is open.
        Rectangle {
            width: 40
            height: 24
            radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: bar.controlCenterOpen ? Qt.rgba(1, 1, 1, 0.22) : "transparent"
            border.width: bar.controlCenterOpen ? 1 : 0
            border.color: Qt.rgba(1, 1, 1, 0.5)
            BarGlyph { anchors.centerIn: parent; text: Theme.icons.controls }
            MouseArea {
                anchors.fill: parent
                onClicked: bar.controlCenterRequested()
            }
        }

        BarGlyph {
            visible: Sys.dnd
            text: Theme.icons.moon
            anchors.verticalCenter: parent.verticalCenter
        }

        // Recording the screen: click to stop.
        BarGlyph {
            visible: Sys.recording
            text: Theme.icons.stopRecording
            color: Theme.danger
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: Sys.stopRecording()
            }
        }

        // Weather and clock open the Notification Center (calendar, forecast), as on macOS.
        Row {
            visible: Sys.weatherOn && Sys.weather !== null
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter
            BarGlyph { text: Sys.weather?.glyph ?? "" }
            BarText { text: (Sys.weather?.temp ?? "") + "°"; anchors.verticalCenter: parent.verticalCenter }
            TapHandler {
                margin: 6
                onTapped: bar.notificationCenterRequested()
            }
        }
        BarText {
            text: Qt.formatDateTime(bar.now, "ddd MMM d") + "   " + Qt.formatDateTime(bar.now, Sys.clock24 ? "H:mm" : "h:mm AP")
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: bar.notificationCenterRequested()
            }
        }
    }
}
