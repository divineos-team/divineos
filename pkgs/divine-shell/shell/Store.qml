import QtQuick
import Quickshell
import Quickshell.Io
import "StoreInfo.js" as StoreInfo

// devine-store: apps from the Arch repos, Flathub, the AUR and GitHub, and system updates. Repo
// packages go through the polkit-guarded /usr/lib/divine-pkg/pkg-helper; Flathub apps install
// for this user; AUR ones build with paru in a terminal; GitHub ones build in the background
// with RepoStation. Updates are checked every 6 hours (menu bar badge, notification).
// Toggle: `devine-store` (IPC); `devine-store updates` opens the Updates tab.
FloatingWindow {
    id: win

    readonly property string helper: "/usr/lib/divine-pkg/pkg-helper"
    readonly property var featured: [
        ["firefox", "Firefox", "Internet", "Fast, private web browsing from Mozilla.", "org.mozilla.firefox"],
        ["chromium", "Chromium", "Internet", "The open-source browser Google Chrome is built on.", "org.chromium.Chromium"],
        ["thunderbird", "Thunderbird", "Internet", "Email, calendars and contacts.", "org.mozilla.Thunderbird"],
        ["telegram-desktop", "Telegram", "Internet", "Messaging that syncs across all your devices.", "org.telegram.desktop"],
        ["signal-desktop", "Signal", "Internet", "Private messaging, encrypted end to end.", "org.signal.Signal"],
        ["discord", "Discord", "Internet", "Voice, video and text chat for communities.", "com.discordapp.Discord"],
        ["libreoffice-fresh", "LibreOffice", "Office", "Documents, spreadsheets and slides. Opens Microsoft Office files.", "org.libreoffice.LibreOffice"],
        ["obsidian", "Obsidian", "Office", "Notes in plain Markdown files, linked together.", "md.obsidian.Obsidian"],
        ["keepassxc", "KeePassXC", "Office", "A password manager that keeps everything on this computer.", "org.keepassxc.KeePassXC"],
        ["gimp", "GIMP", "Graphics", "Photo editing and retouching.", "org.gimp.GIMP"],
        ["inkscape", "Inkscape", "Graphics", "Vector drawing and SVG editing.", "org.inkscape.Inkscape"],
        ["krita", "Krita", "Graphics", "Digital painting and illustration.", "org.kde.krita"],
        ["blender", "Blender", "Graphics", "3D modelling, animation and rendering.", "org.blender.Blender"],
        ["vlc", "VLC", "Media", "Plays almost any video or audio file.", "org.videolan.VLC"],
        ["obs-studio", "OBS Studio", "Media", "Screen recording and live streaming.", "com.obsproject.Studio"],
        ["kdenlive", "Kdenlive", "Media", "Video editing on a timeline.", "org.kde.kdenlive"],
        ["audacity", "Audacity", "Media", "Record and edit audio.", "org.audacityteam.Audacity"],
        ["supertuxkart", "SuperTuxKart", "Games", "Kart racing with Tux and friends.", "net.supertuxkart.SuperTuxKart"],
        ["0ad", "0 A.D.", "Games", "Real-time strategy through ancient history.", "com.play0ad.zeroad"],
        ["code", "Code - OSS", "Development", "The open-source build of Visual Studio Code.", ""],
        ["godot", "Godot", "Development", "An engine for 2D and 3D games.", "org.godotengine.Godot"]
    ].map(([pkg, name, category, about, flatpak]) => ({ pkg, name, category, about, flatpak }))
    readonly property var banners: [
        ["blender", "Model, sculpt, animate and render in 3D. Free, and used for films.", "#E87D0D", "#265787"],
        ["obs-studio", "Record your screen or go live, with scenes, sources and filters.", "#5B3FA8", "#1E2A4A"],
        ["krita", "Paint and sketch with brushes made by artists, for artists.", "#D8336E", "#3B3F9E"],
        ["godot", "Make your own 2D and 3D games, and ship them everywhere.", "#478CBF", "#24395C"]
    ].map(([pkg, tagline, from, to]) => Object.assign({ tagline, from, to }, featured.find(f => f.pkg === pkg)))

    property var installedNames: []
    property var owners: ({}) // desktop entry id → the package that ships it
    property var flatpaks: [] // installed Flatpak app ids
    property var debs: ({}) // Debian packages installed through divine-pkg: pkg → their desktop entry ids
    property var updates: [] // { name, from, to, kind: repo | aur | flatpak | github, aur }
    property int announced: 0 // the update count the last notification told about
    property string query: ""
    property var repoResults: []
    property var aurResults: []
    property var queue: [] // Update All: the jobs still to run, [what, command]

    function toggle() {
        visible = !visible;
        if (visible)
            refresh();
    }
    function show(page) {
        content.page = page;
        visible = true;
        refresh();
    }
    function refresh() {
        installedProc.running = true;
        ownersProc.running = true;
        lastProc.running = true;
        flatpakProc.running = true;
        githubProc.running = true;
        debProc.running = true;
    }
    // Update All: the repos, then Flathub, then GitHub apps, one job after another; AUR apps
    // rebuild in a terminal at the end.
    function next() {
        if (!queue.length) {
            const aur = updates.some(u => u.aur);
            check();
            if (aur)
                inTerminal("Updating AUR apps", ["-Sua"]);
            return;
        }
        const [what, command] = queue[0];
        queue = queue.slice(1);
        opProc.start(what, command);
    }
    function check() {
        checkProc.running = true;
        newsProc.running = true;
    }
    // Background checks say so once per new count, unless the Store is already open.
    function announce() {
        const n = updates.length;
        if (n > 0 && n !== announced && !visible)
            Quickshell.execDetached(["sh", "-c", '[ "$(notify-send -a Store -i devine-store -A default=Open "$1" "Open the Store to install them.")" = default ] && devine-store updates', "sh", n === 1 ? "1 update available" : `${n} updates available`]);
        announced = n;
    }
    function inTerminal(title, args) { // paru asks its questions in the terminal
        if (termProc.running)
            return;
        termProc.command = ["kitty", "--title", title, "--hold", "paru"].concat(args);
        termProc.running = true;
    }

    title: "Store"
    visible: false
    onClosed: visible = false // closing from Hyprland (Super+Q) doesn't clear `visible` by itself
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    minimumSize: Qt.size(760, 520)
    color: Theme.glass

    Timer { // a minute after login, then every 6 hours
        running: true
        repeat: true
        interval: 60 * 1000
        onTriggered: {
            interval = 6 * 3600 * 1000;
            win.check();
        }
    }

    Process {
        id: installedProc
        command: ["pacman", "-Qq"]
        stdout: StdioCollector {
            onStreamFinished: win.installedNames = text.split("\n").filter(l => l)
        }
    }

    // "/usr/share/applications/gimp.desktop is owned by gimp 3.0.4-1"
    Process {
        id: ownersProc
        command: ["sh", "-c", "LC_ALL=C pacman -Qo /usr/share/applications/*.desktop 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const m of text.matchAll(/\/([^\/\n]+)\.desktop is owned by (\S+) /g))
                    map[m[1]] = m[2];
                win.owners = map;
            }
        }
    }

    Process {
        id: flatpakProc
        command: ["flatpak", "list", "--user", "--app", "--columns=application"]
        stdout: StdioCollector {
            onStreamFinished: win.flatpaks = text.split("\n").filter(l => l)
        }
        onExited: code => {
            if (code !== 0)
                win.flatpaks = [];
        }
    }
    // divine-pkg keeps one file per Debian package, listing what it exported ("app vlc"); on the
    // host the entries are named after the container (debian-vlc.desktop).
    Process {
        id: debProc
        command: ["sh", "-c", `for f in "\${XDG_DATA_HOME:-$HOME/.local/share}"/divine-pkg/debian/*; do [ -f "$f" ] && echo "\${f##*/}$(awk '$1 == "app" { printf " debian-%s", $2 }' "$f")"; done`]
        stdout: StdioCollector {
            onStreamFinished: win.debs = Object.fromEntries(text.split("\n").filter(l => l).map(l => l.split(" ")).map(([pkg, ...ids]) => [pkg, ids]))
        }
    }
    Process {
        id: githubProc
        command: ["sh", "-c", 'cat "${XDG_DATA_HOME:-$HOME/.local/share}/repostation/installed.json" 2>/dev/null']
        stdout: StdioCollector {
            onStreamFinished: content.githubInstalled = StoreInfo.githubInstalled(text)
        }
    }

    // checkupdates reads a private copy of the package lists: nothing changes until Update All.
    // Exit 1 means it couldn't check (2 is "no updates"). Then the AUR, Flathub and GitHub apps.
    Process {
        id: checkProc
        command: ["sh", "-c", "checkupdates; c=$?; echo '# aur'; paru -Qua 2>/dev/null; echo '# flatpak'; flatpak remote-ls --user --updates --app --columns=application,version 2>/dev/null; echo '# github'; repostation outdated 2>/dev/null; [ $c -ne 1 ]"]
        stdout: StdioCollector {
            onStreamFinished: {
                let kind = "repo";
                const list = [];
                for (const line of text.split("\n")) {
                    const section = line.match(/^# (aur|flatpak|github)$/);
                    if (section) {
                        kind = section[1];
                        continue;
                    }
                    const m = line.match(/^(\S+) (\S+) -> (\S+)/);
                    if (m && (kind === "repo" || kind === "aur"))
                        list.push({ name: m[1], from: m[2], to: m[3], kind, aur: kind === "aur" });
                    else if (line.trim() && kind === "flatpak")
                        list.push({ name: line.split("\t")[0], from: "", to: line.split("\t")[1] || "newer version", kind, aur: false });
                    else if (line.trim() && kind === "github")
                        list.push({ name: line.trim(), from: "", to: "new commits", kind, aur: false });
                }
                win.updates = list;
                win.announce();
            }
        }
        onExited: code => content.checkFailed = code !== 0
    }

    // An app's page: the Arch and AUR versions, then Flathub's AppStream data (screenshots,
    // description) and ODRS ratings when the app is on Flathub. StoreInfo.info() reads them.
    Process {
        id: infoProc
        property string pkg
        stdout: StdioCollector {
            onStreamFinished: if (content.detail?.pkg === infoProc.pkg)
                content.info = StoreInfo.info(text, infoProc.pkg)
        }
    }
    function details(app) {
        infoProc.running = false;
        infoProc.pkg = app.pkg;
        infoProc.command = ["sh", "-c", 'q() { curl -fsS --max-time 15 "$@" 2>/dev/null; }; ' +
            'q -G --data-urlencode "name=$1" https://archlinux.org/packages/search/json/; echo; echo @@; ' +
            'q -g -G --data-urlencode "arg[]=$1" https://aur.archlinux.org/rpc/v5/info; echo; echo @@; ' +
            '[ -n "$2" ] && q "https://flathub.org/api/v2/appstream/$2"; echo; echo @@; ' +
            '[ -n "$2" ] && q "https://odrs.gnome.org/1.0/reviews/api/ratings/$2"; echo; echo @@; ' +
            '[ -n "$2" ] && q "https://odrs.gnome.org/1.0/reviews/api/ratings/$2.desktop"; echo; echo @@; ' +
            'q -G --data-urlencode "package=$1" -d table=debian -d s=stable -d a=amd64 -d text=on https://qa.debian.org/madison.php; echo', "sh", app.pkg, app.flatpak ?? ""];
        infoProc.running = true;
    }

    // GitHub search, like RepoStation's: only languages it can build.
    Process {
        id: githubSearch
        property string terms
        command: ["curl", "-fsS", "--max-time", "15", "-G", "-H", "Accept: application/vnd.github+json", "--data-urlencode", "q=" + terms + " archived:false", "--data", "per_page=40", "https://api.github.com/search/repositories"]
        stdout: StdioCollector {
            onStreamFinished: content.githubResults = StoreInfo.github(text)
        }
        onExited: code => content.githubFailed = code !== 0
    }

    // "[2026-11-01T12:34:56+0100] [PACMAN] starting full system upgrade"
    Process {
        id: lastProc
        command: ["sh", "-c", "grep -h 'starting full system upgrade' /var/log/pacman.log | tail -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/^\[([^\]]+)\]/);
                if (m)
                    content.lastUpgrade = new Date(m[1].replace(/([+-]\d\d)(\d\d)$/, "$1:$2"));
            }
        }
    }

    Process {
        id: newsProc
        command: ["curl", "-fsS", "--max-time", "15", "https://archlinux.org/feeds/news/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const tag = (item, name) => (item.match(new RegExp(`<${name}>([\\s\\S]*?)</${name}>`)) ?? [])[1] ?? "";
                const unescape = s => s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&");
                content.news = (text.match(/<item>[\s\S]*?<\/item>/g) ?? []).slice(0, 3).map(item => ({
                            title: unescape(tag(item, "title")),
                            link: tag(item, "link"),
                            date: Qt.formatDate(new Date(tag(item, "pubDate")), "d MMM")
                        }));
            }
        }
    }

    // Search: the Arch package web search and the AUR's, so results don't wait for a package sync.
    Timer {
        id: searchDelay
        interval: 350
        onTriggered: {
            repoSearch.running = true;
            aurSearch.running = true;
        }
    }
    Process {
        id: repoSearch
        property string ran: ""
        command: ["curl", "-fsS", "--max-time", "15", "-G", "--data-urlencode", "q=" + win.query, "--data", "repo=Core&repo=Extra&arch=x86_64&arch=any", "https://archlinux.org/packages/search/json/"]
        onStarted: ran = win.query
        stdout: StdioCollector {
            onStreamFinished: {
                if (repoSearch.ran !== win.query)
                    return;
                const q = win.query.toLowerCase();
                const rank = p => p === q ? 0 : p.startsWith(q) ? 1 : p.includes(q) ? 2 : 3;
                const seen = new Set();
                let hits = [];
                try {
                    hits = JSON.parse(text).results;
                } catch (e) {}
                win.repoResults = hits.filter(r => !seen.has(r.pkgname) && seen.add(r.pkgname)).map(r => ({ pkg: r.pkgname, about: r.pkgdesc, aur: false, votes: 0 })).sort((a, b) => rank(a.pkg) - rank(b.pkg)).slice(0, 30);
            }
        }
        onExited: code => {
            content.searchFailed = code !== 0;
            if (ran !== win.query && win.query.length >= 2)
                running = true;
        }
    }
    Process {
        id: aurSearch
        property string ran: ""
        command: ["curl", "-fsS", "--max-time", "15", "https://aur.archlinux.org/rpc/v5/search/" + encodeURIComponent(win.query) + "?by=name-desc"]
        onStarted: ran = win.query
        stdout: StdioCollector {
            onStreamFinished: {
                if (aurSearch.ran !== win.query)
                    return;
                let hits = [];
                try {
                    hits = JSON.parse(text).results;
                } catch (e) {}
                win.aurResults = hits.sort((a, b) => b.Popularity - a.Popularity).slice(0, 15).map(r => ({ pkg: r.Name, about: r.Description ?? "", aur: true, votes: r.NumVotes }));
            }
        }
        onExited: {
            if (ran !== win.query && win.query.length >= 2)
                running = true;
        }
    }

    // One job at a time: pkg-helper (as root, through pkexec), flatpak, or a RepoStation build.
    // Its output is the Details log (View Build Logs for builds); pacman's "(3/12)" steps drive
    // the progress bar, and a build's "==> " steps are its status.
    Process {
        id: opProc
        property string what: "" // the package, Flatpak id or repo, or "upgrade"
        property var lines: []
        property bool build: false
        function start(what, command) {
            if (running)
                return;
            opProc.what = what;
            lines = [];
            build = command[0] === "sh" && command[3] === "repostation";
            content.progress = -1;
            content.showLog = false;
            content.status = command[0] === "pkexec" ? "Waiting for your password…" : build ? "Starting the build…" : "Starting…";
            opProc.command = command;
            running = true;
        }
        function feed(line) {
            line = line.replace(/\x1b\[[0-9;]*m/g, ""); // RepoStation's colours
            lines = lines.concat([line]).slice(-500);
            const m = line.match(/^\(\s*(\d+)\/(\d+)\)/);
            if (m)
                content.progress = m[1] / m[2];
            if (build ? line.startsWith("==> ") : line.trim())
                content.status = line.replace(/^==> /, "").trim();
        }
        stdout: SplitParser {
            onRead: line => opProc.feed(line)
        }
        stderr: SplitParser {
            onRead: line => opProc.feed(line)
        }
        onExited: code => {
            const upgrading = what === "upgrade";
            const why = lines.filter(l => /^(error:|repostation: )/.test(l)).pop()?.replace(/^repostation: /, "") ?? content.status;
            content.progress = -1;
            content.status = code === 0 ? (upgrading ? "divineOS is up to date." : "Done.") : command[0] === "pkexec" && (code === 126 || code === 127) ? "Cancelled." : "Didn't finish. " + why;
            what = "";
            win.refresh();
            if (code === 0 && upgrading)
                return win.next();
            win.queue = [];
            win.check();
        }
    }
    // A RepoStation command in the background; stdin is empty so its questions take their defaults.
    function repostation(what, args) {
        opProc.start(what, ["sh", "-c", 'exec "$@" </dev/null', "repostation", "repostation"].concat(args));
    }

    Process {
        id: termProc
        onExited: {
            win.refresh();
            win.check();
        }
    }

    IpcHandler {
        target: "store"
        function toggle(): void {
            win.toggle();
        }
        function show(page: string): void {
            win.show(page);
        }
    }

    StoreContent {
        id: content
        anchors.fill: parent

        featured: win.featured
        banners: win.banners
        installedNames: win.installedNames
        flatpaks: win.flatpaks
        debs: win.debs
        apps: {
            const deb = {};
            for (const [pkg, ids] of Object.entries(win.debs))
                for (const id of ids)
                    deb[id] = "deb:" + pkg;
            return Sys.apps.filter(a => win.owners[a.id] || deb[a.id] || win.flatpaks.includes(a.id)).map(a => ({ id: a.id, name: a.name, icon: Sys.iconPath(a.icon), pkg: win.owners[a.id] ?? deb[a.id] ?? "flatpak:" + a.id })).sort((a, b) => a.name.localeCompare(b.name));
        }
        results: win.repoResults.concat(win.aurResults.filter(a => !win.repoResults.some(r => r.pkg === a.pkg)))
        searching: repoSearch.running || aurSearch.running || searchDelay.running
        updates: win.updates
        checking: checkProc.running
        busy: opProc.running ? opProc.what : ""
        log: opProc.lines
        building: opProc.build
        githubApps: Sys.apps.some(a => a.id === "repostation")
        githubSearching: githubSearch.running

        onSearch: q => {
            win.query = q;
            win.repoResults = [];
            win.aurResults = [];
            if (q.length >= 2)
                searchDelay.restart();
        }
        onInstall: (pkg, aur) => aur ? win.inTerminal(`Installing ${pkg}`, ["-S", "--", pkg]) : opProc.start(pkg, ["pkexec", win.helper, "install", pkg])
        onInstallFlatpak: id => opProc.start(id, ["sh", "-c", 'flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && exec flatpak install --user -y --noninteractive flathub "$1"', "sh", id])
        onInstallDebian: pkg => opProc.start(pkg, ["divine-pkg", "install", "--yes", "deb:" + pkg])
        onRemove: pkg => pkg.startsWith("flatpak:") ? opProc.start(pkg, ["flatpak", "uninstall", "--user", "-y", "--noninteractive", pkg.slice(8)]) : pkg.startsWith("deb:") ? opProc.start(pkg, ["divine-pkg", "remove", "--yes", pkg]) : opProc.start(pkg, ["pkexec", win.helper, "remove", pkg])
        onOpen: id => DesktopEntries.byId(id)?.execute()
        onUpgrade: {
            const kinds = new Set(win.updates.map(u => u.kind));
            win.queue = [kinds.has("repo") && ["upgrade", ["pkexec", win.helper, "upgrade"]], kinds.has("flatpak") && ["upgrade", ["flatpak", "update", "--user", "-y", "--noninteractive"]], kinds.has("github") && ["upgrade", ["sh", "-c", 'exec "$@" </dev/null', "repostation", "repostation", "update"]], Object.keys(win.debs).length && ["upgrade", ["divine-pkg", "run", "sh", "-c", "sudo apt-get update -q && sudo apt-get upgrade -y"]]].filter(j => j);
            win.next();
        }
        onDetails: app => win.details(app)
        onSearchGithub: q => {
            githubSearch.running = false;
            githubSearch.terms = q;
            content.githubResults = [];
            githubSearch.running = true;
        }
        onInstallGithub: repo => win.repostation(repo, ["install", repo])
        onUpdateGithub: repo => win.repostation(repo, ["update", repo])
        onRemoveGithub: repo => win.repostation(repo, ["remove", repo])
        onCheckUpdates: win.check()
        onOpenLink: url => Quickshell.execDetached(["gio", "open", url])
    }
}
