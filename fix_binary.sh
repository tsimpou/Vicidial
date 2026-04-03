#!/bin/bash
set -e

CHROOT=/opt/iso-build/admin/chroot
BUILD=/opt/iso-build/admin

# Fix 1: Change debian-installer (already may be "false" from previous run)
sed -i 's/LB_DEBIAN_INSTALLER="none"/LB_DEBIAN_INSTALLER="false"/' $BUILD/config/binary 2>/dev/null || true
echo "debian-installer: $(grep LB_DEBIAN_INSTALLER= $BUILD/config/binary | grep -v '#')"

# Fix 2: Generate versioned initrd inside chroot using update-initramfs
KERNEL_VER=$(ls $CHROOT/boot/vmlinuz-* 2>/dev/null | head -1 | sed 's|.*vmlinuz-||')
echo "Kernel version: $KERNEL_VER"

if [ -n "$KERNEL_VER" ] && [ ! -f "$CHROOT/boot/initrd.img-$KERNEL_VER" ]; then
    echo "Generating initrd via update-initramfs..."
    # Mount required filesystems
    mount --bind /proc $CHROOT/proc 2>/dev/null || true
    mount --bind /sys  $CHROOT/sys  2>/dev/null || true
    mount --bind /dev  $CHROOT/dev  2>/dev/null || true
    # Generate initrd
    chroot $CHROOT update-initramfs -c -k "$KERNEL_VER" || true
    # Unmount
    umount $CHROOT/dev  2>/dev/null || true
    umount $CHROOT/sys  2>/dev/null || true
    umount $CHROOT/proc 2>/dev/null || true
fi

if [ -f "$CHROOT/boot/initrd.img-$KERNEL_VER" ]; then
    echo "initrd.img-$KERNEL_VER OK ($(du -sh $CHROOT/boot/initrd.img-$KERNEL_VER | cut -f1))"
else
    echo "ERROR: initrd still missing!"
    exit 1
fi
ls -lah $CHROOT/boot/

# Fix 3: Pre-remove flash-kernel symlink (causes failure in lb_chroot_dpkg)
rm -f $CHROOT/usr/sbin/flash-kernel 2>/dev/null || true
echo "flash-kernel symlink cleared"

# Fix 4: Remove state files for stages that need to re-run
rm -f $BUILD/.build/binary_linux-image
rm -f $BUILD/.build/binary_debian-installer
rm -f $BUILD/.build/binary_manifest
echo "Binary state files cleared: linux-image, debian-installer, manifest"

echo "=== ALL FIXES APPLIED ==="
