import QtQuick
import Qt.labs.folderlistmodel
import "Rename.js" as Rename
import "Places.js" as Places

// devine-files: places on the left, two panes, a function-key toolbar along the bottom.
// Keys act on the active pane (Tab switches); copy and move go to the other pane.
// Right-clicking a file opens a menu with the rest (compress, bulk rename, favorites).
Item {
    id: root

    property string home: "/"
    property string mediaRoot: "/run/media"
    property string gvfsRoot: "/run/user/1000/gvfs" // $XDG_RUNTIME_DIR/gvfs: network mounts
    property int mountsTick: 0 // gvfs's FUSE folder sends no change events; bumping this rereads it
    property var bookmarks: [] // [{ path, label }]
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
    signal addBookmark(string path)
    signal removeBookmark(string path)
    signal connectServer(string uri, string user, string password)
    signal unmount(string path)

    // Called by the window when an operation finishes.
    function finished(args, ok, output) {
        if (!ok) {
            leftPane.pendingSelect = rightPane.pendingSelect = "";
            return;
        }
        if (["copy", "move", "trash", "extract", "compress"].includes(args[0]))
            activePane.marked = {};
        if ((args[0] === "mkdir" || args[0] === "compress") && output)
            activePane.select(output, args[0] === "mkdir");
    }
    function eject(path) {
        for (const p of [leftPane, rightPane])
            if (p.folder === path || p.folder.startsWith(path + "/"))
                p.cd(home);
        unmount(path);
    }

    function openMenu(pane, x, y) {
        const t = pane.targets(), one = t.length === 1, dir = one && pane.isDir(t[0]);
        const items = [];
        if (one)
            items.push({ label: "Open", run: () => dir ? pane.cd(t[0]) : openFile(t[0]) });
        items.push({ label: "Open in Terminal", run: () => openTerminal(dir ? t[0] : pane.folder) });
        items.push(one ? { label: "Rename", run: () => pane.select(t[0], true) } : { label: `Rename ${t.length} Items…`, run: () => renamer.start(pane, t) });
        items.push({ label: "Copy to Other Pane", run: () => act("copy") });
        items.push({ label: "Move to Other Pane", run: () => act("move") });
        items.push({ label: one ? `Compress “${t[0].split("/").pop()}”` : `Compress ${t.length} Items`, run: () => act("compress") });
        if (t.some(f => Theme.isArchive(f)))
            items.push({ label: "Extract", run: () => act("extract") });
        if (dir && !bookmarks.some(b => b.path === t[0]))
            items.push({ label: "Add to Favorites", run: () => addBookmark(t[0]) });
        items.push({ label: "Move to Trash", danger: true, run: () => act("trash") });
        menu.items = items;
        const p = pane.mapToItem(root, x, y);
        menu.x = Math.max(8, Math.min(p.x, width - menu.width - 8));
        menu.y = Math.max(8, Math.min(p.y, height - menu.height - 8));
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
        case "compress":
            if (t.length)
                op(["compress", p.folder].concat(t));
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

    // A FolderListModel whose folder is missing lists the current folder instead, and never sees
    // it appear (udisks makes /run/media/$USER at the first mount; gvfs's FUSE folder sends no
    // change events at all), so the sidebar retries until both are there.
    Timer {
        interval: 3000
        repeat: true
        running: [[drives, root.mediaRoot], [mounts, root.gvfsRoot]].some(([m, dir]) => m.status !== FolderListModel.Ready || !m.folder.toString().startsWith(leftPane.url(dir)))
        onTriggered: root.mountsTick++
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
        if (menu.items.length && e.key === Qt.Key_Escape)
            return menu.items = [];
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
    Flickable {
        id: sidebar
        x: 10
        y: 14
        width: 168
        height: parent.height - 28
        contentHeight: places.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: places
            width: sidebar.width
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
                property string path // "" for an entry that isn't a folder (picked)
                property string action // a glyph shown on hover (acted): eject, remove
                signal picked
                signal acted
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
                    width: parent.width - x - (place.action ? 30 : 8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: place.label
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: place.path ? root.activePane.cd(place.path) : place.picked()
                }
                Glyph {
                    visible: place.action !== "" && area.containsMouse
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    text: place.action
                    font.pixelSize: 15
                    color: Theme.textDim
                    MouseArea {
                        anchors.fill: parent
                        onClicked: place.acted()
                    }
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
            // Folders added from the right-click menu
            Repeater {
                model: root.bookmarks
                Place {
                    required property var modelData
                    label: modelData.label
                    glyph: Theme.icons.folder
                    path: modelData.path
                    action: Theme.icons.close
                    onActed: root.removeBookmark(modelData.path)
                }
            }

            Heading { text: "Locations" }
            Place { label: "divineOS"; glyph: Theme.icons.disk; path: "/" }
            // Mounted drives (udisks mounts them under /run/media/$USER)
            Repeater {
                model: FolderListModel {
                    id: drives
                    folder: leftPane.url(root.mediaRoot) + (root.mountsTick % 2 ? "/" : "")
                    showFiles: false
                }
                Place {
                    required property string fileName
                    required property string filePath
                    visible: filePath.startsWith(root.mediaRoot + "/")
                    label: fileName
                    glyph: Theme.icons.disk
                    path: filePath
                    action: Theme.icons.eject
                    onActed: root.eject(filePath)
                }
            }
            // Network shares (gvfs: SMB, SFTP, FTP, WebDAV)
            Repeater {
                model: FolderListModel {
                    id: mounts
                    folder: leftPane.url(root.gvfsRoot) + (root.mountsTick % 2 ? "/" : "")
                    showFiles: false
                }
                Place {
                    required property string fileName
                    required property string filePath
                    visible: filePath.startsWith(root.gvfsRoot + "/")
                    label: Places.mountLabel(fileName)
                    glyph: Theme.icons.server
                    path: filePath
                    action: Theme.icons.eject
                    onActed: root.eject(filePath)
                }
            }
            Place { label: "Connect to Server…"; glyph: Theme.icons.plus; onPicked: connector.start() }
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
            onMenuRequested: (x, y) => root.openMenu(leftPane, x, y)
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
            onMenuRequested: (x, y) => root.openMenu(rightPane, x, y)
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

    // ── Right-click menu ──
    MouseArea {
        // clicking anywhere else closes it
        anchors.fill: parent
        visible: menu.items.length > 0
        acceptedButtons: Qt.AllButtons
        onPressed: menu.items = []
    }
    Rectangle {
        id: menu
        property var items: [] // { label, run, danger? }
        visible: items.length > 0
        width: 220
        height: items.length * 28 + 12 // not menuColumn.height: openMenu needs it before layout
        radius: 10
        color: Theme.menu
        border.color: Theme.rim

        Column {
            id: menuColumn
            x: 6
            y: 6
            width: parent.width - 12
            Repeater {
                model: menu.items
                Rectangle {
                    id: entry
                    required property var modelData
                    width: menuColumn.width
                    height: 28
                    radius: 6
                    color: entryArea.containsMouse ? Theme.accent : "transparent"
                    Label {
                        x: 10
                        width: parent.width - 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.label
                        color: entryArea.containsMouse ? "#ffffff" : entry.modelData.danger ? Theme.danger : Theme.text
                    }
                    MouseArea {
                        id: entryArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const run = entry.modelData.run;
                            menu.items = [];
                            run();
                        }
                    }
                }
            }
        }
    }

    // ── Sheets: bulk rename, connect to server ──
    component Sheet: Rectangle {
        id: sheet
        property string title
        default property alias body: sheetColumn.data
        signal dismissed
        anchors.fill: parent
        visible: false
        color: Qt.rgba(0, 0, 0, 0.35)
        MouseArea {
            anchors.fill: parent
            onPressed: sheet.dismissed()
        }
        Rectangle {
            anchors.centerIn: parent
            width: 440
            height: sheetColumn.height + 40
            radius: Theme.radius
            color: Theme.menu
            border.color: Theme.rim
            // Keys the fields don't take stop here, so F8 in a field never trashes anything.
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape)
                    sheet.dismissed();
                e.accepted = true;
            }
            MouseArea {
                anchors.fill: parent // clicks inside stay inside
            }
            Column {
                id: sheetColumn
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 10
                Label {
                    text: sheet.title
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }
        }
    }
    component Field: Rectangle {
        id: field
        property alias text: input.text
        property alias echoMode: input.echoMode
        property string hint
        signal submitted
        function edit() {
            input.forceActiveFocus();
        }
        width: parent.width
        height: 32
        radius: 8
        color: Theme.dark ? Qt.rgba(0, 0, 0, 0.3) : "#ffffff"
        border.color: input.activeFocus ? Theme.accent : Theme.rim
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.text
            selectionColor: Theme.accent
            selectByMouse: true
            clip: true
            onAccepted: field.submitted()
        }
        Label {
            anchors.fill: input
            verticalAlignment: Text.AlignVCenter
            visible: !input.text
            text: field.hint
            dim: true
        }
    }
    component Action: Rectangle {
        id: action
        property string text
        property bool primary: false
        signal activated
        width: actionLabel.implicitWidth + 28
        height: 30
        radius: 8
        opacity: enabled ? 1 : 0.4
        color: primary ? Theme.accent : actionArea.containsMouse ? Theme.hover : "transparent"
        border.color: primary ? "transparent" : Theme.rim
        Label {
            id: actionLabel
            anchors.centerIn: parent
            text: action.text
            color: action.primary ? "#ffffff" : Theme.text
        }
        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: action.activated()
        }
    }

    Sheet {
        id: renamer
        property Pane pane: null
        property var paths: []
        property string mode: "replace" // or "number"
        readonly property var names: paths.map(p => p.split("/").pop())
        readonly property var result: Rename.bulkNames(names, mode, findField.text, replaceField.text)
        readonly property int changes: result.filter((n, i) => n !== names[i]).length

        function start(p, t) {
            pane = p;
            paths = t.slice().sort((a, b) => a.localeCompare(b));
            findField.text = replaceField.text = "";
            visible = true;
            findField.edit();
        }
        function close() {
            visible = false;
            root.forceActiveFocus();
        }
        function accept() {
            if (!changes)
                return;
            paths.forEach((path, i) => {
                if (result[i] !== names[i])
                    root.op(["rename", path, result[i]]);
            });
            pane.marked = {};
            close();
        }

        title: `Rename ${paths.length} Items`
        onDismissed: close()

        Row {
            spacing: 6
            Action { text: "Replace Text"; primary: renamer.mode === "replace"; onActivated: renamer.mode = "replace" }
            Action { text: "Number"; primary: renamer.mode === "number"; onActivated: renamer.mode = "number" }
        }
        Field { id: findField; hint: renamer.mode === "replace" ? "Find" : "Name, e.g. Holiday"; onSubmitted: renamer.accept() }
        Field { id: replaceField; hint: renamer.mode === "replace" ? "Replace with" : "Start at (1)"; onSubmitted: renamer.accept() }
        Repeater {
            model: Math.min(6, renamer.paths.length)
            Label {
                required property int index
                width: parent.width
                text: renamer.names[index] + "  →  " + renamer.result[index]
                font.pixelSize: 12
                dim: renamer.result[index] === renamer.names[index]
            }
        }
        Label {
            visible: renamer.paths.length > 6
            text: `and ${renamer.paths.length - 6} more`
            font.pixelSize: 12
            dim: true
        }
        Row {
            anchors.right: parent.right
            spacing: 8
            Action { text: "Cancel"; onActivated: renamer.close() }
            Action { text: "Rename"; primary: true; enabled: renamer.changes > 0; onActivated: renamer.accept() }
        }
    }

    Sheet {
        id: connector
        function start() {
            address.text = user.text = password.text = "";
            visible = true;
            address.edit();
        }
        function close() {
            visible = false;
            password.text = "";
            root.forceActiveFocus();
        }
        function accept() {
            let uri = address.text.trim();
            if (!uri)
                return;
            if (!/^[a-z0-9+.-]+:\/\//i.test(uri))
                uri = "smb://" + uri.replace(/^\/+/, ""); // "nas/photos" means a Windows/Samba share
            root.connectServer(uri, user.text, password.text);
            close();
        }

        title: "Connect to Server"
        onDismissed: close()

        Label {
            width: parent.width
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            text: "SMB, SFTP, FTP or WebDAV, e.g. smb://nas/photos or sftp://you@host. Nextcloud: davs://host/remote.php/dav/files/you"
            font.pixelSize: 12
            dim: true
        }
        Field { id: address; hint: "smb://server/share"; onSubmitted: user.edit() }
        Field { id: user; hint: "User (optional)"; onSubmitted: password.edit() }
        Field { id: password; hint: "Password (optional)"; echoMode: TextInput.Password; onSubmitted: connector.accept() }
        Row {
            anchors.right: parent.right
            spacing: 8
            Action { text: "Cancel"; onActivated: connector.close() }
            Action { text: "Connect"; primary: true; enabled: address.text.trim() !== ""; onActivated: connector.accept() }
        }
    }
}
