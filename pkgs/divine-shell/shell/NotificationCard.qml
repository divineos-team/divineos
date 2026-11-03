import QtQuick

// One notification, macOS style: icon, app and time, summary, body, action buttons.
// As a banner it hides itself after the app's timeout (or 6 s) unless hovered; critical
// notifications stay until handled. A close button appears on hover.
Glass {
    id: card

    required property var notification
    property date now: new Date()
    property bool banner: false

    readonly property var n: notification
    readonly property string icon: Sys.imageUrl(n.image) || Sys.imageUrl(n.appIcon)
    readonly property var buttons: Array.from(n.actions).filter(a => a.identifier !== "default" && a.text)
    readonly property bool critical: n.urgency === 2 // NotificationUrgency.Critical

    function age() {
        const t = Sys.receivedAt[n.id] ?? now;
        const s = (now - t) / 1000;
        return s < 60 ? "now" : s < 3600 ? `${Math.floor(s / 60)}m ago` : Qt.formatTime(t, "h:mm AP");
    }

    width: 360
    implicitHeight: content.implicitHeight + 24
    radius: 22
    border.color: critical ? Theme.danger : Theme.rim

    HoverHandler {
        id: hover
    }

    Timer {
        running: card.banner && !hover.hovered && !card.critical && card.n.expireTimeout !== 0
        interval: card.n.expireTimeout > 0 ? card.n.expireTimeout * 1000 : 6000
        onTriggered: Sys.hideBanner(card.n)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Sys.activateNotification(card.n)
    }

    Column {
        id: content
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Row {
            width: parent.width
            spacing: 10

            Image {
                id: icon
                visible: card.icon !== "" && status !== Image.Error
                width: 36
                height: 36
                sourceSize: Qt.size(72, 72)
                source: card.icon
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Glyph { // no icon: a bell
                visible: !icon.visible
                width: 36
                height: 36
                text: Theme.icons.bell
                font.pixelSize: 24
                color: Theme.textDim
            }

            Column {
                width: parent.width - 46
                spacing: 2

                Item {
                    width: parent.width
                    height: appName.height
                    Label {
                        id: appName
                        width: parent.width - when.width - 8
                        text: card.n.appName || "Notification"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        dim: true
                    }
                    Label {
                        id: when
                        anchors.right: parent.right
                        text: card.age()
                        font.pixelSize: 11
                        dim: true
                    }
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    text: card.n.summary
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    // Markup is allowed, but no <img>: a remote image would tell the sender you read it.
                    text: card.n.body.replace(/<img[^>]*>/gi, "")
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: card.banner ? 3 : 6
                    dim: true
                }
            }
        }

        Row {
            visible: card.buttons.length > 0
            x: 46
            spacing: 6
            Repeater {
                model: card.buttons
                Rectangle {
                    id: button
                    required property var modelData
                    width: Math.min(140, label.implicitWidth + 24)
                    height: 28
                    radius: 14
                    color: buttonArea.pressed ? Theme.track : Theme.off
                    Label {
                        id: label
                        anchors.centerIn: parent
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        text: button.modelData.text
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: buttonArea
                        anchors.fill: parent
                        onClicked: Sys.runNotificationAction(card.n, button.modelData)
                    }
                }
            }
        }
    }

    // Close (dismiss for good), top-left like macOS.
    Rectangle {
        visible: hover.hovered
        x: -6
        y: -6
        width: 22
        height: 22
        radius: 11
        color: Theme.dark ? "#3a3a3c" : "#ffffff"
        border.color: Theme.rim
        Glyph {
            anchors.centerIn: parent
            text: Theme.icons.close
            font.pixelSize: 13
        }
        MouseArea {
            anchors.fill: parent
            onClicked: Sys.dismissNotification(card.n)
        }
    }
}
