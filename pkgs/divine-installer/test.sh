#!/usr/bin/env bash
# Checks the installer backend's parsing, partition maths and config edits on samples (no root,
# no disks): bash test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./backend
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { # name expected actual
  if [[ $2 == "$3" ]]; then echo "ok   $1"; else printf 'FAIL %s\n--- expected\n%s\n--- got\n%s\n' "$1" "$2" "$3"; fail=1; fi
}

# A function named like a command (install) silently runs instead of it.
check "no function shadows a command" "" "$(for f in $(compgen -A function); do type -P "$f" || true; done)"
check "sata partition" /dev/sda2 "$(part_path /dev/sda 2)"
check "nvme partition" /dev/nvme0n1p2 "$(part_path /dev/nvme0n1 2)"
check "mmc partition" /dev/mmcblk0p1 "$(part_path /dev/mmcblk0 1)"

free='Unpartitioned space /dev/sda: 60 GiB, 64424509440 bytes, 125829120 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes

    Start       End  Sectors Size
       34      2047     2014 1007K
 83886080 209715166 125829087   60G'
check "largest free area, 1 MiB aligned" "83886080 125827072" "$(largest_free 512 <<< "$free")"
check "no free area" "" "$(largest_free 512 <<< 'Unpartitioned space /dev/sda: 0 B, 0 bytes, 0 sectors')"
check "4K sectors" "256 2560" "$(largest_free 4096 <<< ' 100 2900 2801 11M')"

check "ntfs minimum" 26318729216 "$(ntfs_min <<< 'You might resize at 26318729216 bytes or 26319 MB (freeing 13427 MB).')"
check "ext4 minimum" $((1048576 * 4096)) "$(ext_min 4096 <<< 'Estimated minimum size of the filesystem: 1048576')"
check "keep: +10% +1 GiB, whole MiB" $((1210 * MiB + GiB)) "$(keep $((1100 * MiB)))"

