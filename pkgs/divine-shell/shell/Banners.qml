import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// New notifications as banners in the top-right corner of the focused monitor, newest on top.
// Hidden while the Notification Center is open; only the cards take clicks.
PanelWindow {
    id: win

    property bool suppressed: false
    property date now: new Date()
    readonly property var shown: Sys.banners.slice(-4).reverse()

    visible: shown.length > 0 && !suppressed
    screen: Array.from(Quickshell.screens).find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    anchors.top: true
    anchors.right: true
    margins.top: 6
    margins.right: 12
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 372 // room for the close button's overhang
    implicitHeight: Math.max(1, stack.implicitHeight + 8)
    color: "transparent"
    mask: Region { item: stack }

    WlrLayershell.namespace: "divine-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    Column {
        id: stack
        x: 8
        y: 8
        spacing: 10
        Repeater {
            model: win.shown
            NotificationCard {
                required property var modelData
                notification: modelData
                banner: true
                now: win.now
            }
        }
    }
}
