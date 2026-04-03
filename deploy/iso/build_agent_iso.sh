#!/bin/bash
# =================================================================
# build_agent_iso.sh
# Builds a bootable Ubuntu 22.04 Live ISO for VICIdial Agent PCs
#
# Features:
#   - Greek language & keyboard (primary)
#   - Auto-login → Openbox desktop
#   - MicroSIP (Windows app) via Wine — pre-configured for VICIdial
#   - VICIdial BT Connector script — bridges browser→MicroSIP
#   - Chromium opens VICIdial agent page
#   - Headset/audio support (PulseAudio)
#   - Timezone: Europe/Athens
#
# MicroSIP + BT Connector integration:
#   - MicroSIP runs in system tray via Wine
#   - BT Connector Python service listens on localhost:5001
#   - Chromium extension (or VICIdial built-in) sends dial commands
#   - bt_connector.py bridges commands → MicroSIP via CLI/Wine
#
# Run on the GCP Ubuntu server:
#   sudo bash /tmp/build_agent_iso.sh
#
# Output: /opt/vicidial-isos/vicidial-agent.iso (~1.2GB)
# =================================================================

set -e

VICIDIAL_URL="http://34.79.89.1/vicidial/vicidial.php"
ASTERISK_HOST="34.79.89.1"
MICROSIP_URL="https://www.microsip.org/pages/download/MicroSIP-3.21.4-full.exe"
OUTPUT_DIR="/opt/vicidial-isos"
BUILD_DIR="/opt/iso-build/agent"

echo "=== Installing live-build ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y live-build syslinux-utils isolinux xorriso wget

echo "=== Downloading MicroSIP installer ==="
mkdir -p /opt/vicidial-isos/cache
MICROSIP_EXE="/opt/vicidial-isos/cache/MicroSIP-full.exe"
if [ ! -f "$MICROSIP_EXE" ]; then
    wget -O "$MICROSIP_EXE" "$MICROSIP_URL" || {
        echo "WARN: MicroSIP download failed — using placeholder. Replace $MICROSIP_EXE manually."
        touch "$MICROSIP_EXE"
    }
fi

echo "=== Creating build directory ==="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "=== Configuring live-build ==="
lb config \
  --architecture amd64 \
  --distribution jammy \
  --archive-areas "main restricted universe multiverse" \
  --apt-options "--yes --no-install-recommends" \
  --debian-installer none \
  --memtest none \
  --bootloaders "grub-efi syslinux" \
  --binary-images iso-hybrid \
  --bootappend-live "boot=live components quiet splash \
    locales=el_GR.UTF-8 \
    keyboard-layouts=gr \
    keyboard-variants= \
    timezone=Europe/Athens \
    hostname=vicidial-agent \
    username=agent \
    autologin"

echo "=== Adding package lists ==="
mkdir -p config/package-lists

cat > config/package-lists/agent.list.chroot << 'EOF'
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
wine
wine32
winetricks
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
autologin-user=agent
autologin-user-timeout=0
user-session=openbox
greeter-session=lightdm-gtk-greeter
EOF

echo "=== Creating BT Connector bridge service ==="
mkdir -p "config/includes.chroot/home/agent/.vicidial"

# bt_connector.py - bridges VICIdial browser commands to MicroSIP via Wine
cat > "config/includes.chroot/home/agent/.vicidial/bt_connector.py" << 'PYEOF'
#!/usr/bin/env python3
"""
VICIdial BT Connector for MicroSIP (Linux/Wine)
Listens on localhost:5001 for commands from the VICIdial web interface
and forwards them to MicroSIP running under Wine.

Compatible with VICIdial's built-in BT Connector URL scheme:
  http://localhost:5001/call?number=XXXXX
  http://localhost:5001/hangup
  http://localhost:5001/status
"""

import http.server
import urllib.parse
import subprocess
import os
import json
import threading
import time

PORT = 5001
WINE_PREFIX = os.path.expanduser("~/.wine")
MICROSIP_PATH = os.path.expanduser("~/.wine/drive_c/Program Files/MicroSIP/MicroSIP.exe")

def run_microsip_command(action, number=None):
    """Control MicroSIP via command line arguments"""
    if action == "call" and number:
        # MicroSIP supports command-line dialing
        cmd = ["wine", MICROSIP_PATH, f"sip:{number}@{HOST}"]
        subprocess.Popen(cmd, env={**os.environ, "WINEPREFIX": WINE_PREFIX})
        return {"status": "calling", "number": number}
    elif action == "hangup":
        # Send close signal to MicroSIP window
        subprocess.run(["xdotool", "search", "--name", "MicroSIP", "key", "Escape"], 
                      capture_output=True)
        return {"status": "hangup_sent"}
    elif action == "status":
        # Check if MicroSIP is running
        result = subprocess.run(["pgrep", "-f", "MicroSIP"], capture_output=True)
        running = result.returncode == 0
        return {"status": "ok", "microsip_running": running}
    return {"status": "unknown_action"}

# Read VICIdial host from config
HOST = "34.79.89.1"
try:
    with open(os.path.expanduser("~/.vicidial/config.json")) as f:
        cfg = json.load(f)
        HOST = cfg.get("asterisk_host", HOST)
