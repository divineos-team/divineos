# divineOS

A fast, glass-surfaced Linux distribution by **devine**. It's built on Arch Linux and uses Hyprland as its Wayland compositor. The desktop (divineDE) uses a liquid-glass design language inspired by macOS 26.

```
                            ▄▄
                          ▄██▀
                         ████
                        ████▀
        ▄▄▄█████████▄▄  ████
     ▄▄█████████████████████
   ▄█████▀▀       ▀▀███████
  █████▀             ██████
 ████▀               ▀████
████▀                ▄████
████                 ████
████               ▄█████
█████▄           ▄▄█████▀
 ██████▄▄    ▄▄▄████████
  ▀███████████████▀████▀
     ▀▀▀████▀▀▀▀   ████
```

## Build the ISO

The build needs root on Arch Linux. On any other OS (Windows included), use Docker.

```powershell
# Windows / macOS / any Linux, from the repo root (PowerShell or bash)
docker run --rm --privileged -v "${PWD}:/src" archlinux:latest bash /src/build.sh
```

```bash
# Native Arch
sudo ./build.sh
```

The output is `out/divineos-YYYY.MM.DD-x86_64.iso`. Hyprland needs GPU acceleration, so a VM must have 3D enabled: QEMU with `-device virtio-vga-gl -display gtk,gl=on`, or VMware with "Accelerate 3D graphics". In VMware, apps (the shell included) render on the CPU, because Hyprland can't use buffers from VMware's GPU driver, so expect it to be slower than on real hardware.

## Install to disk

Boot the ISO. The Welcome guide opens with an **Install divineOS** button; the installer is also first in the dock and in the launcher (`divine-install`). It's a glass window with six steps, and nothing on disk changes before the last one.

1. **Welcome** checks the internet connection and the firmware (UEFI or BIOS). The connection is required: Arch's packages come from the mirrors, divineOS's own from the copy of the `[divine]` repo on the ISO.
2. **Disk** offers four ways in:
   - **Erase a disk.** A new GPT table: a 1 GiB EFI partition at `/boot` plus an ext4 root (UEFI), or a BIOS boot partition plus root (BIOS). You can encrypt the root with LUKS2; on BIOS, `/boot` then gets its own 1 GiB partition, because GRUB can't read LUKS2 with argon2.
   - **Alongside.** Uses the disk's free space, or shrinks a Windows (NTFS) or ext4 partition: drag the divider to split the space. The other system keeps at least what its files use, plus 10% and 1 GiB. It reuses the disk's EFI partition, and adds one (or a BIOS boot partition, on BIOS with GPT) only when the disk has none.
   - **Replace a partition.** Formats one partition of 20 GB or more for divineOS and reuses the disk's EFI partition.
   - **Manual.** Opens GParted. Then pick the partition for divineOS (formatted as ext4) and, on UEFI, the EFI partition (kept as it is).
3. **Region:** time zone, language, and keyboard. The keyboard sets the console keymap, the login screen and Hyprland. Greek, Russian, Ukrainian and Georgian also get US English; Alt+Shift switches between them.
4. **Account:** your name, username, computer name and password. You're in `wheel` (sudo); root's password is locked.
5. **Summary** says what happens to which disk.
6. **Install** shows progress and the full log, then Restart.

Things to know:
- **Windows must shut down fully before it can be shrunk.** With Fast Startup on, Windows hibernates instead, and `ntfsresize` refuses the partition. Turn Fast Startup off in Windows' power settings and shut down.
- After an Alongside or Replace install, GRUB lists Windows and other systems (os-prober).
- On NVIDIA, install the driver after the first boot, for example `sudo pacman -S nvidia-open`.

**How it works.** The window (`/usr/share/divine-installer`, Quickshell) runs `/usr/lib/divine-installer/backend` as root through sudo; the live user needs no password.
- `backend probe` reads the disks (`lsblk`, skipping the live medium), the other systems on them (`os-prober`), the time zones and the languages.
- `backend shrink-info` measures a partition with `ntfsresize --info` or `resize2fs -P`.
- `backend install` reads the settings as JSON on stdin, so passwords never appear on a command line. It reaches the mirrors before it touches any disk. Then it partitions (`sfdisk`), formats, runs `pacstrap` (base, linux, firmware, microcode, `divineos-base`, GRUB, os-prober), and writes fstab, hostname, locale, keymap and the account. Last come GRUB and `post-install`. After an Erase, GRUB also goes to the removable fallback path, for firmware that forgets its boot entries.

`test.sh` checks the backend's parsing, partition maths and config edits (it runs in `check()`).

