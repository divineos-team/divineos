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

The output is `out/divineos-YYYY.MM.DD-x86_64.iso`. Give a VM 3D acceleration (without it everything draws on the CPU and is slow): QEMU with `-device virtio-vga-gl -display gtk,gl=on`, or VMware with "Accelerate 3D graphics". In VMware, apps (the shell included) render on the CPU, because Hyprland can't use buffers from VMware's GPU driver, so expect it to be slower than on real hardware.

## Install to disk

Boot the ISO. The Welcome guide opens with an **Install divineOS** button; the installer is also first in the dock and in the launcher (`divine-install`). It's a glass window with six steps, and nothing on disk changes before the last one.

1. **Welcome** checks the firmware (UEFI or BIOS) and the internet connection. The connection is optional: the installer copies the live system from the ISO, so nothing downloads.
2. **Disk** offers four ways in:
   - **Erase a disk.** A new GPT table: a 1 GiB EFI partition at `/boot` plus a Btrfs root (UEFI), or a BIOS boot partition plus root (BIOS). You can encrypt the root with LUKS2; on BIOS, `/boot` then gets its own 1 GiB partition, because GRUB can't read LUKS2 with argon2.
   - **Alongside.** Uses the disk's free space, or shrinks a Windows (NTFS) or ext4 partition: drag the divider to split the space. The other system keeps at least what its files use, plus 10% and 1 GiB. It reuses the disk's EFI partition, and adds one (or a BIOS boot partition, on BIOS with GPT) only when the disk has none.
   - **Replace a partition.** Formats one partition of 20 GB or more for divineOS and reuses the disk's EFI partition.
   - **Manual.** Opens GParted. Then pick the partition for divineOS (formatted as Btrfs) and, on UEFI, the EFI partition (kept as it is).
3. **Region:** time zone, language, and keyboard. The keyboard sets the console keymap, the login screen and Hyprland. Greek, Russian, Ukrainian and Georgian also get US English; Alt+Shift switches between them.
4. **Account:** your name, username, computer name and password. You're in `wheel` (sudo); root's password is locked.
5. **Summary** says what happens to which disk.
6. **Install** shows progress and the full log, then Restart.

Things to know:
- **Windows must shut down fully before it can be shrunk.** With Fast Startup on, Windows hibernates instead, and `ntfsresize` refuses the partition. Turn Fast Startup off in Windows' power settings and shut down.
- After an Alongside or Replace install, GRUB lists Windows and other systems (os-prober).
- The root is Btrfs in Timeshift's layout: subvolumes `@` (the system), `@home`, `@log` (`/var/log`) and `@pkg` (`/var/cache/pacman/pkg`), mounted with `compress=zstd,noatime`. Copied without sparse holes (no `rsync -S`): GRUB's Btrfs reader stops at a hole at the end of a file, such as the kernel's zero tail. Snapshots of `@` are Settings > Backup's and the boot menu's; logs, downloaded packages and your files stay out of them.
- VM guest tools (VMware, VirtualBox, QEMU, Hyper-V) are on the ISO, so the install keeps the ones this machine needs and turns them on. Drivers that have to download (NVIDIA, Vulkan for Intel and AMD) are one click in Settings > Drivers after the first boot.

**How it works.** The window (`/usr/share/divine-installer`, Quickshell) runs `/usr/lib/divine-installer/backend` as root through sudo; the live user needs no password.
- `backend probe` reads the disks (`lsblk`, skipping the live medium), the other systems on them (`os-prober`), the time zones and the languages.
- `backend shrink-info` measures a partition with `ntfsresize --info` or `resize2fs -P`.
- `backend install` reads the settings as JSON on stdin, so passwords never appear on a command line. It partitions (`sfdisk`), formats (Btrfs, then the subvolumes), and copies the live system's image (`/run/archiso/airootfs`, the squashfs as built) onto the new root with `rsync`. Then it makes the copy an installed system:
  - It removes archiso's live setup and divineOS's live session (`live_only` lists them), copies the kernel back into `/boot` (archiso empties it), restores the stock mkinitcpio preset, and gives the system its own machine ID, pacman keyring and the live system's mirror list.
  - Every package becomes a dependency of the base set (base, linux, firmware, microcode, `divineos-base`, GRUB, os-prober, a few disk tools) and of the drivers `divine-drivers` picks; `pacman -Rns` then removes what's left over (archinstall, other VMs' guest tools, the installer itself), and the dangling service links go too.
  - It writes fstab (subvolumes by name, without `subvolid`, so a restored snapshot still mounts), hostname, locale, keymap and the account. Last come GRUB and `post-install`. After an Erase, GRUB also goes to the removable fallback path, for firmware that forgets its boot entries.

`test.sh` checks the backend's parsing, partition maths and config edits (it runs in `check()`).

