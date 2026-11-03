import QtQuick
import QtQuick.Layouts

// Settings > Printers (CUPS): printers found on the network or plugged in, the default, a test
// page, and adding one by its address. Only driverless printers: nearly every printer since
// 2015 (AirPrint, IPP Everywhere, Mopria).
Flickable {
    id: page

    required property var settings
    property string address: ""
    readonly property var states: ({ idle: "Ready", printing: "Printing", disabled: "Paused" })

    clip: true
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        SettingsCard {
            Label { Layout.topMargin: 10; text: "Printers"; font.weight: Font.DemiBold }
            Label {
                Layout.fillWidth: true
                text: page.settings.printers.length ? "Printers on your network and plugged in by USB show up by themselves." : "No printers found. Turn the printer on and join it to the same network, or plug it in."
                dim: true
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                bottomPadding: 4
            }
            Repeater {
                model: page.settings.printers
                SettingRow {
                    id: printer
                    required property var modelData
                    title: printer.modelData.name.replace(/_/g, " ")
                    hint: (page.states[printer.modelData.state] ?? printer.modelData.state) + (printer.modelData.isDefault ? " · Default" : "")
                    Row {
                        spacing: 8
                        PillButton { text: "Test Page"; primary: false; onClicked: page.settings.testPrinter(printer.modelData.name) }
                        PillButton { visible: !printer.modelData.isDefault; text: "Make Default"; primary: false; onClicked: page.settings.setDefaultPrinter(printer.modelData.name) }
                        PillButton { visible: printer.modelData.added; text: "Remove"; primary: false; onClicked: page.settings.removePrinter(printer.modelData.name) }
                    }
                }
            }
            Item { implicitHeight: 6 }
        }

        SettingsCard {
            SettingRow {
                title: "Add by address"
                hint: "For a printer that doesn't show up: its IP address or name, from its screen or settings page."
                Row {
                    spacing: 8
                    Field {
                        id: address
                        width: 200
                        placeholder: "192.168.1.20"
                        onTextChanged: page.address = text.trim()
                        onAccepted: add.clicked()
                    }
                    PillButton {
                        id: add
                        text: "Add"
                        enabled: /^[A-Za-z0-9.:-]+$/.test(page.address)
                        onClicked: {
                            if (!enabled)
                                return;
                            page.settings.addPrinter(page.address.replace(/[^A-Za-z0-9]/g, "_"), `ipp://${page.address}/ipp/print`);
                            address.text = "";
                        }
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: page.settings.printersStatus
            dim: true
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }
}
