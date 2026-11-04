import QtQuick
import Quickshell.Wayland
import "Dock.js" as Dock

// macOS-style dock: pinned apps, a divider, other running apps, another divider, then the media
// player, Downloads and the Trash. Icons magnify under the pointer, bounce while launching and
// carry a dot while they have windows open; resting on one shows live previews of its windows.
// Pinned apps drag to a new place, or up off the dock to unpin. With auto-hide it slides away
// while a window would cover it and comes back when the pointer touches the bottom edge.
Item {
    id: root

    property var screen: null // the ShellScreen it sits on, for auto-hide

    readonly property int base: Sys.dockSize // Settings > Desktop & Dock
    readonly property int peak: Math.round(base * Sys.dockMagnify)
    readonly property bool autoHide: Sys.dockAutoHide
    readonly property int spacing: 6
    readonly property int pad: 9
    readonly property int margin: 8 // gap under the shelf
    readonly property int shelfHeight: base + 2 * pad
    readonly property int headroom: peak - base + 290 // magnified icons, the name tooltip, menus, previews and the Downloads stack
    readonly property int reserved: autoHide ? 0 : shelfHeight + margin

    // How far the shelf has slid down out of sight, 0 to shelfHeight + margin.
    readonly property bool shown: !autoHide || area.containsMouse || popupOpen || preview.visible || !(screen && Sys.dockCovered(screen, shelfHeight + margin))
    property real sunk: shown ? 0 : shelfHeight + margin
    Behavior on sunk { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // Pinned apps (group 0), other running apps (1), then the stacks (2); a divider between groups.
    // The media tile reads the player itself, so track changes don't rebuild the dock.
    readonly property var apps: Sys.dockApps.map(a => Object.assign({ kind: "app", group: a.pinned ? 0 : 1 }, a)).concat(
        (Sys.player ? [{ id: "media", kind: "media", name: "" }] : []).concat([
            { id: "downloads", kind: "downloads", name: "Downloads", icon: Qt.resolvedUrl("icons/downloads.svg") },
            { id: "trash", kind: "trash", name: "Trash" }
        ]).map(s => Object.assign({ group: 2, windows: 0, pinned: false, launchable: false }, s)))
    readonly property int pinnedCount: apps.filter(a => a.group === 0).length
    readonly property int divider: 2 * spacing + 1
    readonly property var offsets: { // divider space before each item
        let n = 0;
        return apps.map((a, i) => n += gapBefore(i) ? divider : 0);
    }
    readonly property real restWidth: apps.length * (base + spacing) - spacing + (offsets[offsets.length - 1] ?? 0) + 2 * pad

    // Pointer x in the shelf's unmagnified coordinates. Kept after the pointer leaves so
    // the icons shrink back in place while `magnify` eases out.
    property real pointer: -1e4
    property real magnify: area.containsMouse && !popupOpen && !dragging ? 1 : 0
    Behavior on magnify { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    readonly property int hovered: magnify > 0.5 ? nearest(pointer) : -1
    readonly property bool menuOpen: menu.app !== null
    readonly property bool stackOpen: stack.index >= 0
    readonly property bool popupOpen: menuOpen || stackOpen
    // What the window lets clicks through to: everything but these.
    readonly property Item hoverZone: area
    readonly property Item menuZone: menuOpen ? menu : stackOpen ? stack : null
    readonly property Item previewZone: preview.visible ? preview : null

    // Dragging a pinned app: where it would land, or off the dock (unpin) if let go up there.
    property int dragFrom: -1
    readonly property bool dragging: dragFrom >= 0
    property point pressedAt
    property bool dragged: false // the press became a drag, so it isn't a click
    property bool dragOff: false
    readonly property int dragTo: dragging ? Math.max(0, Math.min(pinnedCount - 1, nearest(pointer))) : -1

    function gapBefore(i) {
        return i > 0 && apps[i].group !== apps[i - 1].group;
    }
    function restCenter(i) {
        return pad + i * (base + spacing) + (offsets[i] ?? 0) + base / 2;
    }
    function nearest(x) {
        let best = -1;
        for (let i = 0; i < apps.length; i++)
            if (best < 0 || Math.abs(x - restCenter(i)) < Math.abs(x - restCenter(best)))
                best = i;
        return best;
    }
    function sizeAt(i) {
        const d = (pointer - restCenter(i)) / (base + spacing);
        return base + (peak - base) * magnify * Math.exp(-d * d / 2.2);
    }
    function dragShift(i) { // the dragged icon follows the pointer; the ones it passes make room
        if (!dragging)
            return 0;
        if (i === dragFrom)
            return pointer - restCenter(i);
        const step = base + spacing;
        return dragFrom < dragTo && i > dragFrom && i <= dragTo ? -step : dragFrom > dragTo && i >= dragTo && i < dragFrom ? step : 0;
    }
    function iconOf(item) {
        if (item.kind === "media")
            return Sys.player?.trackArtUrl || Sys.iconPath(Sys.player?.desktopEntry || "audio-x-generic", "audio-x-generic");
        if (item.kind === "trash")
            return Qt.resolvedUrl(Sys.trashFull ? "icons/trash-full.svg" : "icons/trash.svg");
        return item.icon;
    }
    function nameOf(item) {
        return item.kind !== "media" ? item.name : [Sys.player?.trackTitle, Sys.player?.trackArtist].filter(x => x).join(" — ") || (Sys.player?.identity ?? "");
    }
    function above(tile, w) { // x for a popup centred over a tile, kept on screen
        return Math.max(8, Math.min(width - w - 8, row.x + tile.x + tile.width - tile.size / 2 - w / 2));
    }
    function openMenu(i) {
        stack.index = -1;
        menu.armed = "";
        menu.index = i;
        menu.app = apps[i];
    }
    function openStack(i) {
        menu.app = null;
        stack.index = i;
    }
    function closeMenu() {
        menu.app = null;
        stack.index = -1;
    }

    // Window previews: after resting on an app with windows a moment, until the pointer leaves
    // both the icon and the previews.
    property int previewIndex: -1
    readonly property bool previewWanted: hovered >= 0 && apps[hovered].kind === "app" && apps[hovered].windows > 0 && !dragging && !popupOpen
    onHoveredChanged: {
        if (!previewWanted)
            previewClose.restart();
        else if (previewIndex >= 0)
            previewIndex = hovered;
        else
            previewDelay.restart();
    }
    Timer {
        id: previewDelay
        interval: 450
        onTriggered: {
            if (root.previewWanted)
                root.previewIndex = root.hovered;
        }
    }
    Timer {
        id: previewClose
        interval: 250
        onTriggered: {
            if (!root.previewWanted && !previewHover.hovered)
                root.previewIndex = -1;
        }
    }

    implicitHeight: headroom + shelfHeight + margin

    Glass {
        id: shelf
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.margin - root.sunk
        width: row.width + 2 * root.pad
        height: root.shelfHeight
        radius: 24
    }

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: shelf.bottom
        anchors.bottomMargin: root.pad
        spacing: root.spacing

        Repeater {
            id: icons
            model: root.apps

            Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool afterDivider: root.gapBefore(index)
                readonly property real size: root.sizeAt(index)
                readonly property real iconTop: height - size + lift.y

                function launch() {
                    bounce.restart();
                }

                width: size + (afterDivider ? root.divider : 0)
                height: root.peak
                z: index === root.dragFrom ? 1 : 0
                opacity: index === root.dragFrom && root.dragOff ? 0.35 : 1
                transform: Translate {
                    x: root.dragShift(tile.index)
                    Behavior on x {
                        enabled: tile.index !== root.dragFrom
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    visible: tile.afterDivider
                    x: root.spacing / 2
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.base * 0.15
                    width: 1
                    height: root.base * 0.7
                    color: Theme.track
                }

                Image {
                    id: icon
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: tile.size
                    height: tile.size
                    sourceSize: Qt.size(root.peak * 2, root.peak * 2) // fixed, so magnifying never reloads
                    source: root.iconOf(tile.modelData)
                    fillMode: Image.PreserveAspectCrop // album art isn't always square
                    mipmap: true
                    transform: Translate { id: lift }
                }

                // The media tile's play/pause badge: clicking it (the tile) plays or pauses.
                Rectangle {
                    visible: tile.modelData.kind === "media"
                    anchors.right: icon.right
                    anchors.bottom: icon.bottom
                    width: Math.round(tile.size * 0.42)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Glyph {
                        anchors.centerIn: parent
                        text: Sys.player?.isPlaying ? Theme.icons.pause : Theme.icons.play
                        color: "#ffffff"
                        font.pixelSize: parent.width * 0.62
                    }
                }

                // Running dot, brighter for the focused app.
                Rectangle {
                    visible: tile.modelData.windows > 0
                    anchors.horizontalCenter: icon.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: (root.pad - height) / 2
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.text
                    opacity: Sys.dockActive === tile.modelData.id ? 0.95 : 0.5
                }

                // Bounces until the app's first window shows up (which rebuilds this tile) or
                // three times if it never does.
                SequentialAnimation {
                    id: bounce
                    loops: 3
                    NumberAnimation { target: lift; property: "y"; to: -18; duration: 220; easing.type: Easing.OutQuad }
                    NumberAnimation { target: lift; property: "y"; to: 0; duration: 380; easing.type: Easing.OutBounce }
                }
            }
        }
    }

    // One pointer area for the whole shelf, a magnified icon wider on each side so the end
    // icons stay hovered as they grow. It reaches up over the magnified icons while engaged.
    // Auto-hide: it reaches down to the screen edge, and while hidden it's only that edge.
    MouseArea {
        id: area
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.autoHide ? 0 : root.margin
        width: root.restWidth + 2 * (root.peak - root.base)
        height: !root.shown ? 2 : root.shelfHeight + (root.autoHide ? root.margin : 0) + (root.magnify > 0 ? root.peak - root.base : 0)
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPositionChanged: mouse => {
            root.pointer = mouse.x - (root.peak - root.base);
            if (pressed && !root.dragging && !root.popupOpen && Math.hypot(mouse.x - root.pressedAt.x, mouse.y - root.pressedAt.y) > 8) {
                const i = root.nearest(root.pressedAt.x - (root.peak - root.base));
                if (i >= 0 && root.apps[i].group === 0) {
                    root.dragFrom = i;
                    root.dragged = true;
                    root.previewIndex = -1;
                }
            }
            if (root.dragging)
                root.dragOff = mouse.y < -40;
        }
        onPressed: mouse => {
            root.pointer = mouse.x - (root.peak - root.base);
            root.pressedAt = Qt.point(mouse.x, mouse.y);
            root.dragged = false;
            root.dragOff = false;
        }
        onReleased: {
            if (!root.dragging)
                return;
            const app = root.apps[root.dragFrom];
            if (root.dragOff)
                Sys.dockTogglePin(app.id);
            else if (root.dragTo !== root.dragFrom)
                Sys.dockMovePin(app.id, root.apps[root.dragTo].id);
            root.dragFrom = -1;
        }
        onClicked: mouse => {
            if (root.dragged)
                return;
            if (root.popupOpen)
                return root.closeMenu();
            const i = root.nearest(root.pointer);
            if (i < 0)
                return;
            if (mouse.button === Qt.RightButton)
                return root.openMenu(i);
            const app = root.apps[i];
            if (app.kind === "media")
                return Sys.player?.togglePlaying();
            if (app.kind === "downloads")
                return root.openStack(i);
            if (app.kind === "trash")
                return Sys.openPath(Sys.trashDir);
            if (!app.windows)
                icons.itemAt(i).launch();
            Sys.dockOpen(app.id);
        }
    }

    Glass {
        id: tip
        readonly property Item tile: root.hovered >= 0 && !root.popupOpen && !root.dragging && root.previewIndex < 0 ? icons.itemAt(root.hovered) : null

        visible: tile !== null && tipText.text !== ""
        round: true
        width: tipText.width + 24
        height: 28
        x: tile ? root.above(tile, width) : 0
        y: tile ? row.y + tile.iconTop - height - 8 : 0

        Label {
            id: tipText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 320)
            text: tip.tile ? root.nameOf(tip.tile.modelData) : ""
            font.weight: Font.Medium
        }
    }

    // Live previews of the app's windows; click one to go to it.
    Glass {
        id: preview
        readonly property Item tile: root.previewIndex >= 0 ? icons.itemAt(root.previewIndex) : null
        readonly property var windows: tile ? Sys.windowsOf(tile.modelData.id).slice(0, 4) : []

        visible: windows.length > 0
        radius: 18
        width: thumbs.width + 20
        height: thumbs.height + 20
        x: tile ? root.above(tile, width) : 0
        y: row.y - height - 4

        HoverHandler {
            id: previewHover
            onHoveredChanged: {
                if (!hovered)
                    previewClose.restart();
            }
        }

        Row {
            id: thumbs
            x: 10
            y: 10
            spacing: 10

            Repeater {
                model: preview.windows

                Column {
                    id: thumb
                    required property var modelData
                    spacing: 6

                    Rectangle {
                        width: 200
                        height: 125
                        radius: 10
                        color: thumbHover.hovered ? Theme.track : "transparent"
                        ScreencopyView {
                            anchors.centerIn: parent
                            captureSource: thumb.modelData
                            live: true
                            constraintSize: Qt.size(188, 113)
                            width: implicitWidth || 188
                            height: implicitHeight || 113
                        }
                    }
                    Label {
                        width: 200
                        horizontalAlignment: Text.AlignHCenter
                        text: thumb.modelData.title
                        font.pixelSize: 12
                    }
                    HoverHandler {
                        id: thumbHover
                    }
                    TapHandler {
                        onTapped: {
                            thumb.modelData.activate();
                            root.previewIndex = -1;
                        }
                    }
                }
            }
        }
    }

    Glass {
        id: menu
        property var app: null
        property int index: -1
        property string armed: "" // the action waiting for a second click
        readonly property Item tile: app ? icons.itemAt(index) : null
        readonly property var player: Sys.player
        readonly property var actions: (!app ? [] : app.kind === "media" ? [
            { label: "Previous", run: () => player?.previous() },
            { label: player?.isPlaying ? "Pause" : "Play", run: () => player?.togglePlaying() },
            { label: "Next", run: () => player?.next() },
            player?.canRaise ? { label: `Show ${player.identity}`, run: () => player.raise() } : null
        ] : app.kind === "downloads" ? [
            { label: "Open in Files", run: () => Sys.openPath(Sys.downloadsDir) }
        ] : app.kind === "trash" ? [
            { label: "Open", run: () => Sys.openPath(Sys.trashDir) },
            Sys.trashFull ? { label: "Empty Trash", confirm: "Click Again to Empty", run: () => Sys.emptyTrash() } : null
        ] : [
            app.windows ? (app.launchable ? { label: "New Window", run: () => Sys.dockNewWindow(app.id) } : null)
                        : { label: "Open", run: () => { menu.tile?.launch(); Sys.dockOpen(app.id); } },
            app.launchable ? { label: app.pinned ? "Remove from Dock" : "Keep in Dock", run: () => Sys.dockTogglePin(app.id) } : null,
            app.windows ? { label: "Quit", run: () => Sys.dockQuit(app.id) } : null
        ]).filter(a => a)

        visible: app !== null
        radius: 16
        width: 200
        height: list.implicitHeight + 12
        x: tile ? root.above(tile, width) : 0
        y: tile ? row.y + tile.iconTop - height - 8 : 0

        Column {
            id: list
            x: 6
            y: 6
            width: parent.width - 12

            Repeater {
                model: menu.actions

                Rectangle {
                    id: action
                    required property var modelData
                    readonly property bool armed: menu.armed === modelData.label

                    width: list.width
                    height: 32
                    radius: 10
                    color: action.armed ? Theme.danger : actionArea.containsMouse ? Theme.accent : "transparent"

                    Label {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: action.armed ? action.modelData.confirm : action.modelData.label
                        color: action.armed ? "#ffffff" : actionArea.containsMouse ? Theme.textOnAccent : Theme.text
                    }
                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (action.modelData.confirm && !action.armed) {
                                menu.armed = action.modelData.label;
                                return;
                            }
                            action.modelData.run();
                            root.closeMenu();
                        }
                    }
                }
            }
        }
    }

    // The Downloads stack: the newest files and folders; click one to open it.
    Glass {
        id: stack
        property int index: -1
        readonly property Item tile: index >= 0 ? icons.itemAt(index) : null
        readonly property int columns: 6

        visible: tile !== null
        radius: 20
        width: stackColumn.width + 20
        height: stackColumn.height + 24
        x: tile ? root.above(tile, width) : 0
        y: tile ? row.y + tile.iconTop - height - 8 : 0

        Column {
            id: stackColumn
            x: 10
            y: 12
            width: stack.columns * 84
            spacing: 8

            Label {
                leftPadding: 6
                text: "Downloads"
                font.pixelSize: 14
                font.weight: Font.Bold
            }
            Label {
                visible: Sys.downloads.length === 0
                leftPadding: 6
                text: "Nothing downloaded yet."
                dim: true
            }
            Grid {
                columns: stack.columns
                Repeater {
                    model: stack.visible ? Sys.downloads : []
                    Item {
                        id: file
                        required property var modelData
                        width: 84
                        height: 92
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 12
                            color: fileHover.hovered ? Theme.off : "transparent"
                        }
                        Image {
                            x: 18
                            y: 8
                            width: 48
                            height: 48
                            sourceSize: Qt.size(96, 96)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            source: Dock.isImage(file.modelData.name) ? "file://" + file.modelData.path : Sys.iconPath(Dock.fileIcon(file.modelData.name, file.modelData.dir), "text-x-generic")
                        }
                        Label {
                            x: 4
                            y: 60
                            width: 76
                            horizontalAlignment: Text.AlignHCenter
                            text: file.modelData.name
                            font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 2
                        }
                        HoverHandler {
                            id: fileHover
                        }
                        TapHandler {
                            onTapped: {
                                Sys.openPath(file.modelData.path);
                                root.closeMenu();
                            }
                        }
                    }
                }
            }
            Item {
                width: parent.width
                height: openFiles.height
                PillButton {
                    id: openFiles
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    primary: false
                    text: "Open in Files"
                    onClicked: {
                        Sys.openPath(Sys.downloadsDir);
                        root.closeMenu();
                    }
                }
            }
        }
    }
}
