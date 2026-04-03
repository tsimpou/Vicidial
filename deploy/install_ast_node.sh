#!/bin/bash
# Install Asterisk 20 + VICIdial AGI files on a satellite Asterisk node
# Run with: bash install_ast_node.sh <this_server_ip> <main_server_ip> <db_pass>
# Note: no set -e — we handle errors explicitly

THIS_IP="${1:-10.10.0.11}"
MAIN_IP="${2:-10.10.0.10}"
DB_PASS="${3:-Vic1d!al2026Secure}"

echo "=== Installing Asterisk node: $THIS_IP (main=$MAIN_IP) ==="

# Force IPv4 globally — Cloud NAT only does IPv4
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

echo "=== Step 1: Update & install deps ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq 2>&1 | tail -3 || true
# Install required packages, ignore optional ones that may not exist
apt-get install -y build-essential libssl-dev libncurses5-dev libnewt-dev \
  libxml2-dev libsqlite3-dev uuid-dev \
  libjansson-dev libedit-dev subversion wget curl git \
  perl libdbi-perl libdbd-mysql-perl libnet-ssleay-perl \
  sox mpg123 lame screen 2>&1 | tail -5 || true
# Optional packages (may not exist in all repos)
apt-get install -y linux-headers-$(uname -r) 2>&1 | tail -2 || true
apt-get install -y ffmpeg 2>&1 | tail -2 || true
apt-get install -y ntp || apt-get install -y chrony || true
echo "Deps done"

echo "=== Step 2: Get Asterisk 20 source ==="
if [ ! -f /usr/src/asterisk-20.tar.gz ] || [ ! -s /usr/src/asterisk-20.tar.gz ]; then
  echo "Trying SCP from main server ($MAIN_IP)..."
  scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    root@${MAIN_IP}:/usr/src/asterisk-20.tar.gz /usr/src/asterisk-20.tar.gz 2>&1 && \
  echo "SCP from main: OK" || {
    echo "SCP failed, trying wget (IPv4 forced)..."
    wget -4 -q --show-progress --timeout=120 \
      -O /usr/src/asterisk-20.tar.gz \
      "https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-20-current.tar.gz"
  }
fi
ls -lh /usr/src/asterisk-20.tar.gz
cd /usr/src
# Clean previous failed extractions
rm -rf asterisk-20.*/
tar -xzf asterisk-20.tar.gz
AST_DIR=$(ls -d asterisk-20.*/ 2>/dev/null | head -1)
if [ -z "$AST_DIR" ]; then
  echo "ERROR: Failed to extract Asterisk tarball" >&2
  exit 1
fi
echo "Extracted: $AST_DIR"
cd "$AST_DIR"

echo "=== Step 3: install_prereq ==="
contrib/scripts/install_prereq install 2>&1 | tail -3

echo "=== Step 4: Configure ==="
./configure --with-jansson-bundled 2>&1 | tail -3

echo "=== Step 5: Menuselect (enable needed modules) ==="
make menuselect.makeopts
# Note: cdr_mysql was removed in Asterisk 20; chan_sip is deprecated but still available
menuselect/menuselect \
  --enable app_confbridge \
  --enable app_meetme \
  --enable res_musiconhold \
  menuselect.makeopts 2>&1 || true
# Try to enable chan_sip if available
menuselect/menuselect --enable chan_sip menuselect.makeopts 2>&1 || true
echo "Menuselect done"

echo "=== Step 6: Build (this takes ~10 minutes) ==="
make -j$(nproc) 2>&1 | tail -5
echo "Build done"

echo "=== Step 7: Install ==="
make install
make samples

echo "=== Step 8: Configure /etc/asterisk/ ==="

# Set externip (not needed for internal nodes — they use internal IPs)
sed -i "s/externip=.*/;externip=not-needed-for-internal-node/" \
  /etc/asterisk/sip.conf 2>/dev/null || true

# Write astguiclient.conf for this node
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

echo "=== Step 9: Install VICIdial AGI files from main server ==="
mkdir -p /var/lib/asterisk/agi-bin /usr/share/astguiclient /var/log/astguiclient
# Copy AGI files from main server via shared MySQL (they're already installed)
# Also download VICIdial zip if AGI dir is empty
if [ $(ls /var/lib/asterisk/agi-bin/*.agi 2>/dev/null | wc -l) -eq 0 ]; then
  cp /usr/src/vicidial-trunk/2024-07-17/agi/* /var/lib/asterisk/agi-bin/ 2>/dev/null || true
fi

echo "=== Step 10: Create pjsip.conf ==="
cat > /etc/asterisk/pjsip.conf << PJSIP
[global]
type=global
user_agent=Asterisk

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
local_net=10.10.0.0/24
local_net=127.0.0.1/8

[transport-tcp]
type=transport
protocol=tcp
bind=0.0.0.0:5060
local_net=10.10.0.0/24
local_net=127.0.0.1/8
PJSIP

echo "=== Step 11: Create manager.conf (AMI) ==="
cat > /etc/asterisk/manager.conf << MGR
[general]
enabled=yes
port=5038
bindaddr=127.0.0.1
displayconnects=no

[cron]
secret=AmiV1c1d@l2026
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
permit=10.10.0.0/255.255.255.0
read=system,call,log,verbose,command,agent,user,originate
write=system,call,log,verbose,command,agent,user,originate
MGR

echo "=== Step 12: Create Asterisk service ==="
cat > /etc/systemd/system/asterisk.service << SVC
[Unit]
Description=Asterisk PBX
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/sbin/asterisk -f -C /etc/asterisk/asterisk.conf
ExecStop=/usr/sbin/asterisk -rx "core stop now"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable asterisk
systemctl start asterisk
sleep 5

echo "=== Step 13: Verify ==="
systemctl is-active asterisk
asterisk -rx "core show version"
echo "=== NODE $THIS_IP READY ==="
