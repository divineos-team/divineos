import QtQuick
import QtQuick.Effects

// A round account picture; the first letter of the name on glass when there's none.
Item {
    id: root

    property string source: ""
    property string name: ""
    property color textColor: Theme.text

    implicitWidth: 76
    implicitHeight: 76

    Glass {
        anchors.fill: parent
        round: true
        visible: picture.status !== Image.Ready
        Label {
            anchors.centerIn: parent
            text: root.name.charAt(0).toUpperCase()
            color: root.textColor
            font.pixelSize: root.height * 0.42
            font.weight: Font.DemiBold
        }
    }
    Image {
        id: picture
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.width * 2, root.height * 2)
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        visible: picture.status === Image.Ready
        anchors.fill: parent
        source: picture
        maskEnabled: true
        maskSource: circle
    }
    Rectangle {
        id: circle
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }
}