check "erase, UEFI" $'label: gpt\nsize=1GiB, type=U\ntype=L' "$(erase_layout true false)"
# A GPT type GUID on disk: the first three fields little-endian. BIOS boot's spells a phrase.
guid_bytes() { # GUID
  local h=${1//-/} le i
  le=${h:6:2}${h:4:2}${h:2:2}${h:0:2}${h:10:2}${h:8:2}${h:14:2}${h:12:2}${h:16}
  for ((i = 0; i < 32; i += 2)); do printf '%b' "\\x${le:i:2}"; done
}
check "BIOS boot GUID" 'Hah!IdontNeedEFI' "$(guid_bytes "$bios_type")"
check "erase, BIOS" $'label: gpt\nsize=1MiB, type='"$bios_type"$'\ntype=L' "$(erase_layout false false)"
check "erase, BIOS encrypted: /boot" $'label: gpt\nsize=1MiB, type='"$bios_type"$'\nsize=1GiB, type=L\ntype=L' "$(erase_layout false true)"

echo 'HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)' > "$t/mk.conf"
check "systemd initramfs: kernel parameter" rd.luks.name=abc=root "$(crypt_hook "$t/mk.conf" abc)"
check "systemd initramfs: hook" 'HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)' "$(cat "$t/mk.conf")"
echo 'HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)' > "$t/mk.conf"
check "busybox initramfs: kernel parameter" cryptdevice=UUID=abc:root "$(crypt_hook "$t/mk.conf" abc)"
check "busybox initramfs: hook" 'HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)' "$(cat "$t/mk.conf")"

printf '    input = {\n        kb_layout    = "us",\n        follow_mouse = 1,\n' > "$t/hyprland.lua"
set_kb "$t/hyprland.lua" de ""
check "keyboard layout" '        kb_layout    = "de",' "$(sed -n 2p "$t/hyprland.lua")"
set_kb "$t/hyprland.lua" us,ru grp:alt_shift_toggle
check "two layouts with a switch" '        kb_layout    = "us,ru", kb_options = "grp:alt_shift_toggle",' "$(sed -n 2p "$t/hyprland.lua")"

check "valid settings" "" "$(invalid hostname my-pc)$(invalid user ana_1)$(invalid fullname 'Ana Lopez')$(invalid password 'p:ss word')$(invalid timezone America/Argentina/Buenos_Aires)$(invalid locale sr_RS.UTF-8@latin)$(invalid xkb us,ru)$(invalid xkb_options '')"
for bad in "hostname -pc" "hostname my.pc" "user Ana" "user 1ana" "user a;b" "fullname a:b" "password " "timezone ../../etc/shadow" "xkb us\";os" "locale en_US.UTF-8\"x" "keymap 'us'"; do
  [[ -n $(invalid "${bad%% *}" "${bad#* }") ]] || { echo "FAIL accepted: $bad"; fail=1; }
done
echo "ok   bad settings refused"

check "copy progress from rsync" $'step 15 Copying divineOS\nstep 47 Copying divineOS\nstep 80 Copying divineOS' \
  "$(printf '          0   0%%    0.00kB/s    0:00:00\r  1,048,576  50%%    1.00MB/s    0:00:01\r  2,097,152 100%%    1.00MB/s    0:00:02 (xfr#9, to-chk=0/12)\n' | copy_progress 3>&1)"

mkdir -p "$t/root/etc/greetd" "$t/root/etc/systemd/system/multi-user.target.wants" "$t/root/etc/pacman.d/gnupg" "$t/root/root"
touch "$t/root/etc/greetd/live.toml" "$t/root/etc/greetd/divineos.toml" "$t/root/root/.zlogin" "$t/root/etc/motd" \
  "$t/root/etc/systemd/system/multi-user.target.wants/"{systemd-resolved,NetworkManager}.service
echo "Welcome to the live system" > "$t/root/etc/motd"
strip_live "$t/root"
check "live-only files go, divineOS's stay" "etc/greetd/divineos.toml etc/motd etc/systemd/system/multi-user.target.wants/NetworkManager.service" \
  "$(cd "$t/root" && find . -type f | sed 's|^\./||' | sort | xargs)"
check "empty motd" "" "$(cat "$t/root/etc/motd")"

if command -v jq > /dev/null; then
  lsblk='{"blockdevices": [
    {"path": "/dev/sda", "type": "disk", "size": 128849018880, "model": "VMware Virtual S  ", "tran": "spi", "pttype": "gpt", "ro": false, "children": [
      {"path": "/dev/sda1", "type": "part", "size": 104857600, "fstype": "vfat", "label": null, "parttype": "c12a7328-f81f-11d2-ba4b-00a0c93ec93b", "parttypename": "EFI System", "partn": 1, "ro": false},
      {"path": "/dev/sda2", "type": "part", "size": 85899345920, "fstype": "ntfs", "label": "Windows", "parttype": "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7", "parttypename": "Microsoft basic data", "partn": 2, "ro": false}]},
    {"path": "/dev/sdb", "type": "disk", "size": 2000000000, "model": null, "tran": "usb", "pttype": "dos", "fstype": "iso9660", "ro": false, "children": [
      {"path": "/dev/sdb1", "type": "part", "size": 1900000000, "fstype": "iso9660", "partn": 1, "ro": false}]},
    {"path": "/dev/sr0", "type": "rom", "size": 1900000000, "ro": false},
    {"path": "/dev/zram0", "type": "disk", "size": 4000000000, "ro": false}]}'
  check "disks: the live USB, CD and zram left out" '["/dev/sda","VMware Virtual S",["/dev/sda1","/dev/sda2"],"EFI System"]' \
    "$(disk_list <<< "$lsblk" | jq -c '[.[].path, .[0].model, [.[0].parts[].path], .[0].parts[0].typename]')"
else
  echo "skip disk list (no jq)"
fi

exit "$fail"
