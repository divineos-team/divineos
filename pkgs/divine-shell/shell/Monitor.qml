import QtQuick
import Quickshell
import Quickshell.Io

// devine-monitor's glass window. Its data comes from `devine-monitor --json`, which runs
// only while the window is open. Toggle: Super+M, or `devine-monitor --gui` (IPC).
FloatingWindow {
    id: win

    function toggle() {
        visible = !visible;
    }

    title: "System Monitor"
    visible: false
    onClosed: visible = false // closing from Hyprland (Super+Q) doesn't clear `visible` by itself
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    minimumSize: Qt.size(640, 480)
    color: Theme.glass

    Process {
        running: win.visible
        command: ["devine-monitor", "--json"]
        stdout: SplitParser {
            onRead: line => content.feed(JSON.parse(line))
        }
    }

    IpcHandler {
        target: "monitor"
        function toggle(): void {
            win.toggle();
        }
    }

    MonitorContent {
        id: content
        anchors.fill: parent
    }
}
