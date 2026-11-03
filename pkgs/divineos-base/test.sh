#!/usr/bin/env bash
# Checks post-install's file edits on sample files (no root, no chroot): bash test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./post-install
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { # name expected actual
  if [[ $2 == "$3" ]]; then echo "ok   $1"; else printf 'FAIL %s\n--- expected\n%s\n--- got\n%s\n' "$1" "$2" "$3"; fail=1; fi
}

# pacman.conf: a file:// [divine] (the ISO's copy) goes; the hosted one is added only with a mirrorlist.
conf=$'[options]\nHoldPkg = pacman\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n\n[divine]\nSigLevel = Never TrustAll\nServer = file:///usr/local/share/divineos/repo\n'
printf '%s' "$conf" > "$t/pacman.conf"
pacman_conf "$t/pacman.conf" "$t/none"
check "pacman.conf without hosted repo" $'[options]\nHoldPkg = pacman\n\n[core]\nInclude = /etc/pacman.d/mirrorlist' "$(cat "$t/pacman.conf")"
printf '%s' "$conf" > "$t/pacman.conf"
echo 'Server = https://example.org/repo' > "$t/mirrorlist"
pacman_conf "$t/pacman.conf" "$t/mirrorlist"
check "pacman.conf with hosted repo" $'[options]\nHoldPkg = pacman\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[divine]\nSigLevel = Required\nInclude = '"$t/mirrorlist" "$(cat "$t/pacman.conf")"
pacman_conf "$t/pacman.conf" "$t/mirrorlist"
check "pacman.conf twice: one [divine]" 1 "$(grep -c '^\[divine\]' "$t/pacman.conf")"

# Kernel command lines
printf 'title   Arch Linux (linux)\nlinux   /vmlinuz-linux\noptions root=PARTUUID=abc rw rootfstype=ext4\n' > "$t/entry.conf"
add_words "$t/entry.conf" '^options '
check "systemd-boot options" 'options root=PARTUUID=abc rw rootfstype=ext4 quiet splash' "$(grep '^options' "$t/entry.conf")"
add_words "$t/entry.conf" '^options '
check "systemd-boot idempotent" 'options root=PARTUUID=abc rw rootfstype=ext4 quiet splash' "$(grep '^options' "$t/entry.conf")"
printf 'GRUB_DEFAULT=0\nGRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"\nGRUB_CMDLINE_LINUX=""\n' > "$t/grub"
add_words "$t/grub" '^GRUB_CMDLINE_LINUX_DEFAULT='
check "grub default cmdline" $'GRUB_DEFAULT=0\nGRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"\nGRUB_CMDLINE_LINUX=""' "$(cat "$t/grub")"
printf 'GRUB_CMDLINE_LINUX_DEFAULT=""\n' > "$t/grub"
add_words "$t/grub" '^GRUB_CMDLINE_LINUX_DEFAULT='
check "grub empty cmdline" 'GRUB_CMDLINE_LINUX_DEFAULT=" quiet splash"' "$(cat "$t/grub")"
printf 'quiet rw nosplash\n' > "$t/cmdline"
add_words "$t/cmdline" '^.'
check "uki cmdline (nosplash isn't splash)" 'quiet rw nosplash splash' "$(cat "$t/cmdline")"
printf '/Arch Linux\n    protocol: linux\n    cmdline: root=UUID=x rw\n' > "$t/limine.conf"
add_words "$t/limine.conf" '^\s*(kernel_)?cmdline:'
check "limine cmdline" '    cmdline: root=UUID=x rw quiet splash' "$(grep cmdline "$t/limine.conf")"
add_words "$t/none.conf" '^options ' # main tries every boot loader's file
check "missing file skipped" "" "$(ls "$t/none.conf" 2>/dev/null)"

# /etc/default/grub variables
printf 'GRUB_DISTRIBUTOR="Arch"
GRUB_GFXMODE=auto
#GRUB_THEME="/path/to/gfxtheme"
' > "$t/grub"
set_var "$t/grub" GRUB_DISTRIBUTOR '"divineOS"'
set_var "$t/grub" GRUB_THEME '"/boot/grub/themes/divineos/theme.txt"'
set_var "$t/grub" GRUB_DISABLE_OS_PROBER false
set_var "$t/grub" GRUB_DISABLE_OS_PROBER false
check "grub variables" $'GRUB_DISTRIBUTOR="divineOS"
GRUB_GFXMODE=auto
GRUB_THEME="/boot/grub/themes/divineos/theme.txt"
GRUB_DISABLE_OS_PROBER=false' "$(cat "$t/grub")"

# mkinitcpio HOOKS
printf 'MODULES=()\nHOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)\n' > "$t/mk.conf"
add_hook "$t/mk.conf"
check "hooks after udev" 'HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)' "$(grep ^HOOKS "$t/mk.conf")"
add_hook "$t/mk.conf"
check "hooks idempotent" 1 "$(grep -o plymouth "$t/mk.conf" | wc -l | tr -d ' ')"
printf 'HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)\n' > "$t/mk.conf"
add_hook "$t/mk.conf"
check "hooks after systemd" 'HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)' "$(cat "$t/mk.conf")"

# /etc/skel into existing homes, without overwriting
mkdir -p "$t/skel/.config/hypr" "$t/home/ana/.config/hypr"
echo new > "$t/skel/.config/hypr/hyprland.lua"
echo new > "$t/skel/.bashrc"
echo mine > "$t/home/ana/.bashrc"
printf 'root:x:0:0::/root:/bin/bash\nana:x:1000:1000::%s:/bin/bash\n' "$t/home/ana" > "$t/passwd"
chown() { :; } # no root here; the real run chowns
copy_skel "$t/skel" "$t/passwd"
check "skel copied" new "$(cat "$t/home/ana/.config/hypr/hyprland.lua")"
check "skel keeps existing" mine "$(cat "$t/home/ana/.bashrc")"

exit "$fail"
