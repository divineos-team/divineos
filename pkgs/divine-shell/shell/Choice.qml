import QtQuick
import QtQuick.Layouts

// A selectable row in a list (modes, outputs, profiles, apps), ticked when chosen.
Rectangle {
    id: choice

    property string text
    property string detail: "" // dim text on the right
    property bool on
    property string family: Theme.font // Settings > Appearance shows each font in itself
    property string icon: "" // a glyph in front (Control Center's lists)
    signal picked

    Layout.fillWidth: true
    implicitHeight: 36
    radius: 12
    color: on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85) : hover.containsMouse ? Theme.off : "transparent"

    Glyph {
        id: lead
        visible: choice.icon !== ""
        width: visible ? 22 : 0
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        text: choice.icon
        font.pixelSize: 18
        color: choice.on ? Theme.textOnAccent : Theme.text
    }
    Label {
        anchors.left: lead.right
        anchors.leftMargin: lead.visible ? 8 : 2 // 12 from the edge without a glyph
        anchors.right: side.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: choice.text
        font.family: choice.family
        color: choice.on ? Theme.textOnAccent : Theme.text
    }
    Label {
        id: side
        anchors.right: tick.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: choice.detail
        font.pixelSize: 12
        color: choice.on ? Theme.textOnAccent : Theme.textDim
    }
    Glyph {
        id: tick
        visible: choice.on
        width: visible ? implicitWidth : 0
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Theme.icons.check
        color: Theme.textOnAccent
        font.pixelSize: 16
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onClicked: choice.picked()
    }
}
