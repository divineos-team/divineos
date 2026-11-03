import QtQuick

// Filled line graph of the last `window` values, newest at the right edge.
Canvas {
    id: graph

    property var values: []
    property real max: 100 // 0 = scale to the largest value shown
    property int window: 60
    property color color: Theme.accent

    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const n = values.length;
        if (n < 2)
            return;
        const top = max > 0 ? max : Math.max(1, ...values);
        const step = width / (window - 1);
        const x = i => width - (n - 1 - i) * step;
        const y = v => height - Math.min(1, v / top) * (height - 2) - 1;

        ctx.beginPath();
        ctx.moveTo(x(0), y(values[0]));
        for (let i = 1; i < n; i++)
            ctx.lineTo(x(i), y(values[i]));
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.strokeStyle = color;
        ctx.stroke();

        ctx.lineTo(x(n - 1), height);
        ctx.lineTo(x(0), height);
        ctx.closePath();
        const fill = ctx.createLinearGradient(0, 0, 0, height);
        fill.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.35));
        fill.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0));
        ctx.fillStyle = fill;
        ctx.fill();
    }
}
