import QtQuick
import QtQuick.Layouts

// Welcome > Set Up: a theme, a web browser, media codecs and the drivers this computer needs,
// one click each. Installs go through pkg-helper (one password prompt).
Flickable {
    id: page

    required property var welcome // WelcomeContent: installed, defaultBrowser, drivers, busy, status

    readonly property var browsers: [
        { pkg: "firefox", name: "Firefox", desktop: "firefox.desktop", about: "Mozilla's, with tracking protection and add-ons" },
        { pkg: "chromium", name: "Chromium", desktop: "chromium.desktop", about: "The open-source base of Google Chrome" },
        { pkg: "vivaldi", name: "Vivaldi", desktop: "vivaldi-stable.desktop", about: "Tab stacks, side panels, mail and calendar built in" },
        { pkg: "falkon", name: "Falkon", desktop: "org.kde.falkon.desktop", about: "Small and quick, from KDE" }
    ]
    readonly property bool hasCodecs: welcome.installed.includes("gst-libav")
    readonly property var neededDrivers: welcome.drivers.filter(d => !d.installed)

    clip: true
    contentHeight: column.implicitHeight

    component Step: SettingsCard {
        id: step
        property string title
        property string hint
        Label { Layout.topMargin: 10; text: step.title; font.weight: Font.DemiBold }
        Label { Layout.fillWidth: true; text: step.hint; dim: true; font.pixelSize: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone; bottomPadding: 8 }
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        Label { text: "Set Up"; font.pixelSize: 24; font.weight: Font.Bold; bottomPadding: 4 }

        Step {
            title: "Pick a look"
            hint: "Change it, or any part of it, in Settings > Appearance."
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 10
                spacing: 14
                Repeater {
                    model: Theme.presets
                    ThemeTile {
                        required property var modelData
                        theme: modelData
                        on: Theme.dark === modelData.dark && page.welcome.accentName === modelData.accent && Theme.tint === modelData.tint
                        onPicked: page.welcome.applyTheme(modelData)
                    }
                }
            }
        }

        Step {
            title: "Choose a web browser"
            hint: "It's installed and opens your links. Others are in the Store."
            Repeater {
                model: page.browsers
                Choice {
                    required property var modelData
                    readonly property bool installed: page.welcome.installed.includes(modelData.pkg)
                    icon: Theme.icons.web
                    text: modelData.name
                    detail: page.welcome.busy === modelData.pkg ? "Installing…" : installed ? "Installed" : modelData.about
                    on: page.welcome.defaultBrowser === modelData.desktop
                    onPicked: if (!page.welcome.busy) page.welcome.getBrowser(modelData.pkg, modelData.desktop)
                }
            }
            Item { implicitHeight: 8 }
        }

        Step {
            title: "Media codecs"
            hint: "Play MP4, MKV, MP3, AAC and every other common format, in every app."
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 10
                Label { Layout.fillWidth: true; text: page.hasCodecs ? "Installed" : "GStreamer's good, bad, ugly and libav plugins"; dim: true }
                PillButton {
                    text: page.welcome.busy === "codecs" ? "Installing…" : page.hasCodecs ? "Installed" : "Install"
                    primary: !page.hasCodecs
                    enabled: !page.hasCodecs && !page.welcome.busy
                    onClicked: page.welcome.getCodecs()
                }
            }
        }

        Step {
            title: "Drivers"
            hint: page.welcome.drivers.length ? "What this computer needs to run at full speed." : "This computer works with the drivers every divineOS has. Nothing to add."
            Repeater {
                model: page.welcome.drivers
                SettingRow {
                    required property var modelData
                    title: modelData.name
                    hint: modelData.about
                    Label { text: modelData.installed ? "Installed" : ""; dim: true }
                }
            }
            PillButton {
                visible: page.neededDrivers.length > 0
                Layout.alignment: Qt.AlignRight
                Layout.bottomMargin: 10
                text: page.welcome.busy === "drivers" ? "Installing…" : "Install Drivers"
                enabled: !page.welcome.busy
                onClicked: page.welcome.installDrivers(page.neededDrivers.map(d => d.id))
            }
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: page.welcome.status
            dim: true
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }
}