except:
    pass

class BTConnectorHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        path = parsed.path.strip("/")

        result = {"status": "error", "message": "unknown command"}

        if path == "call":
            number = params.get("number", [None])[0]
            if number:
                result = run_microsip_command("call", number)
        elif path == "hangup":
            result = run_microsip_command("hangup")
        elif path == "status":
            result = run_microsip_command("status")
        elif path == "reload":
            result = {"status": "ok", "message": "BT Connector running"}

        body = json.dumps(result).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(body))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # Suppress access logs

def main():
    print(f"VICIdial BT Connector starting on port {PORT}")
    print(f"Asterisk host: {HOST}")
    server = http.server.HTTPServer(("127.0.0.1", PORT), BTConnectorHandler)
    print(f"BT Connector ready — listening on http://127.0.0.1:{PORT}/")
    server.serve_forever()

if __name__ == "__main__":
    main()
PYEOF

echo "=== Creating VICIdial agent config ==="
cat > "config/includes.chroot/home/agent/.vicidial/config.json" << CFGEOF
{
  "asterisk_host": "${ASTERISK_HOST}",
  "vicidial_url": "${VICIDIAL_URL}",
  "bt_connector_port": 5001,
  "sip_domain": "${ASTERISK_HOST}",
  "phone_type": "PJSIP"
}
CFGEOF

echo "=== Creating MicroSIP Wine installer script ==="
cat > "config/includes.chroot/home/agent/.vicidial/install_microsip.sh" << 'MSEOF'
#!/bin/bash
# Run this once on first boot to install MicroSIP under Wine
# Placed at: /home/agent/.vicidial/install_microsip.sh

set -e
WINEPREFIX="$HOME/.wine"
export WINEPREFIX
export WINEARCH=win32

echo "Initializing Wine prefix..."
winecfg /v win10 2>/dev/null &
WINE_PID=$!
sleep 8
kill $WINE_PID 2>/dev/null || true

MICROSIP_EXE="$HOME/.vicidial/MicroSIP-full.exe"
if [ -f "$MICROSIP_EXE" ] && [ -s "$MICROSIP_EXE" ]; then
    echo "Installing MicroSIP..."
    wine "$MICROSIP_EXE" /S 2>/dev/null
    echo "MicroSIP installed at $WINEPREFIX/drive_c/Program Files/MicroSIP/"
else
    echo "ERROR: MicroSIP installer not found at $MICROSIP_EXE"
    echo "Please copy MicroSIP-full.exe to ~/.vicidial/ and run this script again"
    exit 1
fi

# Write MicroSIP configuration for VICIdial
MICROSIP_INI="$WINEPREFIX/drive_c/Program Files/MicroSIP/MicroSIP.ini"
MICROSIP_CFG="$WINEPREFIX/drive_c/users/agent/AppData/Roaming/MicroSIP.ini"
mkdir -p "$(dirname "$MICROSIP_CFG" 2>/dev/null)" || true

# MicroSIP SIP configuration (agent fills in their extension/password)
cat > "$MICROSIP_CFG" << 'INIEOF'
[accounts]
; VICIdial SIP Extension — edit username/password to match your agent extension
; Example: username=8500, password=yourpassword
; The domain should match your VICIdial server IP

[account1]
label=VICIdial
username=
password=
domain=34.79.89.1
proxy=34.79.89.1
transport=UDP
ICEEnabled=1
SRTPEnabled=0
publicAddress=
localPort=0
register=1

[settings]
runOnStartup=1
runMinimized=1
language=Greek
disableSounds=0
INIEOF

echo ""
echo "MicroSIP installation complete!"
echo "Please configure your SIP extension in the MicroSIP settings."
MSEOF
chmod +x "config/includes.chroot/home/agent/.vicidial/install_microsip.sh"

echo "=== Creating Openbox autostart ==="
mkdir -p "config/includes.chroot/home/agent/.config/openbox"

cat > "config/includes.chroot/home/agent/.config/openbox/autostart" << AUTOEOF
#!/bin/bash
# VICIdial Agent Autostart

# Disable screensaver
xset s off
xset -dpms
xset s noblank

# Start system tray
tint2 &

# Start PulseAudio
pulseaudio --start --exit-idle-time=-1 2>/dev/null &

# Hide mouse cursor when idle
unclutter -idle 5 -root &

# Start BT Connector service
python3 /home/agent/.vicidial/bt_connector.py &

# Check if MicroSIP is installed under Wine, otherwise run installer
MICROSIP_PATH="\$HOME/.wine/drive_c/Program Files/MicroSIP/MicroSIP.exe"
MICROSIP_EXE="\$HOME/.vicidial/MicroSIP-full.exe"
if [ -f "\$MICROSIP_PATH" ]; then
    # Start MicroSIP in Wine (minimized to tray)
    WINEPREFIX="\$HOME/.wine" wine "\$MICROSIP_PATH" 2>/dev/null &
