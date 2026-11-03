.pragma library

// The sidebar's own places: GTK bookmarks (~/.config/gtk-3.0/bookmarks, shared with GTK apps,
// one "file:///path Label" per line) and gvfs network mounts.

function decode(s) {
    try {
        return decodeURIComponent(s);
    } catch (e) {
        return s;
    }
}

// Local-folder bookmarks: [{ path, label }]. Other lines (sftp://… bookmarks) are kept but not shown.
function bookmarks(text) {
    const out = [];
    for (const line of text.split("\n")) {
        const m = line.match(/^file:\/\/(\/\S*)(?: (.+))?$/);
        if (m) {
            const path = decode(m[1]);
            out.push({ path, label: m[2] || path.split("/").pop() || "/" });
        }
    }
    return out;
}

function addBookmark(text, path) {
    if (bookmarks(text).some(b => b.path === path))
        return text;
    const lines = text.split("\n").filter(l => l);
    return lines.concat(["file://" + path.split("/").map(encodeURIComponent).join("/")]).join("\n") + "\n";
}

function removeBookmark(text, path) {
    const lines = text.split("\n").filter(l => l && bookmarks(l).every(b => b.path !== path));
    return lines.length ? lines.join("\n") + "\n" : "";
}

// gvfs names its mounts like "smb-share:server=nas,share=photos" or "sftp:host=box,user=me".
function mountLabel(name) {
    const keys = {};
    for (const part of name.slice(name.indexOf(":") + 1).split(",")) {
        const i = part.indexOf("=");
        if (i > 0)
            keys[part.slice(0, i)] = decode(part.slice(i + 1));
    }
    const host = keys.server ?? keys.host;
    return !host ? name : keys.share ? `${keys.share} on ${host}` : host;
}
