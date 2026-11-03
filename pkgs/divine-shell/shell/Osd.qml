import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Shows the volume or brightness pill for a moment whenever either changes, under the menu bar
// of the focused monitor. Quiet while the Control Center is open (its sliders already show
// the level) and for the first moments after start-up. Never takes input.
PanelWindow {
    id: win

    property bool suppressed: false
    property bool ready: false
    property string kind: "volume"

    function show(k) {
        if (!ready || suppressed)
            return;
        kind = k;
        visible = true;
        hide.restart();
    }

    visible: false
    screen: Array.from(Quickshell.screens).find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    anchors.top: true
    margins.top: 44
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    color: "transparent"
    mask: Region {}

    WlrLayershell.namespace: "divine-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    Timer {
        interval: 2000
        running: true
        onTriggered: win.ready = true
    }
    Timer {
        id: hide
        interval: 1500
        onTriggered: win.visible = false
    }

    Connections {
        target: Sys
        function onVolumeChanged() { win.show("volume"); }
        function onMutedChanged() { win.show("volume"); }
        function onBrightnessChanged() { win.show("brightness"); }
    }

    OsdContent {
        id: content
        kind: win.kind
        value: win.kind === "brightness" ? Sys.brightness : Sys.volume
        muted: win.kind === "volume" && Sys.muted
    }
}