`/usr/lib/divineos/post-install` then runs inside the new system. It also turns an existing Arch install into divineOS:
- It points `[divine]` at the hosted repo, or removes it if the ISO was built without one.
- It copies the divineOS dotfiles from `/etc/skel` into the homes of users created before `divineos-base` was installed.
- It drops any other `zram-generator.conf`, so divineOS's own zram setting applies.
- It adds `quiet splash` to the boot entries (systemd-boot, GRUB, Limine or a UKI) and the `plymouth` hook to the initramfs.
- For GRUB, it copies the divineOS theme next to `grub.cfg` (GRUB reads it before an encrypted root is unlocked). It also names the entry divineOS, always shows the menu, and turns on os-prober.

## Boot menu

On UEFI, the ISO starts divineOS's own GRUB menu (`iso/grub/grub.cfg`): a glass panel over the dimmed Tide wallpaper, with Try divineOS, a text-console mode, Boot from the next device, Firmware settings, Restart and Shut down. Installed systems get the same theme for their GRUB menu.

The theme is `branding/grub/theme.txt`. `divineos-base`'s `build()` renders the images it names (background, panel, logo, entry icons, the selected-entry highlight) and the Inter fonts (`grub-mkfont`) into `/usr/share/grub/themes/divineos`.

BIOS boots the ISO through syslinux, because archiso has no BIOS GRUB. Its menu (`iso/syslinux`) copies the GRUB look: Try divineOS, the text console, Boot existing OS, Restart and Shut down, on a 640×480 splash (`splash.svg`) with the glass panel, logo and key hint. vesamenu draws the text in 8×16 cells, so the panel in `splash.svg` follows the rows and columns in `archiso_head.cfg`. Installed BIOS systems use the themed GRUB.

## Cursor

`divine-cursors` is the divineOS cursor theme: a dark pointer with a white outline, and a blue spinner for busy and working. Each cursor is an SVG in `pkgs/divine-cursors/svg`. The build renders it at 24 to 96 px with `xcursorgen`, plus the alias names apps ask for (`pointer`, `grab`, `col-resize` and so on). Names it doesn't draw fall back to Adwaita. Hyprland, the login screen and GTK apps use it (`XCURSOR_THEME`, and a GSettings override).

## Welcome

The Welcome guide opens at the first login, and on every live boot. It's a divine-shell window (`Welcome.qml`) with five pages:
- **divineOS**, with an Install button in the live session.
- **The Desktop:** the menu bar, dock, Control Center, launcher, overview and notifications.
- **Shortcuts:** every key binding.
- **Apps:** what each app is for, with an Open button.
- **Next Steps:** installing software, updating, and where the settings live.

Untick **Show at startup** to stop it opening at login. Reopen it from "Welcome" in the launcher or with `divine-welcome`.

## Package updates

`pacman -Syu` updates everything that comes from Arch. divineOS's own packages (shell, apps, branding) stay at the versions the ISO installed, because the new system has no `[divine]` repo. To ship a newer divineOS, build a new ISO.

### Optional: a hosted repo

To have `pacman -Syu` update divineOS's own packages too, publish the `[divine]` repo on any static web host. Installed systems accept its packages only when they're signed with your key (`SigLevel = Required`). The public half of the key ships in `divineos-base`, and `build.sh` refuses a repo URL without a key.

Create the key once (GnuPG; Git for Windows includes it):

```bash
gpg --batch --passphrase '' --quick-gen-key "divineOS repo" ed25519 sign never
```

Then, for each release:

```bash
export DIVINE_REPO_URL=https://your.host/divine
export DIVINE_SIGNING_KEY="$(gpg --armor --export-secret-keys 'divineOS repo')"
sudo -E ./build.sh repo   # → out/repo: upload its files to $DIVINE_REPO_URL
sudo -E ./build.sh        # an ISO whose installs update from it
```

A `repo` build sets every package's `pkgrel` to the build time (UTC, `YYYYMMDDHHMM`), so each publish is newer than the last one and than the packages on any ISO, and `pacman -Syu` picks it up.

In Docker, pass both variables with `-e DIVINE_REPO_URL -e DIVINE_SIGNING_KEY`. An ISO only needs the public key: export it with `gpg --armor --export 'divineOS repo' > divine-repo.asc` and pass `-e DIVINE_REPO_KEY=/src/divine-repo.asc`. Anyone with the secret key can publish packages that every installed system accepts, so keep it out of the project folder and back it up offline.

If the project moves to GitHub, `.github/workflows/repo.yml` builds, signs and uploads the repo as the `repo` release on every push to `main`. Add the secret key as the repository secret `DIVINE_SIGNING_KEY`, and build ISOs with `DIVINE_REPO_URL=https://github.com/<owner>/<repo>/releases/download/repo`.

## Repository layout

