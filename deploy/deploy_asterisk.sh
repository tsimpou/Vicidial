#!/bin/bash
# Deploy Asterisk configs, start Asterisk, verify web interface
set -e

AMI_PASS="AmiV1c1d@l2026"
EXTERNAL_IP="34.79.89.1"
INTERNAL_IP="10.10.0.10"

echo "=== Deploying Asterisk configs ==="

# Backup existing /etc/asterisk if it has content
if [ -d /etc/asterisk ] && [ "$(ls -A /etc/asterisk)" ]; then
    sudo cp -r /etc/asterisk /etc/asterisk.bak.$(date +%Y%m%d%H%M) 2>/dev/null || true
fi

# Copy configs from home dir to /etc/asterisk/
sudo cp ~/sip.conf /etc/asterisk/sip.conf
sudo cp ~/extensions.conf /etc/asterisk/extensions.conf
sudo cp ~/manager.conf /etc/asterisk/manager.conf
sudo cp ~/meetme.conf /etc/asterisk/meetme.conf

echo "Configs copied to /etc/asterisk/"

# Fix AMI password in manager.conf
sudo sed -i "s/CHANGE_ME_AMI_PASSWORD/$AMI_PASS/" /etc/asterisk/manager.conf

# Fix externip in sip.conf
sudo sed -i "s/externip=.*/externip=$EXTERNAL_IP/" /etc/asterisk/sip.conf

# Add VARasterisk_pass to astguiclient.conf if not present
if ! sudo grep -q "VARasterisk_pass" /etc/astguiclient.conf; then
    echo "VARasterisk_pass => $AMI_PASS" | sudo tee -a /etc/astguiclient.conf
fi

# Also make sure AMI user is 'cron' (what VICIdial bin scripts use)
# Check if manager.conf uses VDAD — add cron user as well
if sudo grep -q "\[VDAD\]" /etc/asterisk/manager.conf; then
    sudo sed -i "s/\[VDAD\]/[cron]/" /etc/asterisk/manager.conf
fi

echo "=== Verifying /etc/asterisk/ contents ==="
ls -la /etc/asterisk/

echo ""
echo "=== Creating Asterisk systemd service ==="
# Check if asterisk binary exists
ASTERISK_BIN=$(which asterisk 2>/dev/null || echo "/usr/sbin/asterisk")

# Create service file
cat <<EOF | sudo tee /etc/systemd/system/asterisk.service
[Unit]
Description=Asterisk PBX
After=network.target mysql.service

[Service]
Type=simple
User=root
ExecStart=$ASTERISK_BIN -f -C /etc/asterisk/asterisk.conf
ExecStop=$ASTERISK_BIN -rx "core stop now"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Check if /etc/asterisk/asterisk.conf exists (main Asterisk config)
if [ ! -f /etc/asterisk/asterisk.conf ]; then
    echo "=== Creating /etc/asterisk/asterisk.conf ==="
    cat <<'ASTCONF' | sudo tee /etc/asterisk/asterisk.conf
[directories]
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk

[options]
verbose=3
debug=0
nocolor=yes
dontwait=no
language=en
maxcalls=500
maxload=0.9
ASTCONF
fi

# Ensure log/run/spool dirs exist
sudo mkdir -p /var/log/asterisk /var/run/asterisk /var/spool/asterisk/outgoing /var/spool/asterisk/tmp

echo "=== Starting Asterisk ==="
sudo systemctl daemon-reload
sudo systemctl enable asterisk
sudo systemctl start asterisk || true
sleep 5

echo "=== Asterisk Status ==="
sudo systemctl status asterisk --no-pager | head -20 || true

echo ""
echo "=== Testing Asterisk CLI ==="
asterisk -rx "core show version" 2>/dev/null || sudo asterisk -rx "core show version" 2>/dev/null || echo "Asterisk not responding yet (may need a moment)"

echo ""
echo "=== Testing Web Interface ==="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/vicidial/admin.php)
echo "HTTP code for admin.php: $HTTP_CODE"

echo ""
echo "=== Done! ==="
echo "VICIdial admin panel: http://$EXTERNAL_IP/vicidial/admin.php"
echo "Login: 6666 / 1234"
echo "AMI password: $AMI_PASS"
echo "Added to /etc/astguiclient.conf: VARasterisk_pass => $AMI_PASS"
