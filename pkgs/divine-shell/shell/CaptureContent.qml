import QtQuick

// The capture bar, like macOS's Screenshot toolbar: capture the screen, a window or a
// selection, or record the screen or a selection. While recording it offers Stop instead.
Glass {
    id: root

    property bool recording: false

    signal capture(string mode)
    signal record(string mode)
    signal stop
    signal dismissed

    radius: 22
    implicitWidth: row.implicitWidth + 16
    implicitHeight: row.implicitHeight + 16

    component Tool: Rectangle {
        id: tool
        property string glyph
        property string label
        property bool rec: false // a red dot: this one records
        signal picked

        width: Math.max(64, name.implicitWidth + 24)
        height: 64
        radius: 14
        color: area.containsMouse ? Theme.off : "transparent"

        Glyph {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            y: 9
            text: tool.glyph
            font.pixelSize: 24
        }
        Rectangle {
            visible: tool.rec
            x: icon.x + icon.width - 5
            y: icon.y + icon.height - 9
            width: 10
            height: 10
            radius: 5
            color: Theme.danger
        }
        Label {
            id: name
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 9
            text: tool.label
            font.pixelSize: 11
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tool.picked()
        }
    }
    component Divider: Rectangle {
        width: 1
        height: 40
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.rim
    }

    Row {
        id: row
        x: 8
        y: 8
        spacing: 4

        Tool { glyph: Theme.icons.display; label: "Screen"; onPicked: root.capture("screen") }
        Tool { glyph: Theme.icons.window; label: "Window"; onPicked: root.capture("window") }
        Tool { glyph: Theme.icons.selection; label: "Selection"; onPicked: root.capture("region") }
        Divider {}
        Tool { visible: !root.recording; glyph: Theme.icons.display; rec: true; label: "Record Screen"; onPicked: root.record("screen") }
        Tool { visible: !root.recording; glyph: Theme.icons.selection; rec: true; label: "Record Selection"; onPicked: root.record("region") }
        Tool { visible: root.recording; glyph: Theme.icons.stopRecording; label: "Stop Recording"; onPicked: root.stop() }
        Divider {}
        Tool { glyph: Theme.icons.close; label: "Close"; onPicked: root.dismissed() }
    }
}
