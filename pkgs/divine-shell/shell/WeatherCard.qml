import QtQuick

// The weather in the Notification Center: now, today's high and low, and the next five days.
// From Open-Meteo through Sys; Settings > Date & Time picks the place and the unit.
Glass {
    id: card

    readonly property var weather: Sys.weather ?? { temp: 0, label: "", glyph: "", high: 0, low: 0, days: [] }

    implicitWidth: 360
    implicitHeight: 150
    radius: 22

    Column {
        x: 18
        y: 12
        Label {
            text: Sys.weatherPlace?.name ?? ""
            font.weight: Font.DemiBold
        }
        Label {
            text: card.weather.temp + "°"
            font.pixelSize: 36
            font.weight: Font.Light
        }
    }

    Column {
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: 14
        spacing: 2
        Glyph {
            anchors.right: parent.right
            text: card.weather.glyph
            font.pixelSize: 24
        }
        Label {
            anchors.right: parent.right
            text: card.weather.label
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        Label {
            anchors.right: parent.right
            text: `H:${card.weather.high}°  L:${card.weather.low}°`
            font.pixelSize: 12
            dim: true
        }
    }

    Row {
        x: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        Repeater {
            model: card.weather.days.slice(1, 6)
            Column {
                required property var modelData
                width: (card.width - 24) / 5
                spacing: 3
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(new Date(parent.modelData.date + "T12:00"), "ddd") // noon: the same day in any zone
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    dim: true
                }
                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.modelData.glyph
                    font.pixelSize: 18
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${parent.modelData.high}°  ${parent.modelData.low}°`
                    font.pixelSize: 11
                }
            }
        }
    }
}
