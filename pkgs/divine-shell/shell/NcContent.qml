import QtQuick

// Notification Center: the calendar and the weather, then Do Not Disturb, Clear, and every
// notification not yet dismissed, newest first.
Item {
    id: nc

    property date now: new Date()
    property real maxHeight: 720
    signal dismiss
    function reset() { // on opening: back to this month
        calendar.offset = 0;
    }

    implicitWidth: 360
    implicitHeight: Math.min(head.y + head.height + 10 + (list.count ? list.contentHeight : empty.height), maxHeight)

    Column {
        id: widgets
        width: parent.width
        spacing: 10
        CalendarCard {
            id: calendar
            width: parent.width
            now: nc.now
        }
        WeatherCard {
            width: parent.width
            visible: Sys.weatherOn && Sys.weather !== null
        }
    }

    Item {
        id: head
        anchors.top: widgets.bottom
        anchors.topMargin: 6
        width: parent.width
        height: 40

        Label {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.barText
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            component Pill: Pressable {
                id: pill
                property alias text: pillLabel.text
                property alias glyph: pillGlyph.text
                property bool on: false
                round: true
                implicitWidth: pillRow.implicitWidth + 24
                implicitHeight: 30
                color: on ? "#ffffff" : Theme.glass
                Row {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 6
                    Glyph { id: pillGlyph; visible: text !== ""; font.pixelSize: 15; color: pill.on ? Theme.accentInk : Theme.text }
                    Label { id: pillLabel; font.pixelSize: 12; font.weight: Font.Medium; color: pill.on ? Theme.accentInk : Theme.text }
                }
            }

            Pill {
                glyph: Theme.icons.moon
                text: "Do Not Disturb"
                on: Sys.dnd
                onClicked: Sys.setDnd(!Sys.dnd)
            }
            Pill {
                visible: Sys.notifications.length > 0
                text: "Clear"
                onClicked: Sys.clearNotifications()
            }
        }
    }

    ListView {
        id: list
        anchors.top: head.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Sys.notifications
        delegate: NotificationCard {
            required property var modelData
            notification: modelData
            now: nc.now
        }
    }

    Glass {
        id: empty
        visible: list.count === 0
        anchors.top: head.bottom
        anchors.topMargin: 10
        width: parent.width
        height: 64
        radius: 22
        Label {
            anchors.centerIn: parent
            text: "No Notifications"
            dim: true
        }
    }
}
