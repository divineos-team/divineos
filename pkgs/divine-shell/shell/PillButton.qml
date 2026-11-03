import QtQuick

// A pill button: accent-filled when primary, plain glass otherwise; dims when disabled.
Rectangle {
    id: pill

    property string text
    property bool primary: true
    property bool danger: false // red, for what deletes
    signal clicked

    implicitWidth: label.implicitWidth + 32
    implicitHeight: 32
    radius: height / 2
    opacity: enabled ? 1 : 0.45
    color: danger ? Theme.danger : primary ? Theme.accent : area.containsMouse ? Theme.track : Theme.off
    scale: area.pressed ? 0.96 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.001 } }

    Label {
        id: label
        anchors.centerIn: parent
        text: pill.text
        font.weight: Font.DemiBold
        color: pill.danger ? "#ffffff" : pill.primary ? Theme.textOnAccent : Theme.text
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: pill.clicked()
    }
}
