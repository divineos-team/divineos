.pragma library

// Dock helpers for Sys.qml and DockContent.qml. Checked by ../test-js.mjs.

// Pins after dragging `id` onto `target`'s place. Pins the dock doesn't show stay where they are.
function movePin(pinned, id, target) {
    if (id === target)
        return pinned.slice();
    const order = pinned.filter(p => p !== id);
    order.splice(order.indexOf(target) + (pinned.indexOf(id) < pinned.indexOf(target) ? 1 : 0), 0, id);
    return order;
}

const images = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif"];
const kinds = [
    [["pdf"], "application-pdf"],
    [["zip", "tar", "gz", "tgz", "xz", "zst", "bz2", "7z", "rar"], "package-x-generic"],
    [["iso", "img"], "media-optical"],
    [["mp3", "flac", "ogg", "opus", "wav", "m4a"], "audio-x-generic"],
    [["mp4", "mkv", "webm", "mov", "avi"], "video-x-generic"],
    [["appimage", "deb", "rpm", "exe", "msi", "sh"], "application-x-executable"],
    [images, "image-x-generic"]
];

function extension(name) {
    const m = name.match(/\.([^.]+)$/);
    return m ? m[1].toLowerCase() : "";
}

// Pictures in the Downloads stack show themselves.
function isImage(name) {
    return images.includes(extension(name));
}

// A freedesktop icon name for a file in the Downloads stack.
function fileIcon(name, dir) {
    if (dir)
        return "folder";
    const kind = kinds.find(k => k[0].includes(extension(name)));
    return kind ? kind[1] : "text-x-generic";
}
