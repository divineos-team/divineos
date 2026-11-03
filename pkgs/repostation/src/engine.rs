//! The build engine.
//!
//! clone → detect build system → find missing toolchains and libraries → `sudo pacman -S`
//! → build with native CPU flags → install into ~/.local/opt/repostation/<owner>__<repo>
//! → symlink its bin/ into ~/.local/bin → record in ~/.local/share/repostation/installed.json.
//! The clone stays in <prefix>/src so updates are a shallow fetch plus rebuild.

use crate::Result;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

#[cfg(unix)]
use std::os::unix::fs::symlink;
#[cfg(not(unix))]
fn symlink(_: &Path, _: &Path) -> io::Result<()> {
    Err(io::ErrorKind::Unsupported.into())
}

const NATIVE_CFLAGS: &str = "-O2 -march=native -pipe";
const NATIVE_RUSTFLAGS: &str = "-C target-cpu=native";

// ───────────────────────────── build systems ─────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum System {
    Cargo,
    Meson,
    CMake,
    Go,
    Npm,
    Make,
}

impl System {
    /// First match wins: a Makefile next to Cargo.toml or go.mod is usually just a wrapper.
    pub fn detect(dir: &Path) -> Option<System> {
        [
            ("Cargo.toml", System::Cargo),
            ("meson.build", System::Meson),
            ("CMakeLists.txt", System::CMake),
            ("go.mod", System::Go),
            ("package.json", System::Npm),
            ("GNUmakefile", System::Make),
            ("Makefile", System::Make),
            ("makefile", System::Make),
        ]
        .into_iter()
        .find(|(file, _)| dir.join(file).is_file())
        .map(|(_, system)| system)
    }

    pub fn name(self) -> &'static str {
        match self {
            System::Cargo => "Cargo",
            System::Meson => "Meson",
            System::CMake => "CMake",
            System::Go => "Go",
            System::Npm => "npm",
            System::Make => "Make",
        }
    }

    /// Arch packages that provide the toolchain.
    fn toolchain(self) -> &'static [&'static str] {
        match self {
            System::Cargo => &["rust", "pkgconf"],
            System::Meson => &["meson", "ninja", "gcc", "pkgconf"],
            System::CMake => &["cmake", "make", "gcc", "pkgconf"],
            System::Go => &["go"],
            System::Npm => &["nodejs", "npm"],
            System::Make => &["make", "gcc", "pkgconf"],
        }
    }
}

// ───────────────────────────── dependency discovery ─────────────────────────────

/// Meson pseudo-dependencies that aren't pkg-config modules.
const MESON_BUILTIN: &[&str] = &["threads", "openmp", "dl", "appleframeworks", "cuda", "mpi", ""];

/// CMake `find_package` names whose module ships with CMake itself, so there's no config
/// file for `pacman -F` to find.
const CMAKE_FIND_MODULES: &[(&str, &str)] = &[
    ("ZLIB", "zlib"),
    ("OpenSSL", "openssl"),
    ("CURL", "curl"),
    ("PNG", "libpng"),
    ("JPEG", "libjpeg-turbo"),
    ("Freetype", "freetype2"),
    ("SQLite3", "sqlite"),
    ("Boost", "boost"),
    ("LibXml2", "libxml2"),
    ("BZip2", "bzip2"),
    ("Curses", "ncurses"),
    ("X11", "libx11"),
];

/// Rust `-sys` crates that link a system library rather than vendoring it by default.
const SYS_CRATES: &[(&str, &str)] = &[
    ("openssl-sys", "openssl"),
    ("alsa-sys", "alsa-lib"),
    ("libudev-sys", "systemd-libs"),
    ("libdbus-sys", "dbus"),
    ("libpulse-sys", "libpulse"),
    ("freetype-sys", "freetype2"),
    ("yeslogic-fontconfig-sys", "fontconfig"),
    ("servo-fontconfig-sys", "fontconfig"),
    ("xcb", "libxcb"),
    ("wayland-sys", "wayland"),
    ("gtk-sys", "gtk3"),
    ("gtk4-sys", "gtk4"),
];

/// Build files in the project, skipping vendored code, tests and build output.
fn project_files(dir: &Path, names: &[&str], depth: u32, out: &mut Vec<PathBuf>) {
    const SKIP: &[&str] = &[
        "subprojects", "third_party", "thirdparty", "external", "vendor", "deps", "build",
        "target", "node_modules", "test", "tests", "examples", "docs",
    ];
    let Ok(entries) = fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().into_owned();
        if path.is_dir() {
            if depth > 0 && !name.starts_with('.') && !SKIP.contains(&name.as_str()) {
                project_files(&path, names, depth - 1, out);
            }
        } else if names.contains(&name.as_str()) {
            out.push(path);
        }
    }
}

