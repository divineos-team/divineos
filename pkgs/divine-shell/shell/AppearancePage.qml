import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import "Palette.js" as Palette

// Settings > Appearance: themes (mode, accent, glass and blur in one click), dark or light,
// the accent colour (a preset, or picked from the wallpaper), the wallpaper, and the icon,
// pointer and font themes. Popular themes that aren't installed have a Get button.
Flickable {
    id: page

    required property var settings
    readonly property var themes: settings.themes // { icons[], cursors[], fonts[] } installed

    // Popular themes, with their packages. `name` is the theme's folder or the font's family.
    readonly property var catalog: ({
        icons: [
            { name: "Adwaita", about: "GNOME's icons", pkg: "adwaita-icon-theme" },
            { name: "Papirus", about: "Colourful and flat, for nearly every app", pkg: "papirus-icon-theme" },
            { name: "breeze", label: "Breeze", about: "KDE's icons", pkg: "breeze-icons" }
        ],
        cursors: [
            { name: "divineOS", about: "divineOS's own", pkg: "divine-cursors" },
            { name: "capitaine-cursors", label: "Capitaine", about: "Shaped like macOS's", pkg: "capitaine-cursors" },
            { name: "Adwaita", about: "GNOME's pointer", pkg: "adwaita-cursors" }
        ],
        fonts: [
            { name: "Inter", pkg: "inter-font" },
            { name: "Noto Sans", pkg: "noto-fonts" },
            { name: "Cantarell", pkg: "cantarell-fonts" },
            { name: "Roboto", pkg: "ttf-roboto" },
            { name: "Open Sans", pkg: "ttf-opensans" },
            { name: "Fira Sans", pkg: "ttf-fira-sans" },
            { name: "IBM Plex Sans", pkg: "ttf-ibm-plex" },
            { name: "Ubuntu", pkg: "ttf-ubuntu-font-family" }
        ]
    })

    function label(kind, name) {
        return catalog[kind].find(t => t.name === name)?.label ?? name;
    }
    function missing(kind) {
        return catalog[kind].filter(t => !themes[kind].includes(t.name));
    }

    // The wallpaper's accent: drawn tiny into the canvas, then read back pixel by pixel.
    function accentFromWallpaper(url) {
        sampler.url = url;
        sampler.pending = true;
        if (sampler.isImageLoaded(url))
            sampler.requestPaint();
        else
            sampler.loadImage(url);
    }

    clip: true
    contentHeight: column.implicitHeight

    Canvas {
        id: sampler
        property url url
        property bool pending: false
        width: 64
        height: 36
        opacity: 0
        onImageLoaded: requestPaint()
        onPaint: {
            if (!pending || !isImageLoaded(url))
                return;
            pending = false;
            const ctx = getContext("2d");
            ctx.drawImage(url, 0, 0, width, height);
            page.settings.setAccent("wallpaper", Palette.accentFromPixels(ctx.getImageData(0, 0, width, height).data));
            unloadImage(url);
        }
    }

    // An accent choice: a dot of the colour, ringed when chosen.
    component Swatch: Item {
        id: swatch
        property color color
        property bool on
        default property alias inside: dot.data
        signal picked
        width: 28
        height: 28
        Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 2; border.color: Theme.text; opacity: swatch.on ? 0.9 : hover.containsMouse ? 0.35 : 0 }
        Rectangle { id: dot; anchors.fill: parent; anchors.margins: 4; radius: width / 2; color: swatch.color }
        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: swatch.picked() }
    }

    // A wallpaper choice: the picture, rounded, ringed when chosen.
    component WallpaperTile: Item {
        id: tile
        property url source
        property bool on
        width: 128
        height: 72
        Rectangle { anchors.fill: parent; anchors.margins: -4; radius: 14; color: "transparent"; border.width: 2; border.color: Theme.accent; visible: tile.on || tileHover.containsMouse; opacity: tile.on ? 1 : 0.5 }
        Image { id: picture; anchors.fill: parent; source: tile.source; sourceSize: Qt.size(256, 144); fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
        Rectangle { id: shape; anchors.fill: parent; radius: 10; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: picture; maskEnabled: true; maskSource: shape }
        MouseArea {
            id: tileHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                page.settings.setWallpaper(tile.source);
                if (page.settings.accentName === "wallpaper")
                    page.accentFromWallpaper(tile.source);
            }
        }
    }

    // A theme that isn't installed: what it is, and Get.
    component GetRow: RowLayout {
        id: get
        property string kind
        property var theme
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        spacing: 10
        Column {
            Layout.fillWidth: true
            leftPadding: 12
            Label { text: page.label(get.kind, get.theme.name); color: Theme.textDim }
            Label { visible: !!get.theme.about; text: get.theme.about ?? ""; dim: true; font.pixelSize: 12 }
        }
        PillButton {
            text: page.settings.themeBusy === get.theme.pkg ? "Getting…" : "Get"
            enabled: page.settings.themeBusy === ""
            onClicked: page.settings.installTheme(get.theme.pkg)
        }
    }

    FolderListModel {
        id: builtin
        folder: page.settings.wallpapersFolder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
    }
    FolderListModel {
        id: photos
        folder: page.settings.picturesFolder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Time
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        SettingsCard {
            Label { Layout.topMargin: 10; text: "Theme"; font.weight: Font.DemiBold }
            Label { text: "Sets the mode, accent colour, glass and blur together. Change any of them after."; dim: true; font.pixelSize: 12 }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 14
                Layout.bottomMargin: 10
                spacing: 14
                Repeater {
                    model: Theme.presets
                    ThemeTile {
                        required property var modelData
                        theme: modelData
                        on: page.settings.dark === modelData.dark && page.settings.accentName === modelData.accent && page.settings.tint === modelData.tint && page.settings.glass === modelData.glass
                        onPicked: page.settings.applyTheme(modelData)
                    }
                }
            }
        }

        SettingsCard {
            SettingRow {
                title: "Appearance"
                hint: "Shell, GTK and Qt apps follow this."
                Segmented { options: [{ label: "Dark", value: true }, { label: "Light", value: false }]; value: page.settings.dark; onPicked: v => page.settings.setDark(v) }
            }
            SettingRow {
                title: "Accent colour"
                hint: page.settings.accentName === "wallpaper" ? "From the wallpaper" : Theme.accents.find(a => a.id === page.settings.accentName)?.label ?? ""
                Row {
                    spacing: 2
                    Repeater {
                        model: Theme.accents
                        Swatch {
                            required property var modelData
                            color: modelData.color
                            on: page.settings.accentName === modelData.id
                            onPicked: page.settings.setAccent(modelData.id, "")
                        }
                    }
                    Swatch { // the wallpaper's own colour
                        on: page.settings.accentName === "wallpaper"
                        color: "transparent"
                        onPicked: page.accentFromWallpaper(page.settings.wallpaper)
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: "#FF375F" }
                                GradientStop { position: 0.5; color: "#30D158" }
                                GradientStop { position: 1; color: "#0A84FF" }
                            }
                        }
                        Glyph { anchors.centerIn: parent; text: Theme.icons.wallpaper; font.pixelSize: 12; color: "#ffffff" }
                    }
                }
            }
        }

        SettingsCard {
            Label { Layout.topMargin: 10; text: "Wallpaper"; font.weight: Font.DemiBold }
            Label { text: "Pictures in ~/Pictures show up here too."; dim: true; font.pixelSize: 12 }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 14
                Layout.bottomMargin: 14
                spacing: 14
                Repeater {
                    model: builtin
                    WallpaperTile {
                        required property url fileUrl
                        source: fileUrl
                        on: page.settings.wallpaper === fileUrl.toString()
                    }
                }
                Repeater {
                    model: photos
                    WallpaperTile {
                        required property url fileUrl
                        required property int index
                        visible: index < 24
                        source: fileUrl
                        on: page.settings.wallpaper === fileUrl.toString()
                    }
                }
            }
        }

        SettingsCard {
            Label { Layout.topMargin: 10; text: "Icons"; font.weight: Font.DemiBold }
            Label { Layout.fillWidth: true; text: "For GTK apps now; the dock and launcher switch the next time you sign in."; dim: true; font.pixelSize: 12; wrapMode: Text.WordWrap }
            Item { implicitHeight: 8 }
            Repeater {
                model: page.themes.icons
                Choice {
                    required property string modelData
                    text: page.label("icons", modelData)
                    on: modelData === page.settings.iconTheme
                    onPicked: page.settings.setIconTheme(modelData)
                }
            }
            Repeater {
                model: page.missing("icons")
                GetRow { required property var modelData; kind: "icons"; theme: modelData }
            }
            Item { implicitHeight: 8 }
        }

        SettingsCard {
            Label { Layout.topMargin: 10; text: "Pointer"; font.weight: Font.DemiBold }
            Item { implicitHeight: 8 }
            Repeater {
                model: page.themes.cursors
                Choice {
                    required property string modelData
                    text: page.label("cursors", modelData)
                    on: modelData === page.settings.cursorTheme
                    onPicked: page.settings.setCursor(modelData, page.settings.cursorSize)
                }
            }
            Repeater {
                model: page.missing("cursors")
                GetRow { required property var modelData; kind: "cursors"; theme: modelData }
            }
            SettingRow {
                title: "Size"
                Segmented {
                    options: [{ label: "Normal", value: 24 }, { label: "Large", value: 32 }, { label: "Larger", value: 48 }]
                    value: page.settings.cursorSize
                    onPicked: v => page.settings.setCursor(page.settings.cursorTheme, v)
                }
            }
        }

        SettingsCard {
            Label { Layout.topMargin: 10; text: "Font"; font.weight: Font.DemiBold }
            Label { text: "For the shell and GTK apps."; dim: true; font.pixelSize: 12 }
            Item { implicitHeight: 8 }
            Repeater {
                model: page.catalog.fonts.filter(f => page.themes.fonts.includes(f.name))
                Choice {
                    required property var modelData
                    text: modelData.name
                    family: modelData.name
                    on: modelData.name === page.settings.font
                    onPicked: page.settings.setFont(modelData.name)
                }
            }
            Repeater {
                model: page.missing("fonts")
                GetRow { required property var modelData; kind: "fonts"; theme: modelData }
            }
            Item { implicitHeight: 8 }
        }

        Label {
            visible: text !== ""
            Layout.fillWidth: true
            text: page.settings.themeStatus
            dim: true
            wrapMode: Text.WordWrap
        }
    }
}
