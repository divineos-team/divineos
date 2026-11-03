import QtQuick
import QtQuick.Layouts

// Settings > Keyboard: input layouts, and the keys that switch between them.
Flickable {
    id: page

    required property var settings
    property string filter: ""
    readonly property var layouts: settings.keyboard.layouts ?? []
    readonly property var options: (settings.keyboard.options ?? "").split(",").filter(o => o)
    readonly property string switchKey: options.find(o => o.startsWith("grp:")) ?? "grp:alt_shift_toggle"

    function nameOf(code) {
        return settings.layoutNames.find(l => l.code === code)?.name ?? code;
    }
    // Keeps other XKB options (from the installer, say); the switch keys only matter with two layouts.
    function save(layouts, key) {
        const rest = options.filter(o => !o.startsWith("grp:"));
        settings.setLayouts(layouts, (layouts.length > 1 ? rest.concat([key]) : rest).join(","));
    }

    clip: true
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        SettingsCard {
            Label { text: "Layouts"; font.weight: Font.DemiBold; topPadding: 8 }
            Label { text: "The first is the one you start with."; dim: true; font.pixelSize: 12; bottomPadding: 6 }
            Repeater {
                model: page.layouts
                RowLayout {
                    id: layout
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: 10
                    Label { Layout.fillWidth: true; text: page.nameOf(layout.modelData) }
                    Label { text: layout.modelData; dim: true; font.pixelSize: 12 }
                    PillButton {
                        visible: page.layouts.length > 1
                        text: "Remove"
                        primary: false
                        onClicked: page.save(page.layouts.filter((_, i) => i !== layout.index), page.switchKey)
                    }
                }
            }
            Item { implicitHeight: 8 }
        }

        SettingsCard {
            visible: page.layouts.length > 1
            SettingRow {
                title: "Switch layouts with"
                Segmented {
                    options: [{ label: "Alt+Shift", value: "grp:alt_shift_toggle" }, { label: "Ctrl+Shift", value: "grp:ctrl_shift_toggle" }, { label: "Caps Lock", value: "grp:caps_toggle" }]
                    value: page.switchKey
                    onPicked: v => page.save(page.layouts, v)
                }
            }
        }

        SettingsCard {
            Label { text: "Add a layout"; font.weight: Font.DemiBold; topPadding: 8; bottomPadding: 8 }
            Field {
                Layout.fillWidth: true
                icon: Theme.icons.search
                placeholder: "Search layouts"
                onTextChanged: page.filter = text.trim().toLowerCase()
            }
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                clip: true
                spacing: 2
                model: page.settings.layoutNames.filter(l => !page.layouts.includes(l.code) && (l.name.toLowerCase().includes(page.filter) || l.code.startsWith(page.filter)))
                delegate: Choice {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.name
                    detail: modelData.code
                    onPicked: page.save(page.layouts.concat([modelData.code]), page.switchKey)
                }
            }
        }
    }
}
