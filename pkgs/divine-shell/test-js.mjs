// Checks the shell's plain-JavaScript helpers (shell/*.js) on made-up input: node test-js.mjs
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const load = (file, names) => {
    const src = readFileSync(new URL(`shell/${file}`, import.meta.url), "utf8").replace(/^\.pragma library$/m, "");
    return new Function(`${src}; return { ${names} };`)();
};

// Palette.js: the wallpaper accent picker
{
    const { accentFromPixels, hsv, rgb } = load("Palette.js", "accentFromPixels, hsv, rgb");
    // A picture of `n` pixels of each [r, g, b] colour.
    const picture = (...parts) => parts.flatMap(([n, c]) => Array.from({ length: n }, () => [...c, 255]).flat());
    const hue = c => Math.round(hsv(...[1, 3, 5].map(i => parseInt(c.slice(i, i + 2), 16) / 255))[0] * 360);

    assert.deepEqual(rgb(...hsv(0.2, 0.4, 0.6)).map(x => +x.toFixed(6)), [0.2, 0.4, 0.6]);
    const tide = accentFromPixels(picture([60, [59, 130, 246]], [30, [220, 230, 243]], [10, [255, 255, 255]]));
    assert.ok(hue(tide) > 210 && hue(tide) < 225, `blue sea, light sky: ${tide}`);
    const ember = accentFromPixels(picture([20, [249, 115, 22]], [70, [30, 30, 30]], [10, [234, 88, 12]]));
    assert.ok(hue(ember) > 18 && hue(ember) < 30, `orange on dark grey: ${ember}`);
    assert.equal(accentFromPixels(picture([99, [128, 128, 128]], [1, [10, 200, 10]])), "#8e8e93", "grey with a speck of green");
    // Saturation and brightness are an accent's, whatever the picture's were.
    const pastel = hsv(...[1, 3, 5].map(i => parseInt(accentFromPixels(picture([100, [200, 170, 230]])).slice(i, i + 2), 16) / 255));
    assert.ok(pastel[1] >= 0.54 && Math.abs(pastel[2] - 0.92) < 0.01, `pastel lilac: ${pastel}`);
}

// Weather.js: Open-Meteo answers → what the bar shows
{
    const { describe, fromForecast, places, zoneCity, forecastUrl } = load("Weather.js", "describe, fromForecast, places, zoneCity, forecastUrl");
    assert.equal(zoneCity("America/Argentina/Buenos_Aires"), "Buenos Aires");
    assert.equal(zoneCity("Europe/Berlin\n"), "Berlin");
    assert.equal(zoneCity("UTC"), "");
    assert.equal(zoneCity("Etc/GMT+3"), "");
    assert.deepEqual(describe(0, false), { label: "Clear", glyph: String.fromCodePoint(0xF0594) }, "a clear night shows the moon");
    assert.equal(describe(3, false).glyph, String.fromCodePoint(0xF0590), "clouds look the same at night");
    assert.equal(describe(1234, true).label, "", "an unknown code");
    assert.match(forecastUrl(52.5, 13.4, true), /latitude=52.5&longitude=13.4.*temperature_unit=fahrenheit/);

    const w = fromForecast({ // trimmed from a real answer
        current: { temperature_2m: 9.6, weather_code: 2, is_day: 1 },
        daily: { time: ["2026-11-03", "2026-11-04"], weather_code: [3, 61], temperature_2m_max: [9.8, 9.7], temperature_2m_min: [3.9, 4.7] }
    });
    assert.equal(w.temp, 10);
    assert.equal(w.label, "Partly Cloudy");
    assert.deepEqual([w.high, w.low], [10, 4]);
    assert.deepEqual(w.days.map(d => [d.date, d.label, d.high, d.low]), [["2026-11-03", "Cloudy", 10, 4], ["2026-11-04", "Rain", 10, 5]]);

    assert.deepEqual(places({ results: [{ name: "Buenos Aires", latitude: -34.6, longitude: -58.4, country: "Argentina", admin1: "Buenos Aires F.D." }, { name: "Berlin", latitude: 52.5, longitude: 13.4, country: "Germany", admin1: "Berlin" }] }),
        [{ name: "Buenos Aires", detail: "Buenos Aires F.D., Argentina", lat: -34.6, lon: -58.4 }, { name: "Berlin", detail: "Germany", lat: 52.5, lon: 13.4 }]);
    assert.deepEqual(places({}), [], "no match");
}

