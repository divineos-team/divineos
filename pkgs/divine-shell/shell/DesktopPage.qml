import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// Settings > Desktop & Dock: a layout to start from, then each part of it on its own: the space
// between windows, their corners and borders, the glass, motion, and the dock.
Flickable {
    id: page

    required property var settings
    readonly property var windows: settings.windows // { gaps, rounding, border }
    readonly property var dock: settings.dock // { size, magnify, autoHide }

    // Divine Default and Auto-Tiling tile windows; macOS and Windows 11 let them float. Windows 11
    // swaps the menu bar and dock for a taskbar; Auto-Tiling hides the dock until you reach for it.
    readonly property var presets: [
        { id: "divine", label: "Divine Default", windows: { gaps: 14, rounding: 22, border: 1 }, blur: 8, dock: { size: 52, magnify: 1.55, autoHide: false } },
        { id: "macos", label: "macOS", windows: { gaps: 10, rounding: 14, border: 0 }, blur: 10, dock: { size: 48, magnify: 1.55, autoHide: false } },
        { id: "windows", label: "Windows 11", windows: { gaps: 8, rounding: 8, border: 1 }, blur: 8, dock: { size: 48, magnify: 1, autoHide: false } },
        { id: "tiling", label: "Auto-Tiling Pro", windows: { gaps: 6, rounding: 10, border: 2 }, blur: 6, dock: { size: 44, magnify: 1, autoHide: true } }
    ]
    function matches(p) {
        const same = (a, b) => Object.keys(a).every(k => a[k] === b[k]);
        return p.id === settings.layout && same(p.windows, windows) && p.blur === settings.blurSize && same(p.dock, dock);
    }
    function setWindows(key, value) {
        settings.setWindows(Object.assign({}, windows, { [key]: value }));
    }

    clip: true
    contentHeight: column.implicitHeight

    // A preset drawn small: the wallpaper, two windows tiled with its gaps and corners, its dock.
    component PresetTile: Item {
        id: tile
        property var preset
        readonly property real k: 0.3 // the drawing's scale
        width: 140
        height: 112
        Rectangle { x: -4; y: -4; width: 148; height: 87; radius: 12; color: "transparent"; border.width: 2; border.color: Theme.accent; visible: page.matches(tile.preset) || hover.containsMouse; opacity: page.matches(tile.preset) ? 1 : 0.5 }
        Item {
            id: screen
            width: 140
            height: 79
            Image { id: wall; anchors.fill: parent; source: page.settings.wallpaper; sourceSize: Qt.size(280, 158); fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
            Rectangle { id: shape; anchors.fill: parent; radius: 8; visible: false; layer.enabled: true }
            MultiEffect { anchors.fill: parent; source: wall; maskEnabled: true; maskSource: shape }
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    readonly property bool taskbar: tile.preset.id === "windows"
                    readonly property bool floating: taskbar || tile.preset.id === "macos"
                    readonly property real gap: Math.max(1, tile.preset.windows.gaps * tile.k)
                    readonly property real above: taskbar ? gap : 6 + gap // under the menu bar
                    readonly property real below: taskbar ? 10 + gap : tile.preset.dock.autoHide ? gap : 16 + gap
                    // tiled side by side, or two overlapping windows
                    x: floating ? 16 + index * 36 : gap + index * (parent.width - gap) / 2
                    y: floating ? above + 4 + index * 10 : above
                    width: floating ? 72 : (parent.width - 3 * gap) / 2
                    height: floating ? 40 : parent.height - above - below
                    radius: tile.preset.windows.rounding * tile.k
                    color: Qt.rgba(1, 1, 1, 0.7)
                    border.width: tile.preset.windows.border
                    border.color: Qt.rgba(1, 1, 1, 0.9)
                }
            }
            Rectangle { // the taskbar
                visible: tile.preset.id === "windows"
                anchors.bottom: parent.bottom
                width: parent.width
                height: 9
                color: Qt.rgba(1, 1, 1, 0.55)
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Repeater { model: 5; Rectangle { width: 5; height: 5; radius: 1; color: Qt.rgba(0, 0, 0, 0.35) } }
                }
            }
            Rectangle { // the dock
                visible: !tile.preset.dock.autoHide && tile.preset.id !== "windows"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: tile.preset.dock.size * 1.1
                height: tile.preset.dock.size * 0.2
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.55)
            }
        }
        Label { anchors.horizontalCenter: parent.horizontalCenter; y: 90; text: tile.preset.label; font.weight: Font.Medium }
        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: page.settings.applyPreset(tile.preset) }
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        SettingsCard {
            Label { Layout.topMargin: 10; text: "Layout"; font.weight: Font.DemiBold }
            Label { text: "A starting point. Everything below changes it further."; dim: true; font.pixelSize: 12 }
            Row {
                Layout.topMargin: 14
                Layout.bottomMargin: 4
                spacing: 14
                Repeater {
                    model: page.presets
                    PresetTile { required property var modelData; preset: modelData }
                }
            }
        }

        SettingsCard {
            SettingRow {
                title: "Space between windows"
                SettingSlider { from: 0; to: 32; value: page.windows.gaps; suffix: " px"; onMoved: v => page.setWindows("gaps", v) }
            }
            SettingRow {
                title: "Rounded corners"
                SettingSlider { from: 0; to: 30; value: page.windows.rounding; suffix: " px"; onMoved: v => page.setWindows("rounding", v) }
            }
            SettingRow {
                title: "Window border"
                Segmented {
                    options: [{ label: "None", value: 0 }, { label: "Thin", value: 1 }, { label: "Thick", value: 2 }]
                    value: page.windows.border
                    onPicked: v => page.setWindows("border", v)
                }
            }
        }

        SettingsCard {
            SettingRow {
                title: "Glass"
                hint: "Liquid refracts what's behind it. Frosted is a plain blur and lighter on the GPU. Off draws solid panels for the longest battery life."
                Segmented {
                    options: [{ label: "Liquid", value: "acrylic" }, { label: "Frosted", value: "kawase" }, { label: "Off", value: "off" }]
                    value: page.settings.glass
                    onPicked: v => page.settings.setGlass(v)
                }
            }
            SettingRow {
                title: "Blur"
                hint: "How much the glass softens what's behind it."
                SettingSlider { enabled: page.settings.glass !== "off"; from: 2; to: 16; value: page.settings.blurSize; onMoved: v => page.settings.setBlur(v) }
            }
            SettingRow {
                title: "Motion"
                hint: "Spring motion for windows, panels and workspaces."
                Segmented {
                    options: [{ label: "Off", value: 0 }, { label: "Relaxed", value: 0.7 }, { label: "Normal", value: 1 }, { label: "Quick", value: 1.6 }]
                    value: page.settings.motion
                    onPicked: v => page.settings.setMotion(v)
                }
            }
        }

        SettingsCard {
            Label { Layout.topMargin: 10; text: "Desktop widgets"; font.weight: Font.DemiBold }
            Label { text: "On the wallpaper, under your windows. Drag them where you like."; dim: true; font.pixelSize: 12 }
            Repeater {
                model: [
                    { kind: "clock", title: "Clock" },
                    { kind: "system", title: "System", hint: "CPU, memory and graphics load" },
                    { kind: "note", title: "Sticky note" },
                    { kind: "media", title: "Now playing" }
                ]
                SettingRow {
                    required property var modelData
                    title: modelData.title
                    hint: modelData.hint ?? ""
                    Segmented {
                        options: [{ label: "On", value: true }, { label: "Off", value: false }]
                        value: page.settings.widgets[modelData.kind] !== undefined
                        onPicked: v => page.settings.setWidget(modelData.kind, v)
                    }
                }
            }
        }

        SettingsCard {
            SettingRow {
                title: "Dock size"
                SettingSlider { from: 36; to: 72; step: 2; value: page.dock.size; suffix: " px"; onMoved: v => page.settings.setDock({ size: v }) }
            }
            SettingRow {
                title: "Magnification"
                hint: "Icons grow under the pointer."
                Segmented {
                    options: [{ label: "Off", value: 1 }, { label: "Small", value: 1.3 }, { label: "Large", value: 1.55 }]
                    value: page.dock.magnify
                    onPicked: v => page.settings.setDock({ magnify: v })
                }
            }
            SettingRow {
                title: "Hide the dock"
                hint: "It slides away and comes back when the pointer touches the bottom of the screen."
                Segmented {
                    options: [{ label: "On", value: true }, { label: "Off", value: false }]
                    value: page.dock.autoHide
                    onPicked: v => page.settings.setDock({ autoHide: v })
                }
            }
        }
    }
}
