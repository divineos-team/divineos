import QtQuick
import QtQuick.Layouts

// The installer's view: a sidebar of steps and one page each. shell.qml runs the backend and
// feeds the machine (`info`), partition measurements (`shrink`) and the install's progress in.
Item {
    id: root

    property var info: null // backend probe: { uefi, online, disks[], timezones[], locales[] }
    property string probeError: ""
    property bool gpartedOpen: false
    property var shrink: ({}) // backend shrink-info for one partition: { part, busy, keep, error }
    property bool installing: false
    property bool finished: false
    property int percent: 0
    property string stepText: ""
    property string error: ""
    property var log: [] // the backend's output, newest last

    signal reprobe
    signal measure(string part)
    signal openGparted
    signal install(var settings)
    signal restart

    property int page: 0 // welcome, disk, region, account, summary, install

    // Disk
    property string mode: "erase" // erase | alongside | replace | manual
    property string disk: ""
    property string part: "" // replace: the partition; alongside: the one to shrink ("" = free space); manual: root
    property string esp: "" // manual, UEFI
    property real keepSize: 0 // alongside: what the shrunk partition keeps, in bytes
    property bool encrypt: false
    property string passphrase: ""
    property string passphrase2: ""

    // Region
    property string timezone: "UTC"
    property string locale: "en_US.UTF-8"
    property int keyboard: 0

    // Account
    property string fullname: ""
    property string user: ""
    property bool userEdited: false
    property string hostname: "divineos"
    property string password: ""
    property string password2: ""

    readonly property real mib: 1048576
    readonly property real gib: 1073741824
    readonly property real minRoot: 20 * gib
    readonly property var bootTypes: ["c12a7328-f81f-11d2-ba4b-00a0c93ec93b", "21686148-6449-6e6f-744e-656564454649", "0xef"]
    readonly property var espTypes: ["c12a7328-f81f-11d2-ba4b-00a0c93ec93b", "0xef"]
    readonly property var shrinkable: ["ntfs", "ext4", "ext3", "ext2"]
    // console keymap and Hyprland (xkb) layout; non-Latin layouts get US as a second one
    readonly property var keyboards: [
        { label: "English (US)", keymap: "us", xkb: "us" },
        { label: "English (UK)", keymap: "uk", xkb: "gb" },
        { label: "German", keymap: "de-latin1", xkb: "de" },
        { label: "German (Switzerland)", keymap: "de_CH-latin1", xkb: "ch" },
        { label: "French", keymap: "fr", xkb: "fr" },
        { label: "French (Belgium)", keymap: "be-latin1", xkb: "be" },
        { label: "Spanish", keymap: "es", xkb: "es" },
        { label: "Spanish (Latin America)", keymap: "la-latin1", xkb: "latam" },
        { label: "Portuguese", keymap: "pt-latin1", xkb: "pt" },
        { label: "Portuguese (Brazil)", keymap: "br-abnt2", xkb: "br" },
        { label: "Italian", keymap: "it", xkb: "it" },
        { label: "Dutch", keymap: "nl", xkb: "nl" },
        { label: "Danish", keymap: "dk", xkb: "dk" },
        { label: "Norwegian", keymap: "no", xkb: "no" },
        { label: "Swedish", keymap: "sv-latin1", xkb: "se" },
        { label: "Finnish", keymap: "fi", xkb: "fi" },
        { label: "Polish", keymap: "pl", xkb: "pl" },
        { label: "Czech", keymap: "cz-qwertz", xkb: "cz" },
        { label: "Hungarian", keymap: "hu", xkb: "hu" },
        { label: "Romanian", keymap: "ro", xkb: "ro" },
        { label: "Turkish", keymap: "trq", xkb: "tr" },
        { label: "Greek", keymap: "gr", xkb: "us,gr", options: "grp:alt_shift_toggle" },
        { label: "Russian", keymap: "ru", xkb: "us,ru", options: "grp:alt_shift_toggle" },
        { label: "Ukrainian", keymap: "ua", xkb: "us,ua", options: "grp:alt_shift_toggle" },
        { label: "Georgian", keymap: "us", xkb: "us,ge", options: "grp:alt_shift_toggle" },
        { label: "Japanese", keymap: "jp106", xkb: "jp" },
        { label: "Korean", keymap: "kr", xkb: "kr" }
    ]

    readonly property var disks: info?.disks ?? []
    readonly property var diskObj: disks.find(d => d.path === disk) ?? null
    readonly property var allParts: disks.reduce((all, d) => all.concat(d.parts.map(p => Object.assign({ disk: d.path }, p))), [])
    readonly property var partObj: allParts.find(p => p.path === part) ?? null
    readonly property bool diskHasEsp: (diskObj?.parts ?? []).some(p => espTypes.includes(p.parttype))
    readonly property real need: minRoot + (info?.uefi && !diskHasEsp ? 512 * mib : 0) // alongside
    readonly property real keepMax: partObj ? Math.floor((partObj.size - need) / mib) * mib : 0
    readonly property bool measured: shrink.part === part && !shrink.busy && !shrink.error

    onModeChanged: {
        part = "";
        esp = "";
    }
    onDiskChanged: part = ""
    onPartChanged: if (mode === "alongside" && part)
        measure(part)
    onShrinkChanged: if (shrink.part === part && shrink.keep) // not `measured`: it may not have updated yet
        keepSize = Math.round((shrink.keep + keepMax) / 2 / mib) * mib
    onFullnameChanged: if (!userEdited)
        user = (fullname.trim().split(/\s+/)[0] ?? "").toLowerCase().replace(/[^a-z0-9_-]/g, "")

    function gb(bytes) {
        const g = bytes / 1e9;
        return (g >= 100 ? g.toFixed(0) : g.toFixed(1)) + " GB";
    }
    function diskName(d) {
        return `${d.model || d.path.slice(5)} · ${gb(d.size)}`;
    }
    function partName(p) {
        return `${p.path.slice(5)} · ${p.label || p.typename || p.fstype || "empty"} · ${gb(p.size)}`;
    }
    function systemIcon(d) {
        return d.systems.some(s => /windows/i.test(s)) ? Theme.icons.windows : d.systems.length ? Theme.icons.linux : Theme.icons.disk;
    }

    readonly property string problem: {
        switch (page) {
        case 0:
            if (probeError)
                return probeError;
            return !info ? "Looking at this computer…" : "";
        case 1:
            return diskProblem;
        case 3:
            return accountProblem;
        }
        return "";
    }
    readonly property string diskProblem: {
        if (gpartedOpen)
            return "Close GParted to continue.";
        switch (mode) {
        case "erase":
            if (!diskObj)
                return "Choose a disk.";
            if (diskObj.size < minRoot + gib)
                return "This disk is too small: divineOS needs 21 GB.";
            if (encrypt && passphrase.length < 8)
                return "The passphrase needs at least 8 characters.";
            if (encrypt && passphrase !== passphrase2)
                return "The passphrases don't match.";
            return "";
        case "alongside":
            if (!diskObj)
                return "Choose a disk.";
            if (!part)
                return diskObj.free >= need ? "" : "Choose a partition to make room in.";
            if (shrink.part !== part || shrink.busy)
                return "Measuring the partition…";
            if (shrink.error)
                return shrink.error;
            return shrink.keep > keepMax ? "This partition is too full to make room for divineOS." : "";
        case "replace":
            return partObj ? "" : "Choose a partition.";
        case "manual":
            if (!partObj)
                return "Choose the partition for divineOS.";
            return info?.uefi && !esp ? "Choose the EFI system partition." : "";
        }
        return "";
    }
    readonly property string accountProblem: {
        if (/[:,]/.test(fullname))
            return "Your name can't contain : or ,.";
        if (!/^[a-z_][a-z0-9_-]{0,31}$/.test(user))
            return "The username must start with a lowercase letter and have only a-z, 0-9, - and _.";
        if (!/^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/.test(hostname))
            return "The computer name can only have letters, digits and dashes.";
        if (!password)
            return "Choose a password.";
        return password === password2 ? "" : "The passwords don't match.";
    }

    // What Install does, in words, for the summary.
    readonly property var plan: {
        switch (mode) {
        case "erase":
            return diskObj ? [`Erase ${diskName(diskObj)} — everything on it is deleted${diskObj.systems.length ? ", including " + diskObj.systems.join(", ") : ""}`, encrypt ? "Encrypt divineOS with your passphrase" : ""] : [];
        case "alongside":
            if (!diskObj)
                return [];
            return partObj ? [`Shrink ${partName(partObj)} to ${gb(keepSize)}`, `Install divineOS in the ${gb(partObj.size - keepSize)} this frees`] : [`Install divineOS in the free space on ${diskName(diskObj)} (${gb(diskObj.free)})`];
        case "replace":
            return partObj ? [`Erase ${partName(partObj)} and install divineOS on it`] : [];
        case "manual":
            return partObj ? [`Format ${partName(partObj)} for divineOS`, esp ? `Boot from ${esp.slice(5)}` : ""] : [];
        }
        return [];
    }

    function settings() {
        const kb = keyboards[keyboard];
        return {
            mode,
            disk: mode === "erase" || mode === "alongside" ? disk : "",
            part: mode === "replace" ? part : "",
            shrink: mode === "alongside" && part ? { part, size: keepSize } : null,
            root: mode === "manual" ? part : "",
            esp: mode === "manual" ? esp : "",
            encrypt: mode === "erase" && encrypt,
            passphrase: mode === "erase" && encrypt ? passphrase : "",
            hostname, fullname, user, password, timezone, locale,
            keymap: kb.keymap,
            xkb: kb.xkb,
            xkb_options: kb.options ?? ""
        };
    }
    function next() {
        if (page === 4) {
            page = 5;
            install(settings());
        } else {
            page++;
        }
    }

    implicitWidth: 1000
    implicitHeight: 660

    // ── Building blocks ──

    component Card: Glass {
        default property alias rows: column.data
        Layout.fillWidth: true
        implicitHeight: column.implicitHeight + 28
        radius: 20
        ColumnLayout {
            id: column
            x: 18
            y: 14
            width: parent.width - 36
            spacing: 6
        }
    }

    // A selectable row: icon, title, optional detail.
    component Choice: Rectangle {
        id: choice
        property string icon
        property string text
        property string detail
        property bool on
        signal picked

        Layout.fillWidth: true
        implicitHeight: detail ? 50 : 38
        radius: 12
        color: on ? Theme.accent : hover.containsMouse ? Theme.hover : "transparent"
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            width: parent.width - 52
            spacing: 10
            Glyph { visible: choice.icon !== ""; text: choice.icon; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter; color: choice.on ? "#ffffff" : Theme.text }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30
                Label { width: parent.width; text: choice.text; font.weight: Font.Medium; color: choice.on ? "#ffffff" : Theme.text }
                Label { width: parent.width; visible: choice.detail !== ""; text: choice.detail; font.pixelSize: 12; color: choice.on ? Qt.rgba(1, 1, 1, 0.8) : Theme.textDim }
            }
        }
        Glyph { visible: choice.on; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: Theme.icons.check; color: "#ffffff"; font.pixelSize: 16 }
        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: choice.picked() }
    }

    // A titled text box.
    component Field: Column {
        id: field
        property string title
        property alias text: input.text
        property bool secret: false
        property string placeholder
        signal edited

        Layout.fillWidth: true
        Layout.preferredWidth: 1 // side by side, fields share the row evenly
        spacing: 6
        Label { text: field.title; font.weight: Font.DemiBold; visible: field.title !== "" }
        Rectangle {
            width: parent.width
            height: 36
            radius: 10
            color: Theme.off
            border.width: input.activeFocus ? 2 : 0
            border.color: Theme.accent
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                echoMode: field.secret ? TextInput.Password : TextInput.Normal
                passwordCharacter: "●"
                font.family: Theme.font
                font.pixelSize: 14
                color: Theme.text
                selectionColor: Theme.accent
                selectByMouse: true
                clip: true
                onTextEdited: field.edited()
                Label { visible: !input.text; anchors.verticalCenter: parent.verticalCenter; text: field.placeholder; dim: true; font.pixelSize: 14 }
            }
        }
    }

    component Button: Rectangle {
        id: button
        property string text
        property string kind: "primary" // primary | danger | plain
        property bool active: true
        signal clicked

        implicitWidth: label.implicitWidth + 40
        implicitHeight: 38
        radius: height / 2
        opacity: active ? 1 : 0.4
        color: kind === "plain" ? (press.containsMouse && active ? Theme.hover : Theme.off) : kind === "danger" ? Theme.danger : Theme.accent
        scale: press.pressed && active ? 0.96 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.001 } }
        Label { id: label; anchors.centerIn: parent; text: button.text; font.weight: Font.DemiBold; color: button.kind === "plain" ? Theme.text : "#ffffff" }
        MouseArea { id: press; anchors.fill: parent; hoverEnabled: true; onClicked: if (button.active) button.clicked() }
    }

    // A list with a search box above it (time zones, languages).
    component Picker: ColumnLayout {
        id: picker
        property string title
        property string icon
        property var items: []
        property string value
        property string filter: ""
        property bool spaces: false // show "_" as spaces (time zones)
        signal picked(string value)

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        spacing: 8
        Row {
            spacing: 8
            Glyph { text: picker.icon; font.pixelSize: 18 }
            Label { text: picker.title; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
        }
        Label { text: picker.spaces ? picker.value.replace(/_/g, " ") : picker.value; dim: true; Layout.fillWidth: true }
        Field { placeholder: "Search"; onEdited: picker.filter = text.toLowerCase() }
        Glass {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                spacing: 2
                model: picker.items.filter(i => i.toLowerCase().replace(/_/g, " ").includes(picker.filter))
                currentIndex: model.indexOf(picker.value)
                Component.onCompleted: positionViewAtIndex(currentIndex, ListView.Center)
                delegate: Choice {
                    required property string modelData
                    width: ListView.view.width
                    text: picker.spaces ? modelData.replace(/_/g, " ") : modelData
                    on: modelData === picker.value
                    onPicked: picker.picked(modelData)
                }
            }
        }
    }

    // ── Sidebar ──
    Column {
        id: sidebar
        x: 18
        y: 18
        width: 200
        spacing: 4

        Row {
            leftPadding: 8
            bottomPadding: 14
            spacing: 10
            Image { source: "file:///usr/share/icons/hicolor/scalable/apps/divineos.svg"; sourceSize: Qt.size(28, 28); anchors.verticalCenter: parent.verticalCenter }
            Label { text: "Install divineOS"; font.pixelSize: 18; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
        }
        Repeater {
            model: [
                { icon: Theme.icons.install, label: "Welcome" },
                { icon: Theme.icons.disk, label: "Disk" },
                { icon: Theme.icons.region, label: "Region" },
                { icon: Theme.icons.account, label: "Account" },
                { icon: Theme.icons.summary, label: "Summary" },
                { icon: root.finished ? Theme.icons.done : Theme.icons.install, label: root.finished ? "Done" : "Install" }
            ]
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool on: root.page === index
                readonly property bool reachable: index < root.page && root.page < 5
                width: sidebar.width
                height: 40
                radius: 14
                color: on ? Theme.accent : navHover.containsMouse && reachable ? Theme.hover : "transparent"
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    spacing: 10
                    opacity: parent.on || parent.index < root.page ? 1 : 0.5
                    Glyph { text: modelData.icon; font.pixelSize: 18; color: parent.parent.on ? "#ffffff" : Theme.text }
                    Label { text: modelData.label; font.weight: Font.Medium; color: parent.parent.on ? "#ffffff" : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: navHover; anchors.fill: parent; hoverEnabled: true; onClicked: if (parent.reachable) root.page = parent.index }
            }
        }
    }

    // ── Pages ──
    StackLayout {
        id: pages
        anchors.left: sidebar.right
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: nav.top
        anchors.margins: 18
        currentIndex: root.page

        // Welcome
        ColumnLayout {
            spacing: 16
            Item { Layout.fillHeight: true }
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "file:///usr/share/icons/hicolor/scalable/apps/divineos.svg"
                sourceSize: Qt.size(96, 96)
            }
            Label { Layout.alignment: Qt.AlignHCenter; text: "Welcome to divineOS"; font.pixelSize: 28; font.weight: Font.Bold }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 520
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                dim: true
                font.pixelSize: 14
                text: "This puts divineOS on this computer's disk: on its own, next to another system, or in place of one partition. Nothing changes until you press Install on the last step."
            }
            Item { implicitHeight: 8 }
            Card {
                Layout.maximumWidth: 520
                Layout.alignment: Qt.AlignHCenter
                Choice {
                    icon: root.info?.online ? Theme.icons.wifi : Theme.icons.wifiOff
                    text: !root.info ? "Checking the connection…" : root.info.online ? "Connected to the internet" : "Not connected"
                    detail: root.info && !root.info.online ? "Not needed: divineOS installs from this USB. Updates and some drivers download later." : ""
                    on: false
                }
                Choice {
                    icon: Theme.icons.disk
                    text: !root.info ? "Reading disks…" : root.disks.length === 1 ? "1 disk found" : `${root.disks.length} disks found`
                    detail: root.info ? (root.info.uefi ? "UEFI firmware" : "BIOS (legacy) firmware") : ""
                    on: false
                }
            }
            Item { Layout.fillHeight: true }
        }

        // Disk
        Flickable {
            clip: true
            contentHeight: diskPage.implicitHeight
            ColumnLayout {
                id: diskPage
                width: parent.width
                spacing: 12

                Label { text: "Where should divineOS go?"; font.pixelSize: 22; font.weight: Font.Bold }
                RowLayout {
                    spacing: 10
                    Repeater {
                        model: [
                            { mode: "erase", icon: Theme.icons.erase, title: "Erase a disk", hint: "divineOS gets the whole disk" },
                            { mode: "alongside", icon: Theme.icons.alongside, title: "Alongside", hint: "Split a disk with Windows or Linux" },
                            { mode: "replace", icon: Theme.icons.replace, title: "Replace a partition", hint: "Reuse one partition" },
                            { mode: "manual", icon: Theme.icons.manual, title: "Manual", hint: "Partition with GParted" }
                        ]
                        Rectangle {
                            required property var modelData
                            readonly property bool on: root.mode === modelData.mode
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 104
                            radius: 18
                            color: on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : tileHover.containsMouse ? Theme.hover : Theme.glass
                            border.width: on ? 2 : 1
                            border.color: on ? Theme.accent : Theme.rim
                            Column {
                                x: 14
                                y: 14
                                width: parent.width - 28
                                spacing: 4
                                Glyph { text: modelData.icon; font.pixelSize: 26; color: parent.parent.on ? Theme.accent : Theme.text; horizontalAlignment: Text.AlignLeft }
                                Label { width: parent.width; text: modelData.title; font.weight: Font.DemiBold; topPadding: 4 }
                                Label { width: parent.width; text: modelData.hint; dim: true; font.pixelSize: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone; maximumLineCount: 2 }
                            }
                            MouseArea { id: tileHover; anchors.fill: parent; hoverEnabled: true; onClicked: root.mode = modelData.mode }
                        }
                    }
                }

                // Erase / alongside: which disk
                Card {
                    visible: root.mode === "erase" || root.mode === "alongside"
                    Label { text: "Disk"; font.weight: Font.DemiBold }
                    Label { visible: root.info !== null && root.disks.length === 0; text: "No disks found."; dim: true }
                    Repeater {
                        model: root.disks
                        Choice {
                            required property var modelData
                            icon: root.systemIcon(modelData)
                            text: root.diskName(modelData)
                            detail: modelData.systems.length ? modelData.systems.join(", ") : modelData.parts.length === 1 ? "1 partition" : modelData.parts.length ? `${modelData.parts.length} partitions` : "Empty"
                            on: root.disk === modelData.path
                            onPicked: root.disk = modelData.path
                        }
                    }
                }

                // Erase: what happens, and encryption
                Card {
                    visible: root.mode === "erase" && root.diskObj !== null
                    Row {
                        spacing: 8
                        Glyph { text: Theme.icons.alert; color: Theme.danger; font.pixelSize: 18 }
                        Label { text: `Everything on ${root.diskObj?.model || root.disk.slice(5)} will be deleted.`; color: Theme.danger; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Choice {
                        icon: Theme.icons.lock
                        text: "Encrypt divineOS"
                        detail: "Asks for a passphrase every time the computer starts. Without it, nobody can read the disk."
                        on: root.encrypt
                        onPicked: root.encrypt = !root.encrypt
                    }
                    RowLayout {
                        visible: root.encrypt
                        spacing: 12
                        Field { title: "Passphrase"; secret: true; text: root.passphrase; onEdited: root.passphrase = text }
                        Field { title: "Confirm passphrase"; secret: true; text: root.passphrase2; onEdited: root.passphrase2 = text }
                    }
                }

                // Alongside: where the room comes from, and the split
                Card {
                    visible: root.mode === "alongside" && root.diskObj !== null
                    Label { text: "Make room in"; font.weight: Font.DemiBold }
                    Choice {
                        visible: (root.diskObj?.free ?? 0) >= root.need
                        icon: Theme.icons.disk
                        text: `Free space · ${root.gb(root.diskObj?.free ?? 0)}`
                        detail: "Space no partition uses yet; nothing gets resized"
                        on: root.part === ""
                        onPicked: root.part = ""
                    }
                    Repeater {
                        model: (root.diskObj?.parts ?? []).filter(p => root.shrinkable.includes(p.fstype) && p.size > root.need + root.gib)
                        Choice {
                            required property var modelData
                            icon: modelData.fstype === "ntfs" ? Theme.icons.windows : Theme.icons.linux
                            text: root.partName(modelData)
                            detail: "Shrink it to make room"
                            on: root.part === modelData.path
                            onPicked: root.part = modelData.path
                        }
                    }
                    Label {
                        visible: root.mode === "alongside" && root.diskObj !== null && (root.diskObj?.free ?? 0) < root.need && !root.diskObj.parts.some(p => root.shrinkable.includes(p.fstype))
                        text: "Nothing on this disk can be shrunk here. Use Manual to make room with GParted."
                        dim: true
                    }

                    // The split: drag the divider
                    Item {
                        visible: root.part !== "" && root.measured && root.shrink.keep <= root.keepMax
                        Layout.fillWidth: true
                        implicitHeight: 86
                        Rectangle {
                            id: bar
                            y: 8
                            width: parent.width
                            height: 44
                            radius: 12
                            color: Theme.accent
                            clip: true
                            readonly property real total: root.partObj?.size ?? 1
                            Rectangle {
                                width: bar.width * root.keepSize / bar.total
                                height: parent.height
                                radius: 12
                                color: Theme.other
                                Label { anchors.centerIn: parent; text: `${root.partObj?.label || root.partObj?.fstype || ""} · ${root.gb(root.keepSize)}`; color: "#ffffff"; font.weight: Font.DemiBold }
                            }
                            Label {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: `divineOS · ${root.gb(bar.total - root.keepSize)}`
                                color: "#ffffff"
                                font.weight: Font.DemiBold
                            }
                            Rectangle { x: bar.width * root.keepSize / bar.total - 2; width: 4; height: parent.height; color: "#ffffff" }
                            MouseArea {
                                anchors.fill: parent
                                function set(x) {
                                    const want = x / width * bar.total;
                                    root.keepSize = Math.round(Math.max(root.shrink.keep, Math.min(root.keepMax, want)) / root.mib) * root.mib;
                                }
                                onPressed: mouse => set(mouse.x)
                                onPositionChanged: mouse => set(mouse.x)
                            }
                        }
                        Label {
                            anchors.top: bar.bottom
                            anchors.topMargin: 8
                            text: "Drag to choose how much space each system gets. Back up anything important first."
                            dim: true
                            font.pixelSize: 12
                        }
                    }
                }

                // Replace: any partition big enough
                Card {
                    visible: root.mode === "replace"
                    Label { text: "Partition to replace"; font.weight: Font.DemiBold }
                    Repeater {
                        model: root.allParts.filter(p => !root.bootTypes.includes(p.parttype) && p.size >= root.minRoot)
                        Choice {
                            required property var modelData
                            icon: modelData.fstype === "ntfs" ? Theme.icons.windows : Theme.icons.disk
                            text: root.partName(modelData)
                            detail: root.diskName(root.disks.find(d => d.path === modelData.disk))
                            on: root.part === modelData.path
                            onPicked: root.part = modelData.path
                        }
                    }
                    Row {
                        visible: root.partObj !== null
                        spacing: 8
                        Glyph { text: Theme.icons.alert; color: Theme.danger; font.pixelSize: 18 }
                        Label { text: `Everything on ${root.part.slice(5)} will be deleted.`; color: Theme.danger; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                // Manual: GParted, then pick the partitions
                Card {
                    visible: root.mode === "manual"
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                            dim: true
                            text: root.info?.uefi ? "Make a partition of at least 20 GB for divineOS. It also needs an EFI system partition (FAT32, flag \"esp\"); reuse Windows' if there is one." : "Make a partition of at least 20 GB for divineOS. On a GPT disk, also add a 1 MB unformatted partition with the \"bios_grub\" flag."
                        }
                        Button { text: root.gpartedOpen ? "GParted is open…" : "Open GParted"; kind: "plain"; active: !root.gpartedOpen; onClicked: root.openGparted() }
                    }
                    Label { text: "divineOS partition (formatted as Btrfs)"; font.weight: Font.DemiBold; topPadding: 6 }
                    Repeater {
                        model: root.allParts.filter(p => !root.bootTypes.includes(p.parttype) && p.size >= root.minRoot)
                        Choice {
                            required property var modelData
                            icon: Theme.icons.disk
                            text: root.partName(modelData)
                            on: root.part === modelData.path
                            onPicked: root.part = modelData.path
                        }
                    }
                    Label { visible: root.info?.uefi ?? false; text: "EFI system partition (kept as it is)"; font.weight: Font.DemiBold; topPadding: 6 }
                    Repeater {
                        model: root.info?.uefi ? root.allParts.filter(p => root.espTypes.includes(p.parttype) || p.fstype === "vfat") : []
                        Choice {
                            required property var modelData
                            icon: Theme.icons.disk
                            text: root.partName(modelData)
                            on: root.esp === modelData.path
                            onPicked: root.esp = modelData.path
                        }
                    }
                }
            }
        }

        // Region
        ColumnLayout {
            spacing: 12
            Label { text: "Region"; font.pixelSize: 22; font.weight: Font.Bold }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14
                Picker {
                    title: "Time zone"
                    icon: Theme.icons.clock
                    spaces: true
                    items: root.info?.timezones ?? ["UTC"]
                    value: root.timezone
                    onPicked: v => root.timezone = v
                }
                Picker {
                    title: "Language"
                    icon: Theme.icons.language
                    items: root.info?.locales ?? ["en_US.UTF-8"]
                    value: root.locale
                    onPicked: v => root.locale = v
                }
                Picker {
                    title: "Keyboard"
                    icon: Theme.icons.keyboard
                    items: root.keyboards.map(k => k.label)
                    value: root.keyboards[root.keyboard].label
                    onPicked: v => root.keyboard = root.keyboards.findIndex(k => k.label === v)
                }
            }
        }

        // Account
        Flickable {
            clip: true
            contentHeight: accountPage.implicitHeight
            ColumnLayout {
                id: accountPage
                width: Math.min(parent.width, 560)
                spacing: 12
                Label { text: "Your account"; font.pixelSize: 22; font.weight: Font.Bold }
                Card {
                    Field { title: "Your name"; placeholder: "Ana Lopez"; text: root.fullname; onEdited: root.fullname = text }
                    Field {
                        title: "Username"
                        placeholder: "ana"
                        text: root.user
                        onEdited: {
                            root.userEdited = true;
                            root.user = text;
                        }
                    }
                    Field { title: "Computer name"; text: root.hostname; onEdited: root.hostname = text }
                }
                Card {
                    Field { title: "Password"; secret: true; text: root.password; onEdited: root.password = text }
                    Field { title: "Confirm password"; secret: true; text: root.password2; onEdited: root.password2 = text }
                    Label { text: "You sign in with it, and Settings and package installs ask for it."; dim: true; font.pixelSize: 12; topPadding: 2 }
                }
            }
        }

        // Summary
        Flickable {
            clip: true
            contentHeight: summaryPage.implicitHeight
            ColumnLayout {
                id: summaryPage
                width: parent.width
                spacing: 12
                Label { text: "Ready to install"; font.pixelSize: 22; font.weight: Font.Bold }
                Card {
                    Label { text: "Disk"; font.weight: Font.DemiBold }
                    Repeater {
                        model: root.plan.filter(s => s)
                        Label {
                            required property string modelData
                            Layout.fillWidth: true
                            text: "•  " + modelData
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                        }
                    }
                }
                Card {
                    Label { text: "System"; font.weight: Font.DemiBold }
                    Label { text: `•  ${root.fullname || root.user} (${root.user}) on ${root.hostname}` }
                    Label { text: `•  ${root.timezone.replace(/_/g, " ")} · ${root.locale} · ${root.keyboards[root.keyboard].label} keyboard` }
                }
                Row {
                    spacing: 8
                    Glyph { text: Theme.icons.alert; color: Theme.danger; font.pixelSize: 18 }
                    Label { text: "Install starts changing the disk right away, and it can't be undone."; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        // Install
        ColumnLayout {
            spacing: 14
            Label {
                text: root.finished ? "divineOS is installed" : root.error ? "The install didn't finish" : "Installing divineOS"
                font.pixelSize: 22
                font.weight: Font.Bold
            }
            Label {
                Layout.fillWidth: true
                text: root.finished ? "Restart, take out the install medium when the screen goes dark, and sign in as " + root.user + "." : root.error || root.stepText || "Starting…"
                color: root.error ? Theme.danger : Theme.text
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Theme.off
                Rectangle {
                    width: parent.width * (root.finished ? 1 : root.percent / 100)
                    height: parent.height
                    radius: 4
                    color: root.error ? Theme.danger : root.finished ? Theme.good : Theme.accent
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                }
            }
            Glass {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ListView {
                    id: logView
                    anchors.fill: parent
                    anchors.margins: 12
                    clip: true
                    model: root.log
                    onCountChanged: positionViewAtEnd()
                    delegate: Text {
                        required property string modelData
                        width: ListView.view.width
                        text: modelData
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ── Back / Continue ──
    RowLayout {
        id: nav
        anchors.left: sidebar.right
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        spacing: 10

        Label {
            Layout.fillWidth: true
            text: root.problem
            dim: true
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            maximumLineCount: 2
        }
        Button {
            visible: root.page > 0 && root.page < 5
            text: "Back"
            kind: "plain"
            onClicked: root.page--
        }
        Button {
            visible: root.page < 5
            text: root.page === 4 ? "Install" : "Continue"
            kind: root.page === 4 && root.mode !== "alongside" ? "danger" : "primary"
            active: root.problem === ""
            onClicked: root.next()
        }
        Button {
            visible: root.page === 5 && root.error !== ""
            text: "Back to Disk"
            kind: "plain"
            onClicked: {
                root.error = "";
                root.page = 1;
                root.reprobe();
            }
        }
        Button {
            visible: root.page === 5 && root.finished
            text: "Restart"
            onClicked: root.restart()
        }
    }
}
