import QtQuick
import QtQuick.Layouts

// Settings > Power: the power mode, and when the screen locks, turns off and the computer sleeps.
Flickable {
    id: page

    required property var settings
    readonly property var idle: settings.idle

    function minutes(list) { // [2, 5] → Segmented options in seconds, then Never (0)
        return list.map(m => ({ label: m < 60 ? `${m} min` : `${m / 60} h`, value: m * 60 })).concat([{ label: "Never", value: 0 }]);
    }
    function set(key, value) {
        settings.setIdle(Object.assign({}, idle, { [key]: value }));
    }

    clip: true
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        SettingsCard {
            SettingRow {
                title: "Power mode"
                hint: "Performance runs the processor faster and warmer. Power Saver makes the battery last."
                Segmented {
                    options: [{ label: "Saver", value: 0 }, { label: "Balanced", value: 1 }].concat(page.settings.hasPerformance ? [{ label: "Performance", value: 2 }] : [])
                    value: page.settings.powerProfile
                    onPicked: v => page.settings.setPowerProfile(v)
                }
            }
        }

        SettingsCard {
            SettingRow {
                title: "Lock the screen after"
                Segmented { options: page.minutes([2, 5, 10, 30]); value: page.idle.lock; onPicked: v => page.set("lock", v) }
            }
            SettingRow {
                title: "Turn the screen off after"
                Segmented { options: page.minutes([5, 10, 15, 30]); value: page.idle.screen; onPicked: v => page.set("screen", v) }
            }
            SettingRow {
                title: "Sleep after"
                hint: "The screen locks first."
                Segmented { options: page.minutes([15, 30, 60]); value: page.idle.suspend; onPicked: v => page.set("suspend", v) }
            }
        }

        Label {
            Layout.fillWidth: true
            text: "Counted from the last time you used the mouse or keyboard. Video players and browsers playing video hold these off."
            dim: true
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }
}