elif [ -f "\$MICROSIP_EXE" ] && [ -s "\$MICROSIP_EXE" ]; then
    # Install MicroSIP first
    bash /home/agent/.vicidial/install_microsip.sh
    WINEPREFIX="\$HOME/.wine" wine "\$MICROSIP_PATH" 2>/dev/null &
else
    # Notify agent that MicroSIP needs to be installed
    notify-send "VICIdial Agent" "MicroSIP not found. Copy MicroSIP-full.exe to ~/.vicidial/ and restart."
fi

# Wait for everything to start
sleep 3

# Open VICIdial agent interface in Chromium
chromium-browser \\
  --no-first-run \\
  --disable-translate \\
  --disable-infobars \\
  --disable-session-crashed-bubble \\
  --disable-restore-session-state \\
  --no-default-browser-check \\
  --password-store=basic \\
  --start-maximized \\
  --new-window \\
  "${VICIDIAL_URL}" &
AUTOEOF

echo "=== Creating Openbox rc.xml ==="
cat > "config/includes.chroot/home/agent/.config/openbox/rc.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <keyboard>
    <keybind key="C-A-t">
      <action name="Execute"><command>bash</command></action>
    </keybind>
    <keybind key="C-A-m">
      <action name="Execute">
        <command>sh -c 'WINEPREFIX=$HOME/.wine wine "$HOME/.wine/drive_c/Program Files/MicroSIP/MicroSIP.exe"'</command>
      </action>
    </keybind>
    <keybind key="C-A-b">
      <action name="Execute">
        <command>python3 /home/agent/.vicidial/bt_connector.py</command>
      </action>
    </keybind>
  </keyboard>
  <desktops><number>1</number></desktops>
  <theme>
    <name>Clearlooks</name>
  </theme>
</openbox_config>
EOF

echo "=== Creating tint2 taskbar config ==="
mkdir -p "config/includes.chroot/home/agent/.config/tint2"
cat > "config/includes.chroot/home/agent/.config/tint2/tint2rc" << 'EOF'
panel_position = BOTTOM CENTER HORIZONTAL
panel_size = 100% 30
panel_margin = 0 0
panel_padding = 2 0 2
panel_dock = 0
panel_layer = normal
panel_background_id = 1
taskbar_mode = single_desktop
taskbar_padding = 0 3 2
taskbar_background_id = 0
taskbar_active_background_id = 1
task_text = 1
task_icon = 1
task_centered = 1
task_padding = 6 3 6
task_font = Liberation Sans 9
task_active_background_id = 2
systray = 1
systray_padding = 0 4 5
systray_sort = ascending
clock_format = %H:%M - %d/%m/%Y
time1_format = %H:%M
time2_format = %d/%m/%Y
clock_font = Liberation Sans Bold 10
EOF

echo "=== Creating post-install hook ==="
mkdir -p config/hooks/live

cat > config/hooks/live/0100-setup-agent-user.hook.chroot << 'HOOKEOF'
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

# Ensure agent user exists
if ! id agent &>/dev/null; then
    useradd -m -s /bin/bash -G audio,video,plugdev,netdev,pulse agent
fi
echo "agent:agent" | chpasswd
usermod -aG sudo agent

# Set ownership
chown -R agent:agent /home/agent/.config 2>/dev/null || true
chown -R agent:agent /home/agent/.vicidial 2>/dev/null || true

# Chromium flags for Wine + no-sandbox
mkdir -p /etc/chromium-browser
echo 'CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage"' > /etc/chromium-browser/default

# Disable screen blanking
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/10-no-blanking.conf << 'XEOF'
Section "ServerFlags"
    Option "BlankTime"   "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime"     "0"
EndSection
XEOF

# Wine 32-bit support
dpkg --add-architecture i386 2>/dev/null || true

HOOKEOF
chmod +x config/hooks/live/0100-setup-agent-user.hook.chroot

echo "=== Starting ISO build (this takes 30-60 minutes) ==="
# Copy MicroSIP to the live image for offline Wine installation
if [ -f "$MICROSIP_EXE" ] && [ -s "$MICROSIP_EXE" ]; then
    mkdir -p "config/includes.chroot/home/agent/.vicidial/"
    cp "$MICROSIP_EXE" "config/includes.chroot/home/agent/.vicidial/MicroSIP-full.exe"
    echo "MicroSIP included in the ISO"
else
    echo "WARN: MicroSIP not included — agents will need to install it manually"
fi

mkdir -p "$OUTPUT_DIR"
lb build 2>&1 | tee "$OUTPUT_DIR/agent-build.log"

ISO_FILE=$(ls "$BUILD_DIR"/*.iso 2>/dev/null | head -1)
if [ -n "$ISO_FILE" ]; then
    cp "$ISO_FILE" "$OUTPUT_DIR/vicidial-agent.iso"
    echo ""
    echo "=== BUILD SUCCESS ==="
    echo "ISO: $OUTPUT_DIR/vicidial-agent.iso"
    ls -lh "$OUTPUT_DIR/vicidial-agent.iso"
else
    echo "=== BUILD FAILED — check $OUTPUT_DIR/agent-build.log ==="
    tail -30 "$OUTPUT_DIR/agent-build.log"
    exit 1
fi
