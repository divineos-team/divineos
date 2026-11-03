import QtQuick

// A compact slider for a Settings row, its value on the right. Dragging shows the value as it
// goes; `moved` fires once, on release, so each change applies once.
Item {
    id: slider

    property real from: 0
    property real to: 1
    property real step: 1
    property real value
    property string suffix: ""
    signal moved(real value)

    readonly property real shown: drag.pressed ? drag.live : value
    readonly property real fraction: (shown - from) / (to - from)

    implicitWidth: 260
    implicitHeight: 28
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: groove
        anchors.left: parent.left
        anchors.right: readout.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Theme.track

        Rectangle {
            width: Math.max(parent.height, parent.width * slider.fraction)
            height: parent.height
            radius: parent.radius
            color: Theme.fill
        }
        Rectangle { // knob
            x: parent.width * slider.fraction - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            radius: 10
            color: "#ffffff"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.12)
        }
    }

    Label {
        id: readout
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(44, implicitWidth)
        horizontalAlignment: Text.AlignRight
        text: Math.round(slider.shown) + slider.suffix
        dim: true
    }

    MouseArea {
        id: drag
        property real live
        anchors.fill: groove
        anchors.margins: -10
        function at(x) {
            const f = Math.max(0, Math.min(1, (x - 10) / groove.width));
            return Math.round((slider.from + f * (slider.to - slider.from)) / slider.step) * slider.step;
        }
        onPressed: mouse => live = at(mouse.x)
        onPositionChanged: mouse => live = at(mouse.x)
        onReleased: {
            if (live !== slider.value)
                slider.moved(live);
        }
    }
}
