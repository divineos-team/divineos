import QtQuick
import "Units.js" as Units

// Spotlight-style search: apps ranked by name and keywords, files and folders in your home,
// plus inline arithmetic and unit conversions ("10 km to mi"). In clipboard mode (Super+Shift+V) it searches the clipboard history.
Glass {
    id: root

    signal done
    property int current: 0
    property bool clipboard: false

    readonly property string query: input.text.trim()
    readonly property string calc: evaluate(query) || Units.convert(query)
    readonly property var items: clipboard ? clips(query) : (calc ? [{
                title: calc,
                subtitle: "Enter copies the result",
                glyph: Theme.icons.calculator,
                run: () => Sys.copy(calc)
            }] : []).concat(rank(query), settings(query), files(query))

    // Settings pages, found by name or by what's on them; Enter opens Settings there.
    readonly property var settingsPages: [
        { id: "appearance", label: "Appearance", glyph: Theme.icons.palette, words: "dark light mode accent colour color wallpaper background icons cursor pointer font theme themes oled pitch neon frost" },
        { id: "desktop", label: "Desktop & Dock", glyph: Theme.icons.desktop, words: "layout preset gaps rounding corners border blur glass animations motion dock magnification auto-hide" },
        { id: "displays", label: "Displays", glyph: Theme.icons.display, words: "monitor screen resolution refresh rate scale scaling night light warmth" },
        { id: "sound", label: "Sound", glyph: Theme.icons.speaker, words: "audio volume output speakers headphones profile" },
        { id: "network", label: "Network", glyph: Theme.icons.wifi, words: "wifi wi-fi wireless ethernet internet vpn wireguard openvpn proxy" },
        { id: "bluetooth", label: "Bluetooth", glyph: Theme.icons.bluetooth, words: "pair headphones earbuds airpods devices forget" },
        { id: "printers", label: "Printers", glyph: Theme.icons.printer, words: "printer print scanner cups airprint test page" },
        { id: "keyboard", label: "Keyboard", glyph: Theme.icons.keyboard, words: "layout language input switch" },
        { id: "mouse", label: "Mouse & Touchpad", glyph: Theme.icons.mouse, words: "pointer speed acceleration scrolling natural left-handed trackpad tap click gestures swipe" },
        { id: "power", label: "Power", glyph: Theme.icons.power, words: "battery mode saver performance sleep suspend lock idle screen off" },
        { id: "time", label: "Date & Time", glyph: Theme.icons.clock, words: "clock time zone timezone 24-hour ntp weather" },
        { id: "users", label: "Users", glyph: Theme.icons.users, words: "account picture avatar password administrator admin" },
        { id: "apps", label: "Default Apps", glyph: Theme.icons.defaultApps, words: "browser email mail files pdf video music open with" },
        { id: "startup", label: "Startup Apps", glyph: Theme.icons.startup, words: "autostart login sign in startup boot open" },
        { id: "drivers", label: "Drivers", glyph: Theme.icons.chip, words: "nvidia amd intel gpu graphics vmware virtualbox guest tools" },
        { id: "disks", label: "Disks", glyph: Theme.icons.disk, words: "drive usb stick format erase partition mount iso image flash burn bootable exfat fat32 ntfs ext4" },
        { id: "backup", label: "Backup", glyph: Theme.icons.backup, words: "snapshot restore rollback undo timeshift btrfs recovery" },
        { id: "performance", label: "Performance", glyph: Theme.icons.performance, words: "swappiness swap cache tcp congestion file watchers sysctl" }
    ]
    function settings(q) {
        q = q.toLowerCase();
        if (calc || q.length < 2)
            return [];
        return settingsPages.filter(p => p.label.toLowerCase().includes(q) || p.words.split(" ").some(w => w.startsWith(q))).slice(0, 3).map(p => ({
            title: p.label,
            subtitle: "Settings",
            glyph: p.glyph,
            run: () => Sys.run(["devine-tweaks", p.id])
        }));
    }

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
            const image = data && /\d+x\d+$/.test(data[1]);
            return {
                title: data ? (image ? "Image" : "Data") : c.text,
                subtitle: data ? data[1] : "",
                glyph: data ? Theme.icons.image : Theme.icons.clipboard, // until the preview loads
                icon: image ? Sys.clipThumb(c.id) : "",
                preview: image,
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
            text: !root.clipboard ? "Search apps, files and settings, or calculate" :Sys.clipboardHistory.length ? "Search clipboard history" : "Clipboard history is empty"
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
            height: row.modelData.preview ? 76 : 50
            radius: 14
            color: selected ? Theme.accent : "transparent"

            Image {
                id: appIcon
                visible: !!row.modelData.icon
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: row.modelData.preview ? 96 : 32
                height: row.modelData.preview ? 60 : 32
                sourceSize: row.modelData.preview ? Qt.size(192, 120) : Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                asynchronous: !!row.modelData.preview
                source: row.modelData.icon ?? ""
            }
            Glyph {
                visible: !!row.modelData.glyph && appIcon.status !== Image.Ready
                anchors.centerIn: appIcon
                text: row.modelData.glyph ?? ""
                font.pixelSize: 26
                color: row.selected ? Theme.textOnAccent : Theme.text
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
                    color: row.selected ? Theme.textOnAccent : Theme.text
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    text: row.modelData.subtitle
                    font.pixelSize: 12
                    color: row.selected ? Qt.rgba(Theme.textOnAccent.r, Theme.textOnAccent.g, Theme.textOnAccent.b, 0.8) : Theme.textDim
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
