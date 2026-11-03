import QtQuick

// Glass that dips under the finger with a spring, like a Control Center tile.
Glass {
    id: root

    signal clicked

    scale: area.pressed ? 0.95 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.001 } }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
