//@ pragma AppId devine-files
import QtQuick
import Quickshell
import Quickshell.Io

// devine-files: one process, any number of windows. `devine-files [dir]` asks the running
// instance for a new window over IPC, or starts this one. The process exits with its last window.
ShellRoot {
    id: root

    property int nextId: 1
    property var windows: [{ id: 0, folder: Quickshell.env("DEVINE_FILES_DIR") ?? Quickshell.env("HOME") ?? "/" }]

    function open(folder) {
        windows = windows.concat([{ id: nextId++, folder }]);
    }
    function closed(id) {
        windows = windows.filter(w => w.id !== id);
        if (!windows.length)
            Qt.quit();
    }

    Variants {
        model: root.windows
        FilesWindow {
            required property var modelData
            folder: modelData.folder
            onClosed: root.closed(modelData.id)
        }
    }

    IpcHandler {
        target: "files"
        function open(folder: string): void {
            root.open(folder);
        }
    }

    // Follow the desktop's light/dark setting (divine-shell's Control Center writes it).
    Process {
        running: true
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface color-scheme; exec gsettings monitor org.gnome.desktop.interface color-scheme"]
        stdout: SplitParser {
            onRead: line => Theme.dark = !line.includes("prefer-light")
        }
    }
}
