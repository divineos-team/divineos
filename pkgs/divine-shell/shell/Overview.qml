import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Super+Tab: the overview on the focused monitor. Thumbnails only exist while it's open.
PanelWindow {
    id: win

    property bool open: false

    function toggle() {
        open = !open;
    }

    visible: open
    screen: Array.from(Quickshell.screens).find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "divine-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Loader {
        anchors.fill: parent
        active: win.open
        focus: true

        sourceComponent: OverviewContent {
            focus: true
            windows: Sys.overviewWindows
            focusedWorkspace: Sys.focusedWorkspace
            onPicked: window => {
                win.open = false;
                window.activate();
            }
            onWorkspacePicked: id => {
                win.open = false;
                Sys.goToWorkspace(id);
            }
            onDismissed: win.open = false
        }
    }
}
