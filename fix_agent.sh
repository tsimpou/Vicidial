#!/bin/bash
# Fix agent build: replace wine32 with hook-based i386 installation
set -e

BUILD=/opt/iso-build/agent

echo "=== Fixing agent package list ==="
# Remove wine32 and winetricks from package list (not available without i386 arch)
# Use wine64 instead - hook will add wine32 after
cat > $BUILD/config/package-lists/agent.list.chroot << 'EOF'
openbox
xorg
x11-xserver-utils
chromium-browser
unclutter
lightdm
lightdm-gtk-greeter
pulseaudio
pulseaudio-utils
pavucontrol
alsa-utils
wine64
python3
python3-requests
fonts-dejavu
fonts-freefont-ttf
locales
keyboard-configuration
console-setup
tzdata
sudo
bash
xdotool
wmctrl
tint2
libnotify-bin
dunst
EOF
echo "Package list updated (wine32 removed)"

echo "=== Adding i386/wine32 hook ==="
mkdir -p $BUILD/config/hooks
cat > $BUILD/config/hooks/0050-wine32.hook.chroot << 'HOOK'
#!/bin/sh
set -e
echo "=== Installing wine32 via i386 arch ==="
dpkg --add-architecture i386
apt-get update -q
apt-get install -y wine32:i386 winetricks --no-install-recommends
echo "wine32 installed successfully"
HOOK
chmod +x $BUILD/config/hooks/0050-wine32.hook.chroot
echo "Hook created: config/hooks/0050-wine32.hook.chroot"

echo "=== Fixing config: debian-installer and bootloader ==="
# Fix debian-installer config
sed -i 's/LB_DEBIAN_INSTALLER="none"/LB_DEBIAN_INSTALLER="false"/' $BUILD/config/binary 2>/dev/null || true
sed -i 's/LB_BOOTLOADER="syslinux"/LB_BOOTLOADER="grub2"/' $BUILD/config/binary 2>/dev/null || true
sed -i 's/LB_SYSLINUX_THEME="ubuntu-oneiric"/LB_SYSLINUX_THEME=""/' $BUILD/config/binary 2>/dev/null || true
echo "Config fixed: bootloader=grub2, debian-installer=false"

echo "=== Removing flash-kernel symlink ==="
rm -f $BUILD/chroot/usr/sbin/flash-kernel 2>/dev/null || true

echo "=== Cleaning failed state files ==="
# Remove state files for failed stages so they retry
rm -f $BUILD/.build/chroot_install-packages.install
rm -f $BUILD/.build/chroot_install-packages.live
rm -f $BUILD/.build/chroot_live-packages
rm -f $BUILD/.build/chroot_includes
rm -f $BUILD/.build/chroot_hooks
echo "State cleaned"

echo "=== Current .build state ==="
ls $BUILD/.build/

echo "=== AGENT FIX COMPLETE ==="
