#!/bin/bash
BUILD=/opt/iso-build/admin

# Switch bootloader from syslinux to grub2
sed -i 's/LB_BOOTLOADER="syslinux"/LB_BOOTLOADER="grub2"/' $BUILD/config/binary
echo "Bootloader: $(grep LB_BOOTLOADER $BUILD/config/binary | grep -v '#')"

# Remove binary_syslinux and binary_grub states so they re-run correctly
rm -f $BUILD/.build/binary_syslinux
rm -f $BUILD/.build/binary_grub
rm -f $BUILD/.build/binary_grub2

# Pre-remove flash-kernel
rm -f $BUILD/chroot/usr/sbin/flash-kernel 2>/dev/null || true

echo "Done"