`/usr/lib/divineos/post-install` then runs inside the new system. It also turns an existing Arch install into divineOS:
- It points `[divine]` at the hosted repo, or removes it if the ISO was built without one.
- It copies the divineOS dotfiles from `/etc/skel` into the homes of users created before `divineos-base` was installed.
- It drops any other `zram-generator.conf`, so divineOS's own zram setting applies.
- It adds `quiet splash` to the boot entries (systemd-boot, GRUB, Limine or a UKI) and the `plymouth` hook to the initramfs.
- For GRUB, it copies the divineOS theme next to `grub.cfg` (GRUB reads it before an encrypted root is unlocked). It also names the entry divineOS, always shows the menu, and turns on os-prober.
- On a Btrfs root in the `@` layout it sets up snapshots: Timeshift's config in Btrfs mode (daily, five kept, home folders left out), `divineos-snapshot.timer` (`timeshift --check` once a day, instead of Timeshift's cron jobs), and `grub-btrfsd --timeshift-auto`, which adds a "divineOS snapshots" submenu to GRUB as snapshots come and go.

## Boot menu

On UEFI, the ISO starts divineOS's own GRUB menu (`iso/grub/grub.cfg`): a glass panel over the dimmed Tide wallpaper, with Try divineOS, a text-console mode, Boot from the next device, Firmware settings, Restart and Shut down. Installed systems get the same theme for their GRUB menu on UEFI; on BIOS, GRUB's text menu (the graphical one triple-faults VMware on Hyper-V hosts).

The theme is `branding/grub/theme.txt`. `divineos-base`'s `build()` renders the images it names (background, panel, logo, entry icons, the selected-entry highlight) and the Inter fonts (`grub-mkfont`) into `/usr/share/grub/themes/divineos`.

BIOS boots the ISO through syslinux, because archiso has no BIOS GRUB. Its menu (`iso/syslinux`) copies the GRUB look: Try divineOS, the text console, Boot existing OS, Restart and Shut down, on a 640×480 splash (`splash.svg`) with the glass panel, logo and key hint. vesamenu draws the text in 8×16 cells, so the panel in `splash.svg` follows the rows and columns in `archiso_head.cfg`. Installed BIOS systems use the themed GRUB.

## Cursor

`divine-cursors` is the divineOS cursor theme: a dark pointer with a white outline, and a blue spinner for busy and working. Each cursor is an SVG in `pkgs/divine-cursors/svg`. The build renders it at 24 to 96 px with `xcursorgen`, plus the alias names apps ask for (`pointer`, `grab`, `col-resize` and so on). Names it doesn't draw fall back to Adwaita. Hyprland, the login screen and GTK apps use it (`XCURSOR_THEME`, and a GSettings override).

## Welcome

The Welcome guide opens at the first login, and on every live boot. It's a divine-shell window (`Welcome.qml`) with six pages:
- **divineOS**, with an Install button in the live session.
- **Set Up:** a theme, a web browser, media codecs and the drivers this computer needs, one click each (through `pkg-helper`, one password prompt).
- **The Desktop:** the menu bar, dock, Control Center, launcher, overview and notifications.
- **Shortcuts:** every key binding.
- **Apps:** what each app is for, with an Open button.
- **Next Steps:** installing software, updating, and where the settings live.

Untick **Show at startup** to stop it opening at login. Reopen it from "Welcome" in the launcher or with `divine-welcome`.

## Package updates

`pacman -Syu` updates everything that comes from Arch. divineOS's own packages (shell, apps, branding) stay at the versions the ISO installed, because the new system has no `[divine]` repo. To ship a newer divineOS, build a new ISO.

