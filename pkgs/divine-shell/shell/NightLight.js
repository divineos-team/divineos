.pragma library

// Night Light's schedule for Sys.qml: whether a time falls in it, and hyprsunset.conf.
// Checked by ../test-js.mjs.

// schedule: { from: "21:00", to: "7:00" }; one that ends before it starts runs past midnight.
function inWindow(schedule, date) {
    const minutes = t => t.split(":").reduce((h, m) => h * 60 + +m);
    const now = date.getHours() * 60 + date.getMinutes(), from = minutes(schedule.from), to = minutes(schedule.to);
    return from <= to ? now >= from && now < to : now >= from || now < to;
}

// Off at `to`, warm at `from`. Without a schedule, a midnight switch that only calls back.
// Every switch runs `sync`, so the shell's toggles follow.
function conf(schedule, kelvin, sync) {
    const profile = (time, look) => ["profile {", `    time = ${time}`, `    ${look}`, `    on-switch = ${sync}`, "}"];
    const body = schedule ? profile(schedule.to, "identity = true").concat([""], profile(schedule.from, `temperature = ${kelvin}`))
        : profile("0:00", "identity = true");
    return ["# Written by divineOS (Settings > Displays > Night Light); edits here are overwritten.", ""].concat(body).join("\n") + "\n";
}
