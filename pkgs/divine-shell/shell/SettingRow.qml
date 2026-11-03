import QtQuick
import QtQuick.Layouts

// A titled setting with its control on the right (Settings, Store).
Item {
    id: setting

    property string title
    property string hint
    default property alias control: slot.data

    Layout.fillWidth: true
    implicitHeight: Math.max(texts.implicitHeight, slot.childrenRect.height) + 22

    Column {
        id: texts
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Label { width: parent.width; text: setting.title; font.weight: Font.DemiBold }
        Label { width: parent.width; visible: text !== ""; text: setting.hint; dim: true; font.pixelSize: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone }
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
