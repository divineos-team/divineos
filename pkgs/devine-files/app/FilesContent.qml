import QtQuick
import Qt.labs.folderlistmodel

// devine-files: places on the left, two panes, a function-key toolbar along the bottom.
// Keys act on the active pane (Tab switches); copy and move go to the other pane.
Item {
    id: root

    property string home: "/"
    property string mediaRoot: "/run/media"
    property string startFolder: home
    property bool showHidden: false
    property string status: ""
    property bool statusError: false
    property var gitLeft: ({ branch: "", files: {} })
    property var gitRight: ({ branch: "", files: {} })
    property int activeIndex: 0

    readonly property Pane activePane: activeIndex === 0 ? leftPane : rightPane
    readonly property Pane otherPane: activeIndex === 0 ? rightPane : leftPane
    readonly property string leftFolder: leftPane.folder
    readonly property string rightFolder: rightPane.folder
    readonly property string title: activePane.folder === home ? "Home" : activePane.folder.split("/").pop() || "/"

    signal op(var args) // devine-files-op arguments
    signal openFile(string path)
    signal openTerminal(string dir)

    // Called by the window when an operation finishes.
    function finished(args, ok, output) {
        if (!ok) {
            leftPane.pendingSelect = rightPane.pendingSelect = "";
            return;
        }
        if (args[0] === "mkdir" && output)
            activePane.select(output, true);
        else if (["copy", "move", "trash", "extract"].includes(args[0]))
            activePane.marked = {};
    }

    function act(kind) {
        const p = activePane, t = p.targets();
        switch (kind) {
        case "copy":
        case "move":
            if (otherPane.folder === p.folder)
                say("Both panes show the same folder.");
            else if (t.length)
                op([kind, otherPane.folder].concat(t));
            break;
        case "trash":
            if (t.length)
                op(["trash"].concat(t));
            break;
        case "extract":
            {
                const archives = t.filter(f => Theme.isArchive(f));
                if (archives.length)
                    op(["extract", p.folder].concat(archives));
                else
                    say("Select an archive (zip, tar, 7z, rar…) to extract.");
            }
            break;
        case "mkdir":
            op(["mkdir", p.folder]);
            break;
        case "rename":
            p.startRename();
            break;
        case "terminal":
            openTerminal(p.folder);
            break;
        case "hidden":
            showHidden = !showHidden;
            break;
        }
    }
    function markAndNext(p) {
        p.toggleMark(p.current);
        p.moveBy(1);
    }
    function say(text) {
        status = text;
        statusError = true;
    }

    focus: true
    Component.onCompleted: {
        leftPane.cd(startFolder, true);
        rightPane.cd(startFolder, true);
    }

    property string typed: ""
    Timer {
        id: typedReset
        interval: 900
        onTriggered: root.typed = ""
    }

    Keys.onPressed: e => {
        const p = activePane;
        const ctrl = e.modifiers & Qt.ControlModifier, alt = e.modifiers & Qt.AltModifier;
        const shift = e.modifiers & Qt.ShiftModifier;
        e.accepted = true;
        if (ctrl) {
            switch (e.key) {
            case Qt.Key_A: return p.markAll();
            case Qt.Key_H: return act("hidden");
            case Qt.Key_L: return p.editingPath = true;
            case Qt.Key_E: return act("extract");
            case Qt.Key_N: return shift ? act("mkdir") : undefined;
            }
        } else if (alt) {
            switch (e.key) {
            case Qt.Key_Left: return p.back();
            case Qt.Key_Right: return p.forward();
            case Qt.Key_Up: return p.up();
            }
        } else {
            switch (e.key) {
            case Qt.Key_Up: return p.moveBy(-1);
            case Qt.Key_Down: return p.moveBy(1);
            case Qt.Key_PageUp: return p.moveBy(-p.page());
            case Qt.Key_PageDown: return p.moveBy(p.page());
            case Qt.Key_Home: return p.moveTo(0);
            case Qt.Key_End: return p.moveTo(p.count - 1);
            case Qt.Key_Return:
            case Qt.Key_Enter: return p.open(p.current);
            case Qt.Key_Backspace: return p.up();
            case Qt.Key_Tab:
            case Qt.Key_Backtab: return activeIndex = 1 - activeIndex;
            case Qt.Key_Insert: return markAndNext(p);
            case Qt.Key_Escape: return p.marked = {};
            case Qt.Key_F2: return act("rename");
            case Qt.Key_F4: return act("terminal");
            case Qt.Key_F5: return act("copy");
            case Qt.Key_F6: return act("move");
            case Qt.Key_F7: return act("mkdir");
            case Qt.Key_F8:
            case Qt.Key_Delete: return act("trash");
            case Qt.Key_Space:
                if (!typed)
                    return markAndNext(p);
            }
            // Type-ahead find
            if (e.text && e.text >= " ") {
                typed += e.text;
                typedReset.restart();
                return p.jumpTo(typed);
            }
        }
        e.accepted = false;
    }

    // ── Sidebar ──
    Column {
        id: sidebar
        x: 10
        y: 14
        width: 168
        spacing: 2

        component Heading: Label {
            leftPadding: 10
            topPadding: 6
            bottomPadding: 4
            font.pixelSize: 11
            font.weight: Font.DemiBold
            dim: true
        }
        component Place: Rectangle {
            id: place
            property string label
            property string glyph
            property string path
            readonly property bool here: root.activePane.folder === path
            width: sidebar.width
            height: 30
            radius: 8
            color: here ? Theme.hover : area.containsMouse ? Qt.rgba(Theme.hover.r, Theme.hover.g, Theme.hover.b, Theme.hover.a / 2) : "transparent"
            Glyph {
                x: 8
                width: 22
                anchors.verticalCenter: parent.verticalCenter
                text: place.glyph
                font.pixelSize: 17
                color: Theme.accent
            }
            Label {
                x: 38
                width: parent.width - x - 8
                anchors.verticalCenter: parent.verticalCenter
                text: place.label
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.activePane.cd(place.path)
            }
        }

        Heading { text: "Favorites" }
        Repeater {
            model: [
                { label: "Home", glyph: Theme.icons.home, dir: "" },
                { label: "Desktop", glyph: Theme.icons.desktop, dir: "Desktop" },
                { label: "Documents", glyph: Theme.icons.document, dir: "Documents" },
                { label: "Downloads", glyph: Theme.icons.download, dir: "Downloads" },
                { label: "Pictures", glyph: Theme.icons.pictures, dir: "Pictures" },
                { label: "Music", glyph: Theme.icons.music, dir: "Music" },
                { label: "Videos", glyph: Theme.icons.videos, dir: "Videos" }
            ]
            Place {
                required property var modelData
                label: modelData.label
                glyph: modelData.glyph
                path: modelData.dir ? root.home + "/" + modelData.dir : root.home
            }
        }

        Heading { text: "Locations" }
        Place { label: "divineOS"; glyph: Theme.icons.disk; path: "/" }
        // Mounted drives (udisks mounts them under /run/media/$USER)
        Repeater {
            model: FolderListModel {
                folder: leftPane.url(root.mediaRoot)
                showFiles: false
            }
            Place {
                required property string fileName
                required property string filePath
                label: fileName
                glyph: Theme.icons.disk
                path: filePath
            }
        }
    }

    // ── Panes ──
    Item {
        id: panes
        anchors.left: sidebar.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.bottom: toolbar.top

        Pane {
            id: leftPane
            width: (panes.width - 10) / 2
            height: panes.height
            home: root.home
            active: root.activeIndex === 0
            showHidden: root.showHidden
            git: root.gitLeft
            onClicked: root.activeIndex = 0
            onOpenFile: path => root.openFile(path)
            onRenameRequested: (path, name) => root.rename(leftPane, path, name)
            onEditDone: root.forceActiveFocus()
        }
        Pane {
            id: rightPane
            x: leftPane.width + 10
            width: leftPane.width
            height: panes.height
            home: root.home
            active: root.activeIndex === 1
            showHidden: root.showHidden
            git: root.gitRight
            onClicked: root.activeIndex = 1
            onOpenFile: path => root.openFile(path)
            onRenameRequested: (path, name) => root.rename(rightPane, path, name)
            onEditDone: root.forceActiveFocus()
        }
    }

    function rename(pane, path, name) {
        pane.pendingSelect = pane.parentOf(path) + "/" + name;
        pane.renameOnSelect = false;
        op(["rename", path, name]);
    }

    // ── Toolbar ──
    Item {
        id: toolbar
        anchors.left: panes.left
        anchors.right: panes.right
        anchors.bottom: parent.bottom
        height: 46

        Row {
            id: chips
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            readonly property string arrow: root.activeIndex === 0 ? "→" : "←"

            Repeater {
                model: [
                    { key: "F2", label: "Rename", act: "rename" },
                    { key: "F4", label: "Terminal", act: "terminal" },
                    { key: "F5", label: "Copy " + chips.arrow, act: "copy" },
                    { key: "F6", label: "Move " + chips.arrow, act: "move" },
                    { key: "F7", label: "New Folder", act: "mkdir" },
                    { key: "Del", label: "Trash", act: "trash" },
                    { key: "^E", label: "Extract", act: "extract" },
                    { key: "^H", label: root.showHidden ? "Hide Dotfiles" : "Dotfiles", act: "hidden" }
                ]
                Rectangle {
                    id: chip
                    required property var modelData
                    width: chipRow.width + 16
                    height: 28
                    radius: 8
                    color: chipArea.pressed ? Theme.marked : chipArea.containsMouse ? Theme.hover : "transparent"
                    border.color: Theme.rim
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Label { text: chip.modelData.key; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.accent }
                        Label { text: chip.modelData.label; font.pixelSize: 12 }
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.act(chip.modelData.act)
                    }
                }
            }
        }

        Label {
            anchors.left: chips.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: root.status
            color: root.statusError ? Theme.danger : Theme.textDim
            font.pixelSize: 12
        }
    }
}
