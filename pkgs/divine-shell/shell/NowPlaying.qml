import QtQuick

// 2×2 media tile driven by MPRIS.
Glass {
    id: tile

    readonly property var player: Sys.player

    implicitWidth: Theme.unit * 2 + Theme.gap
    implicitHeight: Theme.unit * 2 + Theme.gap

    Rectangle {
        id: art
        x: 18
        y: 18
        width: 52
        height: 52
        radius: 12
        color: Theme.off
        clip: true
        Glyph {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: Theme.icons.music
            color: Theme.textDim
        }
        Image {
            id: cover
            anchors.fill: parent
            source: tile.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 18
        anchors.top: art.bottom
        anchors.topMargin: 10
        Label {
            width: parent.width
            text: tile.player?.trackTitle || "Not Playing"
            font.weight: Font.DemiBold
        }
        Label {
            width: parent.width
            text: tile.player?.trackArtist ?? ""
            dim: true
            font.pixelSize: 12
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        spacing: 22
        opacity: tile.player ? 1 : 0.4

        Repeater {
            model: [
                { icon: Theme.icons.previous, size: 26, act: () => tile.player?.previous() },
                { icon: tile.player?.isPlaying ? Theme.icons.pause : Theme.icons.play, size: 32, act: () => tile.player?.togglePlaying() },
                { icon: Theme.icons.next, size: 26, act: () => tile.player?.next() }
            ]
            Glyph {
                required property var modelData
                width: 32
                height: 32
                text: modelData.icon
                font.pixelSize: modelData.size
                scale: press.pressed ? 0.85 : 1
                Behavior on scale { SpringAnimation { spring: 6; damping: 0.4 } }
                MouseArea {
                    id: press
                    anchors.fill: parent
                    onClicked: parent.modelData.act()
                }
            }
        }
    }
}