// NightLight.js: the schedule and hyprsunset.conf
{
    const { inWindow, conf } = load("NightLight.js", "inWindow, conf");
    const at = (h, m) => new Date(2026, 10, 3, h, m);
    const night = { from: "21:00", to: "7:00" };
    assert.ok(inWindow(night, at(23, 30)) && inWindow(night, at(2, 0)) && inWindow(night, at(21, 0)), "overnight");
    assert.ok(!inWindow(night, at(7, 0)) && !inWindow(night, at(12, 0)) && !inWindow(night, at(20, 59)), "daytime");
    const day = { from: "13:00", to: "17:30" };
    assert.ok(inWindow(day, at(17, 29)) && !inWindow(day, at(17, 30)) && !inWindow(day, at(9, 0)), "same day");

    const c = conf(night, 3800, "qs ipc call nightlight sync");
    assert.match(c, /profile \{\n    time = 7:00\n    identity = true\n    on-switch = qs ipc call nightlight sync\n\}/);
    assert.match(c, /time = 21:00\n    temperature = 3800\n/);
    assert.equal(conf(null, 3800, "x").match(/profile/g).length, 1, "by hand: one profile");
    assert.match(conf(null, 3800, "x"), /time = 0:00\n    identity = true/);
}
// Dock.js: dragging pins, and the Downloads stack's icons
{
    const { movePin, isImage, fileIcon } = load("Dock.js", "movePin, isImage, fileIcon");
    const pins = ["divine-install", "files", "kitty", "store", "settings"]; // divine-install isn't shown outside the live ISO
    assert.deepEqual(movePin(pins, "files", "store"), ["divine-install", "kitty", "store", "files", "settings"], "to the right");
    assert.deepEqual(movePin(pins, "settings", "kitty"), ["divine-install", "files", "settings", "kitty", "store"], "to the left");
    assert.deepEqual(movePin(pins, "kitty", "kitty"), pins, "back where it was");
    assert.ok(isImage("Screenshot.PNG") && !isImage("notes.txt") && !isImage("png"));
    assert.equal(fileIcon("divineOS.iso", false), "media-optical");
    assert.equal(fileIcon("photos", true), "folder");
    assert.equal(fileIcon("backup.tar.zst", false), "package-x-generic");
    assert.equal(fileIcon("README", false), "text-x-generic");
}

