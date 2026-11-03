//@ pragma AppId divine-install
import QtQuick
import Quickshell
import Quickshell.Io

// The divineOS installer window. The disk work happens in the root backend, run through sudo
// (the live user needs no password): probe and shrink-info answer in JSON; install reads the
// settings on stdin and reports "step PCT TEXT" lines, then "done" or "error TEXT".
ShellRoot {
    id: root

    readonly property string backend: "/usr/lib/divine-installer/backend"

    FloatingWindow {
        title: "Install divineOS"
        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight
        minimumSize: Qt.size(920, 600)
        color: "transparent"
        // An install keeps going without the window; the backend's lock stops a second one.
        onClosed: if (!installProc.running)
            Qt.quit()

        Rectangle {
            anchors.fill: parent
            color: Theme.window
        }

        InstallerContent {
            id: content
            anchors.fill: parent
            onReprobe: probeProc.running = true
            onMeasure: part => {
                shrink = { part, busy: true };
                shrinkProc.part = part;
                shrinkProc.exec(["sudo", "-n", root.backend, "shrink-info", part]);
            }
            onOpenGparted: {
                gpartedOpen = true;
                gpartedProc.running = true;
            }
            onInstall: settings => {
                log = [];
                percent = 0;
                error = "";
                installing = true;
                installProc.settings = settings;
                installProc.running = true;
            }
            onRestart: Quickshell.execDetached(["systemctl", "reboot"])
        }
    }

    Process {
        id: probeProc
        running: true
        command: ["sudo", "-n", root.backend, "probe"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim())
                content.info = JSON.parse(text)
        }
        onExited: code => content.probeError = code === 0 ? "" : "Couldn't read this computer's disks."
    }

    Process {
        id: shrinkProc
        property string part
        stdout: StdioCollector {
            onStreamFinished: if (text.trim())
                content.shrink = JSON.parse(text) // { part, keep }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                content.shrink = { part: shrinkProc.part, error: text.trim().split("\n").pop() }
        }
    }

    Process {
        id: gpartedProc
        command: ["sudo", "-n", "-E", "gparted"] // -E: the Wayland session to draw on
        onExited: {
            content.gpartedOpen = false;
            probeProc.running = true;
        }
    }

    Process {
        id: installProc
        property var settings
        command: ["sudo", "-n", root.backend, "install"]
        stdinEnabled: true
        onStarted: {
            write(JSON.stringify(settings) + "\n");
            settings = null; // don't keep the passwords around
        }
        stdout: SplitParser {
            onRead: line => {
                const step = line.match(/^step (\d+) (.*)$/);
                if (step) {
                    content.percent = +step[1];
                    content.stepText = step[2];
                } else if (line === "done") {
                    content.finished = true;
                } else if (line.startsWith("error ")) {
                    content.error = line.slice(6);
                }
            }
        }
        stderr: SplitParser {
            onRead: line => content.log = content.log.slice(-400).concat([line])
        }
        onExited: code => {
            content.installing = false;
            if (code !== 0 && !content.error)
                content.error = "The installer stopped unexpectedly. The log below says why.";
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
