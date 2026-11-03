import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Print: the capture bar, above the dock on the focused monitor. Picking a tool closes it
// first, so the bar is never in the shot.
PanelWindow {
    id: win

    property bool open: false

    function toggle() {
        open = !open;
        if (open)
            Sys.refreshWindows();
    }

    visible: open
    screen: Array.from(Quickshell.screens).find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    anchors.bottom: true
    margins.bottom: 120
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    color: "transparent"

    WlrLayershell.namespace: "divine-capture"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    HyprlandFocusGrab {
        active: win.open
        windows: [win]
        onCleared: win.open = false
    }

    CaptureContent {
        id: content
        focus: true
        recording: Sys.recording
        onCapture: mode => {
            win.open = false;
            Sys.capture(mode);
        }
        onRecord: mode => {
            win.open = false;
            Sys.record(mode);
        }
        onStop: {
            win.open = false;
            Sys.stopRecording();
        }
        onDismissed: win.open = false
        Keys.onEscapePressed: win.open = false
    }
}
