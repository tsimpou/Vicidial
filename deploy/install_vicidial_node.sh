#!/bin/bash
# Install VICIdial files on an Asterisk satellite node
# Run after Asterisk is compiled and installed
THIS_IP="${1:-10.10.0.11}"
MAIN_IP="${2:-10.10.0.10}"
DB_PASS="${3:-Vic1d!al2026Secure}"

echo "=== Installing VICIdial files on $THIS_IP ==="

echo "Step 1: Download VICIdial 2.14"
if [ ! -f /tmp/vicidial.zip ]; then
  wget -q -O /tmp/vicidial.zip \
    "https://sourceforge.net/projects/astguiclient/files/latest/download" \
    --content-disposition
fi

echo "Step 2: Extract"
mkdir -p /usr/src/vicidial-node
cd /tmp
unzip -o vicidial.zip -d /usr/src/vicidial-node/ 2>&1 | tail -3
VD_DIR=$(find /usr/src/vicidial-node -name "install.pl" -type f | head -1 | xargs dirname)
echo "VICIdial dir: $VD_DIR"

echo "Step 3: Install VICIdial (no DB - use main server's DB)"
mkdir -p /var/lib/asterisk/agi-bin /usr/share/astguiclient \
         /var/log/astguiclient /var/www/html

cd "$VD_DIR"
cp -f agi/*.agi /var/lib/asterisk/agi-bin/ 2>/dev/null || true
cp -f agi/*.pl /var/lib/asterisk/agi-bin/ 2>/dev/null || true
cp -f bin/*.pl /usr/share/astguiclient/ 2>/dev/null || true
chmod +x /var/lib/asterisk/agi-bin/*.agi 2>/dev/null || true
chmod +x /var/lib/asterisk/agi-bin/*.pl 2>/dev/null || true
chmod +x /usr/share/astguiclient/*.pl 2>/dev/null || true

echo "Step 4: Write /etc/astguiclient.conf"
cat > /etc/astguiclient.conf << CONF
PATHhome=/usr/share/astguiclient
PATHlogs=/var/log/astguiclient
PATHagi=/var/lib/asterisk/agi-bin
PATHweb=/var/www/html
PATHsounds=/var/lib/asterisk/sounds
PATHagi_log=/var/log/astguiclient
VARDB_server=$MAIN_IP
VARDB_database=asterisk
VARDB_user=cron
VARDB_pass=$DB_PASS
VARDB_port=3306
VARserver_ip=$THIS_IP
ASTERISKserver_ip=$THIS_IP
VARasterisk_pass=AmiV1c1d@l2026
enable_sip=1
CONF
chmod 644 /etc/astguiclient.conf

echo "Step 5: Setup crontab for satellite node"
mkdir -p /var/log/astguiclient
chmod 777 /var/log/astguiclient

CRONTAB='### VICIDIAL satellite node keepalive
* * * * * /usr/share/astguiclient/ADMIN_keepalive_ALL.pl >> /var/log/astguiclient/ADMIN_keepalive_ALL.log 2>&1
* * * * * /usr/share/astguiclient/AST_conf_update.pl >> /var/log/astguiclient/AST_conf_update.log 2>&1
*/5 * * * * /usr/share/astguiclient/AST_cleanup_agent_log.pl >> /var/log/astguiclient/AST_cleanup_agent_log.log 2>&1
*/5 * * * * /usr/share/astguiclient/AST_CRON_audio_1_move_mix.pl >> /var/log/astguiclient/AST_CRON_audio_1.log 2>&1'

echo "$CRONTAB" | crontab -
echo "Crontab set: $(crontab -l | wc -l) lines"

echo "=== VICIdial node setup complete ==="
echo "AGI files: $(ls /var/lib/asterisk/agi-bin/*.agi 2>/dev/null | wc -l) agi files"
echo "Bin scripts: $(ls /usr/share/astguiclient/*.pl 2>/dev/null | wc -l) pl files"
