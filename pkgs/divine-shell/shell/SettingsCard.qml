import QtQuick
import QtQuick.Layouts

// Glass card holding a column of rows (Settings, Store).
Glass {
    default property alias rows: column.data

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 24
    radius: 22

    ColumnLayout {
        id: column
        x: 20
        y: 12
        width: parent.width - 40
        spacing: 0
    }
}
