pragma Singleton
import QtQuick
import Quickshell

// divineDE design tokens. Glass colours are tints only: the compositor's acrylic
// blur supplies the refraction behind every translucent pixel.
Singleton {
    property bool dark: true // Sys binds this to the saved setting; the greeter keeps dark

    property string font: "Inter" // Sys binds this, the accent and the tint to Settings > Appearance
    property string tint: "default" // the theme's glass: see tintColors
    readonly property string iconFont: "Symbols Nerd Font"

    readonly property color text: dark ? "#ffffff" : "#1d1d1f"
    readonly property color textDim: dark ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(0, 0, 0, 0.5)
    readonly property var look: tintColors(tint, dark, accent)
    readonly property color glass: look.glass
    readonly property color rim: look.rim
    readonly property real gloss: look.gloss
    readonly property color off: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color track: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12)
    readonly property color fill: dark ? "#ffffff" : accent
    property color accent: "#0A84FF"
    // Text and glyphs on an accent fill: white, or near black on light accents (yellow, green).
    readonly property color textOnAccent: luminance(accent) > 0.4 ? "#1d1d1f" : "#ffffff"
    // The accent as text on white: light accents darkened until they read.
    readonly property color accentInk: luminance(accent) > 0.3 ? Qt.darker(accent, 1.6) : accent
    readonly property color danger: "#FF453A"
    // The menu bar floats straight on the wallpaper; Tide's sky is mid-blue up top.
    readonly property color barText: "#ffffff"

    // Settings > Appearance; gnome is the GTK accent-color it maps to.
    readonly property var accents: [
        { id: "blue", label: "Blue", color: "#0A84FF", gnome: "blue" },
        { id: "purple", label: "Purple", color: "#BF5AF2", gnome: "purple" },
        { id: "pink", label: "Pink", color: "#FF375F", gnome: "pink" },
        { id: "red", label: "Red", color: "#FF453A", gnome: "red" },
        { id: "orange", label: "Orange", color: "#FF9F0A", gnome: "orange" },
        { id: "yellow", label: "Yellow", color: "#FFD60A", gnome: "yellow" },
        { id: "green", label: "Green", color: "#30D158", gnome: "green" },
        { id: "teal", label: "Teal", color: "#40C8E0", gnome: "teal" },
        { id: "graphite", label: "Graphite", color: "#8E8E93", gnome: "slate" }
    ]

    // Themes (Settings > Appearance, Welcome): a mode, accent, glass tint and Hyprland blur together.
    readonly property var presets: [
        { name: "Divine Dark", dark: true, accent: "blue", tint: "default", glass: "acrylic" },
        { name: "Divine Frost", dark: false, accent: "teal", tint: "frost", glass: "kawase" },
        { name: "OLED Pitch", dark: true, accent: "graphite", tint: "pitch", glass: "acrylic" },
        { name: "Neon Cyber", dark: true, accent: "pink", tint: "neon", glass: "acrylic" }
    ]

    readonly property int radius: 28
    readonly property int unit: 76 // Control Center grid cell
    readonly property int gap: 12

    // Material Design glyphs from Symbols Nerd Font
    readonly property var icons: ({
        wifi: String.fromCodePoint(0xF05A9),
        wifiOff: String.fromCodePoint(0xF05AA),
        ethernet: String.fromCodePoint(0xF0200),
        bluetooth: String.fromCodePoint(0xF00AF),
        bluetoothOff: String.fromCodePoint(0xF00B2),
        bluetoothConnected: String.fromCodePoint(0xF00B1),
        volumeHigh: String.fromCodePoint(0xF057E),
        volumeMedium: String.fromCodePoint(0xF0580),
        volumeLow: String.fromCodePoint(0xF057F),
        volumeOff: String.fromCodePoint(0xF0581),
        mic: String.fromCodePoint(0xF036C),
        micOff: String.fromCodePoint(0xF036D),
        sunSmall: String.fromCodePoint(0xF00DE),
        sunLarge: String.fromCodePoint(0xF00E0),
        play: String.fromCodePoint(0xF040A),
        pause: String.fromCodePoint(0xF03E4),
        next: String.fromCodePoint(0xF04AD),
        previous: String.fromCodePoint(0xF04AE),
        music: String.fromCodePoint(0xF0387),
        batteryCharging: String.fromCodePoint(0xF0084),
        controls: String.fromCodePoint(0xF1542),
        search: String.fromCodePoint(0xF0349),
        power: String.fromCodePoint(0xF0425),
        restart: String.fromCodePoint(0xF0709),
        logout: String.fromCodePoint(0xF0343),
        airplane: String.fromCodePoint(0xF001D),
        appearance: String.fromCodePoint(0xF050E),
        screenshot: String.fromCodePoint(0xF0E51),
        performance: String.fromCodePoint(0xF04C5),
        balanced: String.fromCodePoint(0xF05D1),
        saver: String.fromCodePoint(0xF032A),
        calculator: String.fromCodePoint(0xF00EC),
        clipboard: String.fromCodePoint(0xF0A38),
        image: String.fromCodePoint(0xF0976),
        folder: String.fromCodePoint(0xF0256),
        file: String.fromCodePoint(0xF0224),
        account: String.fromCodePoint(0xF0009),
        window: String.fromCodePoint(0xF05AF),
        selection: String.fromCodePoint(0xF0A6C),
        stopRecording: String.fromCodePoint(0xF0666),
        settings: String.fromCodePoint(0xF0493),
        display: String.fromCodePoint(0xF0379),
        speaker: String.fromCodePoint(0xF04C3),
        palette: String.fromCodePoint(0xF03D8),
        check: String.fromCodePoint(0xF012C),
        chevronLeft: String.fromCodePoint(0xF0141),
        chevronRight: String.fromCodePoint(0xF0142),
        bell: String.fromCodePoint(0xF009A),
        moon: String.fromCodePoint(0xF0F65),
        lock: String.fromCodePoint(0xF033E),
        close: String.fromCodePoint(0xF0156),
        arrowRight: String.fromCodePoint(0xF0054),
        download: String.fromCodePoint(0xF01DA),
        store: String.fromCodePoint(0xF04DC),
        apps: String.fromCodePoint(0xF003B),
        web: String.fromCodePoint(0xF059F),
        document: String.fromCodePoint(0xF0219),
        movie: String.fromCodePoint(0xF0381),
        gamepad: String.fromCodePoint(0xF0297),
        code: String.fromCodePoint(0xF0169),
        github: String.fromCodePoint(0xF02A4),
        openExternal: String.fromCodePoint(0xF03CC),
        keyboard: String.fromCodePoint(0xF030C),
        clock: String.fromCodePoint(0xF0150),
        users: String.fromCodePoint(0xF000E),
        chip: String.fromCodePoint(0xF061A),
        plus: String.fromCodePoint(0xF0415),
        delete: String.fromCodePoint(0xF01B4),
        defaultApps: String.fromCodePoint(0xF08C6), // application
        desktop: String.fromCodePoint(0xF10A9), // dock-bottom
        wallpaper: String.fromCodePoint(0xF02F5), // image-filter-hdr
        nightLight: String.fromCodePoint(0xF059A), // weather-sunset
        record: String.fromCodePoint(0xF044A),
        chevronDown: String.fromCodePoint(0xF0140),
        headphones: String.fromCodePoint(0xF02CB),
        mouse: String.fromCodePoint(0xF037D),
        phone: String.fromCodePoint(0xF011C),
        laptop: String.fromCodePoint(0xF0322),
        mapMarker: String.fromCodePoint(0xF034E),
        startup: String.fromCodePoint(0xF14DE), // rocket-launch
        printer: String.fromCodePoint(0xF042A),
        vpn: String.fromCodePoint(0xF099D), // shield-lock
        disk: String.fromCodePoint(0xF02CA), // harddisk
        backup: String.fromCodePoint(0xF02DA), // history
        usbDrive: String.fromCodePoint(0xF129E),
        star: String.fromCodePoint(0xF04CE),
        starHalf: String.fromCodePoint(0xF04D0),
        starOutline: String.fromCodePoint(0xF04D2)
    })

    // Glass, rim and gloss for a tint: "frost" (light: whiter, frosted), "pitch" (dark: OLED
    // black) or "neon" (dark: deep violet with an accent-coloured rim); anything else, or a
    // tint used in the other mode, is divineOS's own.
    function tintColors(tint, dark, accent) {
        if (dark && tint === "pitch")
            return { glass: Qt.rgba(0, 0, 0, 0.78), rim: Qt.rgba(1, 1, 1, 0.12), gloss: 0.04 };
        if (dark && tint === "neon")
            return { glass: Qt.rgba(0.07, 0.02, 0.15, 0.55), rim: Qt.rgba(accent.r, accent.g, accent.b, 0.7), gloss: 0.08 };
        if (!dark && tint === "frost")
            return { glass: Qt.rgba(1, 1, 1, 0.62), rim: Qt.rgba(1, 1, 1, 0.95), gloss: 0.5 };
        return dark ? { glass: Qt.rgba(0.09, 0.11, 0.19, 0.42), rim: Qt.rgba(1, 1, 1, 0.28), gloss: 0.13 }
                    : { glass: Qt.rgba(1, 1, 1, 0.45), rim: Qt.rgba(1, 1, 1, 0.8), gloss: 0.35 };
    }

    // WCAG relative luminance, 0 (black) to 1 (white)
    function luminance(c) {
        const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    // battery-outline, battery-10 … battery-90, battery (full)
    function batteryIcon(fraction) {
        const tenths = Math.round(fraction * 10);
        return String.fromCodePoint(tenths >= 10 ? 0xF0079 : tenths <= 0 ? 0xF008E : 0xF0079 + tenths);
    }

    // wifi-strength-1 … 4, each followed by its -alert and -lock forms
    function wifiIcon(strength, locked) {
        return String.fromCodePoint(0xF091F + 3 * Math.min(3, Math.floor(strength * 4)) + (locked ? 2 : 0));
    }
}
