import QtQuick
import QtQuick.Layouts

// Control Center tiles on a 4-column grid of Theme.unit cells. The Wi-Fi and Bluetooth tiles
// and the Sound slider's arrow open their lists in the tiles' place.
Item {
    id: cc

    property string page: "" // "", "wifi", "bluetooth" or "sound"
    signal dismiss
    signal lockRequested
    function reset() {
        page = "";
    }

    implicitWidth: grid.implicitWidth
    implicitHeight: page ? pages.implicitHeight : grid.implicitHeight

    GridLayout {
        id: grid
        visible: cc.page === ""
        columns: 4
        rowSpacing: Theme.gap
        columnSpacing: Theme.gap

        ToggleTile {
            Layout.columnSpan: 2
            icon: Sys.wifiOn ? Theme.icons.wifi : Theme.icons.wifiOff
            title: "Wi-Fi"
            status: Sys.networkStatus
            active: Sys.wifiOn
            detail: true
            onToggled: Sys.toggleWifi()
            onClicked: cc.page = "wifi"
        }
        NowPlaying {
            Layout.columnSpan: 2
            Layout.rowSpan: 2
        }
        ToggleTile {
            Layout.columnSpan: 2
            icon: Sys.btOn ? Theme.icons.bluetooth : Theme.icons.bluetoothOff
            title: "Bluetooth"
            status: !Sys.btAvailable ? "Unavailable" : !Sys.btOn ? "Off" : Sys.btDevice || "On"
            active: Sys.btOn
            detail: true
            onToggled: Sys.toggleBluetooth()
            onClicked: cc.page = "bluetooth"
        }

        ToggleTile {
            Layout.columnSpan: 2
            icon: [Theme.icons.saver, Theme.icons.balanced, Theme.icons.performance][Sys.powerProfile]
            title: "Power Mode"
            status: Sys.powerProfileName
            active: Sys.powerProfileName !== "Balanced"
            onClicked: Sys.cyclePowerProfile()
        }
        ToggleTile {
            Layout.columnSpan: 2
            icon: Theme.icons.moon
            title: "Do Not Disturb"
            status: Sys.dnd ? "On" : "Off"
            active: Sys.dnd
            onClicked: Sys.setDnd(!Sys.dnd)
        }

        CircleButton {
            icon: Theme.icons.appearance
            active: !Sys.darkMode
            onClicked: Sys.setDarkMode(!Sys.darkMode)
        }
        CircleButton {
            icon: Theme.icons.nightLight
            active: Sys.nightLight
            onClicked: Sys.setNightLight(!Sys.nightLight)
        }
        CircleButton {
            icon: Theme.icons.airplane
            active: Sys.airplane
            onClicked: Sys.toggleAirplane()
        }
        CircleButton {
            icon: Sys.micMuted ? Theme.icons.micOff : Theme.icons.mic
            active: !Sys.micMuted
            onClicked: Sys.toggleMic()
        }

        CircleButton {
            icon: Theme.icons.screenshot
            onClicked: {
                cc.dismiss();
                Sys.capture("region");
            }
        }
        // One click records this screen; the menu bar's red button (or this) stops it.
        CircleButton {
            icon: Sys.recording ? Theme.icons.stopRecording : Theme.icons.record
            active: Sys.recording
            onClicked: {
                if (Sys.recording) {
                    Sys.stopRecording();
                } else {
                    cc.dismiss();
                    Sys.record("screen");
                }
            }
        }
        SessionTile {
            Layout.columnSpan: 2
            onLockRequested: {
                cc.dismiss();
                cc.lockRequested();
            }
        }

        GlassSlider {
            Layout.columnSpan: 4
            visible: Sys.brightness >= 0
            title: "Display"
            iconStart: Theme.icons.sunSmall
            iconEnd: Theme.icons.sunLarge
            value: Sys.brightness
            onMoved: v => Sys.setBrightness(v)
        }
        GlassSlider {
            Layout.columnSpan: 4
            title: "Sound"
            iconStart: Sys.muted ? Theme.icons.volumeOff : Theme.icons.volumeHigh
            iconEnd: Theme.icons.chevronRight
            value: Sys.muted ? 0 : Sys.volume
            onMoved: v => Sys.setVolume(v)
            onIconClicked: Sys.toggleMute()
            onEndClicked: cc.page = "sound"
        }
    }

    Column {
        id: pages
        visible: cc.page !== ""
        width: grid.implicitWidth

        WifiPage {
            visible: cc.page === "wifi"
            width: parent.width
            onBack: cc.reset()
        }
        BluetoothPage {
            visible: cc.page === "bluetooth"
            width: parent.width
            onBack: cc.reset()
        }
        SoundPage {
            visible: cc.page === "sound"
            width: parent.width
            onBack: cc.reset()
        }
    }
}
