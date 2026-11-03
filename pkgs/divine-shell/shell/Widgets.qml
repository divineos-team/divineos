import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The desktop widgets' layer: the whole screen, over the wallpaper and under every window,
// taking clicks only on the widgets. The gauges read `devine-monitor --json` while they're on.
PanelWindow {
    id: win

    property alias now: content.now

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {
        Region { item: content.zones[0] ?? null }
        Region { item: content.zones[1] ?? null }
        Region { item: content.zones[2] ?? null }
        Region { item: content.zones[3] ?? null }
    }
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "divine-widgets"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand // for the sticky note

    Process {
        running: win.visible && !!Sys.widgets.system
        command: ["devine-monitor", "--json"]
        stdout: SplitParser {
            onRead: line => {
                const s = JSON.parse(line);
                content.system = { cpu: s.cpu, mem: 100 * s.mem_used / Math.max(1, s.mem_total), gpu: s.gpu ? s.gpu.util : -1 };
            }
        }
    }

    WidgetsContent {
        id: content
        anchors.fill: parent
        widgets: Sys.widgets
        onMoved: (kind, x, y) => Sys.setWidget(kind, { x, y })
        onNoteEdited: text => Sys.setWidget("note", { text })
    }
}
