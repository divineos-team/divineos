import QtQuick
import Quickshell
import Quickshell.Io
import "Places.js" as Places

// One devine-files window. Everything that touches the system lives here: the file-op helper,
// opening files, a terminal, git status for each pane, bookmarks and network mounts (gio).
FloatingWindow {
    id: win

    property string folder
    readonly property string helper: "/usr/lib/devine-files/devine-files-op"
    property var queue: [] // operations run one at a time, in order
    property string bookmarkText: ""

    function runOp(args) {
        if (opProc.running) {
            queue = queue.concat([args]);
            return;
        }
        const n = args.length - (["copy", "move", "extract", "compress"].includes(args[0]) ? 2 : 1);
        const items = n === 1 ? "1 item" : `${n} items`;
        content.status = ({ copy: `Copying ${items}…`, move: `Moving ${items}…`, extract: `Extracting ${items}…`, compress: `Compressing ${items}…`, trash: `Moving ${items} to Trash…` })[args[0]] ?? "";
        content.statusError = false;
        opProc.args = args;
        opProc.command = [helper].concat(args);
        opProc.running = true;
    }
    function saveBookmarks(text) {
        bookmarkText = text;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "${1%/*}" && printf %s "$2" >"$1"', "sh", bookmarkFile.path, text]);
    }
    function gio(args, user, password) {
        if (gioProc.running)
            return content.say("Still connecting…");
        gioProc.user = user ?? "";
        gioProc.password = password ?? "";
        gioProc.asked = 0;
        content.status = args[0] === "-u" ? "" : "Connecting…";
        content.statusError = false;
        gioProc.command = ["gio", "mount"].concat(args);
        gioProc.running = true;
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
        gvfsRoot: (Quickshell.env("XDG_RUNTIME_DIR") ?? "/run/user/1000") + "/gvfs"
        bookmarks: Places.bookmarks(win.bookmarkText)
        startFolder: win.folder
        gitLeft: leftGit.result
        gitRight: rightGit.result
        onOp: args => win.runOp(args)
        onOpenFile: path => Quickshell.execDetached(["gio", "open", path])
        onOpenTerminal: dir => Quickshell.execDetached({ command: ["kitty"], workingDirectory: dir })
        onAddBookmark: path => win.saveBookmarks(Places.addBookmark(win.bookmarkText, path))
        onRemoveBookmark: path => win.saveBookmarks(Places.removeBookmark(win.bookmarkText, path))
        onConnectServer: (uri, user, password) => win.gio(["--", uri], user, password)
        onUnmount: path => win.gio(["-u", "--", path])
    }

    // GTK's bookmarks, so GTK apps' sidebars and this one agree.
    FileView {
        id: bookmarkFile
        path: (Quickshell.env("HOME") ?? "") + "/.config/gtk-3.0/bookmarks"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: win.bookmarkText = text()
    }

    // gio mount asks for what the server needs ("User [me]: ", "Domain [WORKGROUP]: ",
    // "Password: ") on stdout; answer each from the form. The password never goes on a
    // command line. A second password prompt means it was wrong.
    Process {
        id: gioProc
        property string user
        property string password
        property int asked: 0
        environment: ({ LC_ALL: "C" }) // untranslated prompts
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: ": "
            onRead: chunk => {
                const prompt = chunk.split("\n").pop().trim(); // after any "Authentication Required" lines
                if (prompt.startsWith("User"))
                    gioProc.write(gioProc.user + "\n");
                else if (prompt.startsWith("Domain"))
                    gioProc.write("\n");
                else if (prompt.startsWith("Password") && gioProc.asked++ === 0)
                    gioProc.write(gioProc.password + "\n");
                else if (prompt.startsWith("Password")) {
                    gioProc.running = false;
                    content.say("Wrong user or password.");
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                content.say(text.trim().split("\n").pop().replace(/^gio: /, ""))
        }
        onExited: code => {
            gioProc.password = "";
            content.mountsTick++;
            if (code === 0) {
                content.status = "";
                content.statusError = false;
            }
        }
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
