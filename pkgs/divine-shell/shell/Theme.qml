pragma Singleton
import QtQuick
import Quickshell

// divineDE design tokens. Glass colours are tints only: the compositor's acrylic
// blur supplies the refraction behind every translucent pixel.
Singleton {
    property bool dark: true // Sys binds this to the saved setting; the greeter keeps dark

    readonly property string font: "Inter"
    readonly property string iconFont: "Symbols Nerd Font"

    readonly property color text: dark ? "#ffffff" : "#1d1d1f"
    readonly property color textDim: dark ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(0, 0, 0, 0.5)
    readonly property color glass: dark ? Qt.rgba(0.09, 0.11, 0.19, 0.42) : Qt.rgba(1, 1, 1, 0.45)
    readonly property color rim: dark ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.8)
    readonly property real gloss: dark ? 0.13 : 0.35
    readonly property color off: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color track: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12)
    readonly property color fill: dark ? "#ffffff" : accent
    readonly property color accent: "#0A84FF"
    readonly property color danger: "#FF453A"
    // The menu bar floats straight on the wallpaper; Tide's sky is mid-blue up top.
    readonly property color barText: "#ffffff"

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
        download: String.fromCodePoint(0xF01DA)
    })

    // battery-outline, battery-10 … battery-90, battery (full)
    function batteryIcon(fraction) {
        const tenths = Math.round(fraction * 10);
        return String.fromCodePoint(tenths >= 10 ? 0xF0079 : tenths <= 0 ? 0xF008E : 0xF0079 + tenths);
    }
}
