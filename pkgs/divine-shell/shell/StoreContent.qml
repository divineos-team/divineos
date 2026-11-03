import QtQuick
import QtQuick.Layouts
import "StoreInfo.js" as StoreInfo

// devine-store's view: Discover (banners, featured apps and search), Installed, Updates, GitHub
// (RepoStation) and an app's own page (screenshots, ratings, where to install it from).
// Store.qml supplies the data and acts on the signals.
Item {
    id: root

    property string page: "discover" // discover | installed | updates | github | app
    property string previous: "discover" // where the app page's Back goes
    property string category: "All"
    property string query: ""
    property var featured: [] // { pkg, name, category, about, flatpak }
    property var banners: [] // featured apps with { tagline, from, to } colours
    property var detail: null // the app page's app: { pkg, name, about, category?, aur?, flatpak? }
    property var info: null // StoreInfo.info() for it, null while loading
    property var flatpaks: [] // installed Flatpak app ids
    property var debs: ({}) // Debian packages through divine-pkg: pkg → desktop entry ids
    property var githubResults: [] // { repo, about, stars, language }
    property var githubInstalled: [] // { repo, commit, bins }
    property bool githubSearching: false
    property bool githubFailed: false
    property bool building: false // the running job is a RepoStation build
    property var installedNames: [] // every installed package
    property var apps: [] // installed apps: { id, name, icon, pkg }
    property var results: [] // search hits: { pkg, about, aur, votes }
    property bool searching: false
    property bool searchFailed: false
    property var updates: [] // { name, from, to, aur }
    property bool checking: false
    property bool checkFailed: false
    property date lastUpgrade // invalid until known
    property var news: [] // Arch Linux news: { title, link, date }
    property string busy: "" // the package being worked on, "upgrade", or ""
    property real progress: -1 // 0–1 while pacman counts its steps
    property string status: ""
    property var log: [] // the running job's output, for Details
    property bool showLog: false
    property bool githubApps: false // RepoStation is installed

    readonly property var installed: {
        const s = {};
        for (const n of installedNames)
            s[n] = true;
        return s;
    }
    readonly property var categories: ["All", "Internet", "Office", "Graphics", "Media", "Games", "Development"]
    readonly property var glyphs: ({
            Internet: Theme.icons.web,
            Office: Theme.icons.document,
            Graphics: Theme.icons.palette,
            Media: Theme.icons.movie,
            Games: Theme.icons.gamepad,
            Development: Theme.icons.code
        })

    signal search(string query)
    signal install(string pkg, bool aur)
    signal remove(string pkg)
    signal open(string id)
    signal upgrade
    signal checkUpdates
    signal openLink(string url)
    signal details(var app) // fetch what the app page shows
    signal installFlatpak(string id)
    signal installDebian(string pkg) // into divine-pkg's Debian container
    signal searchGithub(string query)
    signal installGithub(string repo)
    signal updateGithub(string repo)
    signal removeGithub(string repo)

    function appFor(pkg) {
        return apps.find(a => a.pkg === pkg) ?? null;
    }
    function show(app) {
        if (page !== "app")
            previous = page;
        detail = app;
        info = null;
        page = "app";
        details(app);
    }

    implicitWidth: 900
    implicitHeight: 620

    // An app's icon, or a glyph on a blue tile for apps that aren't installed yet.
    component AppIcon: Item {
        id: appIcon
        property string source
        property string glyph: Theme.icons.apps
        implicitWidth: 48
        implicitHeight: 48
        Image {
            anchors.fill: parent
            visible: appIcon.source !== ""
            source: appIcon.source
            sourceSize: Qt.size(96, 96)
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            visible: appIcon.source === ""
            radius: width * 0.26
            gradient: Gradient {
                GradientStop { position: 0; color: "#64D2FF" }
                GradientStop { position: 1; color: Theme.accent }
            }
            Glyph { anchors.centerIn: parent; text: appIcon.glyph; color: Theme.textOnAccent; font.pixelSize: parent.width * 0.5 }
        }
    }

    // Get, Open, or Installed for a package.
    component GetButton: PillButton {
        property string pkg
        property bool aur
        readonly property var app: root.appFor(pkg)
        readonly property bool has: root.installed[pkg] === true
        text: root.busy === pkg ? "Working…" : app ? "Open" : has ? "Installed" : "Get"
        primary: !has
        enabled: app !== null || (!has && root.busy === "")
        onClicked: app ? root.open(app.id) : root.install(pkg, aur)
    }

    component Tag: Rectangle {
        property alias text: tagLabel.text
        implicitWidth: tagLabel.implicitWidth + 14
        implicitHeight: 20
        radius: 10
        color: Theme.off
        Label { id: tagLabel; anchors.centerIn: parent; font.pixelSize: 11; font.weight: Font.DemiBold; dim: true }
    }

    // A 0–5 rating as stars, halves included.
    component Stars: Row {
        id: stars
        property real value
        property int size: 14
        spacing: 1
        Repeater {
            model: 5
            Glyph {
                required property int index
                text: stars.value >= index + 0.75 ? Theme.icons.star : stars.value >= index + 0.25 ? Theme.icons.starHalf : Theme.icons.starOutline
                font.pixelSize: stars.size
                color: "#FFB340"
            }
        }
    }

    // ── Sidebar ──
    Column {
        id: sidebar
        x: 18
        y: 18
        width: 190
        spacing: 4

        Label { text: "Store"; font.pixelSize: 22; font.weight: Font.Bold; bottomPadding: 12; leftPadding: 8 }
        Field {
            width: parent.width
            icon: Theme.icons.search
            placeholder: "Search apps"
            onTextChanged: {
                root.query = text.trim();
                if (root.query)
                    root.page = "discover";
                root.search(root.query);
            }
        }
        Item { width: 1; height: 8 }
        NavItem { width: parent.width; icon: Theme.icons.store; text: "Discover"; on: root.page === "discover"; onClicked: root.page = "discover" }
        NavItem { width: parent.width; icon: Theme.icons.apps; text: "Installed"; on: root.page === "installed"; onClicked: root.page = "installed" }
        NavItem { width: parent.width; icon: Theme.icons.download; text: "Updates"; badge: root.updates.length; on: root.page === "updates"; onClicked: root.page = "updates" }
        NavItem { visible: root.githubApps; width: parent.width; icon: Theme.icons.github; text: "GitHub"; on: root.page === "github"; onClicked: root.page = "github" }
    }

    // ── Pages ──
    StackLayout {
        id: pages
        anchors.left: sidebar.right
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 18
        anchors.bottom: strip.visible ? strip.top : parent.bottom
        anchors.bottomMargin: strip.visible ? Theme.gap : 18
        currentIndex: ["discover", "installed", "updates", "github", "app"].indexOf(root.page)

        // Discover: featured apps by category, or search results
        Flickable {
            clip: true
            contentHeight: discover.implicitHeight
            ColumnLayout {
                id: discover
                width: parent.width
                spacing: Theme.gap

                // Featured banners, one after another every few seconds
                Item {
                    id: hero
                    property int current: 0
                    visible: !root.query && root.category === "All" && root.banners.length > 0
                    Layout.fillWidth: true
                    implicitHeight: 184
                    Timer {
                        interval: 7000
                        repeat: true
                        running: hero.visible && root.page === "discover"
                        onTriggered: hero.current = (hero.current + 1) % root.banners.length
                    }
                    Repeater {
                        model: root.banners
                        Rectangle {
                            id: banner
                            required property var modelData
                            required property int index
                            anchors.fill: parent
                            radius: 24
                            opacity: index === hero.current ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: banner.modelData.from }
                                GradientStop { position: 1; color: banner.modelData.to }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.show(banner.modelData)
                            }
                            Glyph {
                                anchors.right: parent.right
                                anchors.rightMargin: 40
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.glyphs[banner.modelData.category] ?? Theme.icons.apps
                                font.pixelSize: 112
                                color: Qt.rgba(1, 1, 1, 0.28)
                            }
                            Column {
                                x: 28
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.6
                                spacing: 6
                                Label { text: "FEATURED"; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Qt.rgba(1, 1, 1, 0.75) }
                                Label { width: parent.width; text: banner.modelData.name; font.pixelSize: 28; font.weight: Font.Bold; color: "#ffffff" }
                                Label { width: parent.width; text: banner.modelData.tagline; font.pixelSize: 14; color: Qt.rgba(1, 1, 1, 0.88); wrapMode: Text.WordWrap; elide: Text.ElideNone }
                                Item { width: 1; height: 4 }
                                Row {
                                    spacing: 8
                                    GetButton { pkg: banner.modelData.pkg }
                                    PillButton { text: "Learn More"; primary: false; onClicked: root.show(banner.modelData) }
                                }
                            }
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        spacing: 6
                        Repeater {
                            model: root.banners.length
                            Rectangle {
                                required property int index
                                width: index === hero.current ? 18 : 7
                                height: 7
                                radius: 3.5
                                color: Qt.rgba(1, 1, 1, index === hero.current ? 0.95 : 0.45)
                                Behavior on width { NumberAnimation { duration: 200 } }
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: hero.current = parent.index }
                            }
                        }
                    }
                }

                Flow {
                    visible: !root.query
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.categories
                        Rectangle {
                            required property string modelData
                            readonly property bool on: root.category === modelData
                            width: catLabel.implicitWidth + 26
                            height: 30
                            radius: 15
                            color: on ? (Theme.dark ? "#ffffff" : Theme.accent) : catArea.containsMouse ? Theme.track : Theme.off
                            Label { id: catLabel; anchors.centerIn: parent; text: parent.modelData; font.weight: Font.DemiBold; color: parent.on ? (Theme.dark ? Theme.accentInk : Theme.textOnAccent) : Theme.text }
                            MouseArea { id: catArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.category = parent.modelData }
                        }
                    }
                }
                GridLayout {
                    visible: !root.query
                    Layout.fillWidth: true
                    columns: width > 560 ? 2 : 1
                    columnSpacing: Theme.gap
                    rowSpacing: Theme.gap
                    Repeater {
                        model: root.featured.filter(f => root.category === "All" || f.category === root.category)
                        Glass {
                            id: card
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 92
                            radius: 20
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.show(card.modelData) }
                            AppIcon {
                                id: cardIcon
                                x: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: root.appFor(card.modelData.pkg)?.icon ?? ""
                                glyph: root.glyphs[card.modelData.category] ?? Theme.icons.apps
                            }
                            Column {
                                anchors.left: cardIcon.right
                                anchors.leftMargin: 14
                                anchors.right: cardGet.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Label { width: parent.width; text: card.modelData.name; font.pixelSize: 15; font.weight: Font.DemiBold }
                                Label { width: parent.width; text: card.modelData.about; dim: true; font.pixelSize: 12; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                            }
                            GetButton { id: cardGet; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; pkg: card.modelData.pkg }
                        }
                    }
                }

                Label {
                    visible: root.query !== "" && root.results.length === 0
                    text: root.searching ? "Searching…" : root.searchFailed ? "Searching needs the internet." : `Nothing found for “${root.query}”.`
                    dim: true
                }
                Repeater {
                    model: root.query ? root.results : []
                    Glass {
                        id: hit
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 64
                        radius: 18
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.show(root.featured.find(f => f.pkg === hit.modelData.pkg) ?? { pkg: hit.modelData.pkg, name: hit.modelData.pkg, about: hit.modelData.about, aur: hit.modelData.aur, flatpak: "" })
                        }
                        AppIcon {
                            id: hitIcon
                            x: 14
                            width: 36
                            height: 36
                            anchors.verticalCenter: parent.verticalCenter
                            source: root.appFor(hit.modelData.pkg)?.icon ?? ""
                        }
                        Column {
                            anchors.left: hitIcon.right
                            anchors.leftMargin: 12
                            anchors.right: hitTag.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Label { width: parent.width; text: hit.modelData.pkg; font.weight: Font.DemiBold }
                            Label { width: parent.width; text: hit.modelData.about; dim: true; font.pixelSize: 12 }
                        }
                        Tag {
                            id: hitTag
                            anchors.right: hitGet.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: hit.modelData.aur ? `AUR · ${hit.modelData.votes} votes` : "Arch"
                        }
                        GetButton { id: hitGet; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; pkg: hit.modelData.pkg; aur: hit.modelData.aur }
                    }
                }
                Label {
                    visible: root.query !== "" && root.results.some(r => r.aur)
                    Layout.fillWidth: true
                    text: "AUR apps are shared by Arch users and build on this computer, in a terminal that shows each step."
                    dim: true
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }
        }

        // Installed apps
        Flickable {
            clip: true
            contentHeight: installedList.implicitHeight
            ColumnLayout {
                id: installedList
                width: parent.width
                spacing: 8
                Label { text: root.apps.length === 1 ? "1 app" : `${root.apps.length} apps`; dim: true; bottomPadding: 4 }
                Repeater {
                    model: root.apps
                    Glass {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 60
                        radius: 18
                        AppIcon { id: rowIcon; x: 14; width: 36; height: 36; anchors.verticalCenter: parent.verticalCenter; source: row.modelData.icon }
                        Column {
                            anchors.left: rowIcon.right
                            anchors.leftMargin: 12
                            anchors.right: rowButtons.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Label { width: parent.width; text: row.modelData.name; font.weight: Font.DemiBold }
                            Label { width: parent.width; text: row.modelData.pkg.replace(/^flatpak:/, "Flathub · ").replace(/^deb:/, "Debian · "); dim: true; font.pixelSize: 12 }
                        }
                        Row {
                            id: rowButtons
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            PillButton { text: "Open"; primary: false; onClicked: root.open(row.modelData.id) }
                            PillButton {
                                text: root.busy === row.modelData.pkg ? "Removing…" : "Remove"
                                primary: false
                                enabled: root.busy === ""
                                onClicked: root.remove(row.modelData.pkg)
                            }
                        }
                    }
                }
            }
        }

        // Updates
        Flickable {
            clip: true
            contentHeight: updatesPage.implicitHeight
            ColumnLayout {
                id: updatesPage
                width: parent.width
                spacing: Theme.gap

                SettingsCard {
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        spacing: 14
                        Glyph { text: Theme.icons.download; font.pixelSize: 34; color: Theme.accent }
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                width: parent.width
                                font.pixelSize: 17
                                font.weight: Font.Bold
                                text: root.checking ? "Checking for updates…" : root.checkFailed ? "Couldn't check for updates" : root.updates.length === 1 ? "1 update available" : root.updates.length ? `${root.updates.length} updates available` : "divineOS is up to date"
                            }
                            Label {
                                width: parent.width
                                dim: true
                                font.pixelSize: 12
                                text: root.checkFailed ? "Connect to the internet and check again." : isNaN(root.lastUpgrade.getTime()) ? "Checked every 6 hours." : "Last updated " + Qt.formatDate(root.lastUpgrade, "d MMMM yyyy") + ". Checked every 6 hours."
                            }
                        }
                        PillButton { text: "Check Now"; primary: false; enabled: !root.checking && root.busy === ""; onClicked: root.checkUpdates() }
                        PillButton { visible: root.updates.length > 0; text: root.busy === "upgrade" ? "Updating…" : "Update All"; enabled: root.busy === ""; onClicked: root.upgrade() }
                    }
                }

                SettingsCard {
                    visible: root.updates.length > 0
                    Item { implicitHeight: 6 }
                    Repeater {
                        model: root.updates
                        RowLayout {
                            id: update
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            spacing: 8
                            Label { Layout.fillWidth: true; text: update.modelData.name; font.weight: Font.Medium }
                            Tag { visible: update.modelData.kind !== "repo"; text: ({ aur: "AUR", flatpak: "Flathub", github: "GitHub" })[update.modelData.kind] ?? "" }
                            Label { text: update.modelData.from ? `${update.modelData.from}  →  ${update.modelData.to}` : update.modelData.to; dim: true; font.pixelSize: 12 }
                        }
                    }
                    Label {
                        visible: root.updates.some(u => u.aur)
                        Layout.fillWidth: true
                        topPadding: 6
                        bottomPadding: 6
                        text: "AUR apps rebuild in a terminal after the rest is updated."
                        dim: true
                        font.pixelSize: 12
                    }
                }

                SettingsCard {
                    visible: root.news.length > 0
                    Label { text: "Arch Linux news"; font.weight: Font.DemiBold; topPadding: 8 }
                    Label {
                        Layout.fillWidth: true
                        bottomPadding: 6
                        text: "The rare update that needs a manual step is announced here first."
                        dim: true
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                    Repeater {
                        model: root.news
                        Choice {
                            required property var modelData
                            text: modelData.title
                            detail: modelData.date
                            onPicked: root.openLink(modelData.link)
                        }
                    }
                    Item { implicitHeight: 6 }
                }
            }
        }

        // GitHub: RepoStation builds apps from source in the background
        Flickable {
            clip: true
            contentHeight: githubPage.implicitHeight
            ColumnLayout {
                id: githubPage
                width: parent.width
                spacing: Theme.gap

                Label { text: "Apps from GitHub"; font.pixelSize: 20; font.weight: Font.Bold }
                Label {
                    Layout.fillWidth: true
                    text: "RepoStation builds them on this computer, tuned for its processor. Builds run in the background; View Build Logs shows every step. Building runs the project's own scripts, so get apps from people you trust."
                    dim: true
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                Field {
                    Layout.fillWidth: true
                    icon: Theme.icons.search
                    placeholder: "Search GitHub, then press Enter"
                    onAccepted: if (text.trim()) root.searchGithub(text.trim())
                }
                Label {
                    visible: root.githubSearching || root.githubFailed
                    text: root.githubSearching ? "Searching GitHub…" : "GitHub didn't answer. Check the internet, or wait a minute: GitHub limits how often it can be searched."
                    dim: true
                    font.pixelSize: 12
                }
                Repeater {
                    model: root.githubResults
                    Glass {
                        id: repo
                        required property var modelData
                        readonly property bool has: root.githubInstalled.some(e => e.repo === modelData.repo)
                        Layout.fillWidth: true
                        implicitHeight: 64
                        radius: 18
                        AppIcon { id: repoIcon; x: 14; width: 36; height: 36; anchors.verticalCenter: parent.verticalCenter; glyph: Theme.icons.github }
                        Column {
                            anchors.left: repoIcon.right
                            anchors.leftMargin: 12
                            anchors.right: repoMeta.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Label { width: parent.width; text: repo.modelData.repo; font.weight: Font.DemiBold }
                            Label { width: parent.width; text: repo.modelData.about; dim: true; font.pixelSize: 12 }
                        }
                        Row {
                            id: repoMeta
                            anchors.right: repoGet.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Stars { anchors.verticalCenter: parent.verticalCenter; value: StoreInfo.stars(repo.modelData.stars) }
                            Label { anchors.verticalCenter: parent.verticalCenter; text: StoreInfo.count(repo.modelData.stars); dim: true; font.pixelSize: 12 }
                            Tag { anchors.verticalCenter: parent.verticalCenter; text: repo.modelData.language }
                        }
                        PillButton {
                            id: repoGet
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.busy === repo.modelData.repo ? "Building…" : repo.has ? "Installed" : "Get"
                            primary: !repo.has
                            enabled: !repo.has && root.busy === ""
                            onClicked: root.installGithub(repo.modelData.repo)
                        }
                    }
                }

                Label { visible: root.githubInstalled.length > 0; text: "Installed from GitHub"; font.weight: Font.DemiBold; topPadding: 8 }
                Repeater {
                    model: root.githubInstalled
                    Glass {
                        id: built
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 60
                        radius: 18
                        AppIcon { id: builtIcon; x: 14; width: 36; height: 36; anchors.verticalCenter: parent.verticalCenter; glyph: Theme.icons.github }
                        Column {
                            anchors.left: builtIcon.right
                            anchors.leftMargin: 12
                            anchors.right: builtButtons.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Label { width: parent.width; text: built.modelData.repo; font.weight: Font.DemiBold }
                            Label { width: parent.width; text: `${built.modelData.bins.join(" ") || "no commands"} · built from ${built.modelData.commit}`; dim: true; font.pixelSize: 12 }
                        }
                        Row {
                            id: builtButtons
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            PillButton { text: root.busy === built.modelData.repo ? "Building…" : "Update"; primary: false; enabled: root.busy === ""; onClicked: root.updateGithub(built.modelData.repo) }
                            PillButton { text: "Remove"; primary: false; enabled: root.busy === ""; onClicked: root.removeGithub(built.modelData.repo) }
                        }
                    }
                }
            }
        }

        // An app's page: screenshots, ratings, and which version to install from where
        Flickable {
            clip: true
            contentHeight: appPage.implicitHeight
            ColumnLayout {
                id: appPage
                readonly property var app: root.detail ?? ({ pkg: "", name: "", about: "" })
                readonly property var info: root.info
                readonly property var sources: !info ? [] : [
                    info.arch && { value: "arch", label: `Arch · ${info.arch}` },
                    info.flathub && { value: "flathub", label: `Flathub · ${info.flathub}` },
                    info.aur && { value: "aur", label: `AUR · ${info.aur}` },
                    info.debian && { value: "debian", label: `Debian · ${info.debian}` }
                ].filter(s => s)
                property string source: ""
                onSourcesChanged: source = sources.length ? sources[0].value : ""
                readonly property var installedApp: root.appFor(app.pkg) ?? root.appFor("deb:" + app.pkg) ?? (app.flatpak ? root.appFor("flatpak:" + app.flatpak) : null)
                readonly property bool has: root.installed[app.pkg] === true || root.flatpaks.includes(app.flatpak) || root.debs[app.pkg] !== undefined

                width: parent.width
                spacing: Theme.gap

                PillButton { text: "Back"; primary: false; onClicked: root.page = root.previous }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    AppIcon {
                        implicitWidth: 80
                        implicitHeight: 80
                        source: appPage.installedApp?.icon ?? ""
                        glyph: root.glyphs[appPage.app.category] ?? Theme.icons.apps
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Label { width: parent.width; text: appPage.app.name; font.pixelSize: 24; font.weight: Font.Bold }
                        Label { width: parent.width; text: appPage.app.about; dim: true; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                        Row {
                            spacing: 6
                            visible: appPage.info !== null
                            Stars { anchors.verticalCenter: parent.verticalCenter; visible: !!appPage.info?.rating; value: appPage.info?.rating?.average ?? 0 }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 12
                                dim: true
                                text: appPage.info?.rating ? `${appPage.info.rating.average.toFixed(1)} · ${appPage.info.rating.total} ratings` : appPage.info?.votes ? `${appPage.info.votes} AUR votes` : "No ratings yet"
                            }
                        }
                    }
                    PillButton {
                        text: root.busy !== "" && (root.busy === appPage.app.pkg || root.busy === appPage.app.flatpak) ? "Working…" : appPage.installedApp ? "Open" : appPage.has ? "Installed" : "Get"
                        primary: !appPage.has
                        enabled: appPage.installedApp !== null || (!appPage.has && root.busy === "" && appPage.source !== "")
                        onClicked: appPage.installedApp ? root.open(appPage.installedApp.id) : appPage.source === "flathub" ? root.installFlatpak(appPage.app.flatpak) : appPage.source === "debian" ? root.installDebian(appPage.app.pkg) : root.install(appPage.app.pkg, appPage.source === "aur")
                    }
                }

                RowLayout {
                    visible: appPage.sources.length > 0 && !appPage.has
                    spacing: 12
                    Label { text: "Install from"; dim: true }
                    Segmented { options: appPage.sources; value: appPage.source; onPicked: v => appPage.source = v }
                }
                Label {
                    visible: appPage.source !== "" && !appPage.has
                    Layout.fillWidth: true
                    text: ({
                            arch: "From the Arch repositories: updated with the rest of divineOS.",
                            flathub: "From Flathub: sandboxed, updated separately, a bigger download the first time.",
                            aur: "From the AUR: shared by Arch users and built on this computer, in a terminal.",
                            debian: "From Debian, in a container of its own (Distrobox) so it never mixes with Arch's libraries. Set up once, the first time."
                        })[appPage.source] ?? ""
                    dim: true
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                Label {
                    visible: appPage.info === null || appPage.sources.length === 0
                    text: appPage.info === null ? "Loading…" : "Not available right now. Check the internet and try again."
                    dim: true
                }

                ListView {
                    id: shots
                    visible: count > 0
                    Layout.fillWidth: true
                    implicitHeight: 250
                    orientation: ListView.Horizontal
                    spacing: 12
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: appPage.info?.screenshots ?? []
                    delegate: Rectangle {
                        required property string modelData
                        width: shot.implicitHeight > 0 ? height * shot.implicitWidth / shot.implicitHeight : height * 16 / 9
                        height: ListView.view.height
                        radius: 14
                        color: Theme.off
                        Image {
                            id: shot
                            anchors.fill: parent
                            source: parent.modelData
                            sourceSize.height: 500
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openLink(parent.modelData) }
                    }
                }

                Label {
                    visible: text !== ""
                    Layout.fillWidth: true
                    text: appPage.info?.description ?? ""
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    lineHeight: 1.2
                }
                PillButton {
                    visible: (appPage.info?.homepage ?? "") !== ""
                    text: "Website"
                    primary: false
                    onClicked: root.openLink(appPage.info.homepage)
                }
            }
        }
    }

    // ── What the running job is doing ──
    Glass {
        id: strip
        visible: root.status !== ""
        anchors.left: pages.left
        anchors.right: pages.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        implicitHeight: stripColumn.implicitHeight + 24
        radius: 20

        ColumnLayout {
            id: stripColumn
            x: 16
            y: 12
            width: parent.width - 32
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: root.status }
                PillButton { text: root.showLog ? "Hide" : root.building ? "View Build Logs" : "Details"; primary: false; visible: root.log.length > 0; onClicked: root.showLog = !root.showLog }
            }
            Rectangle { // progress: pacman's (n/total) steps, or a sweep before it counts
                visible: root.busy !== ""
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.track
                clip: true
                Rectangle {
                    height: parent.height
                    radius: 3
                    color: Theme.accent
                    width: root.progress >= 0 ? parent.width * root.progress : parent.width * 0.3
                    Behavior on width { NumberAnimation { duration: 200 } }
                    SequentialAnimation on x {
                        running: root.busy !== "" && root.progress < 0
                        loops: Animation.Infinite
                        NumberAnimation { from: -0.3 * stripColumn.width; to: stripColumn.width; duration: 1400 }
                    }
                    Binding on x { when: root.progress >= 0; value: 0 }
                }
            }
            ListView {
                visible: root.showLog
                Layout.fillWidth: true
                implicitHeight: 150
                clip: true
                model: root.log
                onCountChanged: positionViewAtEnd()
                delegate: Text {
                    required property string modelData
                    width: ListView.view.width
                    text: modelData
                    font.family: "monospace"
                    font.pixelSize: 11
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
            }
        }
    }
}