On an installed system, every pacman run that changes packages first makes a Timeshift snapshot (`05-divineos-snapshot.hook` runs `/usr/lib/divineos/snapshot`; at most one an hour, and never blocking the update). If an update breaks something, restore the snapshot in Settings > Backup, or pick it from "divineOS snapshots" in the boot menu when the system won't start.

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
│   ├── wallpaper.svg           "Tide", the default wallpaper (4K PNG at build, plus Dusk, Ember and Lagoon)
│   └── grub/                   GRUB theme: theme.txt, glass panel and entry icons (SVG)
├── pkgs/                       first-party packages → local [divine] pacman repo
│   ├── divineos-base/          installing this turns Arch into divineOS
│   │   ├── PKGBUILD
│   │   ├── divineos-base.install
│   │   ├── post-install        run by divine-install inside the new system
│   │   ├── snapshot            the pre-update Timeshift snapshot (pacman hook)
│   │   ├── test.sh             post-install test (runs in check())
│   │   │                       build() also renders the GRUB theme → /usr/share/grub/themes/divineos
│   │   └── root/               files installed verbatim into /
│   ├── divine-shell/           divineDE: menu bar, dock, Control Center, launcher, Store, Welcome, lock and login (Quickshell)
│   │   ├── PKGBUILD
│   │   ├── divine-lock.pam     PAM config for the lock screen → /etc/pam.d/divine-lock
│   │   ├── divine-greeter      greetd's greeter: the login screen in cage, tuigreet fallback
│   │   ├── divine-session      starts Hyprland, again on the CPU if there's no GPU to draw with
│   │   ├── divine-welcome      opens the Welcome guide (IPC)
│   │   ├── devine-store        opens the Store (IPC); `devine-store updates` its Updates tab
│   │   ├── test-js.mjs         checks shell/*.js: accent picker, weather, Night Light, dock, Store, Disks, Backup (node test-js.mjs)
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
│   │   ├── divine-drivers      which drivers and guest tools this machine needs; installs them
│   │   ├── pkg-helper          the Store's and Settings' root half (pkexec, polkit action)
│   │   └── test.sh             routing, helper and driver tests against stubs (runs in check())
│   ├── devine-monitor/         system monitor (Rust: sysinfo + NVML, ratatui)
│   │   └── src/                main (CLI, --json) · sample · tui
│   ├── devine-tweaks/          Settings: root helpers, polkit actions, launchers (UI is in divine-shell)
│   │   ├── devine-customizer   opens Settings > Appearance, or `devine-customizer desktop`
│   │   ├── devine-disks        opens Settings > Disks; devine-backup opens Settings > Backup
│   │   ├── apply-sysctl        allowlisted, validated sysctl writer run through pkexec
│   │   ├── manage-users        add, remove and promote accounts, run through pkexec
│   │   ├── printers            add and remove driverless printers (lpadmin), run through pkexec
│   │   ├── disks               erase, format and write images to drives that aren't the system's, run through pkexec
│   │   ├── backup, snapshots   make, restore and delete Timeshift snapshots; list them (no password)
│   │   └── test.sh             helper validation tests (runs in check())
│   └── devine-files/           dual-pane file manager (its own Quickshell instance)
│       ├── app/                QML → /usr/share/devine-files
│       ├── devine-files-op     copy/move/extract/compress/trash/mkdir/rename, never overwrites
│       ├── test.sh             file-operation test (runs in check())
│       └── test-js.mjs         bulk rename and bookmarks (node test-js.mjs)
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
 │       rsvg-convert wallpaper.svg → 3840×2160 PNG, and its hue turned for Dusk, Ember, Lagoon
 │       GRUB theme: images + grub-mkfont Inter
 │       git clone CachyOS/ananicy-rules
 │       + hosted repo's mirrorlist and key, when DIVINE_REPO_URL is set
 │     "build.sh repo" stops here    → out/repo (what CI publishes)
 ├─ 3. profile = /usr/share/archiso/configs/releng
 │       + iso/airootfs overlay
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
           live ISO:  create user "live" → autologin → divine-session → start-hyprland
           installed: divine-greeter (cage + qs greeter.qml; tuigreet fallback) → divine-session → start-hyprland
  → Hyprland (~/.config/hypr/hyprland.lua from /etc/skel)
      ├─ qs -p /usr/share/divine-shell   wallpaper, menu bar, dock, Control Center, launcher,
      │                                  notifications, OSD, lock screen, app switcher,
      │                                  overview, capture bar, Settings, Store, Welcome
      ├─ hyprpolkitagent
      ├─ hypridle                         lock after 5 idle minutes and before sleep (Settings > Power)
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
| Glass tint | dark `rgba(23,28,48,.42)` / light `rgba(255,255,255,.45)`, 1 px white rim, top-half gloss; the Frost, Pitch and Neon themes swap these (see Theming) |
| Accent | `#0A84FF` → `#64D2FF`, indigo `#5E5CE6` |
| Type | Inter (UI), JetBrains Mono Nerd Font (code) |
| Motion | spring (mass 1, stiffness 238, damping 24) for windows, ease-out-quint for overlays |

## divineDE shell

| Key | Action |
|---|---|
| `Super+Space` | Launcher: search apps by name or keyword and files or folders in your home by name, or type arithmetic (`3*(4+5)^2`) and press Enter to copy the result |
| `Super+Shift+V` | Clipboard history: type to filter, Enter copies the entry back (then paste with `Ctrl+V`), `Shift+Delete` forgets it. Copied pictures show as previews |
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

**Mark Up** (`devine-shot FILE`): after each screenshot its thumbnail sits in the bottom-right corner for a few seconds; click it to draw on the picture with a pen, arrows, boxes and text in six colours, or pixelate what shouldn't be seen. `Ctrl+Z` undoes, `Ctrl+C` copies, `Ctrl+S` saves over the file (and copies it), `Esc` closes.

**Menu bar:** the logo opens the launcher, then the focused app's name and workspace dots. On the right: the tray (apps' status icons: click to open, right-click for the app's menu, scroll, middle-click), waiting updates (click for the Store), battery, Wi-Fi, Bluetooth and volume status, the Control Center button, the weather, and the clock (12- or 24-hour, Settings > Date & Time). The weather and the clock open the Notification Center.

**Dock:** a glass shelf along the bottom of every screen. Pinned apps come first, then a divider and any other app with a window open, then another divider, the media player, Downloads and the Trash. Icons magnify under the pointer and show their name; a dot marks apps with windows (brighter for the focused one).
- Click launches the app (the icon bounces until its window appears), focuses it, or steps to its next window
- Rest on an app with windows for live previews of up to four of them; click one to go to it
- Drag a pinned app to a new place, or up off the dock to unpin it
- Right-click: New Window, Keep in Dock / Remove from Dock, Quit (closes all its windows)
- **Media** (while an MPRIS player is open): the album art with a play/pause badge; click plays or pauses, right-click has Previous, Next and Show (the player)
- **Downloads:** click for the 12 newest files and folders in `~/Downloads` (pictures show themselves); click one to open it, or Open in Files
- **Trash:** full or empty icon; click opens it in Files, right-click has Empty Trash (click twice; `gio trash --empty`)
- Pins are saved in Quickshell's state folder; defaults are Files, kitty, devenv, Store, RepoStation, System Monitor and Settings (plus Install divineOS in the live session)
- Windows tile above it (it reserves its height); fullscreen windows cover it
- Settings > Desktop & Dock sets its icon size and magnification, and can hide it: it then reserves nothing and slides away only while a window on that screen reaches down into its strip, coming back when the pointer touches the bottom of the screen. Hyprland's window positions are re-read as windows open, close, move workspaces, float or go fullscreen (not while a floating window is being dragged)

**Control Center:**
- Wi-Fi and Bluetooth tiles, each showing the network or connected device name. The round icon switches the radio; the rest of the tile opens its list:
  - **Wi-Fi:** networks in range (scanned while the list is open) with signal and lock. Saved and open ones join on a click; a new secured one asks for its password. Click the joined network to disconnect or forget it.
  - **Bluetooth:** your devices (click to connect or disconnect, battery shown when the device reports it) and named ones nearby (click to pair; they're trusted and connected once paired)
- Now Playing (any MPRIS player)
- Power Mode, which cycles through power-profiles-daemon profiles, and Do Not Disturb
- Dark/light appearance (persisted, and synced to GTK `color-scheme`), Night Light, airplane mode and mic mute
- Selection screenshot (saved to `~/Pictures/Screenshots` and copied) and one-click recording of the screen (click again, or the menu bar's stop button, to stop)
- Lock, then log out, restart and shut down (those three need a second tap)
- Display brightness (only when a backlight exists) and sound volume sliders. The sound slider's arrow lists outputs and inputs to switch between (PipeWire), with the microphone level.
- Escape closes a list first, then the Control Center

**Night Light** (hyprsunset): warmer colours by hand or every day on a schedule, from Control Center or Settings > Displays (warmth 2500–6000 K). The schedule lives in `~/.config/hypr/hyprsunset.conf`, written by the shell; each switch calls the shell back (`qs ipc call nightlight sync`) so the toggles follow. Turning it on or off by hand lasts until the next switch. Screenshots keep the true colours.

**Weather** ([Open-Meteo](https://open-meteo.com): no account, no key): the menu bar shows the temperature and sky; the Notification Center shows today's high and low and the next five days. It follows the city your time zone is named after unless you pick a place in Settings > Date & Time, which also sets °C or °F (otherwise by the locale) or turns it off. It refreshes every 30 minutes and keeps the last forecast when offline.

**Notifications:** divine-shell is the notification server (freedesktop D-Bus spec).
- New ones slide in as glass banners in the top-right corner: app icon or image, summary, body, and action buttons. They hide after the app's timeout (6 s by default) unless hovered; critical ones stay. Clicking runs the app's default action; the hover ✕ dismisses.
- The **Notification Center** (click the clock or `Super+N`) opens on this month's calendar (arrows or the wheel leaf through months; the month's name comes back) and the weather, then keeps every notification not yet dismissed, newest first, with **Do Not Disturb** (no banners except critical; a moon shows in the menu bar) and **Clear**.
- Body markup is shown, but `<img>` tags are dropped so a remote image can't report that you read the message.

**OSD:** changing volume (keys, or any app) or brightness (keys) shows a glass level pill under the menu bar for 1.5 s. It stays quiet while the Control Center's own sliders are open.

**Lock screen:** `Super+L`, the Control Center's lock button, 5 idle minutes, or going to sleep (hypridle: `~/.config/hypr/hypridle.conf`). It's the blurred wallpaper with the date, a large clock, your picture (`~/.face`) and name, and a password field.
- It uses the Wayland session-lock protocol, so if the shell crashes the screen stays locked instead of exposing the desktop.
- Passwords are checked by PAM (`/etc/pam.d/divine-lock`, which includes `login`), so faillock applies: after 3 wrong tries the account waits 10 minutes, and the lock screen shows PAM's message.
- Notifications and the OSD don't appear over it.

**Login screen:** greetd runs `divine-greeter`, which shows `greeter.qml` fullscreen in the cage kiosk. It looks like the lock screen, with the default wallpaper.
- Accounts are the passwd entries with uid 1000–59999 and a login shell. Arrows beside the name switch between them, and the last one to log in comes first (`/var/cache/divine-greeter/last-user`).
- The picture comes from `/var/lib/AccountsService/icons/<user>`, since the greeter can't read your `~/.face`. Settings > Users puts it there.
- Passwords go to greetd (PAM `greetd`); a correct one starts `divine-session` (Hyprland). Restart and Shut Down sit at the bottom.
- No GPU to draw with (a VM without 3D acceleration): cage can't start its renderer, so `divine-greeter` starts it again on the CPU (`WLR_RENDERER=pixman`, Mesa's llvmpipe). `divine-session` does the same for Hyprland when it quits within 20 seconds (`LIBGL_ALWAYS_SOFTWARE=1`). Slow, but it works.
- If cage or Quickshell still can't start (a QML error), `divine-greeter` falls back to tuigreet.

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

**Drivers.** `divine-drivers` prints, as JSON, what this machine needs beyond every divineOS install: the guest tools of the VM it runs in (`systemd-detect-virt`), and for the graphics cards in `/sys/bus/pci` the NVIDIA driver (`nvidia-open`, GeForce GTX 16 / RTX 20 and newer) or Vulkan and video decoding for Intel and AMD. `divine-drivers --install [ID…]` installs them (with a full `-Syu`, as Arch requires) and turns on their services.

**pkg-helper** (`/usr/lib/divine-pkg/pkg-helper`) is how the Store and Settings change packages as root, through `pkexec` and polkit action `org.divineos.pkg.manage`. It does four things: `install` (`pacman -Syu --needed`, since Arch has no partial upgrades), `remove` (`pacman -Rns`), `upgrade` (`pacman -Syu`) and `drivers`. It refuses anything that isn't a package name.

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

Open it with `Super+,`, `devine-tweaks [page]` (say `devine-tweaks drivers`), or "Settings" in the launcher. "Customize" in the launcher (`devine-customizer`) opens its first two pages, which hold the look of divineOS; "Disks" (`devine-disks`) and "Backup" (`devine-backup`) open those pages. It's a glass divine-shell window (`Tweaks.qml`) with eighteen pages:

| Page | What it changes | Where it's stored |
|---|---|---|
| Appearance | Four themes (Divine Dark, Divine Frost, OLED Pitch, Neon Cyber) that set the mode, accent, glass tint and blur in one click. Dark or light. The accent colour: nine presets, or the wallpaper's own colour. The wallpaper: Tide, Dusk, Ember, Lagoon, or a picture from `~/Pictures`. Icon theme, pointer and its size, and the interface font, each with a Get button for popular ones that aren't installed (Papirus, Breeze, Capitaine, Roboto, IBM Plex and others) | Quickshell's state; GSettings for GTK apps; the pointer and icon theme also in `~/.config/hypr/tweaks.lua` |
| Desktop & Dock | A layout to start from (Divine Default, macOS and Windows 11, where windows float where they open, or Auto-Tiling Pro), then each part of it: space between windows, rounded corners, window border, glass style (Liquid acrylic, Frosted kawase, or Off for the least GPU work), blur strength, motion (Off, Relaxed, Normal, Quick), desktop widgets (clock, system load, sticky note, now playing; drag them where you like), and the dock's size, magnification and auto-hide | `~/.config/hypr/tweaks.lua`; the dock and widgets in Quickshell's state |
| Displays | Night Light (on/off, schedule, warmth). Per-monitor scale (Auto, 100–200%) and resolution/refresh rate, from Hyprland's list of supported modes. Current positions are kept, so multi-monitor layouts don't move | `~/.config/hypr/tweaks.lua`, `hyprsunset.conf` |
| Sound | Default output device (PipeWire) and each card's profile, such as Analog Stereo, Pro Audio or Off (`pactl`) | PipeWire's own state |
| Network | Wi-Fi (Control Center's list), Ethernet, and VPNs: turn them on and off, remove them, and import WireGuard (`.conf`) or OpenVPN (`.ovpn`) files found in `~/Downloads` | NetworkManager (`nmcli`) |
| Bluetooth | Control Center's list (connect, disconnect, pair what's nearby), and forgetting a paired device | BlueZ |
| Printers | Printers on the network and plugged in by USB show up by themselves (driverless: AirPrint, IPP Everywhere, Mopria); a test page, the default printer, and adding one by its address | CUPS, through `printers` |
| Keyboard | Layouts (every XKB layout, searchable) and the keys that switch between them: Alt+Shift, Ctrl+Shift or Caps Lock | `~/.config/hypr/tweaks.lua` |
| Mouse & Touchpad | Pointer speed and acceleration, natural scrolling, left-handed; on laptops tap to click, disable while typing, and swiping between workspaces with 3 or 4 fingers | `~/.config/hypr/tweaks.lua` |
| Power | Power mode (power-profiles-daemon); when the screen locks, turns off, and the computer sleeps | `~/.config/hypr/hypridle.conf`, then hypridle restarts |
| Date & Time | Time zone, internet time (timedated asks for your password), 12- or 24-hour clock, weather (on/off, °C or °F, place search) | the system clock; the clock style and weather in Quickshell's state |
| Users | Your picture: one of eight drawn ones, a photo from `~/Pictures` (cropped square), or none (your initial), saved as a 256 px PNG. Every account: add one, make one an administrator (`wheel`) or standard, remove one (their home folder stays) | `~/.face` and AccountsService's copy; accounts through `manage-users` |
| Default Apps | The browser, mail app, file manager, text editor, image viewer, video and music players, and PDF viewer, from the apps that say they open those types (`gio mime`) | `~/.config/mimeapps.list` |
| Startup Apps | What opens when you sign in: turn entries on and off, add an app, remove one you added | `~/.config/autostart` (systemd starts XDG autostart entries) |
| Drivers | What `divine-drivers` finds, one Install button each | packages, through `pkg-helper` |
| Disks | Every drive with its partitions drawn to scale. Mount and unmount (udisks), format a partition, erase a whole drive (exFAT, FAT32, NTFS or ext4, with a name), and write a disc image (`.iso` or `.img`, from `~/Downloads` or any path) to a USB stick with a progress bar. The disk divineOS runs from never gets Erase or Format | the drives themselves, through `disks` |
| Backup | Timeshift's snapshots of the system: make one with a description, restore one (it takes effect at the next start; Restart Now), delete one. Home folders aren't in snapshots, so restoring never touches your files | Timeshift, through `backup` and `snapshots` |
| Performance | Swappiness, file-cache pressure, TCP congestion control (BBR/CUBIC), inotify watch limit | `/etc/sysctl.d/99-z-devine-tweaks.conf` |

**Hyprland settings.** `hyprland.lua` loads `tweaks.lua` last with `pcall(require, "tweaks")`, so Settings wins and a missing file is harmless. Each change rewrites the file and runs `hyprctl reload`. Window gaps, corners and borders stay `hyprland.lua`'s until Desktop & Dock first changes them, so edits there aren't overridden.

**Theming.** `Theme.qml` holds the design tokens every divine-shell view draws with. `Sys` binds its accent and font to the saved choices, so every panel, window and the lock screen change at once.
- **Themes** are presets of four saved choices: dark or light, the accent, the glass tint (`Theme.tint`) and Hyprland's blur. `Theme.tintColors` turns a tint into the glass, rim and gloss colours: Frost is whiter and frosted (Kawase blur) in light mode, Pitch is near-opaque black for OLED screens, Neon is deep violet with an accent-coloured rim. A tint only applies in its own mode; elsewhere you get divineOS's own glass. Changing one of the four afterwards keeps the others, and the theme's tile is no longer ringed.
- Text on an accent fill turns near black for light accents (yellow, orange, green), and accent-coloured text on white is darkened (`Theme.textOnAccent`, `Theme.accentInk`), so every preset stays readable.
- **From the wallpaper:** `Palette.js` draws the wallpaper into a 64×36 canvas and takes its most common vivid hue (12 hue bins weighted by saturation), at an accent's saturation and brightness. Greyscale pictures get graphite. Choosing another wallpaper while it's on picks again.
- GTK 4 apps get the nearest of GNOME's accent colours (`accent-color`), plus the colour scheme, icon theme, pointer and font through GSettings.
- **Motion** rescales `hyprland.lua`'s animations in `tweaks.lua`: bezier durations divide by the factor, and the spring's stiffness and damping multiply by its square and the factor itself, which keeps its bounce.
- The pointer applies at once (`hyprctl setcursor`, GSettings). The shell reads its icon theme at startup (`QS_ICON_THEME`, Adwaita until you choose one), so the dock and launcher switch at the next sign-in.

**Kernel settings** need root. Apply runs `pkexec /usr/lib/devine-tweaks/apply-sysctl …`, and polkit action `org.divineos.tweaks.apply-sysctl` asks for your password through hyprpolkitagent.
- The helper accepts only four allowlisted keys, each with a regex-validated value. Anything else is refused before any write.
- It writes atomically, and its file sorts after the divineOS defaults so it takes effect at boot.
- Reset deletes that file and reloads every sysctl config.

**Accounts** go through `pkexec /usr/lib/devine-tweaks/manage-users` (polkit action `org.divineos.tweaks.manage-users`). The new password reaches it on stdin, never on a command line. It only touches regular accounts (uid 1000–59999), never the account asking, and never the last administrator.

**Printers** go through `pkexec /usr/lib/devine-tweaks/printers` (`org.divineos.tweaks.printers`): `lpadmin` with the driverless `everywhere` model, for `ipp`, `ipps` and `dnssd` addresses only.

**Drives** go through `pkexec /usr/lib/devine-tweaks/disks` (`org.divineos.tweaks.disks`, which asks for the password every time). It checks everything again as root before it writes:
- the device must be a whole disk (erase, write) or a partition (format), not read-only, with no LUKS or LVM volume open on it, and nothing on it mounted at `/`, `/boot`, `/efi`, `/home`, `/usr`, `/var`, swap or the live medium;
- the filesystem must be one of the four, the name 32 letters, digits, spaces, `_` or `-` at most;
- an image must be an absolute `.iso` or `.img` path to a regular file that fits on the drive, read as you (`runuser`), so it can't be used to read root's files.

Then it unmounts what's on the drive. Erase writes a new MBR table with one partition (`sfdisk`, the type each OS expects) and formats it; Write runs `dd` with direct I/O and `fsync`. ext4 is made owned by you. `bash test.sh` runs all of this against made-up drives (`--dry-run`).

**Snapshots** go through `pkexec /usr/lib/devine-tweaks/backup` (`org.divineos.tweaks.backup`) for create, restore and delete, which accept only Timeshift's timestamp names and a plain description. Timeshift needs root even to list snapshots, so `snapshots` has its own action that asks the person at the computer for no password. The page works when `/` is Btrfs (the installer's layout); on the live ISO and other filesystems it says why it doesn't.

**Screens off.** hypridle can't pass Hyprland's Lua dispatchers through its config, so it calls `qs ipc call screen off|on`, and the shell sends `hl.dsp.dpms(…)` itself.

## Store (devine-store)

Open it with `devine-store`, "Store" in the launcher or dock, or the updates icon in the menu bar. It's a glass divine-shell window (`Store.qml`) with four tabs, plus a page for each app:
- **Discover:** a banner carousel of picked apps (Blender, OBS Studio, Krita, Godot), featured apps by category (browsers, office, graphics, media, games, development), and search. Search asks the Arch package website and the AUR directly, so it works before pacman has synced. Each app has Get, or Open once it's installed; clicking one opens its page.
- **App pages:** the icon, star rating and review count ([ODRS](https://odrs.gnome.org), the ratings GNOME Software uses), screenshots and description (Flathub's AppStream data), the website, and **Install from**: Arch, Flathub, the AUR or Debian (Debian's stable version, through `divine-pkg`'s Distrobox container), each with its version, when the app is there.
- **Installed:** every app with a launcher entry, by the package that ships it (`pacman -Qo`), as a Flathub app, or as a Debian package that `divine-pkg` exported, with Open and Remove.
- **Updates:** what `checkupdates` (Arch), `paru -Qua` (AUR), `flatpak remote-ls --updates` (Flathub) and `repostation outdated` (GitHub builds) find, each tagged by where it's from, the last update's date (from `pacman.log`), and the three latest Arch Linux news items, since the rare update that needs a manual step is announced there. **Update All** runs them in turn: pacman (with a snapshot first, see Package updates), then Flatpak, then RepoStation, then the Debian container (`apt-get upgrade`) when it has apps, then the AUR in a kitty window.
- **GitHub:** search GitHub's repositories (stars, language) and Get one: RepoStation clones it, builds it and installs it (Cargo, Meson, CMake, Go, npm or Make projects; search shows only languages those build), with the build log one click away. Installed builds have Update and Remove.

Flathub apps install per user (`flatpak --user`, adding the Flathub remote the first time), and Debian ones into the rootless container, so neither needs a password.

The Store checks for updates a minute after login and every 6 hours. When there are new ones and the Store is closed, a notification says so; clicking it opens the Updates tab. `checkupdates` uses its own copy of the package lists, so checking never half-updates the system.

Repo packages install, remove and update through `pkg-helper` (one password prompt; polkit remembers it for a few minutes). A progress bar follows pacman's steps, and **Details** shows its output. AUR packages build with paru in a kitty window, where you can read the PKGBUILD and answer its questions. GitHub builds run `repostation` in the background; it asks for the password through polkit when there's no terminal (`pkexec pacman --noconfirm`) and `sudo` in one.


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
| right-click | Menu: Open, Open in Terminal, Rename (or Rename N Items), Copy / Move to Other Pane, Compress, Extract, Add to Favorites, Move to Trash |
| `Ctrl+H` / `Ctrl+L` | Show dotfiles / type a path (`~` works) |

- **Nothing is overwritten.** A name that's taken gets " 2", " 3"… like Finder (`photo 2.jpg`, `backup 2.tar.gz`). Operations queue and run one at a time; failures show in the status line.
- **Git.** Inside a repository, files show a badge (U untracked, A added, M modified, R renamed, C conflict), folders a dot for changes inside, and the footer shows the branch.
- **Thumbnails** for PNG, JPEG, GIF, WebP, SVG and BMP; other files get an icon for their kind.
- **Compress** zips the selection into the same folder (`Name.zip`, or `Archive.zip` for several; bsdtar).
- **Bulk rename** (several selected, then Rename): replace text in every name, or number them ("Holiday 1", "Holiday 2"…, zero-padded when there are ten or more, so they sort), with a preview first. Extensions stay; a name that would clash keeps its old one.
- **Favorites** are GTK's bookmarks (`~/.config/gtk-3.0/bookmarks`), so they match the file pickers of GTK apps; the × removes one.
- **Network shares:** Connect to Server takes `smb://host/share` (a bare `host/share` means SMB), `sftp://`, `ftp://` or `dav://`, plus a user name and password, and mounts it with `gio mount` (gvfs). Shares appear under Locations with an eject button.
- Mounted drives under `/run/media/$USER` appear under Locations too. Light/dark follows the desktop setting.

## Component architecture

| Component | Stack | Approach |
|---|---|---|
| **divineDE shell** (`divine-shell`) | Quickshell (Qt 6 / QML) | Done: menu bar, dock, Control Center, launcher (apps, files, calculator, unit conversions, clipboard), app switcher, overview, capture bar, notifications, OSD, lock screen, and the greetd login screen (`greeter.qml`, which uses only the Theme-based views, never `Sys`). Glass panels get the acrylic blur through a Hyprland layer rule (`ignore_alpha` clips it to the drawn tiles). QML draws the tint, gloss and rim. |
| **divine-pkg** | Bash, paru, Distrobox + podman | Done (see above). |
| **RepoStation** | Rust, ratatui, ureq | Done (see above). The UI thread blocks for each network call; the status line says "Searching…" while it waits. |
| **devenv** | Neovim 0.12 distribution | Done (see above). Built on lazy.nvim, snacks.nvim (picker, explorer, terminal, LazyGit, dashboard), gitsigns, nvim-treesitter, Mason + mason-lspconfig, blink.cmp, nvim-dap + dap-ui, bufferline, lualine and which-key. |
| **devine-monitor** | Rust, ratatui, sysinfo, nvml-wrapper; Quickshell window | Done (see above). |
| **devine-launcher** | Quickshell module | Done: app search, Settings pages (by name or what's on them: "wallpaper" finds Appearance, "night" Displays), the inline calculator, unit conversions ("10 km to mi", "72 f in c": length, mass, volume, data, speed, time, temperature) and clipboard history (cliphist; the launcher lists `cliphist list` and restores with `cliphist decode \| wl-copy`; pictures are decoded once into `$XDG_RUNTIME_DIR/divine-clips` for their previews). |
| **devine-files** | Quickshell (Qt 6 / QML) + Bash helper | Done (see Files above). Archives go through bsdtar (libarchive) and git status through the git CLI, so there's no C++ to build. |
| **devine-tweaks** | Quickshell window + Bash polkit helpers | Done (see Settings above). |
| **devine-customizer** | Settings' Appearance and Desktop & Dock pages, `Palette.js` | Done (see Theming above). |
| **devine-store** | Quickshell window + `pkg-helper`, paru, Flatpak, RepoStation, the Arch, AUR, Flathub, Debian, ODRS and GitHub web APIs | Done (see Store above). |
| **devine-disks** | Settings' Disks page + `disks` helper (sfdisk, mkfs, dd) and udisks | Done (see Settings above). |
| **devine-backup** | Settings' Backup page + Timeshift (Btrfs mode), grub-btrfs, a pacman hook | Done (see Settings and Package updates above). |

## Status

- [x] Architecture, ISO pipeline, init flow
- [x] Logo (SVG, ASCII), wallpaper, Plymouth theme, fastfetch, greeter
- [x] Performance tuning, Hyprland liquid-glass config
- [x] `divine-shell`: menu bar, dock, Control Center, launcher
- [x] `divine-shell`: tray, calendar and weather, Night Light, Wi-Fi / Bluetooth / sound lists in Control Center
- [x] `divine-shell` dock: window previews, drag to reorder, media, Downloads and Trash, auto-hide that dodges windows
- [x] `divine-shell`: notifications, OSD, lock screen
- [x] `divine-shell`: graphical greetd greeter (tuigreet as fallback)
- [x] `divine-shell`: app switcher, overview, capture bar, launcher file search, account pictures
- [x] `divine-pkg`
- [x] `RepoStation`
- [x] `devenv`
- [x] Disk installer (`divine-install`: erase, alongside, replace, manual; encryption) + optional hosted `[divine]` repo
- [x] GRUB boot menu theme, cursor theme, Welcome guide
- [x] devine-monitor
- [x] devine-tweaks (Settings): keyboard, mouse and touchpad, power, date and time, users, default apps, startup apps, drivers, network and VPN, Bluetooth, printers
- [x] devine-disks: format, erase and write disc images to USB sticks (Settings > Disks)
- [x] devine-backup: Btrfs install, Timeshift snapshots daily and before every update, restore from Settings > Backup or the boot menu
- [x] devine-store: Discover with banners, app pages (ratings, screenshots, Arch / Flathub / AUR / Debian), Installed, Updates for all four sources, GitHub builds through RepoStation; background checks and menu bar badge
- [x] Welcome Set Up, desktop widgets, macOS / Windows 11 / tiling layouts, Mark Up for screenshots
- [x] devine-customizer: themes (Divine Dark, Divine Frost, OLED Pitch, Neon Cyber), accent colours (presets or from the wallpaper), wallpapers, icon, pointer and font themes, layout presets, window, glass, motion and dock settings
- [x] Offline install (copies the live system) with driver and guest-tool detection
- [x] devine-files: dual panes, git badges, right-click menu, compress and extract, bulk rename, favorites, network shares (SMB, SFTP, FTP, WebDAV)