/// The quoted string right after `pos`, e.g. `'gtk4'` in `dependency('gtk4', …)`.
fn quoted_at(text: &str, pos: usize) -> Option<&str> {
    let rest = text[pos..].trim_start();
    let quote = rest.chars().next().filter(|c| *c == '\'' || *c == '"')?;
    let rest = &rest[1..];
    rest.find(quote).map(|end| &rest[..end])
}

/// Every `call(` in `text` that isn't the tail of a longer identifier, as byte offsets
/// just past the parenthesis.
fn calls<'a>(text: &'a str, call: &'a str) -> impl Iterator<Item = usize> + 'a {
    text.match_indices(call).filter_map(move |(i, _)| {
        let prev = text[..i].chars().next_back();
        (!prev.is_some_and(|c| c.is_alphanumeric() || c == '_')).then_some(i + call.len())
    })
}

fn meson_deps(text: &str, mods: &mut BTreeSet<String>) {
    for pos in calls(text, "dependency(") {
        if let Some(name) = quoted_at(text, pos).filter(|n| !MESON_BUILTIN.contains(n)) {
            mods.insert(name.to_string());
        }
    }
}

fn cmake_deps(text: &str, mods: &mut BTreeSet<String>, pkgs: &mut BTreeSet<String>) {
    const KEYWORDS: &[&str] = &["REQUIRED", "QUIET", "IMPORTED_TARGET", "GLOBAL", "NO_CMAKE_PATH", "NO_CMAKE_ENVIRONMENT_PATH"];
    let lower = text.to_ascii_lowercase(); // CMake commands are case-insensitive
    let args = |pos: usize| text[pos..].split(')').next().unwrap_or("").split_whitespace();

    for call in ["pkg_check_modules(", "pkg_search_module("] {
        for pos in calls(&lower, call) {
            let names = args(pos).skip(1).filter(|t| !KEYWORDS.contains(t) && !t.starts_with('$'));
            for name in names {
                let name = name.split(['>', '<', '=']).next().unwrap_or("");
                if !name.is_empty() {
                    mods.insert(name.to_string());
                }
            }
        }
    }
    for pos in calls(&lower, "find_package(") {
        if let Some(name) = args(pos).next()
            && let Some((_, pkg)) = CMAKE_FIND_MODULES.iter().find(|(n, _)| *n == name)
        {
            pkgs.insert(pkg.to_string());
        }
    }
}

fn cargo_deps(dir: &Path, pkgs: &mut BTreeSet<String>) {
    let Ok(lock) = fs::read_to_string(dir.join("Cargo.lock")) else { return };
    for line in lock.lines() {
        let Some(name) = line.strip_prefix("name = \"").and_then(|s| s.strip_suffix('"')) else { continue };
        if let Some((_, pkg)) = SYS_CRATES.iter().find(|(c, _)| *c == name) {
            pkgs.insert(pkg.to_string());
        }
    }
}

/// System packages (toolchain + known libraries) and pkg-config modules a project needs.
pub fn requirements(dir: &Path, system: System) -> (BTreeSet<String>, BTreeSet<String>) {
    let mut pkgs: BTreeSet<String> = system.toolchain().iter().map(|s| s.to_string()).collect();
    let mut mods = BTreeSet::new();
    match system {
        System::Cargo => cargo_deps(dir, &mut pkgs),
        System::Meson | System::CMake | System::Make => {
            let mut files = Vec::new();
            project_files(dir, &["meson.build", "CMakeLists.txt"], 3, &mut files);
            for file in files {
                let Ok(text) = fs::read_to_string(&file) else { continue };
                if file.ends_with("meson.build") {
                    meson_deps(&text, &mut mods);
                } else {
                    cmake_deps(&text, &mut mods, &mut pkgs);
                }
            }
        }
        System::Go | System::Npm => {}
    }
    (pkgs, mods)
}

fn pc_installed(module: &str) -> bool {
    ["/usr/lib/pkgconfig", "/usr/share/pkgconfig"]
        .iter()
        .any(|dir| Path::new(dir).join(format!("{module}.pc")).exists())
}

