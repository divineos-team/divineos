import QtQuick
import QtQuick.Layouts
import "Backup.js" as Backup

// Settings > Backup (devine-backup): Timeshift's Btrfs snapshots of the system. divineOS makes
// one before every update and one a day; any of them can be restored here, or started from the
// boot menu's "divineOS snapshots" when an update leaves the computer unable to start.
Flickable {
    id: page

    required property var settings
    property string confirm: "" // the snapshot asking "Restore?"
    property string description: ""

    clip: true
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        SettingsCard {
            visible: page.settings.rootFs !== "btrfs"
            Label {
                Layout.fillWidth: true
                topPadding: 10
                bottomPadding: 10
                text: page.settings.rootFs === "overlay" ? "Snapshots start working once divineOS is installed." : `Snapshots need the system on Btrfs, as the divineOS installer sets it up. This one is on ${page.settings.rootFs || "another filesystem"}.`
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }

        // After a restore: it takes effect at the next start.
        SettingsCard {
            visible: page.settings.restored !== ""
            SettingRow {
                title: "Restart to finish"
                hint: "The system goes back to the snapshot when the computer starts again."
                PillButton { text: "Restart Now"; onClicked: page.settings.restart() }
            }
        }

        SettingsCard {
            visible: page.settings.rootFs === "btrfs"
            SettingRow {
                title: "Snapshot now"
                hint: "Keeps the system as it is: apps, settings and updates. Your home folder isn't in snapshots, so restoring never touches your files."
                Row {
                    spacing: 8
                    Field {
                        id: description
                        width: 200
                        placeholder: "Description"
                        onTextChanged: page.description = text.trim()
                        onAccepted: create.clicked()
                    }
                    PillButton {
                        id: create
                        text: page.settings.backupBusy ? "Working…" : "Create"
                        enabled: !page.settings.backupBusy && /^[A-Za-z0-9 .,:_-]{0,80}$/.test(page.description)
                        onClicked: {
                            if (!enabled)
                                return;
                            page.settings.createSnapshot(page.description);
                            description.text = "";
                        }
                    }
                }
            }
        }

        SettingsCard {
            visible: page.settings.rootFs === "btrfs"
            Label { Layout.topMargin: 10; text: "Snapshots"; font.weight: Font.DemiBold }
            Label {
                Layout.fillWidth: true
                visible: !page.settings.snapshots.length
                text: "None yet. The first one is made before the next update, or right now above."
                dim: true
                font.pixelSize: 12
                bottomPadding: 6
            }
            Repeater {
                model: page.settings.snapshots
                SettingRow {
                    id: snap
                    required property var modelData
                    readonly property bool asking: page.confirm === modelData.name
                    title: Qt.formatDateTime(modelData.date, page.settings.clock24 ? "ddd d MMM yyyy, H:mm" : "ddd d MMM yyyy, h:mm AP")
                    hint: asking ? "Restore the system to this snapshot? Apps, settings and updates made since are undone at the next start." : Backup.kind(modelData)
                    Row {
                        spacing: 8
                        PillButton { visible: !snap.asking; enabled: !page.settings.backupBusy; text: "Restore…"; primary: false; onClicked: page.confirm = snap.modelData.name }
                        PillButton { visible: !snap.asking; enabled: !page.settings.backupBusy; text: "Delete"; primary: false; onClicked: page.settings.deleteSnapshot(snap.modelData.name) }
                        PillButton { visible: snap.asking; text: "Cancel"; primary: false; onClicked: page.confirm = "" }
                        PillButton {
                            visible: snap.asking
                            danger: true
                            text: "Restore"
                            onClicked: {
                                page.settings.restoreSnapshot(snap.modelData.name);
                                page.confirm = "";
                            }
                        }
                    }
                }
            }
            Item { implicitHeight: 6 }
        }

        Label {
            Layout.fillWidth: true
            visible: page.settings.rootFs === "btrfs"
            text: page.settings.backupStatus || "If an update stops the computer starting: pick \"divineOS snapshots\" in the boot menu, start the newest snapshot from before it, then restore it here."
            dim: true
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }
}
