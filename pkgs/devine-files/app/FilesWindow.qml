import QtQuick
import Quickshell
import Quickshell.Io

// One devine-files window. Everything that touches the system lives here: the file-op helper,
// opening files, a terminal, and git status for each pane.
FloatingWindow {
    id: win

    property string folder
    readonly property string helper: "/usr/lib/devine-files/devine-files-op"
    property var queue: [] // operations run one at a time, in order

    function runOp(args) {
        if (opProc.running) {
            queue = queue.concat([args]);
            return;
        }
        const n = args.length - (["copy", "move", "extract"].includes(args[0]) ? 2 : 1);
        const items = n === 1 ? "1 item" : `${n} items`;
        content.status = ({ copy: `Copying ${items}…`, move: `Moving ${items}…`, extract: `Extracting ${items}…`, trash: `Moving ${items} to Trash…` })[args[0]] ?? "";
        content.statusError = false;
        opProc.args = args;
        opProc.command = [helper].concat(args);
        opProc.running = true;
    }

    title: content.title
    implicitWidth: 1240
    implicitHeight: 700
    minimumSize: Qt.size(760, 440)
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.window
    }

    FilesContent {
        id: content
        anchors.fill: parent
        home: Quickshell.env("HOME") ?? "/"
        mediaRoot: "/run/media/" + (Quickshell.env("USER") ?? "")
        startFolder: win.folder
        gitLeft: leftGit.result
        gitRight: rightGit.result
        onOp: args => win.runOp(args)
        onOpenFile: path => Quickshell.execDetached(["gio", "open", path])
        onOpenTerminal: dir => Quickshell.execDetached({ command: ["kitty"], workingDirectory: dir })
    }

    Process {
        id: opProc
        property var args: []
        stdout: StdioCollector {
            id: opOut
        }
        stderr: StdioCollector {
            // The helper prints one line per failure; show the last.
            onStreamFinished: if (text.trim()) {
                content.status = text.trim().split("\n").pop().replace(/^devine-files: /, "");
                content.statusError = true;
            }
        }
        onExited: code => {
            if (code === 0)
                content.status = "";
            content.finished(args, code === 0, opOut.text.trim());
            leftGit.refresh();
            rightGit.refresh();
            if (win.queue.length) {
                const next = win.queue[0];
                win.queue = win.queue.slice(1);
                win.runOp(next);
            }
        }
    }

    GitStatus {
        id: leftGit
        dir: content.leftFolder
    }
    GitStatus {
        id: rightGit
        dir: content.rightFolder
    }
}
