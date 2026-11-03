import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The dock along the bottom of a screen. The surface spans the screen width so the shelf can
// grow freely; only the shelf (and its menu) take clicks, the rest passes through.
PanelWindow {
    id: win

    anchors { left: true; right: true; bottom: true }
    implicitHeight: content.implicitHeight
    exclusiveZone: content.reserved
    color: "transparent"
    mask: Region {
        item: content.hoverZone
        Region { item: content.menuZone }
    }

    WlrLayershell.namespace: "divine-dock"

    HyprlandFocusGrab {
        active: content.menuOpen
        windows: [win]
        onCleared: content.closeMenu()
    }

    DockContent {
        id: content
        anchors.fill: parent
    }
}
