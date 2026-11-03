pragma Singleton
import QtQuick
import Quickshell

// divineDE tokens for devine-files, matching divine-shell's. `dark` follows the desktop's
// color-scheme (shell.qml keeps it in sync); the window's acrylic blur comes from Hyprland.
Singleton {
    property bool dark: true

    readonly property string font: "Inter"
    readonly property string iconFont: "Symbols Nerd Font"

    readonly property color text: dark ? "#ffffff" : "#1d1d1f"
    readonly property color textDim: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)
    readonly property color window: dark ? Qt.rgba(0.07, 0.08, 0.14, 0.74) : Qt.rgba(0.95, 0.96, 0.98, 0.76)
    readonly property color glass: dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.6)
    readonly property color rim: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07)
    readonly property real gloss: dark ? 0.04 : 0.2
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color marked: Qt.rgba(0.04, 0.52, 1, 0.3)
    readonly property color accent: "#0A84FF"
    readonly property color folder: "#4FA3FF"
    readonly property color danger: "#FF453A"

    readonly property int radius: 14

    // git badge colours: untracked/added green, modified orange, renamed cyan, deleted/conflict red
    readonly property var gitColors: ({ U: "#30D158", A: "#30D158", M: "#FF9F0A", R: "#64D2FF", D: "#FF453A", C: "#FF453A" })

    // Material Design glyphs from Symbols Nerd Font
    readonly property var icons: ({
        folder: String.fromCodePoint(0xF024B),
        file: String.fromCodePoint(0xF0214),
        document: String.fromCodePoint(0xF09EE),
        image: String.fromCodePoint(0xF021F),
        audio: String.fromCodePoint(0xF0223),
        video: String.fromCodePoint(0xF022B),
        archive: String.fromCodePoint(0xF05C4),
        code: String.fromCodePoint(0xF022E),
        pdf: String.fromCodePoint(0xF0226),
        sheet: String.fromCodePoint(0xF0C7E),
        home: String.fromCodePoint(0xF02DC),
        desktop: String.fromCodePoint(0xF01C4),
        download: String.fromCodePoint(0xF01DA),
        pictures: String.fromCodePoint(0xF02E9),
        music: String.fromCodePoint(0xF075A),
        videos: String.fromCodePoint(0xF0567),
        disk: String.fromCodePoint(0xF02CA),
        back: String.fromCodePoint(0xF004D),
        forward: String.fromCodePoint(0xF0054),
        up: String.fromCodePoint(0xF005D),
        chevron: String.fromCodePoint(0xF0142),
        git: String.fromCodePoint(0xF02A2)
    })

    readonly property var kinds: ({
        image: ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "avif", "ico", "tif", "tiff", "heic"],
        audio: ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac"],
        video: ["mp4", "mkv", "webm", "mov", "avi"],
        archive: ["zip", "tar", "gz", "tgz", "xz", "txz", "bz2", "tbz", "zst", "tzst", "7z", "rar", "iso", "cpio", "deb", "rpm", "jar"],
        code: ["c", "h", "cpp", "hpp", "rs", "go", "py", "js", "ts", "tsx", "jsx", "qml", "lua", "sh", "bash", "zsh", "fish", "java", "kt", "rb", "php", "cs", "swift", "json", "toml", "yaml", "yml", "xml", "html", "css", "ini", "conf", "nix"],
        pdf: ["pdf"],
        sheet: ["csv", "tsv", "xlsx", "xls", "ods"],
        document: ["txt", "md", "rst", "doc", "docx", "odt", "rtf", "log", "tex"]
    })
    // Thumbnailable by Qt's image plugins without a thumbnailer
    readonly property var thumbable: ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp"]

    function kindOf(suffix) {
        const s = suffix.toLowerCase();
        for (const k in kinds)
            if (kinds[k].includes(s))
                return k;
        return "file";
    }
    // What devine-files-op can extract (bsdtar)
    function isArchive(name) {
        return /\.(tar(\.[a-z0-9]+)?|t[gbx]z|tzst|zip|7z|rar|iso|cpio|xpi|jar|apk|deb|rpm)$/i.test(name);
    }
}
