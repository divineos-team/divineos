import QtQuick
import QtQuick.Layouts

// Settings > Date & Time: the time zone, internet time, the 24-hour clock and the weather.
Flickable {
    id: page

    required property var settings
    property string filter: ""
    readonly property var weather: settings.weather

    clip: true
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        SettingsCard {
            SettingRow {
                title: "Set the time automatically"
                hint: page.settings.time.synced ? "In sync with internet time servers." : "From internet time servers, whenever you're online."
                Segmented {
                    options: [{ label: "On", value: true }, { label: "Off", value: false }]
                    value: page.settings.time.ntp
                    onPicked: v => page.settings.setNtp(v)
                }
            }
            SettingRow {
                title: "Clock"
                hint: "In the menu bar and on the lock screen."
                Segmented {
                    options: [{ label: "12-hour", value: false }, { label: "24-hour", value: true }]
                    value: page.settings.clock24
                    onPicked: v => page.settings.setClock24(v)
                }
            }
        }

        SettingsCard {
            Label { text: "Time zone"; font.weight: Font.DemiBold; topPadding: 8 }
            Label { text: (page.settings.time.timezone ?? "").replace(/_/g, " "); dim: true; font.pixelSize: 12; bottomPadding: 8 }
            Field {
                Layout.fillWidth: true
                icon: Theme.icons.search
                placeholder: "Search cities and regions"
                onTextChanged: page.filter = text.trim().toLowerCase().replace(/ /g, "_")
            }
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 260
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                clip: true
                spacing: 2
                model: page.settings.timezones.filter(z => z.toLowerCase().includes(page.filter))
                delegate: Choice {
                    required property string modelData
                    width: ListView.view.width
                    text: modelData.replace(/_/g, " ")
                    on: modelData === page.settings.time.timezone
                    onPicked: page.settings.setTimezone(modelData)
                }
            }
        }

        // Weather in the menu bar and the Notification Center (Open-Meteo: no account, no key).
        SettingsCard {
            SettingRow {
                title: "Weather"
                hint: "In the menu bar and the Notification Center, from Open-Meteo."
                Segmented {
                    options: [{ label: "On", value: true }, { label: "Off", value: false }]
                    value: page.weather.on
                    onPicked: v => page.settings.setWeather({ on: v })
                }
            }
            SettingRow {
                visible: page.weather.on
                title: "Temperature"
                Segmented {
                    options: [{ label: "°C", value: "c" }, { label: "°F", value: "f" }]
                    value: page.weather.unit
                    onPicked: v => page.settings.setWeather({ unit: v })
                }
            }
            SettingRow {
                visible: page.weather.on
                title: page.weather.place ? [page.weather.place.name, page.weather.place.detail].filter(x => x).join(", ") : "No place yet"
                hint: page.weather.picked ? "Chosen here." : "The city your time zone is named after."
                PillButton {
                    visible: page.weather.picked
                    primary: false
                    text: "Use Time Zone"
                    onClicked: page.settings.setWeather({ place: null })
                }
            }
            Field {
                id: placeSearch
                visible: page.weather.on
                Layout.fillWidth: true
                Layout.bottomMargin: page.settings.places.length ? 4 : 8
                icon: Theme.icons.search
                placeholder: "Search for a city"
                onTextChanged: searchSoon.restart()
                onAccepted: page.settings.searchPlaces(text)
                Timer {
                    id: searchSoon
                    interval: 400
                    onTriggered: page.settings.searchPlaces(placeSearch.text)
                }
            }
            Repeater {
                model: page.weather.on && placeSearch.text ? page.settings.places : []
                Choice {
                    required property var modelData
                    Layout.bottomMargin: 2
                    text: modelData.name
                    detail: modelData.detail
                    onPicked: {
                        page.settings.setWeather({ place: modelData });
                        placeSearch.text = "";
                    }
                }
            }
        }
    }
}
