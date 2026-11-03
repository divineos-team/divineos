import QtQuick
import Quickshell
import Quickshell.Io

// The Welcome guide: setting up, the desktop, shortcuts and apps, and Install on the live ISO.
// Opens at login until "Show at startup" is unticked; reopen it from the launcher (Welcome) or
// with `divine-welcome` (IPC). Themes apply through Settings (applyTheme, for the blur).
FloatingWindow {
    id: win

    signal applyTheme(var theme)
    readonly property var codecs: ["gst-plugins-good", "gst-plugins-bad", "gst-plugins-ugly", "gst-libav", "ffmpeg"]
    property string browser: "" // the desktop entry to make the default once it's installed

    // id, what it's for; names and icons come from the desktop entries
    readonly property var guide: [
        ["devine-files", "Two-pane file manager. Super+E."],
        ["kitty", "The terminal. Super+Return."],
        ["devenv", "Code editor in the terminal: file tree, fuzzy finder, Git, language servers, debugger."],
        ["devine-store", "Apps from Arch and the AUR, and updates for the whole system."],
        ["repostation", "App store for GitHub: finds apps and builds them for your CPU."],
        ["devine-monitor", "CPU, memory, GPU, temperatures, network and processes. Super+M."],
        ["devine-tweaks", "Appearance, desktop and dock, displays, keyboard, users, default apps, drivers and more. Super+,"]
    ]

    function toggle() {
        visible = !visible;
    }
    function check() {
        checkProc.running = true;
        driversProc.running = true;
    }
    function helper(what, args) {
        content.status = "Waiting for your password…";
        op.what = what;
        op.command = ["pkexec", "/usr/lib/divine-pkg/pkg-helper"].concat(args);
        op.running = true;
    }
    function setBrowser(desktop) {
        Quickshell.execDetached(["sh", "-c", 'for t in x-scheme-handler/http x-scheme-handler/https text/html; do gio mime "$t" "$1"; done', "sh", desktop]);
        content.defaultBrowser = desktop;
    }
    onVisibleChanged: if (visible) check()

    Process {
        id: checkProc
        command: ["sh", "-c", 'for p in firefox chromium vivaldi falkon gst-libav; do pacman -Q "$p" >/dev/null 2>&1 && echo "$p"; done; echo "default $(LC_ALL=C gio mime x-scheme-handler/https 2>/dev/null | head -1 | sed "s/.*: //")"']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                content.installed = lines.filter(l => !l.startsWith("default "));
                content.defaultBrowser = (lines.find(l => l.startsWith("default ")) ?? "").slice(8);
            }
        }
    }
    Process {
        id: driversProc
        command: ["divine-drivers"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    content.drivers = JSON.parse(text);
                } catch (e) {
                    content.drivers = [];
                }
            }
        }
    }
    Process {
        id: op
        property string what: ""
        property string last: ""
        stdout: SplitParser {
            onRead: line => content.status = op.last = line
        }
        stderr: SplitParser {
            onRead: line => content.status = op.last = line
        }
        onExited: code => {
            content.status = code === 0 ? (op.what === "drivers" ? "Installed. Restart the computer to start using new graphics drivers." : "") : code === 126 || code === 127 ? "Cancelled." : `Not installed: ${op.last}`;
            if (code === 0 && win.browser)
                win.setBrowser(win.browser);
            win.browser = "";
            op.what = "";
            win.check();
        }
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
        accentName: Sys.accentName
        busy: op.what
        onApplyTheme: theme => win.applyTheme(theme)
        onGetBrowser: (pkg, desktop) => {
            if (installed.includes(pkg))
                return win.setBrowser(desktop);
            win.browser = desktop;
            win.helper(pkg, ["install", pkg]);
        }
        onGetCodecs: win.helper("codecs", ["install"].concat(win.codecs))
        onInstallDrivers: ids => win.helper("drivers", ["drivers"].concat(ids))
    }
}