```
divineOS/
├── build.sh                    one-shot ISO build (Docker or native Arch); "build.sh repo" builds only the package repo
├── .github/workflows/repo.yml  builds, signs and publishes the hosted [divine] repo
├── branding/
│   ├── logo.svg                the mark: precision ring + blade stem, sheared 12° for speed
│   ├── logo.txt                ASCII mark (fastfetch, $1/$2 colour slots)
│   ├── wallpaper.svg           "Tide", the default wallpaper (rendered to 4K PNG at build)
│   └── grub/                   GRUB theme: theme.txt, glass panel and entry icons (SVG)
├── pkgs/                       first-party packages → local [divine] pacman repo
│   ├── divineos-base/          installing this turns Arch into divineOS
│   │   ├── PKGBUILD
│   │   ├── divineos-base.install
│   │   ├── post-install        run by divine-install inside the new system
│   │   ├── test.sh             post-install test (runs in check())
│   │   │                       build() also renders the GRUB theme → /usr/share/grub/themes/divineos
│   │   └── root/               files installed verbatim into /
│   ├── divine-shell/           divineDE: menu bar, dock, Control Center, launcher, Welcome, lock and login (Quickshell)
│   │   ├── PKGBUILD
│   │   ├── divine-lock.pam     PAM config for the lock screen → /etc/pam.d/divine-lock
│   │   ├── divine-greeter      greetd's greeter: the login screen in cage, tuigreet fallback
│   │   ├── divine-welcome      opens the Welcome guide (IPC)
│   │   └── shell/              QML → /usr/share/divine-shell
│   ├── divine-installer/       the live ISO's installer
│   │   ├── app/                QML window → /usr/share/divine-installer
│   │   ├── backend             probe, shrink-info, install: run as root through sudo
│   │   └── test.sh             backend test (runs in check())
│   ├── divine-cursors/         the divineOS cursor theme
│   │   ├── svg/                one SVG per cursor ({ROT} turns spinners and resize arrows)
│   │   ├── cursors.list        name, hotspot, frames and aliases of each cursor
│   │   └── make-cursors.sh     rsvg-convert + xcursorgen
│   ├── repostation/            GitHub app store + auto-builder (Rust, ratatui)
│   │   ├── PKGBUILD
│   │   └── src/                main (CLI) · tui · github · engine
│   ├── devenv/                 terminal IDE (Neovim distribution)
│   │   ├── PKGBUILD            pre-fetches every plugin at its locked commit
│   │   ├── devenv              launcher → /usr/bin/devenv
│   │   └── config/             init.lua, lazy-lock.json, lua/devenv/{plugins,keys,tooling}.lua
│   ├── divine-pkg/             Arch + AUR + Debian package command (Bash)
│   │   ├── divine-pkg
│   │   └── test.sh             routing test against stub pacman/paru/distrobox (runs in check())
│   ├── devine-monitor/         system monitor (Rust: sysinfo + NVML, ratatui)
│   │   └── src/                main (CLI, --json) · sample · tui
│   ├── devine-tweaks/          Settings: root helper, polkit action, launcher (UI is in divine-shell)
│   │   ├── apply-sysctl        allowlisted, validated sysctl writer run through pkexec
│   │   └── test.sh             helper validation test (runs in check())
│   └── devine-files/           dual-pane file manager (its own Quickshell instance)
│       ├── app/                QML → /usr/share/devine-files
│       ├── devine-files-op     copy/move/extract/trash/mkdir/rename, never overwrites
│       └── test.sh             file-operation test (runs in check())
└── iso/                        archiso overlay on top of the stock releng profile
    ├── packages.x86_64         appended to releng's list
    ├── profiledef.sh           appended to releng's profiledef (name, label, publisher, boot modes)
    ├── grub/grub.cfg           the ISO's UEFI boot menu
    ├── syslinux/               the ISO's BIOS boot menu (vesamenu configs + splash.svg)
    └── airootfs/               live-session-only files (the autologin user)
```

New packages each get their own `pkgs/<name>/` directory and are picked up by the build automatically.

To build one package by hand, run `BUILDDIR=/tmp/makepkg makepkg` in its folder. Plain `makepkg` uses the package's `src/` as its work folder and wipes it first, which deletes the Rust code of devine-monitor and RepoStation.

### Why the code is split between a package and the ISO

All divineOS behaviour lives in **packages**, not in the ISO. The ISO only adds what's specific to the live session. An installed system then gets the same tuning and branding as the live one, and with a hosted repo (see Package updates) its divineOS packages update through `pacman -Syu` without reinstalling.

## Build pipeline

```
build.sh (root, inside archlinux container or on Arch)
 │
 ├─ 1. pacman -S archiso base-devel git librsvg grub inter-font xorg-xcursorgen jq …
 ├─ 2. makepkg pkgs/* + AUR paru ────►  /tmp/divineos/repo/*.pkg.tar.zst
 │     (as user "builder")             repo-add → [divine] local repo
 │     divineos-base build():          (gpg-signed when DIVINE_SIGNING_KEY is set)
 │       rsvg-convert logo.svg      → plymouth logo.png
 │       rsvg-convert wallpaper.svg → 3840×2160 PNG
 │       GRUB theme: images + grub-mkfont Inter
 │       git clone CachyOS/ananicy-rules
 │       + hosted repo's mirrorlist and key, when DIVINE_REPO_URL is set
 │     "build.sh repo" stops here    → out/repo (what CI publishes)
 ├─ 3. profile = /usr/share/archiso/configs/releng
 │       + iso/airootfs overlay, plus a copy of the repo for divine-install
 │       + iso/grub/grub.cfg + divineos-base's GRUB theme, iso/syslinux menu + splash
 │       + iso/packages.x86_64, iso/profiledef.sh appended
 │       + [divine] repo in pacman.conf (build-time only)
 │       + "plymouth" hook in initramfs, "quiet splash" in every boot entry
 └─ 4. mkarchiso → out/divineos-*.iso
```

