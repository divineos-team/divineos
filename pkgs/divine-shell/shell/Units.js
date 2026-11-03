.pragma library

// Unit conversions for the launcher: "10 km to mi", "72 f in c", "3.5 gib to mb".
// Checked by ../test-js.mjs.

// unit: [kind, size in the kind's base unit]. Temperatures go through kelvin instead.
const units = {
    mm: ["length", 0.001], cm: ["length", 0.01], m: ["length", 1], km: ["length", 1000],
    in: ["length", 0.0254], ft: ["length", 0.3048], yd: ["length", 0.9144], mi: ["length", 1609.344],
    mg: ["mass", 0.001], g: ["mass", 1], kg: ["mass", 1000], t: ["mass", 1e6], oz: ["mass", 28.349523125], lb: ["mass", 453.59237],
    ml: ["volume", 0.001], l: ["volume", 1], floz: ["volume", 0.0295735295625], cup: ["volume", 0.2365882365], gal: ["volume", 3.785411784],
    b: ["data", 1], kb: ["data", 1e3], mb: ["data", 1e6], gb: ["data", 1e9], tb: ["data", 1e12],
    kib: ["data", 1024], mib: ["data", 1048576], gib: ["data", 1073741824], tib: ["data", 1099511627776],
    "m/s": ["speed", 1], "km/h": ["speed", 1 / 3.6], mph: ["speed", 0.44704], kn: ["speed", 0.514444],
    s: ["time", 1], min: ["time", 60], h: ["time", 3600], d: ["time", 86400], wk: ["time", 604800],
    c: ["temp"], f: ["temp"], k: ["temp"]
};
const aliases = {
    meter: "m", meters: "m", metre: "m", metres: "m", kilometer: "km", kilometers: "km", kilometre: "km", kilometres: "km",
    inch: "in", inches: "in", foot: "ft", feet: "ft", yard: "yd", yards: "yd", mile: "mi", miles: "mi",
    gram: "g", grams: "g", kilogram: "kg", kilograms: "kg", kgs: "kg", ounce: "oz", ounces: "oz", pound: "lb", pounds: "lb", lbs: "lb",
    liter: "l", liters: "l", litre: "l", litres: "l", gallon: "gal", gallons: "gal", cups: "cup",
    kmh: "km/h", kph: "km/h", knots: "kn", sec: "s", second: "s", seconds: "s", minute: "min", minutes: "min", mins: "min",
    hr: "h", hour: "h", hours: "h", day: "d", days: "d", week: "wk", weeks: "wk",
    celsius: "c", fahrenheit: "f", kelvin: "k"
};

function unit(word) {
    const w = word.toLowerCase().replace(/^°/, "");
    return units[w] ? w : aliases[w] ?? "";
}

function kelvin(v, u) {
    return u === "c" ? v + 273.15 : u === "f" ? (v - 32) * 5 / 9 + 273.15 : v;
}

function fromKelvin(v, u) {
    return u === "c" ? v - 273.15 : u === "f" ? (v - 273.15) * 9 / 5 + 32 : v;
}

// "10 km to mi" → "6.21371 mi"; anything else → "".
function convert(q) {
    const m = q.match(/^(-?\d+(?:\.\d+)?)\s*([a-z°/]+)\s+(?:to|in|as)\s+([a-z°/]+)$/i);
    if (!m)
        return "";
    const v = +m[1], from = unit(m[2]), to = unit(m[3]);
    if (!from || !to || units[from][0] !== units[to][0])
        return "";
    const r = units[from][0] === "temp" ? fromKelvin(kelvin(v, from), to) : v * units[from][1] / units[to][1];
    return `${Number(r.toPrecision(6))} ${m[3]}`;
}
