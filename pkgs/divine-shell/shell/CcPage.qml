import QtQuick
import QtQuick.Layouts

// A Control Center detail page (Wi-Fi, Bluetooth, Sound) in the space the tiles took: back,
// title and an on/off switch over a list.
Glass {
    id: page

    property string title
    property bool switchable: false
    property bool on
    property bool backable: true // false in Settings, where the page stands on its own
    signal back
    signal switched
    default property alias body: column.data

    component Heading: Label {
        Layout.topMargin: 8
        leftPadding: 10
        dim: true
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    implicitWidth: Theme.unit * 4 + Theme.gap * 3
    implicitHeight: column.y + column.implicitHeight + 14

    Glyph {
        id: backButton
        x: 10
        y: 12
        width: page.backable ? 30 : 4
        height: 30
        visible: page.backable
        text: Theme.icons.chevronLeft
        font.pixelSize: 22
        MouseArea {
            anchors.fill: parent
            onClicked: page.back()
        }
    }
    Label {
        anchors.left: backButton.right
        anchors.leftMargin: 4
        anchors.verticalCenter: backButton.verticalCenter
        text: page.title
        font.pixelSize: 15
        font.weight: Font.Bold
    }

    Rectangle {
        visible: page.switchable
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: backButton.verticalCenter
        width: 42
        height: 24
        radius: 12
        color: page.on ? Theme.accent : Theme.track
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            x: page.on ? parent.width - width - 2 : 2
            y: 2
            width: 20
            height: 20
            radius: 10
            color: "#ffffff"
            Behavior on x { SpringAnimation { spring: 5; damping: 0.4 } }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: page.switched()
        }
    }

    ColumnLayout {
        id: column
        x: 12
        y: 50
        width: parent.width - 24
        spacing: 2
    }
}