Basing on releng means bootloaders (GRUB for UEFI, syslinux for BIOS), networking (systemd-networkd + iwd), the pacman keyring service and VM guest tools stay in sync with upstream archiso.

## Boot and init flow

```
firmware → GRUB, divineOS theme (UEFI) / syslinux (BIOS) — "divineOS", quiet splash
  → initramfs: base udev plymouth … archiso
      plymouth: divineOS splash (breathing logo, LUKS prompt)
  → systemd (default: graphical.target)
      ├─ zram-generator   → /dev/zram0 swap, zstd, ½ RAM ≤ 8 GiB
      ├─ systemd-sysctl   → /usr/lib/sysctl.d/99-divineos.conf
      ├─ ananicy-cpp      → auto nice/ionice/sched from CachyOS rules
      ├─ NetworkManager, bluetooth (upower, power-profiles-daemon via D-Bus)
      └─ greetd (display-manager, vt1, replaces getty@tty1)
           live ISO:  create user "live" → autologin → start-hyprland
           installed: divine-greeter (cage + qs greeter.qml; tuigreet fallback) → start-hyprland
  → Hyprland (~/.config/hypr/hyprland.lua from /etc/skel)
      ├─ qs -p /usr/share/divine-shell   wallpaper, menu bar, dock, Control Center, launcher,
      │                                  notifications, OSD, lock screen, app switcher,
      │                                  overview, capture bar, Welcome
      ├─ hyprpolkitagent
      ├─ hypridle                         lock after 5 idle minutes and before sleep
      └─ wl-paste --watch cliphist store  clipboard history
```

## Performance baseline (`divineos-base`)

| Area | Setting | Why |
|---|---|---|
| Swap | zram, zstd, `swappiness=180`, `page-cluster=0` | Compressed RAM swap; no disk swap I/O |
| Scheduling | ananicy-cpp + CachyOS rules | Compilers and indexers yield to the compositor and audio |
| Writeback | `dirty_bytes=256M`, `dirty_background_bytes=64M` | Large copies don't freeze the UI |
| Caches | `vfs_cache_pressure=50` | Keeps file trees hot for editors and LSPs |
| Dev | `inotify.max_user_watches=524288` | File watchers on large repos |
| Network | BBR + fq, TCP Fast Open | Lower latency under load |
| Shutdown | `DefaultTimeoutStopSec=10s` | No 90 s hang on a stuck unit |
| Boot | `quiet splash`, `nmi_watchdog=0` | Clean boot, one less per-CPU interrupt |

All defaults live in `/usr/lib/…`. Override any of them with a file of the same name in `/etc/…`.

## Design language: liquid glass

The reference is macOS 26 Control Center: translucent tiles that refract what's behind them, with a curved lens rim, a light chromatic edge, continuous corners and spring motion.

**Refraction happens in the compositor, not in each app.** Hyprland 0.57 ships an `acrylic` blur variant: a lens shader with refraction, a curved "bulb" rim and chromatic aberration, applied to whatever is behind a surface (windows and wallpaper). divineDE turns it on globally (`decoration.blur.variant = "acrylic"`). Any window or panel becomes glass just by having a translucent background.

The reactbits `GlassSurface` / `GlassIcons` components fake the same effect inside a web page, using SVG displacement maps over `backdrop-filter`. They only work in Chromium, can only see the page's own pixels (not other windows), and would force the shell into a webview. divineDE gets the real effect natively, so the shell has no web dependency.

| Token | Value |
|---|---|
| Corner radius / power | 22 px / 4 (squircle) |
| Glass tint | dark `rgba(23,28,48,.42)` / light `rgba(255,255,255,.45)`, 1 px white rim, top-half gloss |
| Accent | `#0A84FF` → `#64D2FF`, indigo `#5E5CE6` |
| Type | Inter (UI), JetBrains Mono Nerd Font (code) |
| Motion | spring (mass 1, stiffness 238, damping 24) for windows, ease-out-quint for overlays |

## divineDE shell

