import QtQuick
import Quickshell
import Quickshell.Wayland

// The taskbar along the bottom of a screen (Settings > Desktop & Dock > Windows 11).
PanelWindow {
    id: win

    property alias now: content.now
    property alias controlCenterOpen: content.controlCenterOpen
    signal launcherRequested
    signal controlCenterRequested
    signal notificationCenterRequested

    anchors { left: true; right: true; bottom: true }
    implicitHeight: content.implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "divine-taskbar"

    TaskbarContent {
        id: content
        anchors.fill: parent
        onLauncherRequested: win.launcherRequested()
        onControlCenterRequested: win.controlCenterRequested()
        onNotificationCenterRequested: win.notificationCenterRequested()
    }
}
