import QtQuick
import Quickshell
import Quickshell.Io

// The Welcome guide: the desktop, shortcuts and apps, and Install on the live ISO. Opens at
// login until "Show at startup" is unticked; reopen it from the launcher (Welcome) or with
// `divine-welcome` (IPC).
FloatingWindow {
    id: win

    // id, what it's for; names and icons come from the desktop entries
    readonly property var guide: [
        ["devine-files", "Two-pane file manager. Super+E."],
        ["kitty", "The terminal. Super+Return."],
        ["devenv", "Code editor in the terminal: file tree, fuzzy finder, Git, language servers, debugger."],
        ["repostation", "App store for GitHub: finds apps and builds them for your CPU."],
        ["devine-monitor", "CPU, memory, GPU, temperatures, network and processes. Super+M."],
        ["devine-tweaks", "Appearance, displays, sound and performance. Super+,"]
    ]

    function toggle() {
        visible = !visible;
    }

    title: "Welcome"
    visible: false
    onClosed: visible = false // closing from Hyprland (Super+Q) doesn't clear `visible` by itself
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    minimumSize: Qt.size(820, 560)
    color: Theme.glass

    FileView {
        path: Quickshell.statePath("welcome.json")
        onAdapterUpdated: writeAdapter()
        onLoaded: win.visible = state.showAtStartup
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                writeAdapter();
                win.visible = true; // first login
            }
        }
        JsonAdapter {
            id: state
            property bool showAtStartup: true
        }
    }

    IpcHandler {
        target: "welcome"
        function toggle(): void {
            win.toggle();
        }
    }

    WelcomeContent {
        id: content
        anchors.fill: parent

        live: Sys.apps.some(a => a.id === "divine-install")
        showAtStartup: state.showAtStartup
        apps: win.guide.map(([id, about]) => {
            const e = Sys.apps.find(a => a.id === id);
            return e ? { id, about, name: e.name, icon: Sys.iconPath(e.icon) } : null;
        }).filter(a => a)

        onInstall: Sys.apps.find(a => a.id === "divine-install")?.execute()
        onOpenApp: id => Sys.apps.find(a => a.id === id)?.execute()
        onSetShowAtStartup: on => state.showAtStartup = on
    }
}
