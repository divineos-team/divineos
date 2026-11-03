import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Alt+Tab, centred on the focused monitor. Hyprland sends Alt+Tab and Alt+Shift+Tab as
// global shortcuts (step) and releasing Alt as another (commit). The window also commits
// on Alt release itself, since it holds the keyboard while open.
PanelWindow {
    id: win

    property bool open: false
    property int index: 0
    property var apps: [] // taken when it opens, so the order holds still while you choose

    function step(delta) {
        if (!open) {
            apps = Sys.switcherApps;
            if (!apps.length)
                return;
            index = 0;
            open = true;
            content.forceActiveFocus();
        }
        index = (index + delta + apps.length) % apps.length;
    }
    function commit() {
        if (!open)
            return;
        open = false;
        apps[index]?.window.activate();
    }

    visible: open
    screen: Array.from(Quickshell.screens).find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    color: "transparent"

    WlrLayershell.namespace: "divine-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    SwitcherContent {
        id: content
        focus: true
        apps: win.apps
        current: win.index
        onSelect: i => win.index = i
        onPicked: i => {
            win.index = i;
            win.commit();
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt)
                win.commit();
        }
        Keys.onEscapePressed: win.open = false
        Keys.onReturnPressed: win.commit()
        Keys.onLeftPressed: win.step(-1)
        Keys.onRightPressed: win.step(1)
    }
}