| Key | Action |
|---|---|
| `Super+Space` | Launcher: search apps by name or keyword and files or folders in your home by name, or type arithmetic (`3*(4+5)^2`) and press Enter to copy the result |
| `Super+Shift+V` | Clipboard history: type to filter, Enter copies the entry back (then paste with `Ctrl+V`), `Shift+Delete` forgets it |
| `Super+C` | Control Center (or click the sliders icon in the menu bar) |
| `Super+M` | System Monitor window |
| `Super+,` | Settings |
| `Super+N` | Notification Center (or click the clock) |
| `Super+L` | Lock the screen |
| `Super+Return` | Terminal |
| `Super+E` | Files |
| `Super+Q` | Close window |
| `Alt+Tab` | App switcher: keep Alt held and press Tab (`Shift+Tab` goes back); letting go switches |
| `Super+Tab` | Overview: every window as a live thumbnail, grouped by workspace |
| `Print` | Capture bar: screenshots and screen recording |

**Clipboard history:** every copy (text or image) goes into cliphist's database (`~/.cache/cliphist/db`, last 750 entries). Copies a password manager marks as secret aren't kept. Run `cliphist wipe` to clear it.

**File search:** the launcher looks up names (two letters or more) under your home with `fd`, skipping hidden and git-ignored files. Names starting with what you typed come first, then the shallowest. Enter opens the file in its default app, or the folder in Files.

**App switcher and overview:** `Alt+Tab` shows one icon per app with a window, most recently used first; letting go of Alt focuses that app's most recent window (hovering or the arrow keys also choose, Escape cancels). `Super+Tab` lays every window out as a live thumbnail under its workspace: click one to go to it, a workspace's title to switch there, or anywhere else to leave.

**Capture bar** (`Print`): Screen (the focused monitor), Window (click one), Selection (drag), Record Screen and Record Selection. Screenshots go to `~/Pictures/Screenshots` and the clipboard, with a notification. Recordings (`wf-recorder`, no audio) go to `~/Videos/Screen Recordings`; while one runs, a red stop button sits in the menu bar.

**Menu bar:** the logo opens the launcher, then the focused app's name and workspace dots. On the right: battery, Wi-Fi, Bluetooth and volume status, the Control Center button, and the clock.

**Dock:** a glass shelf along the bottom of every screen. Pinned apps come first, then a divider and any other app with a window open. Icons magnify under the pointer and show their name; a dot marks apps with windows (brighter for the focused one).
- Click launches the app (the icon bounces until its window appears), focuses it, or steps to its next window
- Right-click: New Window, Keep in Dock / Remove from Dock, Quit (closes all its windows)
- Pins are saved in Quickshell's state folder; defaults are Files, kitty, devenv, RepoStation, System Monitor and Settings (plus Install divineOS in the live session)
- Windows tile above it (it reserves its height); fullscreen windows cover it

**Control Center:**
- Wi-Fi and Bluetooth toggles, each showing the network or connected device name
- Now Playing (any MPRIS player)
- Power Mode, which cycles through power-profiles-daemon profiles
- Dark/light appearance (persisted, and synced to GTK `color-scheme`)
- Selection screenshot, saved to `~/Pictures/Screenshots` and copied to the clipboard
- Airplane mode and mic mute
- Lock, then log out, restart and shut down (those three need a second tap)
- Display brightness (only when a backlight exists) and sound volume sliders

**Notifications:** divine-shell is the notification server (freedesktop D-Bus spec).
- New ones slide in as glass banners in the top-right corner: app icon or image, summary, body, and action buttons. They hide after the app's timeout (6 s by default) unless hovered; critical ones stay. Clicking runs the app's default action; the hover ✕ dismisses.
- The **Notification Center** (click the clock or `Super+N`) keeps everything not yet dismissed, newest first, with **Do Not Disturb** (no banners except critical; a moon shows in the menu bar) and **Clear**.
- Body markup is shown, but `<img>` tags are dropped so a remote image can't report that you read the message.

**OSD:** changing volume (keys, or any app) or brightness (keys) shows a glass level pill under the menu bar for 1.5 s. It stays quiet while the Control Center's own sliders are open.

**Lock screen:** `Super+L`, the Control Center's lock button, 5 idle minutes, or going to sleep (hypridle: `~/.config/hypr/hypridle.conf`). It's the blurred wallpaper with the date, a large clock, your picture (`~/.face`) and name, and a password field.
- It uses the Wayland session-lock protocol, so if the shell crashes the screen stays locked instead of exposing the desktop.
- Passwords are checked by PAM (`/etc/pam.d/divine-lock`, which includes `login`), so faillock applies: after 3 wrong tries the account waits 10 minutes, and the lock screen shows PAM's message.
- Notifications and the OSD don't appear over it.

**Login screen:** greetd runs `divine-greeter`, which shows `greeter.qml` fullscreen in the cage kiosk. It looks like the lock screen, with the default wallpaper.
- Accounts are the passwd entries with uid 1000–59999 and a login shell. Arrows beside the name switch between them, and the last one to log in comes first (`/var/cache/divine-greeter/last-user`).
- The picture comes from `/var/lib/AccountsService/icons/<user>`, since the greeter can't read your `~/.face`. Settings > Account puts it there.
- Passwords go to greetd (PAM `greetd`); a correct one starts Hyprland. Restart and Shut Down sit at the bottom.
- If cage or Quickshell can't start (no usable GPU, a QML error), `divine-greeter` falls back to tuigreet.

