#!/usr/bin/env bash
# Validation tests for the root helpers: everything here uses --dry-run, so nothing is written.
#   bash pkgs/devine-tweaks/test.sh
set -euo pipefail
helper="$(cd "$(dirname "$0")" && pwd)/apply-sysctl"

pass() { printf 'ok   %s\n' "$1"; }
refuses() {
	if bash "$helper" --dry-run "$@" >/dev/null 2>&1; then
		printf 'FAIL: accepted %q\n' "$*"
		exit 1
	fi
}

out=$(bash "$helper" --dry-run vm.swappiness=180 vm.vfs_cache_pressure=50 net.ipv4.tcp_congestion_control=bbr fs.inotify.max_user_watches=524288)
grep -qx "vm.swappiness = 180" <<<"$out"
grep -qx "net.ipv4.tcp_congestion_control = bbr" <<<"$out"
[[ $(grep -c ' = ' <<<"$out") == 4 ]]
pass "valid settings render to sysctl.d lines"

for v in 0 99 100 199 200; do bash "$helper" --dry-run "vm.swappiness=$v" >/dev/null; done
pass "swappiness accepts 0–200"

refuses vm.swappiness=201
refuses vm.swappiness=-1
refuses vm.swappiness=1e3
pass "swappiness rejects out-of-range values"

refuses kernel.core_pattern=/tmp/x
refuses kernel.modprobe=/tmp/evil
pass "keys outside the allowlist are refused"

refuses "vm.swappiness=10"$'\n'"kernel.modprobe=/tmp/evil"
refuses "vm.swappiness=10; reboot"
refuses vm.swappiness
refuses net.ipv4.tcp_congestion_control=bbr2
pass "injection, missing values and unknown choices are refused"

if bash "$helper" >/dev/null 2>&1; then echo "FAIL: ran without arguments"; exit 1; fi
pass "no arguments prints usage"

# --- manage-users, against made-up accounts: alice (1001, asking), bob (1002), root ---
users="$(cd "$(dirname "$0")" && pwd)/manage-users"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/id" <<'STUB'
#!/usr/bin/env bash
case $2 in alice) echo 1001 ;; bob) echo 1002 ;; root) echo 0 ;; *) exit 1 ;; esac
STUB
cat >"$tmp/getent" <<STUB
#!/usr/bin/env bash
echo "wheel:x:998:\$(cat $tmp/wheel)"
STUB
chmod +x "$tmp/id" "$tmp/getent"
manage() { PKEXEC_UID=1001 PATH="$tmp:$PATH" bash "$users" --dry-run "$@"; }
refused() {
	if manage "$@" </dev/null >/dev/null 2>&1; then printf 'FAIL: manage-users accepted %q
' "$*"; exit 1; fi
}
echo alice >"$tmp/wheel"

out=$(manage add carol "Carol Danvers" standard <<<"secret")
grep -qx "useradd -m -c Carol Danvers carol" <<<"$out"
grep -qx "chpasswd carol" <<<"$out"
grep -qx "useradd -m -c Dan -G wheel dan" <<<"$(manage add dan Dan admin <<<"pw")"
pass "adds standard and admin users"

refused add bob Bob standard
refused add Carol Carol standard
refused add -rf x standard
refused add "a b" x standard
refused add eve "Eve: x" standard
refused add eve Eve root
refused add eve Eve standard # no password on stdin
pass "refuses taken or odd usernames, names with : and missing passwords"

[[ $(manage delete bob) == "userdel bob" ]]
[[ $(manage admin bob yes) == "gpasswd -a bob wheel" ]]
refused delete alice
refused admin alice no
refused delete root
refused delete nobody
pass "changes others, never yourself or system accounts"

echo bob >"$tmp/wheel"
refused delete bob
refused admin bob no
echo alice,bob >"$tmp/wheel"
[[ $(manage admin bob no) == "gpasswd -d bob wheel" ]]
pass "keeps the last administrator"

