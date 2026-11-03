import QtQuick

// Mark Up (devine-shot): draw on a screenshot with a pen, arrows, boxes and text, pixelate what
// shouldn't be seen, then copy or save it. Shapes are kept in the picture's own pixels and
// drawn over it; `grab` renders picture and shapes together at full size. Markup.qml opens it
// and writes the file.
Item {
    id: root

    property url source
    property string tool: "arrow" // pen, arrow, box, text, pixelate
    property color ink: "#FF453A"
    property var shapes: [] // { tool, color, points: [{ x, y }…], text? }
    property var drawing: null // the shape being drawn
    property var typing: null // where a text is being typed: { x, y }
    signal save(var image) // an ItemGrabResult, the picture's size
    signal copy(var image)
    signal close

    readonly property real line: Math.max(3, stage.width / 360) // stroke width, in picture pixels
    readonly property var tools: [
        { id: "pen", glyph: String.fromCodePoint(0xF03EB), label: "Pen" },
        { id: "arrow", glyph: String.fromCodePoint(0xF005C), label: "Arrow" },
        { id: "box", glyph: String.fromCodePoint(0xF0763), label: "Box" },
        { id: "text", glyph: String.fromCodePoint(0xF0284), label: "Text" },
        { id: "pixelate", glyph: String.fromCodePoint(0xF00B5), label: "Pixelate" }
    ]
    readonly property var inks: ["#FF453A", "#FFD60A", "#30D158", "#0A84FF", "#ffffff", "#000000"]

    function add(shape) {
        shapes = shapes.concat([shape]);
        canvas.requestPaint();
    }
    function undo() {
        shapes = shapes.slice(0, -1);
        canvas.requestPaint();
    }
    function commitText() {
        if (typing && textInput.text.trim())
            add({ tool: "text", color: ink, points: [typing], text: textInput.text });
        typing = null;
        textInput.text = "";
    }
    function grab(then) {
        commitText();
        stage.grabToImage(then, Qt.size(stage.width, stage.height));
    }
    function reset() {
        shapes = [];
        drawing = null;
        typing = null;
        canvas.requestPaint();
    }
    // The box a two-point shape covers, in picture pixels.
    function rect(s) {
        const [a, b] = s.points;
        return Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
    }

    implicitWidth: 1040
    implicitHeight: 720
    focus: true
    Keys.onPressed: event => {
        if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_Z)
            undo();
        else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_C)
            grab(r => root.copy(r));
        else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_S)
            grab(r => root.save(r));
        else if (event.key === Qt.Key_Escape)
            root.close();
        else
            return;
        event.accepted = true;
    }

    // ── Toolbar ──
    Row {
        id: toolbar
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        spacing: 6

        Repeater {
            model: root.tools
            Rectangle {
                required property var modelData
                readonly property bool on: root.tool === modelData.id
                width: 40
                height: 36
                radius: 10
                color: on ? Theme.accent : toolArea.containsMouse ? Theme.off : "transparent"
                Glyph { anchors.centerIn: parent; text: modelData.glyph; font.pixelSize: 20; color: parent.on ? Theme.textOnAccent : Theme.text }
                MouseArea {
                    id: toolArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.commitText();
                        root.tool = parent.modelData.id;
                    }
                }
            }
        }
        Rectangle { width: 1; height: 24; anchors.verticalCenter: parent.verticalCenter; color: Theme.rim }
        Repeater {
            model: root.inks
            Rectangle {
                required property string modelData
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 11
                color: modelData
                border.width: Qt.colorEqual(root.ink, modelData) ? 3 : 1
                border.color: Qt.colorEqual(root.ink, modelData) ? Theme.text : Theme.rim
                MouseArea { anchors.fill: parent; onClicked: root.ink = parent.modelData }
            }
        }
        Rectangle { width: 1; height: 24; anchors.verticalCenter: parent.verticalCenter; color: Theme.rim }
        PillButton { anchors.verticalCenter: parent.verticalCenter; text: "Undo"; primary: false; enabled: root.shapes.length > 0; onClicked: root.undo() }
        PillButton { anchors.verticalCenter: parent.verticalCenter; text: "Copy"; primary: false; onClicked: root.grab(r => root.copy(r)) }
        PillButton { anchors.verticalCenter: parent.verticalCenter; text: "Save"; onClicked: root.grab(r => root.save(r)) }
    }

    // ── The picture, fitted to the window ──
    Item {
        id: view
        anchors.top: toolbar.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        readonly property real fit: stage.width ? Math.min(1, width / stage.width, height / stage.height) : 1

        Item {
            id: stage
            x: (view.width - width * view.fit) / 2
            y: (view.height - height * view.fit) / 2
            width: shot.implicitWidth
            height: shot.implicitHeight
            scale: view.fit
            transformOrigin: Item.TopLeft

            Image { id: shot; source: root.source; cache: false }

            // Pixelated areas: the picture under them sampled coarsely, drawn unsmoothed.
            Repeater {
                model: root.shapes.concat(root.drawing ? [root.drawing] : []).filter(s => s.tool === "pixelate")
                ShaderEffectSource {
                    required property var modelData
                    readonly property rect area: root.rect(modelData)
                    x: area.x
                    y: area.y
                    width: Math.max(1, area.width)
                    height: Math.max(1, area.height)
                    sourceItem: shot
                    sourceRect: area
                    textureSize: Qt.size(Math.max(1, area.width / 16), Math.max(1, area.height / 16))
                    smooth: false
                }
            }

            Canvas {
                id: canvas
                anchors.fill: parent
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    c.lineWidth = root.line;
                    c.lineCap = "round";
                    c.lineJoin = "round";
                    for (const s of root.shapes.concat(root.drawing ? [root.drawing] : [])) {
                        c.strokeStyle = s.color;
                        c.fillStyle = s.color;
                        const p = s.points;
                        if (s.tool === "pen") {
                            c.beginPath();
                            c.moveTo(p[0].x, p[0].y);
                            for (const q of p)
                                c.lineTo(q.x, q.y);
                            c.stroke();
                        } else if (s.tool === "box") {
                            const r = root.rect(s);
                            c.beginPath();
                            c.roundedRect(r.x, r.y, r.width, r.height, root.line * 2, root.line * 2);
                            c.stroke();
                        } else if (s.tool === "arrow") {
                            const angle = Math.atan2(p[1].y - p[0].y, p[1].x - p[0].x), head = root.line * 5;
                            c.beginPath();
                            c.moveTo(p[0].x, p[0].y);
                            c.lineTo(p[1].x - Math.cos(angle) * head * 0.6, p[1].y - Math.sin(angle) * head * 0.6);
                            c.stroke();
                            c.beginPath();
                            c.moveTo(p[1].x, p[1].y);
                            c.lineTo(p[1].x - head * Math.cos(angle - 0.45), p[1].y - head * Math.sin(angle - 0.45));
                            c.lineTo(p[1].x - head * Math.cos(angle + 0.45), p[1].y - head * Math.sin(angle + 0.45));
                            c.closePath();
                            c.fill();
                        }
                    }
                }
            }

            Repeater {
                model: root.shapes.filter(s => s.tool === "text")
                Text {
                    required property var modelData
                    x: modelData.points[0].x
                    y: modelData.points[0].y
                    text: modelData.text
                    color: modelData.color
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.35)
                    font.family: Theme.font
                    font.pixelSize: root.line * 9
                    font.weight: Font.Bold
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                onPressed: mouse => {
                    root.commitText();
                    const p = { x: mouse.x, y: mouse.y };
                    if (root.tool === "text") {
                        root.typing = p;
                        textInput.forceActiveFocus();
                    } else {
                        root.drawing = { tool: root.tool, color: root.ink.toString(), points: [p, p] };
                    }
                }
                onPositionChanged: mouse => {
                    if (!root.drawing)
                        return;
                    const p = { x: mouse.x, y: mouse.y }, d = root.drawing;
                    root.drawing = { tool: d.tool, color: d.color, points: d.tool === "pen" ? d.points.concat([p]) : [d.points[0], p] };
                    canvas.requestPaint();
                }
                onReleased: {
                    const d = root.drawing;
                    root.drawing = null;
                    if (d && (d.tool === "pen" ? d.points.length > 2 : root.rect(d).width + root.rect(d).height > 6))
                        root.add(d);
                    else
                        canvas.requestPaint();
                }
            }

            TextInput {
                id: textInput
                visible: root.typing !== null
                x: root.typing?.x ?? 0
                y: root.typing?.y ?? 0
                width: Math.max(40, contentWidth + 20)
                color: root.ink
                font.family: Theme.font
                font.pixelSize: root.line * 9
                font.weight: Font.Bold
                cursorVisible: visible
                onAccepted: root.commitText()
                Keys.onEscapePressed: {
                    text = "";
                    root.commitText();
                    root.forceActiveFocus();
                }
            }
        }
    }
}
