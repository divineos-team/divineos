import QtQuick
import QtQuick.Layouts

// Control Center tiles on a 4-column grid of Theme.unit cells.
GridLayout {
    id: cc

    signal dismiss
    signal lockRequested

    columns: 4
    rowSpacing: Theme.gap
    columnSpacing: Theme.gap

    ToggleTile {
        Layout.columnSpan: 2
        icon: Sys.wifiOn ? Theme.icons.wifi : Theme.icons.wifiOff
        title: "Wi-Fi"
        status: Sys.networkStatus
        active: Sys.wifiOn
        onClicked: Sys.toggleWifi()
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
        onClicked: Sys.toggleBluetooth()
    }

    ToggleTile {
        Layout.columnSpan: 2
        icon: [Theme.icons.saver, Theme.icons.balanced, Theme.icons.performance][Sys.powerProfile]
        title: "Power Mode"
        status: Sys.powerProfileName
        active: Sys.powerProfileName !== "Balanced"
        onClicked: Sys.cyclePowerProfile()
    }
    CircleButton {
        icon: Theme.icons.appearance
        active: !Sys.darkMode
        onClicked: Sys.setDarkMode(!Sys.darkMode)
    }
    CircleButton {
        icon: Theme.icons.screenshot
        onClicked: {
            cc.dismiss();
            Sys.capture("region");
        }
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
        value: Sys.muted ? 0 : Sys.volume
        onMoved: v => Sys.setVolume(v)
        onIconClicked: Sys.toggleMute()
    }
}
