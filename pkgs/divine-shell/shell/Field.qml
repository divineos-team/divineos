import QtQuick

// A rounded text field with a placeholder and an optional glyph in front.
Rectangle {
    id: field

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string placeholder
    property string icon: ""
    signal accepted
    function takeFocus() {
        input.forceActiveFocus();
    }

    implicitWidth: 220
    implicitHeight: 34
    radius: height / 2
    color: Theme.off
    border.width: input.activeFocus ? 2 : 0
    border.color: Theme.accent

    MouseArea { // clicks beside the text still focus it
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }
    Glyph {
        id: glyph
        visible: field.icon !== ""
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: field.icon
        font.pixelSize: 16
        color: Theme.textDim
    }
    TextInput {
        id: input
        anchors.left: glyph.visible ? glyph.right : parent.left
        anchors.leftMargin: glyph.visible ? 8 : 14
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.font
        font.pixelSize: 13
        color: Theme.text
        selectionColor: Theme.accent
        selectByMouse: true
        clip: true
        onAccepted: field.accepted()

        Label {
            visible: !input.text
            anchors.verticalCenter: parent.verticalCenter
            text: field.placeholder
            dim: true
        }
    }
}