**Code layout:** `Sys.qml` is the only file that talks to system services. The view files bind to its plain properties, so missing hardware never breaks a view. To render the views on any machine with PySide6, swap in a mock `Sys.qml`.

## RepoStation

```bash
repostation                        # store UI: browse categories, search, read READMEs
repostation search hex viewer      # quick search from the shell
repostation install sharkdp/hexyl  # build from source and install
repostation update                 # rebuild every app whose upstream moved
repostation remove sharkdp/hexyl
repostation list
```

In the UI: `/` search, `Tab` or `←` `→` to switch between categories and results, `↵` to read the README. On a selected app: `i` install, `u` update, `x` remove, `o` open on GitHub. An install pauses the UI and runs in the plain terminal, so sudo prompts and compiler output work normally.

**How an install works:**
1. Shallow-clone into `~/.local/opt/repostation/<owner>__<repo>/src`.
2. Detect the build system (first match wins): `Cargo.toml` → `meson.build` → `CMakeLists.txt` → `go.mod` → `package.json` → `Makefile`.
3. Work out which system packages are missing, using `pacman -T` (it honours `provides`):
   - **Toolchain** for the detected build system.
   - **Meson / CMake libraries:** `dependency('x')` and `pkg_check_modules(… x)` entries are looked up as pkg-config files. Their owning packages come from pacman's file database (`pacman -F`), which is fetched once if it's missing. `find_package(…)` uses a short built-in table instead.
   - **Rust `-sys` crates** in `Cargo.lock`: a short built-in table.
4. Show the plan and ask once, then run `sudo pacman -S --needed` for whatever is missing.
5. Build with native CPU flags: `-O2 -march=native` for C/C++/cgo, `-C target-cpu=native` for Rust.
6. Install into the app's prefix and symlink its `bin/` into `~/.local/bin` (on `PATH` via `/etc/profile.d/divineos.sh`). An existing file there that RepoStation didn't create is never overwritten.
7. Record the app in `~/.local/share/repostation/installed.json`. A failed install leaves nothing behind.

**Updates:** `git ls-remote` checks the upstream HEAD without using the GitHub API. If it moved, RepoStation shallow-fetches, cleans and rebuilds into a fresh prefix.

Building runs the project's own build scripts as your user. The plan screen says so before you confirm.

Anonymous GitHub search is limited to 10 requests a minute. Export `GITHUB_TOKEN` to raise that.

## devenv

`devenv [files…]` opens a VS Code-style IDE in the terminal. It's Neovim with its own app name, so its plugins and settings never touch a personal Neovim config. Plugins are pinned in `lazy-lock.json` and pre-fetched by the package, so the first launch works offline.

