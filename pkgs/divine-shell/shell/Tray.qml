import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Menu bar extras: the icons apps put in the tray (StatusNotifierItem). Click opens the app,
// right-click its menu, middle-click its second action, scroll whatever the app does with it.
// Passive ones (nothing to report) stay hidden, as on macOS.
Row {
    spacing: 14

    Repeater {
        model: SystemTray.items

        Image {
            id: extra
            required property SystemTrayItem modelData

            visible: modelData.status !== Status.Passive
            width: 16
            height: 16
            sourceSize: Qt.size(32, 32)
            anchors.verticalCenter: parent.verticalCenter
            source: modelData.icon

            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    const item = extra.modelData;
                    if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                        const below = extra.mapToItem(null, 0, extra.height + 10);
                        if (item.hasMenu)
                            item.display(QsWindow.window, below.x, below.y);
                    } else {
                        item.activate();
                    }
                }
                onWheel: wheel => extra.modelData.scroll(wheel.angleDelta.y / 120, false)
            }
        }
    }
}
