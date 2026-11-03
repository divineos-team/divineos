import QtQuick

// macOS-style dock: pinned apps, a divider, then other running apps. Icons magnify under
// the pointer, bounce while launching and carry a dot while they have windows open.
Item {
    id: root

    readonly property int base: 52
    readonly property int peak: 80
    readonly property int spacing: 6
    readonly property int pad: 9
    readonly property int margin: 8 // gap under the shelf
    readonly property int shelfHeight: base + 2 * pad
    readonly property int headroom: 124 // magnified icons, the name tooltip and the menu
    readonly property int reserved: shelfHeight + margin

    readonly property var apps: Sys.dockApps
    readonly property int split: apps.findIndex(a => !a.pinned) // first running-only app
    readonly property int divider: split > 0 ? 2 * spacing + 1 : 0
    readonly property real restWidth: apps.length * (base + spacing) - spacing + divider + 2 * pad

    // Pointer x in the shelf's unmagnified coordinates. Kept after the pointer leaves so
    // the icons shrink back in place while `magnify` eases out.
    property real pointer: -1e4
    property real magnify: area.containsMouse && !menuOpen ? 1 : 0
    Behavior on magnify { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    readonly property int hovered: magnify > 0.5 ? nearest(pointer) : -1
    readonly property bool menuOpen: menu.app !== null
    // What the window lets clicks through to: everything but these.
    readonly property Item hoverZone: area
    readonly property Item menuZone: menuOpen ? menu : null

    function restCenter(i) {
        return pad + i * (base + spacing) + (split > 0 && i >= split ? divider : 0) + base / 2;
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
    function openMenu(i) {
        menu.index = i;
        menu.app = apps[i];
    }
    function closeMenu() {
        menu.app = null;
    }

    implicitHeight: headroom + shelfHeight + margin

    Glass {
        id: shelf
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.margin
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
                readonly property bool afterDivider: index === root.split && root.split > 0
                readonly property real size: root.sizeAt(index)
                readonly property real iconTop: height - size + lift.y

                function launch() {
                    bounce.restart();
                }

                width: size + (afterDivider ? root.divider : 0)
                height: root.peak

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
                    source: tile.modelData.icon
                    mipmap: true
                    transform: Translate { id: lift }
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
    MouseArea {
        id: area
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.margin
        width: root.restWidth + 2 * (root.peak - root.base)
        height: root.shelfHeight + (root.magnify > 0 ? root.peak - root.base : 0)
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPositionChanged: mouse => root.pointer = mouse.x - (root.peak - root.base)
        onPressed: mouse => root.pointer = mouse.x - (root.peak - root.base)
        onClicked: mouse => {
            if (root.menuOpen)
                return root.closeMenu();
            const i = root.nearest(root.pointer);
            if (i < 0)
                return;
            if (mouse.button === Qt.RightButton)
                return root.openMenu(i);
            const app = root.apps[i];
            if (!app.windows)
                icons.itemAt(i).launch();
            Sys.dockOpen(app.id);
        }
    }

    Glass {
        id: tip
        readonly property Item tile: root.hovered >= 0 && !root.menuOpen ? icons.itemAt(root.hovered) : null

        visible: tile !== null
        round: true
        width: tipText.implicitWidth + 24
        height: 28
        x: tile ? row.x + tile.x + tile.width - tile.size / 2 - width / 2 : 0
        y: tile ? row.y + tile.iconTop - height - 8 : 0

        Label {
            id: tipText
            anchors.centerIn: parent
            text: tip.tile?.modelData.name ?? ""
            font.weight: Font.Medium
        }
    }

    Glass {
        id: menu
        property var app: null
        property int index: -1
        readonly property Item tile: app ? icons.itemAt(index) : null
        readonly property var actions: !app ? [] : [
            app.windows ? (app.launchable ? { label: "New Window", run: () => Sys.dockNewWindow(app.id) } : null)
                        : { label: "Open", run: () => { menu.tile?.launch(); Sys.dockOpen(app.id); } },
            app.launchable ? { label: app.pinned ? "Remove from Dock" : "Keep in Dock", run: () => Sys.dockTogglePin(app.id) } : null,
            app.windows ? { label: "Quit", run: () => Sys.dockQuit(app.id) } : null
        ].filter(a => a)

        visible: app !== null
        radius: 16
        width: 200
        height: list.implicitHeight + 12
        x: tile ? Math.max(8, Math.min(root.width - width - 8, row.x + tile.x + tile.width - tile.size / 2 - width / 2)) : 0
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

                    width: list.width
                    height: 32
                    radius: 10
                    color: actionArea.containsMouse ? Theme.accent : "transparent"

                    Label {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: action.modelData.label
                        color: actionArea.containsMouse ? "#ffffff" : Theme.text
                    }
                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            action.modelData.run();
                            root.closeMenu();
                        }
                    }
                }
            }
        }
    }
}
