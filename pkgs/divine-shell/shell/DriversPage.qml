import QtQuick
import QtQuick.Layouts

// Settings > Drivers: what divine-drivers finds this computer needs, and installing it.
Flickable {
    id: page

    required property var settings

    clip: true
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        SettingsCard {
            visible: page.settings.drivers.length === 0
            Label {
                Layout.fillWidth: true
                topPadding: 10
                bottomPadding: 10
                text: "This computer works with the drivers every divineOS has. Nothing to add."
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
        Repeater {
            model: page.settings.drivers
            SettingsCard {
                id: driver
                required property var modelData
                SettingRow {
                    title: driver.modelData.name
                    hint: driver.modelData.about + "\n" + driver.modelData.packages.join(", ")
                    PillButton {
                        text: driver.modelData.installed ? "Installed" : page.settings.driversBusy ? "Installing…" : "Install"
                        primary: !driver.modelData.installed
                        enabled: !driver.modelData.installed && !page.settings.driversBusy
                        onClicked: page.settings.installDrivers([driver.modelData.id])
                    }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: page.settings.driversStatus
            dim: true
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }
}
