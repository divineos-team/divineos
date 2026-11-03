pragma ComponentBehavior: Bound
import QtQuick

// The app switcher, macOS style: one icon per app with a window, most recent first. The
// selected one is highlighted and named; hovering selects, clicking picks.
Glass {
    id: root

    property var apps: [] // Sys.switcherApps
    property int current: 0

    signal select(int index)
    signal picked(int index)

    radius: 30
    implicitWidth: row.implicitWidth + 24
    implicitHeight: row.implicitHeight + 24

    Row {
        id: row
        x: 12
        y: 12
        spacing: 4

        Repeater {
            model: root.apps

            Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool selected: index === root.current

                width: 112
                height: 126

                Rectangle {
                    anchors.fill: parent
                    radius: 22
                    color: Theme.track
                    visible: cell.selected
                }
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                    width: 72
                    height: 72
                    sourceSize: Qt.size(144, 144)
                    source: cell.modelData.icon
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 11
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                    visible: cell.selected
                    text: cell.modelData.name
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.select(cell.index)
                    onClicked: root.picked(cell.index)
                }
            }
        }
    }
}
