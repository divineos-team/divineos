import QtQuick

// Full-width Control Center slider (Display, Sound). The track thickens while touched.
Glass {
    id: slider

    property string title
    property string iconStart
    property string iconEnd
    property real value // 0..1
    signal moved(real value)
    signal iconClicked
    signal endClicked

    implicitWidth: Theme.unit * 4 + Theme.gap * 3
    implicitHeight: 84

    Label {
        x: 22
        y: 14
        text: slider.title
        font.weight: Font.DemiBold
    }

    Glyph {
        id: start
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        width: 24
        text: slider.iconStart
        font.pixelSize: 18
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            onClicked: slider.iconClicked()
        }
    }

    Glyph {
        id: end
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: start.verticalCenter
        width: slider.iconEnd ? 24 : 0
        text: slider.iconEnd
        font.pixelSize: 22
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            onClicked: slider.endClicked()
        }
    }

    Item {
        id: track
        anchors.left: start.right
        anchors.right: end.left
        anchors.leftMargin: 12
        anchors.rightMargin: slider.iconEnd ? 12 : 0
        anchors.verticalCenter: start.verticalCenter
        height: 28

        Rectangle {
            id: groove
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: drag.containsMouse || drag.pressed ? 10 : 6
            radius: height / 2
            color: Theme.track
            Behavior on height { SpringAnimation { spring: 5; damping: 0.4 } }

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.min(1, slider.value))
                height: parent.height
                radius: parent.radius
                color: Theme.fill
            }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            hoverEnabled: true
            function set(x) {
                slider.moved(Math.max(0, Math.min(1, x / width)));
            }
            onPressed: mouse => set(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    set(mouse.x);
            }
            onWheel: wheel => slider.moved(Math.max(0, Math.min(1, slider.value + wheel.angleDelta.y / 2400)))
        }
    }
}
