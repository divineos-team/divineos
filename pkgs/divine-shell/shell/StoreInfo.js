.pragma library

// What the Store's app pages show, from the services' JSON answers. Store.qml fetches them in
// one go, separated by "@@" lines: the Arch package search, the AUR, Flathub's AppStream data,
// then ODRS (the ratings GNOME Software uses) for "<id>" and for "<id>.desktop".

function json(s) {
    try {
        return JSON.parse(s);
    } catch (e) {
        return null;
    }
}

// HTML from AppStream (<p>, <ul><li>) as plain paragraphs.
function plain(html) {
    return (html ?? "").replace(/<li>/g, "• ").replace(/<\/(p|li)>/g, "\n").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/\n{2,}/g, "\n").trim();
}

// The screenshot size nearest 1248 px wide: Flathub gives sizes as a list of { src, width } or,
// in older answers, as { "1248x702": url }.
function screenshot(shot) {
    const sizes = Array.isArray(shot.sizes) ? shot.sizes.map(s => ({ src: s.src, width: parseInt(s.width) || 0 })) : Object.entries(shot.sizes ?? {}).map(([k, src]) => ({ src, width: parseInt(k) || 0 }));
    if (!sizes.length)
        return shot.imgDesktopUrl ?? shot.thumbUrl ?? "";
    sizes.sort((a, b) => Math.abs(a.width - 1248) - Math.abs(b.width - 1248));
    return sizes[0].src ?? "";
}

// ODRS: { star1: n, … star5: n } → { average, total }, or null without ratings.
function rating(r) {
    if (!r)
        return null;
    let total = 0, sum = 0;
    for (let i = 1; i <= 5; i++) {
        total += r[`star${i}`] ?? 0;
        sum += i * (r[`star${i}`] ?? 0);
    }
    return total ? { average: sum / total, total } : null;
}

function info(text, pkg) {
    const parts = text.split("\n@@\n");
    const [arch, aur, flathub, odrs, odrsDesktop] = parts.map(json);
    // Debian's madison: "vlc | 3.0.21-0+deb12u1 | stable | source, amd64"
    const deb = (parts[5] ?? "").split("\n").map(l => l.split("|").map(f => f.trim())).find(f => f[0] === pkg && f.length > 2);
    const a = (arch?.results ?? []).find(r => r.pkgname === pkg);
    const u = (aur?.results ?? []).find(r => r.Name === pkg);
    const ratings = [rating(odrs), rating(odrsDesktop)].filter(r => r).sort((x, y) => y.total - x.total);
    return {
        arch: a ? `${a.epoch ? a.epoch + ":" : ""}${a.pkgver}-${a.pkgrel}` : "",
        aur: u ? u.Version : "",
        votes: u ? u.NumVotes : 0,
        debian: deb ? deb[1] : "",
        flathub: flathub?.id ? flathub.releases?.[0]?.version ?? "latest" : "",
        screenshots: (flathub?.screenshots ?? []).map(screenshot).filter(s => s).slice(0, 6),
        description: plain(flathub?.description) || (a?.pkgdesc ?? u?.Description ?? ""),
        homepage: flathub?.urls?.homepage ?? a?.url ?? u?.URL ?? "",
        rating: ratings[0] ?? null
    };
}

// GitHub stars as a rating, on a log scale like RepoStation's: 10 → 1, 100 → 2 … 100k → 5.
function stars(n) {
    return Math.max(0, Math.min(5, Math.round(Math.log10(Math.max(1, n)))));
}
function count(n) {
    return n < 1000 ? String(n) : n < 1e6 ? (n / 1e3).toFixed(1) + "k" : (n / 1e6).toFixed(1) + "M";
}

// Languages RepoStation's build engine turns into programs.
const buildable = ["Rust", "Go", "C", "C++", "JavaScript", "TypeScript", "Vala"];

function github(text) {
    return (json(text)?.items ?? []).filter(r => buildable.includes(r.language)).map(r => ({
                repo: r.full_name,
                about: r.description ?? "",
                stars: r.stargazers_count,
                language: r.language
            }));
}

// RepoStation's installed.json: [{ repo, commit, system, bins }]
function githubInstalled(text) {
    const list = json(text);
    return Array.isArray(list) ? list.map(e => ({ repo: e.repo, commit: (e.commit ?? "").slice(0, 7), bins: e.bins ?? [] })) : [];
}