| Need | Standard preset | Either preset |
|---|---|---|
| Save, undo, redo | `Ctrl+S`, `Ctrl+Z`, `Ctrl+Y` | `Ctrl+S` |
| Copy / cut / paste (system clipboard) | `Ctrl+C` / `Ctrl+X` / `Ctrl+V`, select with `Shift+arrows` | `"+y`, `"+p` |
| Quick open, command palette | `Ctrl+P`, `Ctrl+Shift+P` or `F1` | `Space f f`, `Space f c` |
| Find in file / project | `Ctrl+F` / `Ctrl+Shift+F` | `Space f g` |
| File tree, terminal | `Ctrl+B`, ``Ctrl+` `` or `Ctrl+\` | `Space e`, `Space t` |
| Close tab, next/previous tab | `Ctrl+W`, `Ctrl+PgDn` / `Ctrl+PgUp` | `Space b d` |
| Comment, move line, format | `Ctrl+/`, `Alt+↑/↓`, `Shift+Alt+F` | `gcc`, `Space l f` |
| Definition, references, rename, quick fix | `F12`, `Shift+F12`, `F2`, `Ctrl+.` | `gd`, `grr`, `Space l a` |
| Debug | `F5` start or continue, `F9` breakpoint, `F10` / `F11` / `Shift+F11` step | `Space d …` |
| Git | `Space g g` opens LazyGit (stage, commit, push); `Space g h` stages a hunk | |

Press `Space` and wait to see every leader map (which-key).

**Presets.** The standard preset opens files ready to type; `Esc` still drops into Vim's Normal mode. Switch for good with `:DevenvKeys vim` or `:DevenvKeys standard`, then restart. Personal settings go in `~/.config/devenv/user.lua`.

**Language tooling on demand.** The first time you open a file type, devenv installs what that language needs and attaches it to the buffers already open:
- Its treesitter parser, compiled with `tree-sitter-cli`.
- Its language server, through Mason. Covered: Lua, Python, Rust, Go, C/C++, JS/TS, JSON, YAML, TOML, shell, HTML, CSS, Markdown and Zig.

The first `F5` installs the debugger: codelldb, debugpy, delve or js-debug.

**Glass.** Tokyo Night runs with a transparent background, so kitty's translucency plus Hyprland's acrylic blur turn the editor into a glass pane.

**Startup.** Only the colour scheme, snacks and treesitter load at startup; everything else waits for an event, key or command.

## divine-pkg

```bash
divine-pkg install htop          # in the Arch repos → pacman
divine-pkg install visual-studio-code-bin   # only in the AUR → paru (shows the PKGBUILD first)
divine-pkg install deb:cowsay    # force Debian
divine-pkg install ./tool.deb    # a downloaded .deb
divine-pkg remove cowsay         # removes from wherever it came from
divine-pkg update                # pacman + AUR + the Debian container
divine-pkg search ripgrep        # all three sources
divine-pkg list | info <pkg> | shell | run <cmd>
```

**Where a package comes from.** Without a prefix, the first match wins: the Arch repos, then the AUR, then Debian. Prefix a name with `arch:`, `aur:` or `deb:` to pick the source yourself.

**How Debian packages run.** They install into a rootless Distrobox container (`debian:stable` on podman). The container is created on the first Debian install, and only after you confirm.
- Each package's commands and `.desktop` entries are exported to the host, so they show up on `PATH` and in the launcher.
- A command the host already has (say `python3`) isn't exported, so Arch software is never shadowed. `divine-pkg run <cmd>` reaches the Debian copy.
- `.deb` and Arch software never share libraries, which is what avoids dependency hell.
- Exports are tracked in `~/.local/share/divine-pkg/debian/<pkg>`, so `remove` cleans them up.

**AUR packages** build through paru. paru isn't in the official repos, so `build.sh` builds it from the AUR into the `[divine]` repo.

## devine-monitor

```bash
devine-monitor          # terminal dashboard
devine-monitor --gui    # glass window (also Super+M, or "System Monitor" in the launcher)
devine-monitor --json   # one JSON snapshot per second, for scripts and the window
```

**Terminal dashboard:**
- **CPU:** total history graph and per-core bars, with package temperature.
- **Memory and swap.**
- **GPU:** utilisation, VRAM, temperature and power, plus a history graph.
- **Network:** download and upload graphs.
- **Temperatures:** every sensor, sorted hottest first.
- **Processes:** a table sorted by CPU, memory, PID or name (`c`/`m`/`p`/`n`). `/` filters by name or command line. `x` ends the selected process and `X` kills it; both ask `y/N` first. The selection follows the process through re-sorts.

**Glass window.** It lives in divine-shell (`Monitor.qml`) and reads `devine-monitor --json`, which only runs while the window is open. It shows CPU, memory, GPU and network tiles, each with a 60-second graph, and the top processes. Hyprland floats it and blurs behind it.

**GPU support:**

| GPU | Source | Notes |
|---|---|---|
| NVIDIA | NVML | Loaded at runtime, so it works whenever the driver is installed |
| AMD | amdgpu's sysfs files | |
| Intel iGPU | none | No busy counter in sysfs; the GPU shows as absent |

## Settings (devine-tweaks)

Open it with `Super+,`, `devine-tweaks`, or "Settings" in the launcher. It's a glass divine-shell window (`Tweaks.qml`) with five pages:

| Page | What it changes | Where it's stored |
|---|---|---|
| Appearance | Dark or light; glass style (Liquid acrylic, Frosted kawase, or Off for the least GPU work); animations on or off | `~/.config/hypr/tweaks.lua` |
| Displays | Per-monitor scale (Auto, 100–200%) and resolution/refresh rate, from Hyprland's list of supported modes. Current positions are kept, so multi-monitor layouts don't move | `~/.config/hypr/tweaks.lua` |
| Sound | Default output device (PipeWire) and each card's profile, such as Analog Stereo, Pro Audio or Off (`pactl`) | PipeWire's own state |
| Performance | Swappiness, file-cache pressure, TCP congestion control (BBR/CUBIC), inotify watch limit | `/etc/sysctl.d/99-z-devine-tweaks.conf` |
| Account | Your picture: one of eight drawn ones, a photo from `~/Pictures` (cropped square), or none (your initial). It's saved as a 256 px PNG | `~/.face` (lock screen), and AccountsService's copy in `/var/lib/AccountsService/icons` (login screen) |

**Hyprland settings.** `hyprland.lua` loads `tweaks.lua` last with `pcall(require, "tweaks")`, so Settings wins and a missing file is harmless. Each change rewrites the file and runs `hyprctl reload`.

**Kernel settings** need root. Apply runs `pkexec /usr/lib/devine-tweaks/apply-sysctl …`, and polkit action `org.divineos.tweaks.apply-sysctl` asks for your password through hyprpolkitagent.
- The helper accepts only four allowlisted keys, each with a regex-validated value. Anything else is refused before any write.
- It writes atomically, and its file sorts after the divineOS defaults so it takes effect at boot.
- Reset deletes that file and reloads every sysctl config.

## Files (devine-files)

Open it with `Super+E`, `devine-files [folder]`, "Files" in the launcher or dock, or any app's "open folder". It's a dual-pane file manager in liquid glass: places on the left, two folders side by side, and a toolbar of function keys. It runs as its own Quickshell instance (app id `devine-files`), so a slow folder never stalls the desktop shell; extra windows open in the same process.

| Key | Action |
|---|---|
| `Tab` | Switch pane |
| `Enter` / double-click | Open a folder, or a file in its default app (`gio open`) |
| `Backspace`, `Alt+↑` / `Alt+←` `Alt+→` | Parent folder / back, forward |
| `Space` or `Insert`, `Ctrl`/`Shift`+click, `Ctrl+A` | Select entries (operations use the selection, or the highlighted entry) |
| typing | Jump to the first name that starts with what you typed |
| `F2` | Rename in place |
| `F4` | Terminal (kitty) in this folder |
| `F5` / `F6` | Copy / move to the other pane |
| `F7` or `Ctrl+Shift+N` | New folder, ready to rename |
| `Del` or `F8` | Move to Trash (`gio trash`) |
| `Ctrl+E` | Extract archives here, each into its own folder (bsdtar: zip, tar.*, 7z, rar, iso…) |
| `Ctrl+H` / `Ctrl+L` | Show dotfiles / type a path (`~` works) |

- **Nothing is overwritten.** A name that's taken gets " 2", " 3"… like Finder (`photo 2.jpg`, `backup 2.tar.gz`). Operations queue and run one at a time; failures show in the status line.
- **Git.** Inside a repository, files show a badge (U untracked, A added, M modified, R renamed, C conflict), folders a dot for changes inside, and the footer shows the branch.
- **Thumbnails** for PNG, JPEG, GIF, WebP, SVG and BMP; other files get an icon for their kind.
- Mounted drives under `/run/media/$USER` appear under Locations. Light/dark follows the desktop setting.

## Component architecture

| Component | Stack | Approach |
|---|---|---|
| **divineDE shell** (`divine-shell`) | Quickshell (Qt 6 / QML) | Done: menu bar, dock, Control Center, launcher (apps, files, calculator, clipboard), app switcher, overview, capture bar, notifications, OSD, lock screen, and the greetd login screen (`greeter.qml`, which uses only the Theme-based views, never `Sys`). Glass panels get the acrylic blur through a Hyprland layer rule (`ignore_alpha` clips it to the drawn tiles). QML draws the tint, gloss and rim. |
| **divine-pkg** | Bash, paru, Distrobox + podman | Done (see above). |
| **RepoStation** | Rust, ratatui, ureq | Done (see above). The UI thread blocks for each network call; the status line says "Searching…" while it waits. |
| **devenv** | Neovim 0.12 distribution | Done (see above). Built on lazy.nvim, snacks.nvim (picker, explorer, terminal, LazyGit, dashboard), gitsigns, nvim-treesitter, Mason + mason-lspconfig, blink.cmp, nvim-dap + dap-ui, bufferline, lualine and which-key. |
| **devine-monitor** | Rust, ratatui, sysinfo, nvml-wrapper; Quickshell window | Done (see above). |
| **devine-launcher** | Quickshell module | Done: app search, the inline calculator and clipboard history (cliphist; the launcher lists `cliphist list` and restores with `cliphist decode \| wl-copy`). |
| **devine-files** | Quickshell (Qt 6 / QML) + Bash helper | Done (see Files above). Archives go through bsdtar (libarchive) and git status through the git CLI, so there's no C++ to build. |
| **devine-tweaks** | Quickshell window + Bash polkit helper | Done (see Settings above). |

## Status

- [x] Architecture, ISO pipeline, init flow
- [x] Logo (SVG, ASCII), wallpaper, Plymouth theme, fastfetch, greeter
- [x] Performance tuning, Hyprland liquid-glass config
- [x] `divine-shell`: menu bar, dock, Control Center, launcher
- [x] `divine-shell`: notifications, OSD, lock screen
- [x] `divine-shell`: graphical greetd greeter (tuigreet as fallback)
- [x] `divine-shell`: app switcher, overview, capture bar, launcher file search, account pictures
- [x] `divine-pkg`
- [x] `RepoStation`
- [x] `devenv`
- [x] Disk installer (`divine-install`: erase, alongside, replace, manual; encryption) + optional hosted `[divine]` repo
- [x] GRUB boot menu theme, cursor theme, Welcome guide
- [x] devine-monitor
- [x] devine-tweaks (Settings)
- [x] devine-files
