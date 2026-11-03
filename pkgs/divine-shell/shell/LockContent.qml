pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// Lock and login screen, macOS style: the blurred wallpaper, date and a large clock up top, and
// the user's picture, name and password field near the bottom. The greeter adds user switching
// (when there's more than one) and Restart / Shut Down. Doesn't touch Sys, so the greeter can
// use it without starting the desktop's services.
Item {
    id: lock

    property date now: new Date()
    property string userName: ""
    property string avatar: ""
    property bool busy: false
    property string message: ""
    property string wallpaper: ""
    property int userCount: 1
    property bool showPower: false
    property bool clock24: false

    signal submit(string password)
    signal switchUser(int delta)
    signal reboot
    signal poweroff

    // Wrong password: clear the field and shake it.
    function fail() {
        field.text = "";
        shake.restart();
        field.forceActiveFocus();
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: lock.wallpaper
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: true
        blur: 1
        blurMax: 64
        saturation: 0.15
        brightness: -0.08
        autoPaddingEnabled: false
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.09
        spacing: -8
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(lock.now, "dddd, MMMM d")
            color: Theme.barText
            font.pixelSize: 22
            font.weight: Font.DemiBold
            opacity: 0.85
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: lock.clock24 ? Qt.formatTime(lock.now, "H:mm") : Qt.formatTime(lock.now, "h:mm AP").replace(/\s*[AP]M$/i, "") // like the menu bar, without AM/PM
            color: Theme.barText
            font.pixelSize: 120
            font.weight: Font.Bold
            opacity: 0.9
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(parent.height * 0.1, lock.showPower ? 140 : 0)
        spacing: 12

        // Picture from ~/.face (the login screen: AccountsService), else the first letter of the name.
        Avatar {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76
            height: 76
            source: lock.avatar
            name: lock.userName
            textColor: Theme.barText
        }

        // The name, with arrows to the other accounts on the login screen.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            component Switcher: Glyph {
                id: arrow
                property int delta
                visible: lock.userCount > 1
                width: 22
                font.pixelSize: 18
                color: Theme.barText
                opacity: 0.75
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: !lock.busy
                    onClicked: lock.switchUser(arrow.delta)
                }
            }
            Switcher { delta: -1; text: Theme.icons.chevronLeft; anchors.verticalCenter: parent.verticalCenter }
            Label {
                text: lock.userName
                color: Theme.barText
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Switcher { delta: 1; text: Theme.icons.chevronRight; anchors.verticalCenter: parent.verticalCenter }
        }

        Glass {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            round: true
            width: 240
            height: 36

            transform: Translate {
                id: nudge
            }
            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: nudge; property: "x"; to: -10; duration: 50 }
                NumberAnimation { target: nudge; property: "x"; to: 10; duration: 80 }
                NumberAnimation { target: nudge; property: "x"; to: 0; duration: 50 }
            }

            TextInput {
                id: field
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: go.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                focus: true
                enabled: !lock.busy
                echoMode: TextInput.Password
                passwordCharacter: "●"
                font.family: Theme.font
                font.pixelSize: 14
                color: Theme.barText
                clip: true
                onAccepted: lock.submit(text)
                Keys.onEscapePressed: text = ""

                Label {
                    visible: !field.text
                    anchors.verticalCenter: parent.verticalCenter
                    text: lock.busy ? "Checking…" : "Enter Password"
                    color: Theme.barText
                    opacity: 0.6
                    font.pixelSize: 14
                }
            }

            Rectangle {
                id: go
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: 14
                visible: field.text !== "" && !lock.busy
                color: Qt.rgba(1, 1, 1, 0.25)
                Glyph {
                    anchors.centerIn: parent
                    text: Theme.icons.arrowRight
                    font.pixelSize: 16
                    color: Theme.barText
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: lock.submit(field.text)
                }
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, 420)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: lock.message
            color: Theme.barText
            opacity: text ? 0.85 : 0
            font.pixelSize: 12
        }
    }

    // Login screen only: Restart and Shut Down, as on the macOS login window.
    Row {
        visible: lock.showPower
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        spacing: 36
        Repeater {
            model: [
                { label: "Restart", glyph: Theme.icons.restart, act: () => lock.reboot() },
                { label: "Shut Down", glyph: Theme.icons.power, act: () => lock.poweroff() }
            ]
            Column {
                id: power
                required property var modelData
                spacing: 6
                Pressable {
                    anchors.horizontalCenter: parent.horizontalCenter
                    round: true
                    width: 44
                    height: 44
                    onClicked: power.modelData.act()
                    Glyph {
                        anchors.centerIn: parent
                        text: power.modelData.glyph
                        color: Theme.barText
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: power.modelData.label
                    color: Theme.barText
                    font.pixelSize: 11
                    opacity: 0.85
                }
            }
        }
    }
}
