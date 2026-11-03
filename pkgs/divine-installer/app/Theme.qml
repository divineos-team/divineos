pragma Singleton
import QtQuick
import Quickshell

// divineDE tokens for the installer, matching divine-shell's. `dark` follows the desktop's
// color-scheme (shell.qml keeps it in sync); the window's acrylic blur comes from Hyprland.
Singleton {
    property bool dark: true

    readonly property string font: "Inter"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property string mono: "JetBrainsMono Nerd Font"

    readonly property color text: dark ? "#ffffff" : "#1d1d1f"
    readonly property color textDim: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)
    readonly property color window: dark ? Qt.rgba(0.07, 0.08, 0.14, 0.74) : Qt.rgba(0.95, 0.96, 0.98, 0.76)
    readonly property color glass: dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.6)
    readonly property color rim: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07)
    readonly property real gloss: dark ? 0.04 : 0.2
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color off: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color accent: "#0A84FF"
    readonly property color other: "#5E5CE6" // the other system's share of a split disk
    readonly property color danger: "#FF453A"
    readonly property color good: "#30D158"

    readonly property int radius: 14

    // Material Design glyphs from Symbols Nerd Font
    readonly property var icons: ({
        install: String.fromCodePoint(0xF01DA),
        disk: String.fromCodePoint(0xF02CA),
        erase: String.fromCodePoint(0xF01FE),
        alongside: String.fromCodePoint(0xF084C),
        replace: String.fromCodePoint(0xF04E1),
        manual: String.fromCodePoint(0xF1064),
        region: String.fromCodePoint(0xF01E7),
        clock: String.fromCodePoint(0xF0150),
        language: String.fromCodePoint(0xF05CA),
        keyboard: String.fromCodePoint(0xF030C),
        account: String.fromCodePoint(0xF0004),
        summary: String.fromCodePoint(0xF0756),
        done: String.fromCodePoint(0xF05E0),
        alert: String.fromCodePoint(0xF0026),
        lock: String.fromCodePoint(0xF033E),
        wifi: String.fromCodePoint(0xF05A9),
        wifiOff: String.fromCodePoint(0xF05AA),
        windows: String.fromCodePoint(0xF05B3),
        linux: String.fromCodePoint(0xF033D),
        check: String.fromCodePoint(0xF012C),
        restart: String.fromCodePoint(0xF0709),
        search: String.fromCodePoint(0xF0349)
    })
}
