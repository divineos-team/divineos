import QtQuick

// A sidebar entry (Settings, Store): glyph and label, filled with the accent when chosen, with
// an optional count on the right.
Rectangle {
    id: item

    property string icon
    property string text
    property bool on
    property int badge: 0 // hidden at 0
    signal clicked

    implicitWidth: 190
    implicitHeight: 40
    radius: 14
    color: on ? Theme.accent : hover.containsMouse ? Theme.off : "transparent"

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        spacing: 10
        Glyph { text: item.icon; font.pixelSize: 18; color: item.on ? Theme.textOnAccent : Theme.text }
        Label { text: item.text; font.weight: Font.Medium; color: item.on ? Theme.textOnAccent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
    }
    Rectangle {
        visible: item.badge > 0
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(height, count.implicitWidth + 12)
        height: 20
        radius: 10
        color: item.on ? "#ffffff" : Theme.danger
        Label { id: count; anchors.centerIn: parent; text: item.badge; font.pixelSize: 11; font.weight: Font.Bold; color: item.on ? Theme.accentInk : "#ffffff" }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onClicked: item.clicked()
    }
}
