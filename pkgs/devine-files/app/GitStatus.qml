import QtQuick
import Quickshell.Io

// `git status` for one folder: its branch, plus a code per entry (U untracked, A added,
// M modified, R renamed, D deleted, C conflict) for the badges. Empty outside a repo.
Process {
    id: proc

    property string dir
    property var result: ({ branch: "", files: {} })
    property string ranFor: ""
    property bool again: false

    function refresh() {
        if (running) {
            again = true;
            return;
        }
        ranFor = dir;
        // Prints the folder's path inside the repo, the branch, then NUL-separated status.
        command = ["sh", "-c", 'exec 2>/dev/null; cd -- "$1" && git rev-parse --show-prefix && git branch --show-current && exec git status --porcelain=v1 -z --untracked-files=normal -- .', "sh", dir];
        running = true;
    }

    function parse(text) {
        const a = text.indexOf("\n"), b = text.indexOf("\n", a + 1);
        if (a < 0 || b < 0)
            return { branch: "", files: {} };
        const prefix = text.slice(0, a), files = {};
        const severity = "UARDMC";
        const parts = text.slice(b + 1).split("\0");
        for (let i = 0; i < parts.length; i++) {
            const e = parts[i];
            if (e.length < 4)
                continue;
            const xy = e.slice(0, 2);
            if (xy[0] === "R" || xy[0] === "C")
                i++; // the next field is the old path
            const path = e.slice(3);
            if (!path.startsWith(prefix))
                continue;
            const name = path.slice(prefix.length).split("/")[0];
            const code = xy === "??" ? "U" : /U|AA|DD/.test(xy) ? "C" : xy.includes("A") ? "A" : xy.includes("R") ? "R" : xy.includes("D") ? "D" : "M";
            // A folder shows its most serious change.
            if (!files[name] || severity.indexOf(code) > severity.indexOf(files[name]))
                files[name] = code;
        }
        return { branch: text.slice(a + 1, b) || "detached", files };
    }

    onDirChanged: {
        result = { branch: "", files: {} };
        refresh();
    }
    onExited: if (again) {
        again = false;
        refresh();
    }

    stdout: StdioCollector {
        onStreamFinished: if (proc.ranFor === proc.dir) proc.result = proc.parse(text)
    }
}