/// Packages from `pkgs` that aren't installed (pacman -T also honours `provides`).
fn pacman_missing(pkgs: &BTreeSet<String>) -> Vec<String> {
    let out = Command::new("pacman").arg("-T").args(pkgs).output();
    out.map(|o| String::from_utf8_lossy(&o.stdout).lines().map(str::to_owned).collect())
        .unwrap_or_default()
}

/// Arch packages that ship the given pkg-config files, via pacman's file database.
fn pacman_owners(modules: &[String]) -> BTreeSet<String> {
    let files = modules.iter().flat_map(|m| [format!("usr/lib/pkgconfig/{m}.pc"), format!("usr/share/pkgconfig/{m}.pc")]);
    let Ok(out) = Command::new("pacman").arg("-Fq").args(files).output() else { return BTreeSet::new() };
    String::from_utf8_lossy(&out.stdout)
        .lines()
        .filter_map(|l| l.rsplit('/').next().map(str::to_owned)) // "extra/gtk4" → "gtk4"
        .collect()
}

// ───────────────────────────── paths & manifest ─────────────────────────────

fn home() -> PathBuf {
    std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| ".".into())
}

fn opt_root() -> PathBuf {
    home().join(".local/opt/repostation")
}

fn bin_dir() -> PathBuf {
    home().join(".local/bin")
}

