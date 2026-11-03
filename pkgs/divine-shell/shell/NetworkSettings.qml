import QtQuick
import QtQuick.Layouts

// Settings > Network: Wi-Fi (the same list as Control Center), Ethernet, and VPNs through
// NetworkManager: turn them on and off, and import WireGuard (.conf) or OpenVPN (.ovpn) files
// found in ~/Downloads.
Flickable {
    id: page

    required property var settings
    readonly property var imported: settings.vpns.map(v => v.name)
    readonly property var newFiles: settings.vpnFiles.filter(f => !imported.includes(f.name.replace(/\.(conf|ovpn)$/, "")))

    clip: true
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        WifiPage {
            Layout.fillWidth: true
            backable: false
            radius: 22
        }

        SettingsCard {
            visible: Sys.hasWired ?? false
            SettingRow {
                title: "Ethernet"
                hint: Sys.wired ? "Connected" : "No cable"
                Glyph { text: Theme.icons.ethernet; font.pixelSize: 22; color: Sys.wired ? Theme.text : Theme.textDim }
            }
        }

        SettingsCard {
            Label { Layout.topMargin: 10; text: "VPN"; font.weight: Font.DemiBold }
            Label {
                Layout.fillWidth: true
                visible: page.settings.vpns.length === 0
                text: "Your VPN provider gives you a WireGuard (.conf) or OpenVPN (.ovpn) file. Save it in Downloads and it shows up here."
                dim: true
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                bottomPadding: 8
            }
            Repeater {
                model: page.settings.vpns
                SettingRow {
                    id: vpn
                    required property var modelData
                    title: vpn.modelData.name
                    hint: (vpn.modelData.type === "wireguard" ? "WireGuard" : "OpenVPN") + (vpn.modelData.active ? " · Connected" : "")
                    Row {
                        spacing: 8
                        PillButton { text: "Remove"; primary: false; onClicked: page.settings.removeVpn(vpn.modelData.name) }
                        Segmented {
                            options: [{ label: "On", value: true }, { label: "Off", value: false }]
                            value: vpn.modelData.active
                            onPicked: v => page.settings.setVpn(vpn.modelData.name, v)
                        }
                    }
                }
            }
            Repeater {
                model: page.newFiles
                SettingRow {
                    id: file
                    required property var modelData
                    title: file.modelData.name
                    hint: "In Downloads · " + (file.modelData.type === "wireguard" ? "WireGuard" : "OpenVPN")
                    PillButton { text: "Import"; onClicked: page.settings.importVpn(file.modelData.type, file.modelData.path) }
                }
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: page.settings.vpnStatus
                dim: true
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                bottomPadding: 8
            }
        }
    }
}
