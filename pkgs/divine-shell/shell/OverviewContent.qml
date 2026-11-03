pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland

// Mission Control: every window as a live thumbnail, grouped by workspace, over the dimmed
// desktop. Click a window to go to it, a workspace's title to switch there, anywhere else
// (or Escape) to leave.
Rectangle {
    id: root

    property var windows: [] // Sys.overviewWindows
    property int focusedWorkspace: 1

    signal picked(var window)
    signal workspacePicked(int id)
    signal dismissed

    readonly property var groups: [...new Set(windows.map(w => w.workspace))]

    color: Qt.rgba(0, 0, 0, 0.35)
    Keys.onEscapePressed: dismissed()

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Label {
        visible: !root.windows.length
        anchors.centerIn: parent
        text: "No open windows"
        color: Theme.barText
        font.pixelSize: 20
        opacity: 0.7
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 56
        contentHeight: column.implicitHeight
        interactive: contentHeight > height // otherwise clicks on empty space reach the dismiss area
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width
            spacing: 32

            Repeater {
                model: root.groups

                Column {
                    id: group
                    required property int modelData
                    readonly property bool focused: modelData === root.focusedWorkspace

                    width: column.width
                    spacing: 14

                    Label {
                        text: "Desktop " + group.modelData
                        color: Theme.barText
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        opacity: group.focused ? 1 : 0.7
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            onClicked: root.workspacePicked(group.modelData)
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: 28

                        Repeater {
                            model: root.windows.filter(w => w.workspace === group.modelData)

                            Column {
                                id: card
                                required property var modelData

                                spacing: 8

                                Rectangle {
                                    width: shot.width + 6
                                    height: shot.height + 6
                                    radius: 14
                                    color: "transparent"
                                    border.width: 3
                                    border.color: hover.hovered ? Theme.accent : "transparent"

                                    ScreencopyView {
                                        id: shot
                                        anchors.centerIn: parent
                                        captureSource: card.modelData.window
                                        live: true
                                        constraintSize: Qt.size(360, 220)
                                        width: implicitWidth || 360
                                        height: implicitHeight || 220
                                    }

                                    HoverHandler {
                                        id: hover
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.picked(card.modelData.window)
                                    }
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 8
                                    Image {
                                        width: 20
                                        height: 20
                                        sourceSize: Qt.size(40, 40)
                                        source: card.modelData.icon
                                    }
                                    Label {
                                        width: Math.min(implicitWidth, shot.width - 28)
                                        text: card.modelData.title || card.modelData.name
                                        color: Theme.barText
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
