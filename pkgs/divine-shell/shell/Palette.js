.pragma library

// The accent a wallpaper suggests: its most common vivid hue, at a saturation and brightness
// an accent needs. `data` is RGBA bytes (a Canvas's getImageData().data); grey pictures get
// graphite. Checked by ../test-js.mjs.
function accentFromPixels(data) {
    const bins = [];
    for (let i = 0; i < 12; i++)
        bins.push({ weight: 0, hue: 0, sat: 0 });
    for (let i = 0; i + 3 < data.length; i += 4) {
        const [h, s, v] = hsv(data[i] / 255, data[i + 1] / 255, data[i + 2] / 255);
        if (s < 0.2 || v < 0.2)
            continue; // greys, whites and near blacks say nothing about colour
        const w = s * s * v * data[i + 3] / 255;
        const bin = bins[Math.floor(h * 12) % 12];
        bin.weight += w;
        bin.hue += h * w;
        bin.sat += s * w;
    }
    const best = bins.reduce((a, b) => b.weight > a.weight ? b : a);
    if (best.weight < 0.02 * data.length / 4)
        return "#8e8e93";
    const sat = Math.min(0.85, Math.max(0.55, best.sat / best.weight));
    return hex(rgb(best.hue / best.weight, sat, 0.92));
}

function hsv(r, g, b) {
    const max = Math.max(r, g, b), d = max - Math.min(r, g, b);
    let h = 0;
    if (d > 0)
        h = max === r ? ((g - b) / d + 6) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return [h / 6, max ? d / max : 0, max];
}

function rgb(h, s, v) {
    const f = n => {
        const k = (n + h * 6) % 6;
        return v - v * s * Math.max(0, Math.min(k, 4 - k, 1));
    };
    return [f(5), f(3), f(1)];
}

function hex(c) {
    return "#" + c.map(x => Math.round(x * 255).toString(16).padStart(2, "0")).join("");
}
