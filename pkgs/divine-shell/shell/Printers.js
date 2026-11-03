.pragma library

// Settings > Printers: what `lpstat -e`, `lpstat -p` and `lpstat -d` print (LC_ALL=C), each
// after an @@e, @@p or @@d line → [{ name, state, added, isDefault }]. `lpstat -e` also lists
// the driverless printers CUPS found on the network, which work without being added.
// Checked by ../test-js.mjs.
function printers(text) {
    const lines = { e: [], p: [], d: [] };
    let section = "";
    for (const line of text.split("\n")) {
        if (/^@@[epd]$/.test(line))
            section = line[2];
        else if (line && lines[section])
            lines[section].push(line);
    }
    const states = {};
    for (const line of lines.p) {
        const m = line.match(/^printer (\S+) (?:is )?(\w+)/); // "is idle.", "now printing X-3.", "disabled since"
        if (m)
            states[m[1]] = m[2] === "now" ? "printing" : m[2];
    }
    const fallback = (lines.d[0] ?? "").match(/destination: (\S+)/)?.[1] ?? "";
    return Array.from(new Set(lines.e.concat(Object.keys(states)))).sort().map(name => ({
        name,
        state: states[name] ?? "idle",
        added: name in states,
        isDefault: name === fallback
    }));
}
