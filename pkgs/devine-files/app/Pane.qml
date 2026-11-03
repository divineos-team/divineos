import QtQuick
import Qt.labs.folderlistmodel

// One side of the browser: navigation and breadcrumbs, the file list, a footer. The pane tracks
// where it is and what's selected; FilesContent decides what operations do.
Glass {
    id: pane

    property string folder: home
    property string home: "/"
    property bool active: false
    property bool showHidden: false
    property var git: ({ branch: "", files: {} })

    property int current: 0
    property var marked: ({}) // path → true
    property var history: []
    property var future: []
    property bool renaming: false
    property bool editingPath: false
    property string pendingSelect: ""
    property bool renameOnSelect: false

    readonly property int count: files.count
    readonly property int markedCount: Object.keys(marked).length

    signal clicked
    signal openFile(string path)
    signal renameRequested(string path, string name)
    signal editDone // hand keyboard focus back

    function url(path) {
        // Encode each segment so names with # or % survive; a drive letter only appears in the preview.
        return "file://" + (path.startsWith("/") ? "" : "/") + path.split("/").map(s => /^[A-Za-z]:$/.test(s) ? s : encodeURIComponent(s)).join("/");
    }
    function parentOf(path) {
        const i = path.lastIndexOf("/");
        return i <= 0 ? "/" : path.slice(0, i);
    }
    function pathAt(i) {
        return i >= 0 && i < files.count ? files.get(i, "filePath") : "";
    }

    function cd(path, fromHistory) {
        path = path.length > 1 ? path.replace(/\/+$/, "") : path;
        if (path === folder)
            return;
        if (!fromHistory) {
            history = history.concat([folder]);
            future = [];
        }
        marked = {};
        renaming = false;
        current = 0;
        folder = path;
    }
    function up() {
        if (folder === "/")
            return;
        pendingSelect = folder; // land on the folder we came out of
        cd(parentOf(folder));
    }
    function back() {
        if (!history.length)
            return;
        future = [folder].concat(future);
        pendingSelect = folder;
        const to = history[history.length - 1];
        history = history.slice(0, -1);
        cd(to, true);
    }
    function forward() {
        if (!future.length)
            return;
        history = history.concat([folder]);
        const to = future[0];
        future = future.slice(1);
        cd(to, true);
    }
    function open(i) {
        if (i < 0 || i >= files.count)
            return;
        if (files.get(i, "fileIsDir"))
            cd(files.get(i, "filePath"));
        else
            openFile(files.get(i, "filePath"));
    }

    function moveTo(i) {
        current = Math.max(0, Math.min(files.count - 1, i));
        list.positionViewAtIndex(current, ListView.Contain);
    }
    function moveBy(d) {
        moveTo(current + d);
    }
    function page() {
        return Math.max(1, Math.floor(list.height / 30) - 1);
    }
    function toggleMark(i) {
        const p = pathAt(i);
        if (!p)
            return;
        const m = Object.assign({}, marked);
        if (m[p])
            delete m[p];
        else
            m[p] = true;
        marked = m;
    }
    function markRange(to) {
        const m = Object.assign({}, marked);
        for (let i = Math.min(current, to); i <= Math.max(current, to); i++)
            m[pathAt(i)] = true;
        marked = m;
        current = to;
    }
    function markAll() {
        const m = {};
        for (let i = 0; i < files.count; i++)
            m[pathAt(i)] = true;
        marked = m;
    }
    // Marked entries, or the current one.
    function targets() {
        const t = Object.keys(marked);
        return t.length ? t : current < files.count ? [pathAt(current)] : [];
    }
    // Type-ahead: jump to the first name starting with what was typed.
    function jumpTo(prefix) {
        prefix = prefix.toLowerCase();
        for (let i = 0; i < files.count; i++)
            if (files.get(i, "fileName").toLowerCase().startsWith(prefix))
                return moveTo(i);
    }
    function select(path, rename) {
        pendingSelect = path;
        renameOnSelect = !!rename;
        trySelect();
    }
    function trySelect() {
        if (!pendingSelect)
            return;
        for (let i = 0; i < files.count; i++)
            if (files.get(i, "filePath") === pendingSelect) {
                pendingSelect = "";
                moveTo(i);
                if (renameOnSelect)
                    renaming = true;
                return;
            }
    }
    function startRename() {
        if (current < files.count)
            renaming = true;
    }
    function gitCode(name) {
        return git.files[name] ?? "";
    }

    function size(bytes) {
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (bytes >= 1000 && i < u.length - 1) {
            bytes /= 1000;
            i++;
        }
        return (i ? bytes.toFixed(bytes < 10 ? 1 : 0) : bytes) + " " + u[i];
    }
    function when(d) {
        const now = new Date();
        if (d.toDateString() === now.toDateString())
            return "Today, " + Qt.formatTime(d, "h:mm AP");
        return Qt.formatDate(d, d.getFullYear() === now.getFullYear() ? "MMM d" : "MMM d, yyyy") + ", " + Qt.formatTime(d, "h:mm AP");
    }

    FolderListModel {
        id: files
        folder: pane.url(pane.folder)
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: pane.showHidden
        sortCaseSensitive: false
        onCountChanged: pane.trySelect()
        onStatusChanged: if (status === FolderListModel.Ready) pane.trySelect()
    }

    radius: Theme.radius
    border.color: active ? Qt.rgba(0.04, 0.52, 1, 0.55) : Theme.rim

    // ── Navigation and breadcrumbs ──
    Row {
        id: nav
        x: 10
        y: 8
        spacing: 2
        component NavButton: Glyph {
            id: btn
            signal activated
            width: 26
            height: 26
            font.pixelSize: 17
            opacity: enabled ? 0.85 : 0.3
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    pane.clicked();
                    btn.activated();
                }
            }
        }
        NavButton { text: Theme.icons.back; enabled: pane.history.length > 0; onActivated: pane.back() }
        NavButton { text: Theme.icons.forward; enabled: pane.future.length > 0; onActivated: pane.forward() }
        NavButton { text: Theme.icons.up; enabled: pane.folder !== "/"; onActivated: pane.up() }
    }

    Item {
        id: crumbs
        anchors.left: nav.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: 8
        height: 26
        clip: true

        // "Home" stands in for the home folder; otherwise the path starts at /.
        readonly property var parts: {
            const f = pane.folder;
            const inHome = f === pane.home || f.startsWith(pane.home + "/");
            const rest = (inHome ? f.slice(pane.home.length) : f).split("/").filter(s => s);
            const out = [inHome ? { label: "Home", path: pane.home } : { label: "/", path: "/" }];
            let p = inHome ? pane.home : "";
            for (const s of rest) {
                p += "/" + s;
                out.push({ label: s, path: p });
            }
            return out;
        }

        Row {
            id: crumbRow
            visible: !pane.editingPath
            // Long paths keep their deepest folders in view.
            x: Math.min(0, crumbs.width - width)
            height: parent.height
            spacing: 0
            Repeater {
                model: crumbs.parts
                Row {
                    id: crumb
                    required property var modelData
                    required property int index
                    height: crumbRow.height
                    Glyph {
                        visible: crumb.index > 0
                        text: Theme.icons.chevron
                        font.pixelSize: 14
                        color: Theme.textDim
                        height: parent.height
                    }
                    Label {
                        text: crumb.modelData.label
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 4
                        rightPadding: 4
                        font.weight: crumb.index === crumbs.parts.length - 1 ? Font.DemiBold : Font.Normal
                        dim: crumb.index !== crumbs.parts.length - 1
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                pane.clicked();
                                pane.cd(crumb.modelData.path);
                            }
                        }
                    }
                }
            }
        }
        // Clicking past the breadcrumbs edits the path (also Ctrl+L).
        MouseArea {
            anchors.left: crumbRow.right
            anchors.right: parent.right
            height: parent.height
            visible: !pane.editingPath
            onClicked: {
                pane.clicked();
                pane.editingPath = true;
            }
        }
        TextInput {
            id: pathInput
            visible: pane.editingPath
            anchors.fill: parent
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.text
            selectionColor: Theme.accent
            selectByMouse: true
            clip: true
            onVisibleChanged: if (visible) {
                pathInput.text = pane.folder;
                pathInput.selectAll();
                pathInput.forceActiveFocus();
            }
            onAccepted: {
                const t = text.trim();
                pane.editingPath = false;
                if (t)
                    pane.cd(t === "~" || t.startsWith("~/") ? pane.home + t.slice(1) : t);
                pane.editDone();
            }
            Keys.onEscapePressed: {
                pane.editingPath = false;
                pane.editDone();
            }
            onActiveFocusChanged: if (!activeFocus) pane.editingPath = false
        }
    }

    // ── Column headings ──
    Item {
        id: heading
        y: 40
        x: 12
        width: parent.width - 24
        height: 20
        readonly property bool wide: width > 440
        Label { x: 32; text: "Name"; font.pixelSize: 11; dim: true }
        Label { anchors.right: parent.right; anchors.rightMargin: heading.wide ? 150 : 8; text: "Size"; font.pixelSize: 11; dim: true }
        Label { visible: heading.wide; x: parent.width - 140; text: "Date Modified"; font.pixelSize: 11; dim: true }
    }

    ListView {
        id: list
        anchors.top: heading.bottom
        anchors.bottom: foot.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        anchors.topMargin: 2
        clip: true
        model: files
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: pane.current

        delegate: Rectangle {
            id: row
            required property int index
            required property string fileName
            required property string filePath
            required property string fileSuffix
            required property bool fileIsDir
            required property var fileSize
            required property date fileModified

            readonly property bool isCurrent: index === pane.current
            readonly property bool isMarked: !!pane.marked[filePath]
            readonly property bool lit: isCurrent && pane.active && !(pane.renaming && isCurrent)
            readonly property string kind: fileIsDir ? "folder" : Theme.kindOf(fileSuffix)
            readonly property string code: pane.gitCode(fileName)

            width: ListView.view.width
            height: 30
            radius: 8
            color: lit ? Theme.accent : isMarked ? Theme.marked : isCurrent ? Theme.hover : "transparent"

            Image {
                id: thumb
                readonly property bool wanted: row.kind === "image" && Theme.thumbable.includes(row.fileSuffix.toLowerCase())
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                visible: wanted && status === Image.Ready
                source: wanted ? pane.url(row.filePath) : ""
                sourceSize: Qt.size(40, 40)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
            Glyph {
                visible: !thumb.visible
                anchors.centerIn: thumb
                text: Theme.icons[row.kind === "file" ? "file" : row.kind]
                font.pixelSize: 19
                color: row.lit ? "#ffffff" : row.fileIsDir ? Theme.folder : Theme.textDim
            }

            Label {
                id: name
                visible: !(pane.renaming && row.isCurrent)
                x: 38
                width: sizeLabel.x - x - 34
                anchors.verticalCenter: parent.verticalCenter
                text: row.fileName
                color: row.lit ? "#ffffff" : Theme.text
            }
            // git: a letter for files, a dot for folders with changes inside
            Rectangle {
                visible: row.code !== "" && row.fileIsDir
                x: name.x + Math.min(name.implicitWidth, name.width) + 8
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: Theme.gitColors[row.code] ?? Theme.textDim
            }
            Label {
                visible: row.code !== "" && !row.fileIsDir
                x: name.x + Math.min(name.implicitWidth, name.width) + 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.code
                font.pixelSize: 11
                font.weight: Font.Bold
                color: row.lit ? "#ffffff" : Theme.gitColors[row.code] ?? Theme.textDim
            }

            Label {
                id: sizeLabel
                x: parent.width - width - (heading.wide ? 156 : 14)
                width: 70
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
                text: row.fileIsDir ? "—" : pane.size(row.fileSize)
                color: row.lit ? "#ffffff" : Theme.textDim
            }
            Label {
                visible: heading.wide
                x: parent.width - 146
                width: 140
                anchors.verticalCenter: parent.verticalCenter
                text: pane.when(row.fileModified)
                color: row.lit ? "#ffffff" : Theme.textDim
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => {
                    pane.clicked();
                    if (mouse.modifiers & Qt.ControlModifier)
                        pane.toggleMark(row.index);
                    else if (mouse.modifiers & Qt.ShiftModifier)
                        pane.markRange(row.index);
                    else {
                        if (pane.current !== row.index)
                            pane.renaming = false;
                        pane.current = row.index;
                    }
                }
                onDoubleClicked: pane.open(row.index)
            }

            // Inline rename: Enter saves, Esc or clicking away cancels.
            Rectangle {
                visible: pane.renaming && row.isCurrent
                x: name.x - 4
                width: parent.width - x - 8
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                radius: 6
                color: Theme.dark ? Qt.rgba(0, 0, 0, 0.35) : "#ffffff"
                border.color: Theme.accent
                border.width: 2

                TextInput {
                    id: renameInput
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.font
                    font.pixelSize: 13
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectByMouse: true
                    clip: true
                    onVisibleChanged: if (visible) {
                        renameInput.text = row.fileName;
                        // Select the name without its extension, like Finder.
                        const dot = row.fileIsDir ? -1 : row.fileName.lastIndexOf(".");
                        renameInput.select(0, dot > 0 ? dot : row.fileName.length);
                        renameInput.forceActiveFocus();
                    }
                    onAccepted: {
                        pane.renaming = false;
                        if (text !== row.fileName)
                            pane.renameRequested(row.filePath, text);
                        pane.editDone();
                    }
                    Keys.onEscapePressed: {
                        pane.renaming = false;
                        pane.editDone();
                    }
                    onActiveFocusChanged: if (!activeFocus && visible) pane.renaming = false
                }
            }
        }
    }

    Label {
        visible: files.status === FolderListModel.Ready && files.count === 0
        anchors.centerIn: list
        text: "Empty folder"
        dim: true
    }

    // ── Footer: counts and the git branch ──
    Item {
        id: foot
        anchors.bottom: parent.bottom
        width: parent.width
        height: 28

        Label {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 11
            dim: true
            text: pane.markedCount ? `${pane.markedCount} of ${files.count} selected` : `${files.count} ${files.count === 1 ? "item" : "items"}`
        }
        Row {
            visible: pane.git.branch !== ""
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Glyph { text: Theme.icons.git; font.pixelSize: 13; color: Theme.textDim }
            Label { text: pane.git.branch; font.pixelSize: 11; dim: true }
        }
    }
}
