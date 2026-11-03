
# --- divineOS overrides (appended to archiso's releng profiledef.sh by build.sh) ---
iso_name="divineos"
iso_label="DIVINEOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="devine"
iso_application="divineOS Live"
install_dir="divine"
bootmodes=('bios.syslinux' 'uefi.grub') # UEFI boots divineOS's GRUB menu (iso/grub)
