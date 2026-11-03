import QtQuick
import QtQuick.Layouts

// Control Center > Wi-Fi: networks in range, scanned for while the page is open. Saved and
// open networks join on a click, others ask for the password; the joined one can be left or
// forgotten.
CcPage {
    id: page

    property var picked: null // the network asking for its password, or the joined one clicked
    property string error: ""
    readonly property bool asking: picked !== null && !picked.connected && Sys.wifiNeedsPassword(picked)

    function use(network) {
        error = "";
        password.text = "";
        picked = picked === network && network.connected ? null : network;
        if (asking)
            password.takeFocus();
        else if (!network.connected)
            Sys.joinWifi(network, "");
    }

    title: "Wi-Fi"
    switchable: true
    on: Sys.wifiOn
    onSwitched: Sys.toggleWifi()
    onVisibleChanged: {
        Sys.setWifiScanning(visible);
        picked = null;
        error = "";
    }

    Connections {
        target: page.picked
        function onConnectionFailed(reason) {
            page.error = `Couldn't join “${page.picked.name}”.` + (page.picked.known ? " If its password changed, forget it and join again." : " Check the password and try again.");
        }
    }

    Label {
        visible: !Sys.wifiOn || Sys.wifiNetworks.length === 0
        Layout.bottomMargin: 6
        leftPadding: 10
        text: Sys.wifiOn ? "Looking for networks…" : "Wi-Fi is off."
        dim: true
    }

    ListView {
        visible: Sys.wifiOn
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 320)
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: Sys.wifiNetworks
        delegate: Choice {
            required property var modelData
            width: ListView.view.width
            icon: Theme.wifiIcon(modelData.signalStrength, Sys.wifiLocked(modelData))
            text: modelData.name
            detail: modelData.known && !modelData.connected ? "Saved" : ""
            on: modelData.connected
            onPicked: page.use(modelData)
        }
    }

    // The joined network, clicked: leave it, or forget its password too.
    RowLayout {
        visible: page.picked?.connected ?? false
        Layout.topMargin: 8
        Layout.leftMargin: 6
        spacing: 8
        PillButton {
            primary: false
            text: "Disconnect"
            onClicked: {
                page.picked.disconnect();
                page.picked = null;
            }
        }
        PillButton {
            primary: false
            text: "Forget This Network"
            onClicked: {
                page.picked.forget();
                page.picked = null;
            }
        }
    }

    // A new secured network: its password, then Join.
    Label {
        visible: page.asking
        Layout.topMargin: 8
        leftPadding: 10
        text: `Password for “${page.picked?.name ?? ""}”`
        font.weight: Font.DemiBold
    }
    RowLayout {
        visible: page.asking
        Layout.topMargin: 4
        spacing: 8
        Field {
            id: password
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholder: "Password"
            onAccepted: join.clicked()
        }
        PillButton {
            id: join
            text: "Join"
            enabled: password.text.length >= 8 // WPA's shortest
            onClicked: {
                if (!enabled)
                    return;
                Sys.joinWifi(page.picked, password.text);
                password.text = "";
            }
        }
    }

    Label {
        visible: page.error !== ""
        Layout.fillWidth: true
        Layout.topMargin: 8
        leftPadding: 10
        text: page.error
        color: Theme.danger
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
}
