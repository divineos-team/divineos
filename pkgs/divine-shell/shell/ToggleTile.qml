import QtQuick

// Wide Control Center tile: icon disc (white when on), title and status. With `detail`, the
// disc switches it (toggled) and the rest of the tile opens its list (clicked), as on macOS.
Pressable {
    id: tile

    property string icon
    property string title
    property string status
    property bool active
    property bool detail: false
    signal toggled

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
            color: tile.active ? Theme.accentInk : Theme.text
        }
        MouseArea {
            anchors.fill: parent
            onClicked: tile.detail ? tile.toggled() : tile.clicked()
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
