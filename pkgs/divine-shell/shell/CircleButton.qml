import QtQuick

// Round Control Center button. Turns into a white disc when active.
Pressable {
    id: button

    property string icon
    property bool active

    round: true
    implicitWidth: Theme.unit
    implicitHeight: Theme.unit
    color: active ? "#ffffff" : Theme.glass

    Glyph {
        anchors.centerIn: parent
        text: button.icon
        font.pixelSize: 24
        color: button.active ? Theme.accent : Theme.text
    }
}
