.pragma library

// Weather from Open-Meteo (no account, no key) for the menu bar and the Notification Center.
// Checked by ../test-js.mjs.

// What a WMO weather code looks like: [codes, label, day glyph, night glyph (if different)]
const kinds = [
    [[0], "Clear", 0xF0599, 0xF0594],
    [[1], "Mostly Clear", 0xF0599, 0xF0594],
    [[2], "Partly Cloudy", 0xF0595, 0xF0F31],
    [[3], "Cloudy", 0xF0590],
    [[45, 48], "Fog", 0xF0591],
    [[51, 53, 55, 56, 57], "Drizzle", 0xF0F33],
    [[61, 63, 80, 81], "Rain", 0xF0597],
    [[65, 82], "Heavy Rain", 0xF0596],
    [[66, 67], "Freezing Rain", 0xF067F],
    [[71, 73, 77, 85], "Snow", 0xF0598],
    [[75, 86], "Heavy Snow", 0xF0F36],
    [[95], "Thunderstorms", 0xF067E],
    [[96, 99], "Thunderstorms and Hail", 0xF0592]
];

function describe(code, day) {
    const k = kinds.find(k => k[0].includes(code)) ?? [[], "", 0xF0590];
    return { label: k[1], glyph: String.fromCodePoint(!day && k[3] ? k[3] : k[2]) };
}

function forecastUrl(lat, lon, fahrenheit) {
    return `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}`
        + "&current=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min"
        + `&timezone=auto&forecast_days=6&temperature_unit=${fahrenheit ? "fahrenheit" : "celsius"}`;
}

function searchUrl(name) {
    return `https://geocoding-api.open-meteo.com/v1/search?count=6&language=en&format=json&name=${encodeURIComponent(name)}`;
}

// Geocoding results → places: { name, detail (region, country), lat, lon }
function places(json) {
    return (json.results ?? []).map(r => ({
        name: r.name,
        detail: [r.admin1, r.country].filter(x => x && x !== r.name).join(", "),
        lat: r.latitude,
        lon: r.longitude
    }));
}

// The city a time zone is named after: "America/Argentina/Buenos_Aires" → "Buenos Aires".
function zoneCity(zone) {
    const parts = zone.trim().split("/");
    return parts.length > 1 && parts[0] !== "Etc" ? parts[parts.length - 1].replace(/_/g, " ") : "";
}

// A forecast → { temp, label, glyph, high, low, days[{ date, label, glyph, high, low }] }
function fromForecast(json) {
    const c = json.current, d = json.daily;
    const days = d.time.map((date, i) => Object.assign({ date, high: Math.round(d.temperature_2m_max[i]), low: Math.round(d.temperature_2m_min[i]) }, describe(d.weather_code[i], true)));
    return Object.assign({ temp: Math.round(c.temperature_2m), high: days[0].high, low: days[0].low, days }, describe(c.weather_code, c.is_day === 1));
}
