import QtQuick

// Desktop widgets (devine-widgets) over the wallpaper: a clock, CPU / memory / GPU gauges, a
// sticky note and the media player. Each one drags anywhere; Settings > Desktop & Dock turns
// them on and off. Widgets.qml supplies the positions and the system numbers.
Item {
    id: root

    property var widgets: ({}) // kind → { x, y, text? }; missing kinds are off
    property date now: new Date()
    property var system: ({ cpu: 0, mem: 0, gpu: -1 }) // percent; gpu -1 is none
    signal moved(string kind, real x, real y)
    signal noteEdited(string text)

    // The area that takes clicks: every widget shown (Widgets.qml's input mask).
    readonly property var zones: [clock, gauges, note, media].filter(w => w.visible)

    // A widget at its saved place, dragged anywhere on the screen.
    component Movable: Item {
        id: movable
        property string kind
        readonly property var where: root.widgets[kind] ?? null
        visible: where !== null
        x: where?.x ?? 0
        y: where?.y ?? 0
        width: childrenRect.width
        height: childrenRect.height
        DragHandler {
            xAxis.minimum: 0
            xAxis.maximum: root.width - movable.width
            yAxis.minimum: 0
            yAxis.maximum: root.height - movable.height
            onActiveChanged: if (!active) root.moved(movable.kind, movable.x, movable.y)
        }
    }

    component Gauge: Item {
        id: gauge
        property real value // percent
        property string label
        width: 64
        height: 84
        onValueChanged: ring.requestPaint()
        Canvas {
            id: ring
            width: 64
            height: 64
            onPaint: {
                const c = getContext("2d"), start = 0.75 * Math.PI;
                c.reset();
                c.lineWidth = 6;
                c.lineCap = "round";
                c.strokeStyle = Theme.track;
                c.beginPath();
                c.arc(32, 32, 27, start, start + 1.5 * Math.PI);
                c.stroke();
                c.strokeStyle = Theme.accent;
                c.beginPath();
                c.arc(32, 32, 27, start, start + 1.5 * Math.PI * Math.max(0.01, Math.min(1, gauge.value / 100)));
                c.stroke();
            }
        }
        Label { anchors.centerIn: ring; text: Math.round(gauge.value) + "%"; font.weight: Font.DemiBold }
        Label { anchors.horizontalCenter: parent.horizontalCenter; y: 64; text: gauge.label; dim: true; font.pixelSize: 11 }
    }

    Movable {
        id: clock
        kind: "clock"
        Glass {
            width: 230
            height: 118
            radius: 24
            Column {
                anchors.centerIn: parent
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(root.now, Sys.clock24 ? "H:mm" : "h:mm")
                    font.pixelSize: 54
                    font.weight: Font.Light
                }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(root.now, "dddd, MMMM d"); dim: true }
            }
        }
    }

    Movable {
        id: gauges
        kind: "system"
        Glass {
            width: row.width + 36
            height: 112
            radius: 24
            Row {
                id: row
                anchors.centerIn: parent
                spacing: 14
                Gauge { value: root.system.cpu; label: "CPU" }
                Gauge { value: root.system.mem; label: "Memory" }
                Gauge { visible: root.system.gpu >= 0; value: root.system.gpu; label: "GPU" }
            }
        }
    }

    Movable {
        id: note
        kind: "note"
        Rectangle {
            width: 220
            height: 200
            radius: 18
            color: Qt.rgba(1, 0.86, 0.35, 0.82)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.5)
            TextEdit {
                anchors.fill: parent
                anchors.margins: 16
                text: note.where?.text ?? ""
                font.family: Theme.font
                font.pixelSize: 14
                color: "#3a2f00"
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                selectionColor: Qt.rgba(0.6, 0.45, 0, 0.4)
                onTextChanged: if (activeFocus) save.restart()
                Timer {
                    id: save
                    interval: 600
                    onTriggered: root.noteEdited(parent.text)
                }
                Label {
                    visible: !parent.text && !parent.activeFocus
                    text: "Click to write a note"
                    color: Qt.rgba(0.23, 0.18, 0, 0.5)
                }
            }
        }
    }

    Movable {
        id: media
        kind: "media"
        NowPlaying {}
    }
}
