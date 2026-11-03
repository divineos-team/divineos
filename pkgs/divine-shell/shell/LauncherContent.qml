import QtQuick

// Spotlight-style search: apps ranked by name and keywords, files and folders in your home,
// plus inline arithmetic. In clipboard mode (Super+Shift+V) it searches the clipboard history.
Glass {
    id: root

    signal done
    property int current: 0
    property bool clipboard: false

    readonly property string query: input.text.trim()
    readonly property string calc: evaluate(query)
    readonly property var items: clipboard ? clips(query) : (calc ? [{
                title: calc,
                subtitle: "Enter copies the result",
                glyph: Theme.icons.calculator,
                run: () => Sys.copy(calc)
            }] : []).concat(rank(query), files(query))

    function reset() {
        input.text = "";
        current = 0;
        input.forceActiveFocus();
        if (clipboard)
            Sys.loadClipboard();
    }

    // Newest first. Enter copies the entry back to the clipboard; Shift+Delete forgets it.
    function clips(q) {
        q = q.toLowerCase();
        return Sys.clipboardHistory.filter(c => c.text.toLowerCase().includes(q)).map(c => {
            const data = c.text.match(/^\[\[ binary data (.*) \]\]$/); // e.g. "245 KiB png 1920x1080"
            return {
                title: data ? (/\d+x\d+$/.test(data[1]) ? "Image" : "Data") : c.text,
                subtitle: data ? data[1] : "",
                glyph: data ? Theme.icons.image : Theme.icons.clipboard,
                clip: c.id,
                run: () => Sys.restoreClip(c.id)
            };
        });
    }

    function rank(q) {
        q = q.toLowerCase();
        if (!q)
            return [];
        const hits = [];
        for (const app of Sys.apps) {
            const name = app.name.toLowerCase();
            const extra = [app.genericName ?? ""].concat(app.keywords ?? []).join(" ").toLowerCase();
            const score = name.startsWith(q) ? 4 : name.split(/\s+/).some(w => w.startsWith(q)) ? 3 : name.includes(q) ? 2 : extra.includes(q) ? 1 : 0;
            if (score)
                hits.push({ app, score });
        }
        hits.sort((a, b) => b.score - a.score || a.app.name.localeCompare(b.app.name));
        return hits.slice(0, 8).map(h => ({
            title: h.app.name,
            subtitle: h.app.genericName || h.app.comment || "",
            icon: Sys.iconPath(h.app.icon),
            run: () => h.app.execute()
        }));
    }

    // Names containing the query: those starting with it first, then the shallowest.
    function files(q) {
        if (calc || q.length < 2)
            return [];
        q = q.toLowerCase();
        return Sys.fileResults.map(path => {
            const parts = path.replace(/\/$/, "").split("/");
            const name = parts.pop();
            return { path, name, folder: parts.join("/"), dir: path.endsWith("/") };
        }).filter(f => f.name.toLowerCase().includes(q)) // drops results left from the last query
        .map(f => Object.assign(f, { rank: (f.name.toLowerCase().startsWith(q) ? 0 : 100) + f.folder.split("/").length }))
        .sort((a, b) => a.rank - b.rank).slice(0, 5).map(f => ({
            title: f.name,
            subtitle: f.folder.replace(Sys.home, "~"),
            glyph: f.dir ? Theme.icons.folder : Theme.icons.file,
            run: () => Sys.openPath(f.path)
        }));
    }

    // Only digits, operators and parentheses reach the evaluator, so no identifiers can run.
    function evaluate(q) {
        if (!/^[\d\s.+\-*/%()^]+$/.test(q) || !/\d\s*[-+*/%^]\s*[\d(]/.test(q))
            return "";
        try {
            const v = Function(`"use strict"; return (${q.replace(/\^/g, "**")});`)();
            return Number.isFinite(v) ? String(Number(v.toPrecision(12))) : "";
        } catch (e) {
            return "";
        }
    }

    function activate(i) {
        if (i < 0 || i >= items.length)
            return;
        items[i].run();
        done();
    }

    onQueryChanged: {
        current = 0;
        if (!clipboard)
            Sys.searchFiles(calc ? "" : query);
    }

    radius: 26
    implicitWidth: 640
    implicitHeight: 60 + (items.length ? list.height + 14 : 0)
    Behavior on implicitHeight { SpringAnimation { spring: 5; damping: 0.45 } }

    Glyph {
        id: lens
        x: 22
        y: 18
        text: root.clipboard ? Theme.icons.clipboard : Theme.icons.search
        font.pixelSize: 22
        color: Theme.textDim
    }

    TextInput {
        id: input
        anchors.left: lens.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 22
        y: 16
        focus: true
        font.family: Theme.font
        font.pixelSize: 22
        color: Theme.text
        selectionColor: Theme.accent
        clip: true

        Label {
            visible: !input.text
            text: !root.clipboard ? "Search apps and files, or calculate" :Sys.clipboardHistory.length ? "Search clipboard history" : "Clipboard history is empty"
            font.pixelSize: 22
            dim: true
        }

        Keys.onDeletePressed: event => {
            const item = root.items[root.current];
            if (root.clipboard && item && event.modifiers & Qt.ShiftModifier) {
                Sys.deleteClip(item.clip);
                root.current = Math.max(0, Math.min(root.current, root.items.length - 1));
            } else {
                event.accepted = false; // plain Delete edits the search text
            }
        }
        Keys.onUpPressed: root.current = Math.max(0, root.current - 1)
        Keys.onDownPressed: root.current = Math.min(root.items.length - 1, root.current + 1)
        Keys.onReturnPressed: root.activate(root.current)
        Keys.onEnterPressed: root.activate(root.current)
        Keys.onEscapePressed: root.done()
    }

    Rectangle {
        visible: root.items.length > 0
        anchors.top: parent.top
        anchors.topMargin: 59
        width: parent.width
        height: 1
        color: Theme.rim
    }

    ListView {
        id: list
        anchors.top: parent.top
        anchors.topMargin: 66
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        height: Math.min(contentHeight, 8 * 50) // the clipboard can hold hundreds; it scrolls
        clip: true
        interactive: contentHeight > height
        model: root.items
        currentIndex: root.current
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool selected: index === root.current

            width: ListView.view.width
            height: 50
            radius: 14
            color: selected ? Theme.accent : "transparent"

            Image {
                id: appIcon
                visible: !!row.modelData.icon
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                sourceSize: Qt.size(64, 64)
                source: row.modelData.icon ?? ""
            }
            Glyph {
                visible: !!row.modelData.glyph
                anchors.centerIn: appIcon
                text: row.modelData.glyph ?? ""
                font.pixelSize: 26
                color: row.selected ? "#ffffff" : Theme.text
            }
            Column {
                anchors.left: appIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    text: row.modelData.title
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: row.selected ? "#ffffff" : Theme.text
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    text: row.modelData.subtitle
                    font.pixelSize: 12
                    color: row.selected ? Qt.rgba(1, 1, 1, 0.8) : Theme.textDim
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.current = row.index
                onClicked: root.activate(row.index)
            }
        }
    }
}
