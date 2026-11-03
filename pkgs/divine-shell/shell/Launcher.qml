import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Spotlight-style launcher, centred in the upper third of the focused monitor.
PanelWindow {
    id: win

    property bool open: false
    property bool clipboard: false

    function toggle() {
        show(false);
    }
    function toggleClipboard() {
        show(true);
    }
    // The same shortcut again closes it; the other one switches mode.
    function show(clip) {
        open = !(open && clipboard === clip);
        clipboard = clip;
        if (open)
            content.reset();
    }

    visible: open

    screen: Array.from(Quickshell.screens).find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    anchors.top: true
    margins.top: (screen?.height ?? 1080) * 0.22
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    color: "transparent"

    WlrLayershell.namespace: "divine-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    HyprlandFocusGrab {
        active: win.open
        windows: [win]
        onCleared: win.open = false
    }

    LauncherContent {
        id: content
        clipboard: win.clipboard
        onDone: win.open = false
    }
}
