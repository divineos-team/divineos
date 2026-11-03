import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Drops from the top-right corner when you click the clock (or Super+N), like the Control
// Center. Closes on any click outside.
PanelWindow {
    id: win

    property bool open: false
    property real closedAt: 0
    property date now: new Date()

    function toggle() {
        // The clock's click also clears the focus grab; don't reopen right after.
        if (!open && Date.now() - closedAt < 250)
            return;
        open = !open;
    }
    function close() {
        open = false;
        closedAt = Date.now();
    }

    visible: open
    screen: Array.from(Quickshell.screens).find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    anchors.top: true
    anchors.right: true
    margins.top: 6
    margins.right: 12
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    color: "transparent"

    WlrLayershell.namespace: "divine-nc"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        active: win.open
        windows: [win]
        onCleared: win.close()
    }

    NcContent {
        id: content
        focus: true
        now: win.now
        Keys.onEscapePressed: win.close()
    }
}
