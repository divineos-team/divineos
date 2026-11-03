import QtQuick

// Wide Control Center tile: icon disc (white when on), title and status.
Pressable {
    id: tile

    property string icon
    property string title
    property string status
    property bool active

    implicitWidth: Theme.unit * 2 + Theme.gap
    implicitHeight: Theme.unit

    Rectangle {
        id: disc
        width: 42
        height: 42
        radius: 21
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: tile.active ? "#ffffff" : Theme.off
        Behavior on color { ColorAnimation { duration: 160 } }
        Glyph {
            anchors.centerIn: parent
            text: tile.icon
            color: tile.active ? Theme.accent : Theme.text
        }
    }

    Column {
        anchors.left: disc.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Label { width: parent.width; text: tile.title; font.weight: Font.DemiBold }
        Label {
            width: parent.width
            text: tile.status
            dim: true
            font.pixelSize: 12
            wrapMode: Text.WrapAnywhere // long SSIDs wrap like macOS instead of vanishing
            maximumLineCount: 2
        }
    }
}
