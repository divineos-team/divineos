#!/usr/bin/env bash
# Build divineOS into ./out: the live ISO, or with "repo" only the [divine] package repo
# (out/repo, what CI publishes). Needs root on Arch Linux, or any OS with Docker:
#   docker run --rm --privileged -v "${PWD}:/src" archlinux:latest bash /src/build.sh
#   sudo ./build.sh [repo]     # on Arch
# Hosted repo: DIVINE_REPO_URL is where out/repo gets published, plus DIVINE_SIGNING_KEY
# (the armored secret key; signs the repo) or DIVINE_REPO_KEY (its public key file; for an
# ISO that trusts the published repo). Installed systems then update divineOS's own packages
# from there. Without a URL they keep the versions their ISO shipped.
set -euo pipefail

mode=${1:-iso}
src=$(cd "$(dirname "$0")" && pwd)
work=/tmp/divineos # keep off bind mounts: mkarchiso needs real POSIX permissions
repo=$work/repo
profile=$work/profile
key=$work/divine.gpg # the repo signer's public key, shipped in divineos-base

die() { echo "build.sh: $*" >&2; exit 1; }
(( EUID == 0 )) || die "run as root"
[[ $mode == iso || $mode == repo ]] || die "usage: build.sh [iso|repo]"
# Never point installed systems at a repo they can't verify.
[[ -z ${DIVINE_REPO_URL:-} || -n ${DIVINE_SIGNING_KEY:-}${DIVINE_REPO_KEY:-} ]] ||
  die "DIVINE_REPO_URL needs DIVINE_SIGNING_KEY or DIVINE_REPO_KEY"
# A published repo's divineos-base must carry its URL and key, or upgrading to it breaks pacman.
[[ $mode == iso || ( -n ${DIVINE_REPO_URL:-} && -n ${DIVINE_SIGNING_KEY:-} ) ]] ||
  die "repo mode needs DIVINE_REPO_URL and DIVINE_SIGNING_KEY"

# A build stopped mid-pacman (Ctrl+C, docker stop) leaves its lock behind; clear it when no
# pacman is running.
grep -qsx pacman /proc/[0-9]*/comm || rm -f /var/lib/pacman/db.lck
# Build tools + the makedepends of every pkgs/* (makepkg runs with --nodeps below).
pacman -Syu --needed --noconfirm archiso base-devel git librsvg rust neovim grub inter-font xorg-xcursorgen jq

rm -rf "$work"
mkdir -p "$work/src" "$repo" "$src/out"
cp -r "$src"/{branding,iso,pkgs} "$work/src/"
rm -rf "$work"/src/pkgs/*/target # stray local cargo builds
# pacman only updates a package whose version went up, so a published repo's builds get the
# build time as pkgrel: newer than any ISO's (pkgrel=1) and than every earlier publish.
# ponytail: each publish re-releases every package; per-package versions if downloads get big
if [[ $mode == repo ]]; then
  sed -i "s/^pkgrel=.*/pkgrel=$(date -u +%Y%m%d%H%M)/" "$work"/src/pkgs/*/PKGBUILD
fi

if [[ -n ${DIVINE_SIGNING_KEY:-} ]]; then
  export GNUPGHOME=$work/gnupg # throwaway keyring, also used by repo-add --sign
  install -dm700 "$GNUPGHOME"
  gpg --batch --import <<< "$DIVINE_SIGNING_KEY"
  fpr=$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1 == "fpr" { print $10; exit }')
  gpg --batch --export "$fpr" > "$key"
elif [[ -n ${DIVINE_REPO_KEY:-} ]]; then
  cp "$DIVINE_REPO_KEY" "$key"
fi