fn manifest_path() -> PathBuf {
    let data = std::env::var_os("XDG_DATA_HOME").map(PathBuf::from).unwrap_or_else(|| home().join(".local/share"));
    data.join("repostation/installed.json")
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Installed {
    pub repo: String,
    pub commit: String,
    pub system: String,
    pub bins: Vec<String>,
    pub installed_at: u64,
}

pub fn load() -> Vec<Installed> {
    fs::read(manifest_path()).ok().and_then(|b| serde_json::from_slice(&b).ok()).unwrap_or_default()
}

/// Write via a temp file + rename so a crash never leaves a truncated manifest.
fn save(list: &[Installed]) -> Result<()> {
    let path = manifest_path();
    fs::create_dir_all(path.parent().unwrap())?;
    let tmp = path.with_extension("json.tmp");
    fs::write(&tmp, serde_json::to_vec_pretty(list)?)?;
    fs::rename(tmp, path)?;
    Ok(())
}

/// A validated `owner/repo`.
#[derive(Debug, Clone, PartialEq)]
pub struct Id {
    pub owner: String,
    pub name: String,
}

impl Id {
    pub fn parse(s: &str) -> Result<Id> {
        let s = s.trim().trim_start_matches("https://github.com/").trim_end_matches('/').trim_end_matches(".git");
        let ok = |p: &str| !p.is_empty() && !p.starts_with('.') && p.chars().all(|c| c.is_ascii_alphanumeric() || "-_.".contains(c));
        match s.split_once('/') {
            Some((owner, name)) if ok(owner) && ok(name) => Ok(Id { owner: owner.into(), name: name.into() }),
            _ => Err(format!("`{s}` is not an owner/repo name").into()),
        }
    }

    fn full(&self) -> String {
        format!("{}/{}", self.owner, self.name)
    }

    fn dir(&self) -> PathBuf {
        opt_root().join(format!("{}__{}", self.owner, self.name))
    }
}

// ───────────────────────────── running things ─────────────────────────────

fn say(msg: &str) {
    println!("\x1b[1;36m==>\x1b[0m \x1b[1m{msg}\x1b[0m");
}

fn run(cmd: &mut Command) -> Result<()> {
    let line = std::iter::once(cmd.get_program()).chain(cmd.get_args()).map(|a| a.to_string_lossy()).collect::<Vec<_>>().join(" ");
    println!("\x1b[2m$ {line}\x1b[0m");
    let status = cmd.status().map_err(|e| format!("`{line}`: {e}"))?;
    if status.success() { Ok(()) } else { Err(format!("`{line}` failed ({status})").into()) }
}

fn git(dir: &Path, args: &[&str]) -> Result<String> {
    let out = Command::new("git").arg("-C").arg(dir).args(args).output()?;
    if !out.status.success() {
        return Err(format!("git {}: {}", args.join(" "), String::from_utf8_lossy(&out.stderr).trim()).into());
    }
    Ok(String::from_utf8_lossy(&out.stdout).trim().to_owned())
}

pub fn ask(question: &str) -> bool {
    print!("\x1b[1;33m::\x1b[0m {question} [Y/n] ");
    let _ = io::stdout().flush();
    let mut answer = String::new();
    io::stdin().read_line(&mut answer).is_ok() && matches!(answer.trim(), "" | "y" | "Y" | "yes")
}

// ───────────────────────────── building ─────────────────────────────

/// The Cargo package to install: the root, or for a virtual workspace the member named
/// after the repo (`foo/`, `crates/foo/`, `foo-cli/`, …).
fn cargo_member(src: &Path, name: &str) -> Result<String> {
    let candidates = [".".into(), name.into(), format!("crates/{name}"), format!("{name}-cli"), format!("crates/{name}-cli"), "cli".into()];
    candidates
        .into_iter()
        .find(|c| fs::read_to_string(src.join(c).join("Cargo.toml")).is_ok_and(|t| t.lines().any(|l| l.trim() == "[package]")))
        .ok_or_else(|| "Cargo workspace without a member named after the repo; install that member manually".into())
}

fn build_commands(system: System, id: &Id, src: &Path, prefix: &Path, cargo_target: &Path) -> Result<Vec<Command>> {
    let p = prefix.to_string_lossy().into_owned();
    let p = p.as_str();
    let jobs = std::thread::available_parallelism().map_or(4, |n| n.get()).to_string();
    let jobs = jobs.as_str();
    let cmd = |args: &[&str]| {
        let mut c = Command::new(args[0]);
        c.args(&args[1..])
            .current_dir(src)
            .env("CFLAGS", NATIVE_CFLAGS)
            .env("CXXFLAGS", NATIVE_CFLAGS)
            .env("CGO_CFLAGS", NATIVE_CFLAGS)
            .env("RUSTFLAGS", NATIVE_RUSTFLAGS);
        c
    };
    Ok(match system {
        System::Cargo => {
            let member = cargo_member(src, &id.name)?;
            let target = cargo_target.to_string_lossy();
            let mut args = vec!["cargo", "install", "--path", member.as_str(), "--root", p, "--target-dir", target.as_ref()];
            if src.join("Cargo.lock").exists() {
                args.push("--locked");
            }
            vec![cmd(&args)]
        }
        System::Meson => vec![
            cmd(&["meson", "setup", "build", "--prefix", p, "--buildtype=release"]),
            cmd(&["meson", "compile", "-C", "build"]),
            cmd(&["meson", "install", "-C", "build"]),
        ],
        System::CMake => vec![
            cmd(&["cmake", "-S", ".", "-B", "build", "-DCMAKE_BUILD_TYPE=Release", format!("-DCMAKE_INSTALL_PREFIX={p}").as_str()]),
            cmd(&["cmake", "--build", "build", "--parallel", jobs]),
            cmd(&["cmake", "--install", "build"]),
        ],
        System::Go => {
            fs::create_dir_all(prefix.join("bin"))?;
            let pkg = if src.join("cmd").is_dir() { "./cmd/..." } else { "." };
            vec![cmd(&["go", "build", "-trimpath", "-o", format!("{p}/bin/").as_str(), pkg])]
        }
        // A global install of a folder is a symlink to it, which is fine: src/ stays put.
        System::Npm => vec![cmd(&["npm", "install"]), cmd(&["npm", "install", "--global", "--prefix", p, "."])],
        System::Make => vec![
            cmd(&["make", "-j", jobs]),
            cmd(&["make", "install", format!("PREFIX={p}").as_str(), format!("prefix={p}").as_str()]),
        ],
    })
}

/// Symlink every executable in <prefix>/bin into ~/.local/bin, never clobbering files
/// that RepoStation doesn't own.
fn link_bins(prefix: &Path) -> Result<Vec<String>> {
    let bin = bin_dir();
    fs::create_dir_all(&bin)?;
    let mut linked = Vec::new();
    let Ok(entries) = fs::read_dir(prefix.join("bin")) else { return Ok(linked) };
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        let link = bin.join(&name);
        if link.symlink_metadata().is_ok() {
            if !fs::read_link(&link).is_ok_and(|t| t.starts_with(opt_root())) {
                println!("\x1b[1;33mwarning:\x1b[0m {} exists and isn't ours; not linking {name}", link.display());
                continue;
            }
            fs::remove_file(&link)?;
        }
        symlink(&entry.path(), &link)?;
        linked.push(name);
    }
    Ok(linked)
}

