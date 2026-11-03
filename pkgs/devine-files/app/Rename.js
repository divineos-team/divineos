.pragma library

// Renaming several files at once. Each keeps its extension (.tar.gz together, dotfiles whole,
// like devine-files-op's numbering). A result that isn't a valid name, or that another file in
// the batch has or gets, keeps the old name.
//   replace: every `a` in the name (without extension) becomes `b`
//   number:  "`a` 1", "`a` 2"… counting from `b` (default 1), zero-padded to one width

function split(name) {
    const m = name.match(/^(.+)(\.tar\.[^.]+)$/) || name.match(/^(.+)(\.[^./]+)$/);
    return m ? [m[1], m[2]] : [name, ""];
}

function bulkNames(names, mode, a, b) {
    const start = parseInt(b, 10), first = isNaN(start) ? 1 : start;
    const width = String(first + names.length - 1).length, base = a.trim() || "File";
    const used = new Set();
    return names.map((name, i) => {
        const [stem, ext] = split(name);
        const next = mode === "number" ? `${base} ${String(first + i).padStart(width, "0")}${ext}` : a ? stem.split(a).join(b) + ext : name;
        const ok = next.trim() !== "" && next !== "." && next !== ".." && !next.includes("/") && !used.has(next) && (next === name || !names.includes(next));
        used.add(ok ? next : name);
        return ok ? next : name;
    });
}
