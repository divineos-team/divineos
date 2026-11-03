import QtQuick
import QtQuick.Layouts

// Control Center > Bluetooth: paired devices (click to connect or disconnect) and the ones
// nearby (click to pair, trust and connect), looked for while the page is open.
CcPage {
    id: page

    function glyph(device) {
        const icon = device.icon ?? "";
        return icon.startsWith("audio") ? Theme.icons.headphones : icon === "input-mouse" ? Theme.icons.mouse : icon === "input-keyboard" ? Theme.icons.keyboard : icon === "phone" ? Theme.icons.phone : icon === "computer" ? Theme.icons.laptop : Theme.icons.bluetooth;
    }
    function status(device) {
        return device.pairing ? "Pairing…" : !device.connected ? "" : device.batteryAvailable ? Math.round(device.battery * 100) + "%" : "Connected";
    }

    title: "Bluetooth"
    switchable: Sys.btAvailable
    on: Sys.btOn
    onSwitched: Sys.toggleBluetooth()
    onVisibleChanged: Sys.setBtScanning(visible)
    onOnChanged: Sys.setBtScanning(visible && on) // turned on while open

    Label {
        visible: !Sys.btOn
        Layout.bottomMargin: 6
        leftPadding: 10
        text: Sys.btAvailable ? "Bluetooth is off." : "No Bluetooth adapter."
        dim: true
    }

    CcPage.Heading {
        visible: Sys.btOn && Sys.btPaired.length > 0
        text: "My Devices"
    }
    Repeater {
        model: Sys.btOn ? Sys.btPaired : []
        Choice {
            required property var modelData
            icon: page.glyph(modelData)
            text: modelData.name
            detail: page.status(modelData)
            on: modelData.connected
            onPicked: Sys.useBtDevice(modelData)
        }
    }

    CcPage.Heading {
        visible: Sys.btOn
        text: Sys.btNearby.length ? "Nearby" : "Looking for devices…"
    }
    Repeater {
        model: Sys.btOn ? Sys.btNearby : []
        Choice {
            required property var modelData
            icon: page.glyph(modelData)
            text: modelData.name
            detail: page.status(modelData)
            onPicked: Sys.useBtDevice(modelData)
        }
    }
}
