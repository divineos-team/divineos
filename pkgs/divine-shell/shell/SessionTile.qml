import QtQuick

// Lock, then log out / restart / shut down. Those three need a second tap within 3 s; the armed
// button turns red.
Glass {
    id: tile

    property string armed: ""
    signal lockRequested

    implicitWidth: Theme.unit * 2 + Theme.gap
    implicitHeight: Theme.unit

    Timer {
        id: disarm
        interval: 3000
        onTriggered: tile.armed = ""
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: [
                { id: "lock", icon: Theme.icons.lock, act: () => tile.lockRequested(), safe: true },
                { id: "logout", icon: Theme.icons.logout, act: () => Sys.logout() },
                { id: "reboot", icon: Theme.icons.restart, act: () => Sys.reboot() },
                { id: "poweroff", icon: Theme.icons.power, act: () => Sys.poweroff() }
            ]
            Rectangle {
                required property var modelData
                readonly property bool isArmed: tile.armed === modelData.id
                width: 34
                height: 34
                radius: 17
                color: isArmed ? Theme.danger : Theme.off
                Behavior on color { ColorAnimation { duration: 150 } }
                Glyph {
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    color: parent.isArmed ? "#ffffff" : Theme.text
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (parent.isArmed || parent.modelData.safe)
                            return parent.modelData.act();
                        tile.armed = parent.modelData.id;
                        disarm.restart();
                    }
                }
            }
        }
    }
}
