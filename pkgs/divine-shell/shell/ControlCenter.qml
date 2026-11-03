import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Drops from the top-right corner of the focused monitor. Hyprland animates it in
// ("popin" layer rule) and closes it on any click outside (focus grab).
PanelWindow {
    id: win

    property bool open: false
    property real closedAt: 0
    signal lockRequested

    function toggle() {
        // The bar button's click also clears the focus grab; don't reopen right after.
        if (!open && Date.now() - closedAt < 250)
            return;
        open = !open;
        if (open)
            Sys.refreshBrightness();
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

    WlrLayershell.namespace: "divine-cc"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        active: win.open
        windows: [win]
        onCleared: win.close()
    }

    CcContent {
        id: content
        focus: true
        Keys.onEscapePressed: win.close()
        onDismiss: win.close()
        onLockRequested: win.lockRequested()
    }
}
