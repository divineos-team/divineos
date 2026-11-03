import QtQuick
import QtQuick.Layouts
import "Disks.js" as Disks

// Settings > Disks (devine-disks): every drive with its partitions, mounting them, formatting a
// partition, erasing a whole drive, and writing a disc image (a divineOS ISO, say) to a USB stick.
// The disk holding the running system is never offered; /usr/lib/devine-tweaks/disks checks again.
Flickable {
    id: page

    required property var settings
    // The confirmation open below a drive: { disk, action: erase|format|write, part?, fs, label, image }
    property var pending: null
    readonly property var colors: ["#0A84FF", "#30D158", "#FF9F0A", "#BF5AF2", "#40C8E0", "#FF375F"]

    function ask(disk, action, part) {
        pending = { disk, action, part: part ?? "", fs: "exfat", label: "", image: page.settings.images[0]?.path ?? "" };
    }
    function edit(change) {
        pending = Object.assign({}, pending, change);
    }

    clip: true
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        Repeater {
            model: page.settings.disks
            SettingsCard {
                id: card
                required property var modelData
                readonly property var disk: modelData
                readonly property bool open: page.pending?.disk === disk.path
                readonly property bool safe: !disk.system && !disk.readOnly

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    spacing: 12
                    Glyph { text: card.disk.removable ? Theme.icons.usbDrive : Theme.icons.disk; font.pixelSize: 26 }
                    Column {
                        Layout.fillWidth: true
                        Label { width: parent.width; text: card.disk.name; font.weight: Font.DemiBold }
                        Label {
                            width: parent.width
                            text: [Disks.size(card.disk.size), card.disk.path, card.disk.system ? "divineOS runs from this disk" : card.disk.readOnly ? "Read-only" : ""].filter(t => t).join(" · ")
                            dim: true
                            font.pixelSize: 12
                        }
                    }
                    PillButton { visible: card.safe; enabled: !page.settings.diskBusy; text: "Erase…"; primary: false; onClicked: page.ask(card.disk.path, "erase") }
                    PillButton { visible: card.safe; enabled: !page.settings.diskBusy; text: "Write Image…"; primary: false; onClicked: page.ask(card.disk.path, "write") }
                }

                // The partitions to scale, free space left grey.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    implicitHeight: 10
                    radius: 5
                    color: Theme.off
                    clip: true
                    Row {
                        anchors.fill: parent
                        spacing: 2
                        Repeater {
                            model: card.disk.parts
                            Rectangle {
                                required property var modelData
                                required property int index
                                width: Math.max(3, parent.width * modelData.size / card.disk.size - 2)
                                height: parent.height
                                color: page.colors[index % page.colors.length]
                            }
                        }
                    }
                }

                Repeater {
                    model: card.disk.parts
                    SettingRow {
                        id: part
                        required property var modelData
                        required property int index
                        readonly property bool mountable: !!modelData.fstype && !["swap", "crypto_LUKS", "LVM2_member"].includes(modelData.fstype)
                        title: modelData.label || Disks.fsName(modelData.fstype)
                        hint: [Disks.size(modelData.size), Disks.fsName(modelData.fstype), modelData.mounts.join(", ") || "Not mounted"].join(" · ")
                        Row {
                            spacing: 8
                            Rectangle { width: 10; height: 10; radius: 5; anchors.verticalCenter: parent.verticalCenter; color: page.colors[part.index % page.colors.length] }
                            PillButton {
                                visible: part.mountable && !part.modelData.system
                                enabled: !page.settings.diskBusy
                                text: part.modelData.mounts.length ? "Unmount" : "Mount"
                                primary: false
                                onClicked: page.settings.mountPart(part.modelData.path, !part.modelData.mounts.length)
                            }
                            PillButton {
                                visible: card.safe
                                enabled: !page.settings.diskBusy
                                text: "Format…"
                                primary: false
                                onClicked: page.ask(card.disk.path, "format", part.modelData.path)
                            }
                        }
                    }
                }

                // Erase or format: the filesystem and a name.
                ColumnLayout {
                    visible: card.open && page.pending.action !== "write"
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 8
                    Label { text: page.pending?.action === "format" ? `Format ${page.pending.part}` : `Erase ${card.disk.name}`; font.weight: Font.DemiBold }
                    Segmented {
                        options: Disks.filesystems.map(f => ({ label: f.label, value: f.value }))
                        value: page.pending?.fs ?? "exfat"
                        onPicked: v => page.edit({ fs: v })
                    }
                    Label { text: Disks.filesystems.find(f => f.value === page.pending?.fs)?.hint ?? ""; dim: true; font.pixelSize: 12 }
                    Field {
                        id: name
                        Layout.preferredWidth: 240
                        placeholder: "Name (optional)"
                        onVisibleChanged: if (visible) text = ""
                        onTextChanged: page.edit({ label: text.trim() })
                    }
                }

                // Write an image: one from Downloads, or any file by its path.
                ColumnLayout {
                    visible: card.open && page.pending.action === "write"
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 4
                    Label { text: `Write a disc image to ${card.disk.name}`; font.weight: Font.DemiBold }
                    Label { visible: !page.settings.images.length; text: "No .iso or .img files in Downloads."; dim: true; font.pixelSize: 12 }
                    Repeater {
                        model: page.settings.images
                        Choice {
                            required property var modelData
                            text: modelData.name
                            detail: Disks.size(modelData.size)
                            on: page.pending?.image === modelData.path
                            onPicked: page.edit({ image: modelData.path })
                        }
                    }
                    Field {
                        Layout.preferredWidth: 360
                        Layout.topMargin: 4
                        placeholder: "Or the image's full path"
                        onVisibleChanged: if (visible) text = ""
                        onTextChanged: if (text.trim()) page.edit({ image: text.trim().replace(/^file:\/\//, "") })
                    }
                }

                RowLayout {
                    visible: card.open
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.bottomMargin: 6
                    spacing: 8
                    readonly property var image: page.settings.images.find(i => i.path === page.pending?.image)
                    readonly property bool fits: !image || image.size <= card.disk.size
                    Label {
                        Layout.fillWidth: true
                        text: !parent.fits ? "That image is bigger than this drive." : page.pending?.action === "format" ? "Everything on this partition will be deleted." : "Everything on this drive will be deleted."
                        color: Theme.danger
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                    PillButton { text: "Cancel"; primary: false; onClicked: page.pending = null }
                    PillButton {
                        danger: true
                        text: ({ erase: "Erase", format: "Format", write: "Write" })[page.pending?.action] ?? ""
                        enabled: parent.fits && /^[A-Za-z0-9 _-]{0,32}$/.test(page.pending?.label ?? "") && (page.pending?.action !== "write" || /^\/.+\.(iso|img)$/i.test(page.pending.image))
                        onClicked: {
                            if (!enabled)
                                return;
                            const p = page.pending;
                            if (p.action === "erase")
                                page.settings.eraseDisk(p.disk, p.fs, p.label);
                            else if (p.action === "format")
                                page.settings.formatPart(p.part, p.fs, p.label);
                            else
                                page.settings.writeImage(p.disk, p.image, parent.image?.size ?? 0);
                            page.pending = null;
                        }
                    }
                }
                Item { implicitHeight: 6 }
            }
        }

        // A write's progress
        Rectangle {
            visible: page.settings.diskProgress >= 0
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.off
            Rectangle { width: parent.width * Math.max(0, page.settings.diskProgress); height: parent.height; radius: 3; color: Theme.accent }
        }
        Label {
            Layout.fillWidth: true
            text: page.settings.disksStatus || "Erasing, formatting and writing images ask for your password every time."
            dim: true
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }
}
