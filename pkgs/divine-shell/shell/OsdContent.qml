import QtQuick

// Volume / brightness pill: icon, level bar, percentage.
Glass {
    id: osd

    property string kind: "volume" // or "brightness"
    property real value: 0
    property bool muted: false

    readonly property real level: muted ? 0 : Math.max(0, Math.min(1, value))

    round: true
    implicitWidth: 300
    implicitHeight: 52

    Glyph {
        id: glyph
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        font.pixelSize: 22
        text: osd.kind === "brightness" ? Theme.icons.sunLarge
            : osd.muted ? Theme.icons.volumeOff
            : osd.level > 0.66 ? Theme.icons.volumeHigh : osd.level > 0.33 ? Theme.icons.volumeMedium : Theme.icons.volumeLow
    }

    Rectangle {
        id: track
        anchors.left: glyph.right
        anchors.leftMargin: 12
        anchors.right: percent.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Theme.track

        Rectangle {
            width: parent.width * osd.level
            height: parent.height
            radius: 3
            color: Theme.fill
            Behavior on width { NumberAnimation { duration: 90 } }
        }
    }

    Label {
        id: percent
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        horizontalAlignment: Text.AlignRight
        text: Math.round(osd.level * 100)
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
    }
}
