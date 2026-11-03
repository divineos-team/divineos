import QtQuick

// A theme preset (Settings > Appearance, Welcome): a little desktop with a window of its glass,
// ringed when it's what you have.
Item {
    id: tile

    property var theme // { name, dark, accent, tint, glass }
    property bool on
    signal picked

    readonly property color accent: Theme.accents.find(a => a.id === theme.accent).color
    readonly property var look: Theme.tintColors(theme.tint, theme.dark, accent)
    readonly property color ink: theme.dark ? "#ffffff" : "#1d1d1f"

    width: 130
    height: desk.height + 28

    Rectangle { x: -4; y: -4; width: desk.width + 8; height: desk.height + 8; radius: 16; color: "transparent"; border.width: 2; border.color: Theme.accent; visible: tile.on || hover.containsMouse; opacity: tile.on ? 1 : 0.5 }
    Rectangle {
        id: desk
        width: parent.width
        height: 78
        radius: 12
        color: !tile.theme.dark ? "#dce6f4" : tile.theme.tint === "pitch" ? "#000000" : tile.theme.tint === "neon" ? "#1a0838" : "#1b2442"
        Rectangle { // a window
            x: 12; y: 12; width: 80; height: 54; radius: 10
            color: tile.look.glass; border.width: 1; border.color: tile.look.rim
            Rectangle { x: 9; y: 10; width: 14; height: 14; radius: 7; color: tile.accent }
            Rectangle { x: 29; y: 12; width: 40; height: 4; radius: 2; color: tile.ink; opacity: 0.8 }
            Rectangle { x: 29; y: 20; width: 26; height: 4; radius: 2; color: tile.ink; opacity: 0.4 }
            Rectangle { x: 9; y: 34; width: 62; height: 8; radius: 4; color: tile.ink; opacity: 0.15
                Rectangle { width: 40; height: parent.height; radius: 4; color: tile.accent }
            }
        }
        Rectangle { // a toggle
            x: 100; y: 12; width: 20; height: 20; radius: 10
            color: tile.look.glass; border.width: 1; border.color: tile.look.rim
        }
    }
    Label {
        anchors.top: desk.bottom
        anchors.topMargin: 8
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: tile.theme.name
        font.pixelSize: 12
        font.weight: tile.on ? Font.DemiBold : Font.Normal
    }
    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: tile.picked() }
}
