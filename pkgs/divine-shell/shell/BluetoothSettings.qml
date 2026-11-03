import QtQuick
import QtQuick.Layouts

// Settings > Bluetooth: Control Center's list (connect, disconnect, pair what's nearby), and
// forgetting a paired device.
Flickable {
    id: page

    required property var settings

    clip: true
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        BluetoothPage {
            Layout.fillWidth: true
            backable: false
            radius: 22
        }

        SettingsCard {
            visible: Sys.btOn && Sys.btPaired.length > 0
            Label { Layout.topMargin: 10; text: "Forget a device"; font.weight: Font.DemiBold }
            Label { text: "It has to pair again before it can connect."; dim: true; font.pixelSize: 12; bottomPadding: 4 }
            Repeater {
                model: Sys.btPaired
                SettingRow {
                    required property var modelData
                    title: modelData.name
                    PillButton { text: "Forget"; primary: false; onClicked: modelData.forget() }
                }
            }
        }
    }
}
