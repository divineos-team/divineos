import QtQuick

Text {
    property bool dim: false

    font.family: Theme.font
    font.pixelSize: 13
    color: dim ? Theme.textDim : Theme.text
    elide: Text.ElideRight
}
