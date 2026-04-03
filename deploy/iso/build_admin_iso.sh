#!/bin/bash
# =================================================================
# build_admin_iso.sh
# Builds a bootable Ubuntu 22.04 Live ISO for the VICIdial Admin PC
#
# Features:
#   - Greek language & keyboard (primary)
#   - Auto-login kiosk → Chromium → VICIdial admin page
#   - Timezone: Europe/Athens
#   - Read-only session (live, no install)
#   - BIOS + UEFI bootable
#
# Run on the GCP Ubuntu server:
#   sudo bash /tmp/build_admin_iso.sh
#
# Output: /opt/vicidial-isos/vicidial-admin.iso (~700MB)
# =================================================================

set -e

VICIDIAL_URL="http://34.79.89.1/vicidial/admin.php"
OUTPUT_DIR="/opt/vicidial-isos"
BUILD_DIR="/opt/iso-build/admin"

echo "=== Installing live-build ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y live-build syslinux-utils isolinux xorriso

echo "=== Creating build directory ==="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "=== Configuring live-build ==="
lb config \
  --architecture amd64 \
  --distribution jammy \
  --archive-areas "main restricted universe" \
  --apt-options "--yes --no-install-recommends" \
  --debian-installer none \
  --memtest none \
  --binary-images iso-hybrid \
  --bootappend-live "boot=live components quiet splash locales=el_GR.UTF-8 keyboard-layouts=gr keyboard-variants= timezone=Europe/Athens hostname=vicidial-admin username=admin autologin"

echo "=== Adding package lists ==="
mkdir -p config/package-lists

cat > config/package-lists/kiosk.list.chroot << 'EOF'
openbox
xorg
x11-xserver-utils
chromium-browser
unclutter
lightdm
lightdm-gtk-greeter
pulseaudio
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
EOF

echo "=== Creating locale & keyboard config ==="
mkdir -p config/includes.chroot/etc/default

cat > config/includes.chroot/etc/default/locale << 'EOF'
LANG=el_GR.UTF-8
LANGUAGE=el_GR:el
LC_ALL=el_GR.UTF-8
EOF

cat > config/includes.chroot/etc/default/keyboard << 'EOF'
XKBMODEL="pc105"
XKBLAYOUT="gr,us"
XKBVARIANT=","
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOF

echo "=== Creating LightDM auto-login config ==="
mkdir -p config/includes.chroot/etc/lightdm

cat > config/includes.chroot/etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=admin
autologin-user-timeout=0
user-session=openbox
greeter-session=lightdm-gtk-greeter
EOF

echo "=== Creating Openbox autostart (kiosk) ==="
mkdir -p "config/includes.chroot/home/admin/.config/openbox"

cat > "config/includes.chroot/home/admin/.config/openbox/autostart" << AUTOEOF
# Disable screensaver and power management
xset s off
xset -dpms
xset s noblank

# Hide mouse cursor after 1 second of inactivity
unclutter -idle 1 -root &

# Wait for display to settle
sleep 2

# Launch Chromium in kiosk mode pointing to VICIdial Admin
chromium-browser \\
  --kiosk \\
  --no-first-run \\
  --disable-translate \\
  --disable-infobars \\
  --disable-session-crashed-bubble \\
  --disable-restore-session-state \\
  --no-default-browser-check \\
  --password-store=basic \\
  --start-maximized \\
  --app="${VICIDIAL_URL}" &
AUTOEOF

echo "=== Creating Openbox rc.xml (minimal, no decorations) ==="
cat > "config/includes.chroot/home/admin/.config/openbox/rc.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <keyboard>
    <keybind key="C-A-t">
      <action name="Execute"><command>bash</command></action>
    </keybind>
    <keybind key="C-A-r">
      <action name="Execute">
        <command>chromium-browser --kiosk --no-first-run --start-maximized http://34.79.89.1/vicidial/admin.php</command>
      </action>
    </keybind>
  </keyboard>
  <mouse>
    <context name="Desktop">
      <mousebind button="Left" action="Press"/>
    </context>
  </mouse>
  <desktops><number>1</number></desktops>
  <theme>
    <name>Clearlooks</name>
    <titleLayout>NLIMC</titleLayout>
  </theme>
  <applications>
    <application class="*">
      <decor>no</decor>
      <maximized>true</maximized>
    </application>
  </applications>
</openbox_config>
EOF

echo "=== Creating post-install hook ==="
mkdir -p config/hooks/live

cat > config/hooks/live/0100-setup-admin-user.hook.chroot << 'HOOKEOF'
#!/bin/bash
set -e

# Generate Greek locale
echo "el_GR.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=el_GR.UTF-8

# Set timezone
ln -snf /usr/share/zoneinfo/Europe/Athens /etc/localtime
echo "Europe/Athens" > /etc/timezone

# Ensure admin user exists with proper home
if ! id admin &>/dev/null; then
    useradd -m -s /bin/bash -G audio,video,plugdev,netdev admin
fi
echo "admin:admin" | chpasswd
usermod -aG sudo admin

# Set ownership of openbox config
chown -R admin:admin /home/admin/.config 2>/dev/null || true

# Ensure Chromium accepts command line flags  
mkdir -p /etc/chromium-browser
echo 'CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage"' > /etc/chromium-browser/default

# Disable screen blanking system-wide
cat > /etc/X11/xorg.conf.d/10-no-blanking.conf << 'XEOF'
Section "ServerFlags"
    Option "BlankTime"  "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime"    "0"
EndSection
XEOF
mkdir -p /etc/X11/xorg.conf.d

HOOKEOF
chmod +x config/hooks/live/0100-setup-admin-user.hook.chroot

echo "=== Starting ISO build (this takes 20-40 minutes) ==="
mkdir -p "$OUTPUT_DIR"
lb build 2>&1 | tee "$OUTPUT_DIR/admin-build.log"

ISO_FILE=$(ls "$BUILD_DIR"/*.iso 2>/dev/null | head -1)
if [ -n "$ISO_FILE" ]; then
    cp "$ISO_FILE" "$OUTPUT_DIR/vicidial-admin.iso"
    echo ""
    echo "=== BUILD SUCCESS ==="
    echo "ISO: $OUTPUT_DIR/vicidial-admin.iso"
    ls -lh "$OUTPUT_DIR/vicidial-admin.iso"
else
    echo "=== BUILD FAILED - check $OUTPUT_DIR/admin-build.log ==="
    tail -30 "$OUTPUT_DIR/admin-build.log"
    exit 1
fi
