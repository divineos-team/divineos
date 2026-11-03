import QtQuick

// A liquid-glass surface. Hyprland blurs and refracts whatever is behind it
// (layer rule on the divine-* namespaces); this adds the tint, gloss and rim.
Rectangle {
    property bool round: false

    radius: round ? Math.min(width, height) / 2 : Theme.radius
    color: Theme.glass
    border.width: 1
    border.color: Theme.rim

    // Specular gloss: light falling across the upper half of the lens.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, Theme.gloss) }
            GradientStop { position: 0.55; color: "transparent" }
        }
    }

    Behavior on color { ColorAnimation { duration: 200 } }
}
