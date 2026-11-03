import QtQuick

// The month at a glance, at the top of the Notification Center: today in the accent, arrows
// (or the wheel) to leaf through months, the month's name back to this one. Weeks start on
// the locale's first day.
Glass {
    id: cal

    property date now: new Date()
    property int offset: 0 // months from this one

    readonly property date month: new Date(now.getFullYear(), now.getMonth() + offset, 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek // 0 is Sunday
    readonly property int lead: (month.getDay() - firstDay + 7) % 7 // days shown from the month before
    readonly property int days: new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
    readonly property real cell: (width - 24) / 7

    implicitWidth: 360
    implicitHeight: grid.y + grid.height + 12
    radius: 22

    MouseArea {
        anchors.fill: parent
        onWheel: wheel => cal.offset += wheel.angleDelta.y > 0 ? -1 : 1
    }

    Label {
        id: title
        x: 18
        y: 14
        text: Qt.formatDate(cal.month, cal.month.getFullYear() === cal.now.getFullYear() ? "MMMM" : "MMMM yyyy")
        font.pixelSize: 15
        font.weight: Font.Bold
        color: cal.offset === 0 ? Theme.text : Theme.textDim
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            onClicked: cal.offset = 0
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: title.verticalCenter
        spacing: 4
        Repeater {
            model: [-1, 1]
            Glyph {
                required property int modelData
                width: 26
                height: 26
                text: modelData < 0 ? Theme.icons.chevronLeft : Theme.icons.chevronRight
                font.pixelSize: 18
                color: Theme.textDim
                MouseArea {
                    anchors.fill: parent
                    onClicked: cal.offset += parent.modelData
                }
            }
        }
    }

    Row {
        id: weekdays
        x: 12
        anchors.top: title.bottom
        anchors.topMargin: 10
        Repeater {
            model: 7
            Label {
                required property int index
                width: cal.cell
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(new Date(2023, 0, 1 + (cal.firstDay + index) % 7), "ddd") // 1 Jan 2023 was a Sunday; named like the menu bar's date
                dim: true
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }

    Grid {
        id: grid
        x: 12
        anchors.top: weekdays.bottom
        anchors.topMargin: 4
        columns: 7

        Repeater {
            model: Math.ceil((cal.lead + cal.days) / 7) * 7

            Item {
                required property int index
                readonly property date day: new Date(cal.month.getFullYear(), cal.month.getMonth(), index - cal.lead + 1)
                readonly property bool today: day.toDateString() === cal.now.toDateString()

                width: cal.cell
                height: 30

                Rectangle {
                    visible: parent.today
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: 13
                    color: Theme.accent
                }
                Label {
                    anchors.centerIn: parent
                    text: parent.day.getDate()
                    font.pixelSize: 12
                    font.weight: parent.today ? Font.Bold : Font.Medium
                    color: parent.today ? Theme.textOnAccent : Theme.text
                    opacity: parent.day.getMonth() === cal.month.getMonth() ? 1 : 0.35
                }
            }
        }
    }
}
