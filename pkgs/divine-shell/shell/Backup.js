.pragma library

// Settings > Backup: Timeshift's snapshot table (`timeshift --list`), newest first.
//   Num     Name                 Tags  Description
//   ------------------------------------------------------------
//   0    >  2026-11-01_09-12-44  D     Before update
// Columns are where the header puts them; names are always timestamps.
function snapshots(text) {
    const lines = text.split("\n");
    const head = lines.findIndex(l => /^Num\s+Name\s+Tags\s+Description/.test(l));
    if (head < 0)
        return [];
    const h = lines[head], tags = h.indexOf("Tags"), desc = h.indexOf("Description");
    const out = [];
    for (const line of lines.slice(head + 1)) {
        const m = line.match(/(\d{4})-(\d\d)-(\d\d)_(\d\d)-(\d\d)-(\d\d)/);
        if (!m || !/^\d+\s/.test(line))
            continue;
        out.push({
            name: m[0],
            date: new Date(+m[1], m[2] - 1, +m[3], +m[4], +m[5], +m[6]),
            tags: line.slice(tags, desc).trim(),
            description: line.slice(desc).trim()
        });
    }
    return out.reverse();
}

// How a snapshot came to be: its description, or what its Timeshift tags mean.
function kind(s) {
    if (s.description)
        return s.description;
    const names = { O: "Made by hand", B: "At startup", H: "Hourly", D: "Daily", W: "Weekly", M: "Monthly" };
    return s.tags.split("").map(t => names[t]).filter(n => n).join(", ") || "Snapshot";
}
