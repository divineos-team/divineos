import QtQuick
import QtQuick.Layouts

// Settings > Startup Apps: what opens when you sign in (XDG autostart), and adding an app.
Flickable {
    id: page

    required property var settings
    property string query: ""
    readonly property var matches: query.length < 2 ? [] : settings.apps.filter(a => a.name.toLowerCase().includes(query.toLowerCase()) && !settings.startup.some(s => s.file === a.id + ".desktop")).slice(0, 6)

    clip: true
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        SettingsCard {
            Label { Layout.topMargin: 10; text: "Open when you sign in"; font.weight: Font.DemiBold }
            Label { visible: page.settings.startup.length === 0; text: "Nothing yet. Add an app below."; dim: true; font.pixelSize: 12; bottomPadding: 10 }
            Repeater {
                model: page.settings.startup
                RowLayout {
                    id: entry
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    spacing: 12
                    Image { Layout.preferredWidth: 28; Layout.preferredHeight: 28; sourceSize: Qt.size(56, 56); source: entry.modelData.icon }
                    Label { Layout.fillWidth: true; text: entry.modelData.name; font.weight: Font.Medium }
                    PillButton { visible: entry.modelData.own; text: "Remove"; primary: false; onClicked: page.settings.removeStartup(entry.modelData.file) }
                    Segmented {
                        options: [{ label: "On", value: true }, { label: "Off", value: false }]
                        value: entry.modelData.on
                        onPicked: v => page.settings.setStartup(entry.modelData.file, v)
                    }
                }
            }
            Item { implicitHeight: 6 }
        }

        SettingsCard {
            Label { Layout.topMargin: 10; text: "Add an app"; font.weight: Font.DemiBold }
            Field {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.bottomMargin: 8
                icon: Theme.icons.search
                placeholder: "Search apps"
                onTextChanged: page.query = text.trim()
            }
            Repeater {
                model: page.matches
                Choice {
                    required property var modelData
                    text: modelData.name
                    detail: "Add"
                    onPicked: page.settings.addStartup(modelData.id)
                }
            }
            Item { implicitHeight: 8 }
        }
    }
}