# 1. First-party packages -> local [divine] repo. makepkg refuses root, so build as "builder".
id builder &>/dev/null || useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/builder
install -d -o builder "$work/build"
chown -R builder "$work/src" "$repo"
# --nodeps: our packages depend on each other and aren't in a repo yet; pacstrap resolves
# runtime deps later. BUILDDIR: makepkg's default work dir is <pkg>/src, which it wipes, and
# that's where the Rust packages keep their code.
for pkg in "$work"/src/pkgs/*/; do
  (cd "$pkg" && sudo -u builder env PKGDEST="$repo" BUILDDIR="$work/build" \
    DIVINE_REPO_URL="${DIVINE_REPO_URL:-}" DIVINE_REPO_KEY="$key" makepkg --nodeps --cleanbuild --noconfirm)
done

# paru, divine-pkg's AUR backend, isn't in the official repos: build it from the AUR
# (maintained by paru's author).
# ponytail: builds the AUR's current PKGBUILD; pin a commit once releases must be reproducible
install -d -o builder "$work/aur"
sudo -u builder git clone --depth 1 https://aur.archlinux.org/paru.git "$work/aur/paru"
(cd "$work/aur/paru" && sudo -u builder env PKGDEST="$repo" makepkg --nodeps --cleanbuild --noconfirm)
if [[ -n ${fpr:-} ]]; then
  for p in "$repo"/*.pkg.tar.zst; do gpg --batch --yes --detach-sign -u "$fpr" "$p"; done
  cp "$key" "$repo/divine.gpg"
fi
repo-add ${fpr:+--sign --key "$fpr"} "$repo/divine.db.tar.gz" "$repo"/*.pkg.tar.zst

if [[ $mode == repo ]]; then
  rm -rf "$src/out/repo"
  cp -rL "$repo" "$src/out/repo" # -L: GitHub releases can't hold repo-add's symlinks
  ls -lh "$src/out/repo"
  exit
fi

# 2. Profile = archiso's releng (bootloaders, live tooling) + divineOS overlay.
cp -r /usr/share/archiso/configs/releng "$profile"
cp -r "$work/src/iso/airootfs/." "$profile/airootfs/"
cat "$work/src/iso/packages.x86_64" >> "$profile/packages.x86_64"
cat "$work/src/iso/profiledef.sh" >> "$profile/profiledef.sh"
printf '\n[divine]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$repo" >> "$profile/pacman.conf"
sed -i 's/\budev\b/udev plymouth/' "$profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
# NetworkManager (enabled by divineos-base, drives the Wi-Fi tile) replaces releng's networkd + iwd.
rm -f "$profile"/airootfs/etc/systemd/system/{multi-user.target.wants/{systemd-networkd,iwd}.service,sockets.target.wants/systemd-networkd.socket,network-online.target.wants/systemd-networkd-wait-online.service,dbus-org.freedesktop.network1.service}
# Boot menus. UEFI: divineOS's GRUB menu, themed with divineos-base's GRUB theme. BIOS boots
# through syslinux (archiso has no BIOS GRUB): divineOS's menu (iso/syslinux) in the same style.
cp "$work/src/iso/grub/grub.cfg" "$profile/grub/"
install -d "$profile/grub/themes"
bsdtar -xf "$(ls "$repo"/divineos-base-[0-9]*.pkg.tar.zst)" -C "$work" usr/share/grub/themes/divineos
cp -r "$work/usr/share/grub/themes/divineos" "$profile/grub/themes/"
cp "$work/src/iso/syslinux/"*.cfg "$profile/syslinux/"
# librsvg only loads images from the SVG's own folder, so the splash is drawn next to its pieces.
splash="$work/splash"
install -d "$splash"
cp "$work/src/iso/syslinux/splash.svg" "$work"/usr/share/grub/themes/divineos/{background,logo}.png "$splash/"
rsvg-convert -o "$profile/syslinux/splash.png" "$splash/splash.svg"
sed -i -e 's/archisosearchuuid=%ARCHISO_UUID%/& quiet splash/' -e 's/Arch Linux install medium/Try divineOS/' \
  -e 's/Arch Linux/divineOS/g' "$profile"/efiboot/loader/entries/*.conf "$profile"/syslinux/*.cfg "$profile"/grub/*.cfg

# 3. ISO
mkarchiso -v -r -w "$work/mkarchiso" -o "$src/out" "$profile"
ls -lh "$src"/out/*.iso
