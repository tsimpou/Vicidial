#!/bin/bash
BUILD=/opt/iso-build/admin

# Fix syslinux theme (ubuntu-oneiric not available on jammy)
sed -i 's/LB_SYSLINUX_THEME="ubuntu-oneiric"/LB_SYSLINUX_THEME=""/' $BUILD/config/binary
echo "SYSLINUX_THEME: $(grep LB_SYSLINUX_THEME $BUILD/config/binary)"

# Also check if syslinux packages are even installable, switch to grub2 if not
if ! apt-cache show syslinux > /dev/null 2>&1; then
    echo "syslinux not available, switching bootloader to grub-pc"
    sed -i 's/LB_BOOTLOADER="syslinux"/LB_BOOTLOADER="grub-pc"/' $BUILD/config/binary
fi

# Remove state files for stages that failed/need re-run
rm -f $BUILD/.build/binary_syslinux
rm -f $BUILD/.build/binary_grub
rm -f $BUILD/.build/binary_grub2
rm -f $BUILD/.build/binary_debian-installer
echo "Cleared: syslinux, grub, grub2, debian-installer states"

# Also pre-remove flash-kernel again
rm -f $BUILD/chroot/usr/sbin/flash-kernel 2>/dev/null || true
echo "flash-kernel cleared"

echo "=== SYSLINUX FIX APPLIED ==="
grep "LB_BOOTLOADER\|LB_SYSLINUX_THEME" $BUILD/config/binary
