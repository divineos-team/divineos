import QtQuick
import QtQuick.Layouts

// Settings > Default Apps: which app opens links, mail, folders, text, pictures, video, music and PDFs.
Flickable {
    id: page

    required property var settings

    clip: true
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        Repeater {
            model: page.settings.defaultApps
            SettingsCard {
                id: kind
                required property var modelData
                Label { text: kind.modelData.label; font.weight: Font.DemiBold; topPadding: 8; bottomPadding: 6 }
                Label { visible: kind.modelData.apps.length === 0; text: "No installed app opens these. The Store has some."; dim: true; font.pixelSize: 12; bottomPadding: 8 }
                Repeater {
                    model: kind.modelData.apps
                    Choice {
                        required property var modelData
                        text: modelData.name
                        on: modelData.id === kind.modelData.current
                        onPicked: page.settings.setDefaultApp(kind.modelData.mimes, modelData.id)
                    }
                }
                Item { implicitHeight: 8 }
            }
        }
    }
}