# --- printers ---
printers="$(cd "$(dirname "$0")" && pwd)/printers"
print() { bash "$printers" --dry-run "$@"; }
refuses_print() {
	if print "$@" >/dev/null 2>&1; then printf 'FAIL: printers accepted %q\n' "$*"; exit 1; fi
}
[[ $(print add Office ipp://192.168.1.20/ipp/print) == "lpadmin -p Office -E -v ipp://192.168.1.20/ipp/print -m everywhere" ]]
print add HP_M281 "dnssd://HP%20M281._ipp._tcp.local/?uuid=1234-ab" >/dev/null
print add Lab ipps://printer.lab.example:631/ipp/print >/dev/null
[[ $(print remove Office) == "lpadmin -x Office" ]]
pass "adds driverless printers and removes them"

refuses_print add "Of fice" ipp://h/ipp/print
refuses_print add -x ipp://h/ipp/print
refuses_print add Office file:///etc/shadow
refuses_print add Office "ipp://h/ipp/print;reboot"
refuses_print add Office "ipp://h/x y"
refuses_print add Office
refuses_print format Office
pass "refuses odd names, other schemes and injection"

# --- disks, against made-up drives: sdb a USB stick, nvme0n1 the system disk, sdc read-only,
# sdd with an unlocked LUKS volume ---
disks="$(cd "$(dirname "$0")" && pwd)/disks"
mkdir "$tmp/disks"
cat >"$tmp/disks/lsblk" <<'STUB'
#!/usr/bin/env bash
dev=${!#} what=$1
case $what:$dev in
-dno:*) [[ $2 == TYPE ]] && { [[ $dev =~ [0-9]$ && $dev != /dev/nvme0n1 ]] && echo part || echo disk; } || { [[ $dev == /dev/sdc ]] && echo 1 || echo 0; } ;;
-lno:/dev/sdd) [[ $2 == TYPE ]] && printf 'disk\npart\ncrypt\n' ;;
-lno:/dev/nvme0n1) [[ $2 == TYPE ]] && printf 'disk\npart\npart\n' || printf '\n/boot\n/\n' ;;
-lno:*) [[ $2 == TYPE ]] && printf 'disk\npart\n' || printf '\n/run/media/me/STICK\n' ;;
esac
STUB
printf '#!/bin/sh\necho 64000000000\n' >"$tmp/disks/blockdev"
chmod +x "$tmp/disks/"*
disk() { PATH="$tmp/disks:$PATH" bash "$disks" --dry-run "$@"; }
refuses_disk() {
	if disk "$@" >/dev/null 2>&1; then printf 'FAIL: disks accepted %q\n' "$*"; exit 1; fi
}
out=$(disk erase /dev/sdb exfat "My Stick")
grep -qx "umount -- /run/media/me/STICK" <<<"$out"
grep -qx "sfdisk --quiet --wipe always --wipe-partitions always --label dos /dev/sdb" <<<"$out"
grep -qx "mkfs.exfat -L My Stick /dev/sdb1" <<<"$out"
grep -qx "mkfs.fat -F 32 -n LONGLABELNA /dev/sdb1" <<<"$(disk erase /dev/sdb fat32 LONGLABELNAME)"
grep -q "^mkfs.ext4 -F -q -E root_owner=$(id -u):$(id -g) /dev/sdb1$" <<<"$(disk erase /dev/sdb ext4)"
grep -qx "mkfs.ntfs -Q -L Data /dev/sdb1" <<<"$(disk format /dev/sdb1 ntfs Data)"
img="$tmp/divineOS.iso"
: >"$img"
grep -q "| dd of=/dev/sdb bs=4M" <<<"$(disk write /dev/sdb "$img")"
pass "erases, formats and writes images to drives that aren't the system's"

refuses_disk erase /dev/nvme0n1 exfat
refuses_disk write /dev/nvme0n1 "$img"
refuses_disk erase /dev/sdc exfat
refuses_disk erase /dev/sdd exfat
refuses_disk erase /dev/sdb1 exfat
refuses_disk format /dev/sdb exfat
refuses_disk erase /dev/sdb zfs
refuses_disk erase /dev/sdb exfat 'x;reboot'
refuses_disk erase "/dev/sdb;reboot" exfat
refuses_disk erase /etc/passwd exfat
refuses_disk write /dev/sdb /etc/shadow
refuses_disk write /dev/sdb relative.iso
refuses_disk wipe /dev/sdb
pass "refuses the system disk, read-only and in-use drives, odd names, filesystems and images"

# --- backup ---
backup="$(cd "$(dirname "$0")" && pwd)/backup"
snap() { bash "$backup" --dry-run "$@"; }
refuses_snap() {
	if snap "$@" >/dev/null 2>&1; then printf 'FAIL: backup accepted %q\n' "$*"; exit 1; fi
}
[[ $(snap create "Before trying KDE") == "timeshift --create --scripted --tags O --comments Before trying KDE" ]]
[[ $(snap create) == "timeshift --create --scripted --tags O --comments Made in Settings" ]]
[[ $(snap restore 2026-11-03_10-00-01) == "timeshift --restore --snapshot 2026-11-03_10-00-01 --scripted --yes --skip-grub" ]]
[[ $(snap delete 2026-11-03_10-00-01) == "timeshift --delete --snapshot 2026-11-03_10-00-01 --scripted" ]]
pass "creates, restores and deletes Timeshift snapshots"
refuses_snap restore "2026-11-03_10-00-01 --target-device /dev/sdb"
refuses_snap delete ../x
refuses_snap create 'x"; reboot'
refuses_snap create "$(printf 'a\nb')"
refuses_snap list
pass "refuses odd snapshot names and descriptions"

echo "all devine-tweaks helper tests passed"
