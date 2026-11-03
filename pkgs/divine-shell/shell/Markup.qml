import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// After each screenshot: its thumbnail in the bottom-right corner for a few seconds, like
// macOS. Clicking it opens Mark Up; saving there replaces the file and copies the picture.
// `devine-shot FILE` (IPC) marks up any picture.
Scope {
    id: markup

    property string path: "" // the picture being shown or marked up

    function open(file) {
        path = file;
        thumb.visible = false;
        content.reset();
        editor.visible = true;
    }

    Connections {
        target: Sys
        function onShotTaken(file) {
            markup.path = file;
            thumb.visible = true;
            hide.restart();
        }
    }

    PanelWindow {
        id: thumb
        visible: false
        screen: Array.from(Quickshell.screens).find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
        anchors.bottom: true
        anchors.right: true
        margins.bottom: 24
        margins.right: 24
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 240
        implicitHeight: picture.paintedHeight + 44
        color: "transparent"
        WlrLayershell.namespace: "divine-capture"
        WlrLayershell.layer: WlrLayer.Overlay

        Timer {
            id: hide
            interval: 6000
            onTriggered: thumb.visible = false
        }

        Glass {
            anchors.fill: parent
            radius: 18
            Image {
                id: picture
                x: 10
                y: 10
                width: parent.width - 20
                height: 140
                fillMode: Image.PreserveAspectFit
                verticalAlignment: Image.AlignTop
                sourceSize: Qt.size(440, 280)
                source: markup.path ? "file://" + markup.path : ""
                cache: false
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                text: "Copied and saved · Click to mark up"
                dim: true
                font.pixelSize: 11
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: containsMouse ? hide.stop() : hide.restart()
                onClicked: markup.open(markup.path)
            }
        }
    }

    FloatingWindow {
        id: editor
        title: "Mark Up"
        visible: false
        onClosed: visible = false
        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight
        minimumSize: Qt.size(720, 480)
        color: Theme.glass

        MarkupContent {
            id: content
            anchors.fill: parent
            source: editor.visible && markup.path ? "file://" + markup.path : ""
            onCopy: image => {
                const tmp = `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/divine-markup.png`;
                if (image.saveToFile(tmp))
                    Quickshell.execDetached(["sh", "-c", 'wl-copy < "$1"', "sh", tmp]);
            }
            onSave: image => {
                if (image.saveToFile(markup.path))
                    Quickshell.execDetached(["sh", "-c", 'wl-copy < "$1"', "sh", markup.path]);
                editor.visible = false;
            }
            onClose: editor.visible = false
        }
    }

    IpcHandler {
        target: "markup"
        function open(file: string): void {
            markup.open(file);
        }
    }
}