fn unlink_bins(entry: &Installed, prefix: &Path) {
    for name in &entry.bins {
        let link = bin_dir().join(name);
        if fs::read_link(&link).is_ok_and(|t| t.starts_with(prefix)) {
            let _ = fs::remove_file(link);
        }
    }
}

/// Everything after the clone: resolve deps, build, install, link, record.
fn build_and_install(id: &Id, confirm: bool) -> Result<()> {
    let prefix = id.dir();
    let src = prefix.join("src");
    let system = System::detect(&src).ok_or("no supported build system (Cargo, Meson, CMake, Go, npm, Make)")?;
    let (pkgs, mods) = requirements(&src, system);
    let mut missing = pacman_missing(&pkgs);
    let missing_mods: Vec<String> = mods.into_iter().filter(|m| !pc_installed(m)).collect();

    say(&format!("Plan for {}", id.full()));
    println!("   build system   {}  (CFLAGS {NATIVE_CFLAGS}, RUSTFLAGS {NATIVE_RUSTFLAGS})", system.name());
    println!("   packages       {}", if missing.is_empty() { "nothing to install".into() } else { missing.join(" ") });
    if !missing_mods.is_empty() {
        println!("   libraries      {} (resolved through pacman -F)", missing_mods.join(" "));
    }
    println!("   install into   {} → {}", prefix.display(), bin_dir().display());
    println!("   \x1b[2mBuilding runs the project's own build scripts as you.\x1b[0m");
    if confirm && !ask("Proceed?") {
        return Err("cancelled".into());
    }

    if !missing_mods.is_empty() {
        if !Path::new("/var/lib/pacman/sync/core.files").exists() {
            say("Downloading pacman's file database for library lookup");
            run(Command::new("sudo").args(["pacman", "-Fy"]))?;
        }
        let owners = pacman_owners(&missing_mods);
        missing.extend(pacman_missing(&owners));
    }
    if !missing.is_empty() {
        say("Installing build dependencies");
        run(Command::new("sudo").args(["pacman", "-S", "--needed"]).args(&missing))?;
    }

    say(&format!("Building with {}", system.name()));
    let cargo_target = std::env::temp_dir().join(format!("repostation-{}__{}", id.owner, id.name));
    let built = build_commands(system, id, &src, &prefix, &cargo_target).and_then(|cmds| cmds.into_iter().try_for_each(|mut c| run(&mut c)));
    let _ = fs::remove_dir_all(&cargo_target);
    built?;

    let bins = link_bins(&prefix)?;
    if bins.is_empty() {
        println!("\x1b[1;33mwarning:\x1b[0m the build installed nothing into {}/bin", prefix.display());
    } else if !std::env::var("PATH").unwrap_or_default().split(':').any(|p| Path::new(p) == bin_dir()) {
        println!("\x1b[1;33mnote:\x1b[0m add {} to PATH to run {}", bin_dir().display(), bins.join(", "));
    }

    let mut list = load();
    list.retain(|e| e.repo != id.full());
    list.push(Installed {
        repo: id.full(),
        commit: git(&src, &["rev-parse", "HEAD"])?,
        system: system.name().into(),
        bins: bins.clone(),
        installed_at: SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_secs()),
    });
    list.sort_by(|a, b| a.repo.cmp(&b.repo));
    save(&list)?;
    say(&format!("Installed {}: {}", id.full(), bins.join(" ")));
    Ok(())
}

// ───────────────────────────── public operations ─────────────────────────────

pub fn install(repo: &str) -> Result<()> {
    let id = Id::parse(repo)?;
    let prefix = id.dir();
    if prefix.exists() {
        return Err(format!("{} is already installed; use update", id.full()).into());
    }
    say(&format!("Cloning {}", id.full()));
    fs::create_dir_all(&prefix)?;
    let url = format!("https://github.com/{}.git", id.full());
    let result = run(Command::new("git").args(["clone", "--depth", "1", "--recurse-submodules", "--shallow-submodules", &url]).arg(prefix.join("src")))
        .and_then(|_| build_and_install(&id, true));
    if result.is_err() {
        let _ = fs::remove_dir_all(&prefix); // no half-installed apps
    }
    result
}

