import QtQuick

// A row of pill choices; the picked one lights up like an active Control Center toggle.
Rectangle {
    id: seg

    property var options: [] // [{ label, value }]
    property var value
    signal picked(var value)

    implicitHeight: 34
    implicitWidth: row.implicitWidth + 8
    radius: height / 2
    color: Theme.off

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: seg.options

            Rectangle {
                required property var modelData
                readonly property bool on: modelData.value === seg.value

                width: label.implicitWidth + 26
                height: seg.height - 6
                radius: height / 2
                color: on ? (Theme.dark ? "#ffffff" : Theme.accent) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Label {
                    id: label
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    font.weight: Font.DemiBold
                    color: parent.on ? (Theme.dark ? Theme.accentInk : Theme.textOnAccent) : Theme.text
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: seg.picked(parent.modelData.value)
                }
            }
        }
    }
}