// Units.js: the launcher's conversions
{
    const { convert } = load("Units.js", "convert");
    assert.equal(convert("10 km to mi"), "6.21371 mi");
    assert.equal(convert("72 F in C"), "22.2222 C");
    assert.equal(convert("0 celsius to fahrenheit"), "32 fahrenheit");
    assert.equal(convert("1 gib to mb"), "1073.74 mb");
    assert.equal(convert("5 kg to lbs"), "11.0231 lbs");
    assert.equal(convert("100 km/h to mph"), "62.1371 mph");
    assert.equal(convert("3 kg to km"), "", "different kinds");
    assert.equal(convert("firefox"), "");
}
// Autostart.js: Settings > Startup Apps
{
    const { entries } = load("Autostart.js", "entries");
    const text = `== /etc/xdg/autostart/nm-applet.desktop
[Desktop Entry]
Type=Application
Name=Network
Name[de]=Netzwerk
Icon=nm-device-wireless
== /etc/xdg/autostart/gnome-keyring.desktop
[Desktop Entry]
Type=Application
Name=Keyring
OnlyShowIn=GNOME;Unity;
== /etc/xdg/autostart/at-spi.desktop
[Desktop Entry]
Type=Application
Name=AT-SPI
NoDisplay=true
== /etc/xdg/autostart/kde-only.desktop
[Desktop Entry]
Type=Application
Name=Hypr
OnlyShowIn=KDE;Hyprland;
== /home/devine/.config/autostart/nm-applet.desktop
[Desktop Entry]
Hidden=true
Type=Application
Name=Network
== /home/devine/.config/autostart/discord.desktop
[Desktop Entry]
Type=Application
Name=Discord
X-GNOME-Autostart-enabled=false
[Desktop Action new]
Name=New Window
`;
    assert.deepEqual(entries(text, "Hyprland"), [
        { file: "discord.desktop", name: "Discord", icon: "", on: false, own: true },
        { file: "kde-only.desktop", name: "Hypr", icon: "", on: true, own: false },
        { file: "nm-applet.desktop", name: "Network", icon: "", on: false, own: false }
    ], "the user's copy overrides; other desktops' and hidden entries are left out");
    assert.deepEqual(entries("", "Hyprland"), []);
}
// Printers.js: Settings > Printers
{
    const { printers } = load("Printers.js", "printers");
    const text = "@@e\nBrother_HL_L2350DW\nHP_OfficeJet_Pro_9010_3A2B1C\nOffice\n@@p\n" +
        "printer HP_OfficeJet_Pro_9010_3A2B1C now printing HP_OfficeJet_Pro_9010_3A2B1C-3.  enabled since Tue 03 Nov 2026 10:00:00 AM CET\n" +
        "printer Office disabled since Mon 02 Nov 2026 09:00:00 AM CET -\n\treason unknown\n" +
        "@@d\nsystem default destination: Office\n";
    assert.deepEqual(printers(text), [
        { name: "Brother_HL_L2350DW", state: "idle", added: false, isDefault: false },
        { name: "HP_OfficeJet_Pro_9010_3A2B1C", state: "printing", added: true, isDefault: false },
        { name: "Office", state: "disabled", added: true, isDefault: true }
    ]);
    assert.deepEqual(printers("@@e\n@@p\n@@d\nno system default destination\n"), [], "no printers");
}
// StoreInfo.js: the Store's app pages and GitHub search
{
    const { info, plain, stars, count, github, githubInstalled } = load("StoreInfo.js", "info, plain, stars, count, github, githubInstalled");
    const arch = JSON.stringify({ results: [{ pkgname: "gimp-help", pkgver: "1", pkgrel: "1" }, { pkgname: "gimp", pkgver: "3.0.4", pkgrel: "2", epoch: 0, pkgdesc: "GNU Image Manipulation Program", url: "https://gimp.org" }] });
    const flathub = JSON.stringify({
        id: "org.gimp.GIMP",
        description: "<p>GIMP is an image editor.</p><ul><li>Layers</li><li>Filters &amp; more</li></ul>",
        releases: [{ version: "3.0.4" }],
        screenshots: [{ sizes: [{ src: "small.png", width: "624" }, { src: "big.png", width: "1248" }] }, { sizes: { "1600x900": "old.png" } }, { sizes: [] }]
    });
    const odrs = JSON.stringify({ star0: 9, star1: 1, star2: 0, star3: 0, star4: 1, star5: 2, total: 13 });
    const got = info([arch, "", flathub, odrs, "{}"].join("\n@@\n"), "gimp");
    assert.equal(got.arch, "3.0.4-2");
    assert.equal(got.aur, "");
    assert.equal(got.flathub, "3.0.4");
    assert.deepEqual(got.screenshots, ["big.png", "old.png"]);
    assert.equal(got.description, "GIMP is an image editor.\n• Layers\n• Filters & more");
    assert.deepEqual(got.rating, { average: 3.75, total: 4 }, "star0 isn't a rating");
    assert.equal(got.homepage, "https://gimp.org");
    const aurOnly = info(["{}", JSON.stringify({ results: [{ Name: "yay", Version: "12.4-1", NumVotes: 2400, Description: "AUR helper" }] }), "", "", ""].join("\n@@\n"), "yay");
    assert.deepEqual([aurOnly.arch, aurOnly.aur, aurOnly.votes, aurOnly.flathub, aurOnly.description, aurOnly.rating], ["", "12.4-1", 2400, "", "AUR helper", null]);
    assert.equal(info("garbage", "x").arch, "", "offline or broken answers");
    const madison = " gimp-data | 3.0.4-1 | stable | all\n gimp      | 3.0.4-1+b1 | stable | amd64\n";
    assert.equal(info(["{}", "{}", "", "", "", madison].join("\n@@\n"), "gimp").debian, "3.0.4-1+b1", "Debian's version, not a similar name's");
    assert.equal(got.debian, "");
    assert.equal(plain(""), "");
    assert.deepEqual([stars(0), stars(9), stars(48213), stars(5e6)], [0, 1, 5, 5]);
    assert.deepEqual([count(999), count(48213), count(2.5e6)], ["999", "48.2k", "2.5M"]);
    const repos = JSON.stringify({ items: [
        { full_name: "sharkdp/bat", description: "A cat clone", stargazers_count: 50000, language: "Rust" },
        { full_name: "someone/dotfiles", description: null, stargazers_count: 3, language: "Shell" }
    ] });
    assert.deepEqual(github(repos), [{ repo: "sharkdp/bat", about: "A cat clone", stars: 50000, language: "Rust" }], "only what RepoStation can build");
    assert.deepEqual(githubInstalled(JSON.stringify([{ repo: "sharkdp/bat", commit: "0123456789abcdef", system: "Cargo", bins: ["bat"] }])), [{ repo: "sharkdp/bat", commit: "0123456", bins: ["bat"] }]);
    assert.deepEqual(githubInstalled(""), []);
}
// Disks.js: Settings > Disks
{
    const { disks, size, copied, fsName } = load("Disks.js", "disks, size, copied, fsName");
    const lsblk = JSON.stringify({ blockdevices: [
        { name: "nvme0n1", path: "/dev/nvme0n1", size: 512110190592, type: "disk", tran: "nvme", rm: false, hotplug: false, ro: false, model: "Samsung SSD 980 ", mountpoints: [null], children: [
            { name: "nvme0n1p1", path: "/dev/nvme0n1p1", size: 536870912, type: "part", fstype: "vfat", label: "EFI", mountpoints: ["/boot"] },
            { name: "nvme0n1p2", path: "/dev/nvme0n1p2", size: 511573319680, type: "part", fstype: "crypto_LUKS", label: null, mountpoints: [null], children: [
                { name: "root", path: "/dev/mapper/root", size: 511556542464, type: "crypt", fstype: "btrfs", mountpoints: ["/home", "/"] }] }] },
        { name: "sdb", path: "/dev/sdb", size: "32010928128", type: "disk", tran: "usb", rm: "1", hotplug: "1", ro: "0", model: null, mountpoints: [null], children: [
            { name: "sdb1", path: "/dev/sdb1", size: "32009879552", type: "part", fstype: "exfat", label: "STICK", mountpoints: ["/run/media/me/STICK"] }] },
        { name: "zram0", path: "/dev/zram0", size: 4294967296, type: "disk", mountpoints: ["[SWAP]"] },
        { name: "loop0", path: "/dev/loop0", size: 1000, type: "loop", mountpoints: ["/run/archiso/airootfs"] }
    ] });
    const [ssd, usb, ...rest] = disks(lsblk);
    assert.equal(rest.length, 0, "zram and loop devices aren't disks");
    assert.deepEqual([ssd.name, ssd.system, ssd.removable, ssd.parts.length], ["Samsung SSD 980", true, false, 2]);
    assert.deepEqual(ssd.parts[1].mounts, ["/home", "/"], "mounts inside an unlocked LUKS volume count");
    assert.equal(ssd.parts[1].system, true);
    assert.deepEqual([usb.name, usb.size, usb.usb, usb.removable, usb.readOnly, usb.system], ["USB Drive", 32010928128, true, true, false, false], "old lsblk: numbers and flags as strings");
    assert.deepEqual(usb.parts[0], { path: "/dev/sdb1", size: 32009879552, fstype: "exfat", label: "STICK", mounts: ["/run/media/me/STICK"], system: false });
    assert.deepEqual(disks("not json"), []);
    assert.deepEqual([size(32010928128), size(536870912), size(512)], ["32 GB", "537 MB", "512 B"]);
    assert.equal(copied("10485760 bytes (10 MB, 10 MiB) copied, 1 s\r524288000 bytes (524 MB, 500 MiB) copied, 3 s, 175 MB/s"), 524288000);
    assert.equal(copied("dd: starting"), -1);
    assert.deepEqual([fsName("vfat"), fsName(""), fsName("zfs_member")], ["FAT32", "Empty", "zfs_member"]);
}
// Backup.js: Settings > Backup
{
    const { snapshots, kind } = load("Backup.js", "snapshots, kind");
    const text = "Mounted '/dev/sda2' at '/run/timeshift/3046/backup'\nDevice : /dev/sda2\nMode   : BTRFS\nStatus : OK\n2 snapshots, 18.4 GB free\n\n" +
        "Num     Name                 Tags  Description\n" +
        "------------------------------------------------------------------------------\n" +
        "0    >  2026-11-01_09-12-44  D     Before update\n" +
        "1    >  2026-11-03_10-00-01  O     \n";
    const list = snapshots(text);
    assert.deepEqual(list.map(s => [s.name, s.tags, s.description, kind(s)]), [["2026-11-03_10-00-01", "O", "", "Made by hand"], ["2026-11-01_09-12-44", "D", "Before update", "Before update"]], "newest first");
    assert.equal(list[1].date.getHours(), 9);
    assert.deepEqual(snapshots("No snapshots found"), []);
}
console.log("shell js ok");