/// Rebuild `repo` (or every installed app) if its default branch moved upstream.
pub fn update(repo: Option<&str>) -> Result<()> {
    let wanted = repo.map(Id::parse).transpose()?;
    let targets: Vec<Installed> = load().into_iter().filter(|e| wanted.as_ref().is_none_or(|w| w.full() == e.repo)).collect();
    if let Some(w) = &wanted
        && targets.is_empty()
    {
        return Err(format!("{} is not installed", w.full()).into());
    }
    let mut failures = Vec::new();
    for entry in targets {
        let id = Id::parse(&entry.repo)?;
        let prefix = id.dir();
        let src = prefix.join("src");
        let remote = git(&src, &["ls-remote", "origin", "HEAD"])?;
        if remote.split_whitespace().next() == Some(entry.commit.as_str()) {
            say(&format!("{} is up to date", entry.repo));
            continue;
        }
        say(&format!("Updating {}", entry.repo));
        let result = (|| {
            run(Command::new("git").arg("-C").arg(&src).args(["fetch", "--depth", "1", "origin", "HEAD"]))?;
            run(Command::new("git").arg("-C").arg(&src).args(["reset", "--hard", "FETCH_HEAD"]))?;
            run(Command::new("git").arg("-C").arg(&src).args(["submodule", "update", "--init", "--recursive", "--depth", "1"]))?;
            run(Command::new("git").arg("-C").arg(&src).args(["clean", "-ffdx"]))?;
            // Fresh prefix: stale files from the old version must not survive.
            unlink_bins(&entry, &prefix);
            for item in fs::read_dir(&prefix)?.flatten().filter(|i| i.file_name() != "src") {
                let path = item.path();
                if path.is_dir() { fs::remove_dir_all(path)? } else { fs::remove_file(path)? }
            }
            build_and_install(&id, false)
        })();
        if let Err(e) = result {
            println!("\x1b[1;31merror:\x1b[0m {}: {e}", entry.repo);
            failures.push(entry.repo);
        }
    }
    if failures.is_empty() { Ok(()) } else { Err(format!("failed to update {}", failures.join(", ")).into()) }
}

pub fn remove(repo: &str) -> Result<()> {
    let id = Id::parse(repo)?;
    let mut list = load();
    let entry = list.iter().find(|e| e.repo == id.full()).cloned().ok_or_else(|| format!("{} is not installed", id.full()))?;
    let prefix = id.dir();
    unlink_bins(&entry, &prefix);
    if prefix.exists() {
        fs::remove_dir_all(&prefix)?;
    }
    list.retain(|e| e.repo != entry.repo);
    save(&list)?;
    say(&format!("Removed {}", entry.repo));
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_build_systems_in_priority_order() {
        let dir = std::env::temp_dir().join(format!("repostation-test-{}", std::process::id()));
        fs::create_dir_all(&dir).unwrap();
        assert_eq!(System::detect(&dir), None);
        fs::write(dir.join("Makefile"), "").unwrap();
        assert_eq!(System::detect(&dir), Some(System::Make));
        fs::write(dir.join("CMakeLists.txt"), "").unwrap();
        assert_eq!(System::detect(&dir), Some(System::CMake));
        fs::write(dir.join("Cargo.toml"), "[package]\nname = \"x\"\n").unwrap();
        assert_eq!(System::detect(&dir), Some(System::Cargo));
        assert_eq!(cargo_member(&dir, "x").unwrap(), ".");
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn finds_meson_and_cmake_dependencies() {
        let mut mods = BTreeSet::new();
        let mut pkgs = BTreeSet::new();
        meson_deps("gtk = dependency('gtk4', version: '>=4.10')\nt = dependency('threads')\nx = declare_dependency(link_with: y)\nw = dependency( \"wayland-client\" )", &mut mods);
        cmake_deps("find_package(PkgConfig REQUIRED)\nPKG_CHECK_MODULES(DEPS REQUIRED IMPORTED_TARGET libpipewire-0.3>=1.0 ${EXTRA} x11)\nfind_package(ZLIB REQUIRED)\nmy_find_package(OpenSSL)", &mut mods, &mut pkgs);
        assert_eq!(mods.into_iter().collect::<Vec<_>>(), ["gtk4", "libpipewire-0.3", "wayland-client", "x11"]);
        assert_eq!(pkgs.into_iter().collect::<Vec<_>>(), ["zlib"]);
    }

    #[test]
    fn parses_repo_ids() {
        assert_eq!(Id::parse("https://github.com/sharkdp/bat.git").unwrap(), Id { owner: "sharkdp".into(), name: "bat".into() });
        assert!(Id::parse("../etc/passwd").is_err());
        assert!(Id::parse("owner/..").is_err());
        assert!(Id::parse("just-a-name").is_err());
    }
}
