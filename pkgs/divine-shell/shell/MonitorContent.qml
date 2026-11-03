import QtQuick
import QtQuick.Layouts

// System Monitor window contents. Monitor.qml feeds it snapshots from `devine-monitor --json`.
Item {
    id: root

    property var snap: null
    property var cpu: []
    property var mem: []
    property var gpu: []
    property var rx: []
    property var tx: []

    function feed(s) {
        snap = s;
        cpu = keep(cpu, s.cpu);
        mem = keep(mem, 100 * s.mem_used / Math.max(1, s.mem_total));
        gpu = keep(gpu, s.gpu ? s.gpu.util : 0);
        rx = keep(rx, s.net_rx);
        tx = keep(tx, s.net_tx);
    }
    function keep(list, v) {
        return list.concat([v]).slice(-60);
    }
    function bytes(b) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1024 && i < units.length - 1) {
            b /= 1024;
            i++;
        }
        return (i ? b.toFixed(1) : b) + " " + units[i];
    }
    function uptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s / 3600) % 24, m = Math.floor(s / 60) % 60;
        return d ? `${d}d ${h}h` : `${h}h ${m}m`;
    }

    implicitWidth: 780
    implicitHeight: 630

    component StatTile: Glass {
        id: tile
        property string title
        property string value
        property string detail
        property var values: []
        property real max: 100
        property color color: Theme.accent

        Layout.fillWidth: true
        Layout.preferredHeight: 150
        radius: 22

        Column {
            x: 18
            y: 14
            spacing: 2
            Label { text: tile.title; dim: true; font.pixelSize: 12; font.weight: Font.DemiBold }
            Label { text: tile.value; font.pixelSize: 24; font.weight: Font.Bold }
            Label { text: tile.detail; dim: true; font.pixelSize: 12 }
        }
        Graph {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 64
            values: tile.values
            max: tile.max
            color: tile.color
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: Theme.gap

        RowLayout {
            Label { text: "System Monitor"; font.pixelSize: 20; font.weight: Font.Bold }
            Item { Layout.fillWidth: true }
            Label {
                dim: true
                text: root.snap ? `${root.snap.host} · up ${root.uptime(root.snap.uptime)} · load ${root.snap.load[0].toFixed(2)}` : "Starting…"
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Theme.gap
            columnSpacing: Theme.gap

            StatTile {
                title: "CPU"
                value: Math.round(root.snap?.cpu ?? 0) + "%"
                detail: (root.snap?.cores.length ?? 0) + " cores" + (root.snap?.cpu_temp ? ` · ${Math.round(root.snap.cpu_temp)}°C` : "")
                values: root.cpu
                color: Theme.accent
            }
            StatTile {
                title: "Memory"
                value: root.snap ? `${root.bytes(root.snap.mem_used)} / ${root.bytes(root.snap.mem_total)}` : "—"
                detail: root.snap?.swap_total ? `swap ${root.bytes(root.snap.swap_used)} / ${root.bytes(root.snap.swap_total)}` : "no swap"
                values: root.mem
                color: "#5E5CE6"
            }
            StatTile {
                readonly property var g: root.snap?.gpu ?? null
                title: g ? g.name : "GPU"
                value: g ? Math.round(g.util) + "%" : "—"
                detail: g ? [`VRAM ${root.bytes(g.vram_used)} / ${root.bytes(g.vram_total)}`, g.temp ? `${Math.round(g.temp)}°C` : "", g.power_w ? `${Math.round(g.power_w)} W` : ""].filter(s => s).join(" · ") : "No NVIDIA or AMD stats"
                values: root.gpu
                color: "#64D2FF"
            }
            StatTile {
                title: "Network"
                value: "↓ " + root.bytes(root.snap?.net_rx ?? 0) + "/s"
                detail: "↑ " + root.bytes(root.snap?.net_tx ?? 0) + "/s"
                values: root.rx
                max: 0
                color: "#30D158"
            }
        }

        Glass {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 22
            clip: true // a shrunken window shows fewer rows instead of spilling

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6

                Row {
                    width: parent.width
                    Label { width: parent.width - 170; text: "Top processes"; dim: true; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Label { width: 70; text: "CPU"; dim: true; font.pixelSize: 12; horizontalAlignment: Text.AlignRight }
                    Label { width: 100; text: "Memory"; dim: true; font.pixelSize: 12; horizontalAlignment: Text.AlignRight }
                }
                Repeater {
                    model: root.snap?.procs ?? []
                    Row {
                        required property var modelData
                        width: parent.width
                        Label { width: parent.width - 170; text: modelData.name; font.weight: Font.Medium }
                        Label { width: 70; text: modelData.cpu.toFixed(1) + "%"; horizontalAlignment: Text.AlignRight }
                        Label { width: 100; text: root.bytes(modelData.mem); dim: true; horizontalAlignment: Text.AlignRight }
                    }
                }
            }
        }
    }
}
