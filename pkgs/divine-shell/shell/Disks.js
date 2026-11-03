.pragma library

// Settings > Disks: drives from `lsblk -J -b -o NAME,PATH,SIZE,TYPE,TRAN,RM,HOTPLUG,RO,MODEL,LABEL,FSTYPE,MOUNTPOINTS`.
// A disk holding the running system (/, /boot, swap, the live USB…) is never offered for erasing;
// devine-tweaks' disks helper checks again as root.

const systemMounts = ["/", "/boot", "/efi", "/boot/efi", "/home", "/usr", "/var", "[SWAP]", "/run/archiso/bootmnt"];

function flag(v) {
    return v === true || v === 1 || v === "1";
}
// Every mount point on a device and inside it (partitions, an unlocked LUKS volume, LVM).
function allMounts(dev) {
    const own = (dev.mountpoints ?? [dev.mountpoint]).filter(m => m);
    return own.concat(...(dev.children ?? []).map(allMounts));
}

function disks(text) {
    let list = [];
    try {
        list = JSON.parse(text).blockdevices ?? [];
    } catch (e) {}
    return list.filter(d => d.type === "disk" && !/^zram/.test(d.name) && Number(d.size) > 0).map(d => {
        const removable = flag(d.rm) || flag(d.hotplug) || d.tran === "usb";
        const parts = (d.children ?? []).filter(p => p.type === "part").map(p => {
            const mounts = allMounts(p);
            return { path: p.path, size: Number(p.size), fstype: p.fstype ?? "", label: p.label ?? "", mounts, system: mounts.some(m => systemMounts.includes(m)) };
        });
        return {
            path: d.path,
            name: (d.model ?? "").trim() || (removable ? "USB Drive" : "Disk"),
            size: Number(d.size),
            usb: d.tran === "usb",
            removable,
            readOnly: flag(d.ro),
            system: allMounts(d).some(m => systemMounts.includes(m)),
            parts
        };
    });
}

// 32010928128 → "32 GB", like the file manager
function size(bytes) {
    const u = ["B", "KB", "MB", "GB", "TB"];
    let i = 0;
    while (bytes >= 1000 && i < u.length - 1) {
        bytes /= 1000;
        i++;
    }
    return (i ? bytes.toFixed(bytes < 10 ? 1 : 0) : bytes) + " " + u[i];
}

// dd's progress, "1048576000 bytes (1.0 GB, 1000 MiB) copied, 5 s, 210 MB/s": bytes so far, or -1.
function copied(text) {
    const m = text.match(/(\d+) bytes/g);
    return m ? parseInt(m[m.length - 1]) : -1;
}

// What a filesystem is called, and what it's for.
const filesystems = [
    { value: "exfat", label: "exFAT", hint: "Works on Windows, macOS, Linux, cameras and TVs." },
    { value: "fat32", label: "FAT32", hint: "For older devices; files up to 4 GB." },
    { value: "ntfs", label: "NTFS", hint: "For Windows computers." },
    { value: "ext4", label: "ext4", hint: "For Linux only." }
];
function fsName(fstype) {
    return ({ vfat: "FAT32", exfat: "exFAT", ntfs: "NTFS", ext4: "ext4", btrfs: "Btrfs", xfs: "XFS", swap: "Swap", crypto_LUKS: "Encrypted", iso9660: "Disc image" })[fstype] ?? (fstype || "Empty");
}
