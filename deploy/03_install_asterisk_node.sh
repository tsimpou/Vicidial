#!/bin/bash
# ============================================================
# VICIdial Asterisk Node Install Script
# Runs on: vicidial-ast1 (10.10.0.11) OR vicidial-ast2 (10.10.0.12)
# Role: Asterisk voice server only (no web, no DB)
# ============================================================

set -e

# ---- EDIT THESE BEFORE RUNNING ----
THIS_SERVER_IP="10.10.0.11"          # Change to 10.10.0.12 for ast2
MAIN_SERVER_IP="10.10.0.10"
EXTERNAL_IP="YOUR_EXTERNAL_IP_HERE"  # The external IP of vicidial-main
DB_VICIDIAL_PASS="CHANGE_ME_VICIDIAL_PASSWORD"  # Same as in 02_install_main.sh

echo "=== [1/7] System update ==="
apt-get update -y && apt-get upgrade -y

echo "=== [2/7] Installing dependencies ==="
apt-get install -y \
  build-essential \
  wget curl subversion unzip \
  ntp screen \
  sox libsox-fmt-all \
  mysql-client-8.0 \
  perl libdbi-perl libdbd-mysql-perl \
  libnet-telnet-perl libproc-processtable-perl \
  libtime-hires-perl \
  lame mpg123 \
  libasound2-dev libssl-dev libxml2-dev libncurses5-dev \
  uuid-dev libjansson-dev libsqlite3-dev libedit-dev \
  libspandsp-dev libsrtp2-dev dahdi-linux dahdi-tools \
  libpri-dev \
  vim htop

echo "=== [3/7] Installing Perl CPAN modules ==="
cpan -fi Net::Server Mail::Sendmail Proc::ProcessTable

echo "=== [4/7] Installing Asterisk 20 LTS ==="
cd /usr/src
wget -q "https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz"
tar xzf asterisk-20-current.tar.gz
ASTERISK_DIR=$(ls -d asterisk-20.*/ | head -1)
cd /usr/src/$ASTERISK_DIR

contrib/scripts/get_mp3_source.sh

./configure --with-jansson-bundled
make menuselect.makeopts
menuselect/menuselect \
  --enable app_macro \
  --enable res_parking \
  --enable app_meetme \
  --enable format_mp3 \
  menuselect.makeopts

make -j$(nproc)
make install
make samples
make config

echo "=== [5/7] Install VICIdial scripts (connecting to main DB) ==="
cd /usr/src
svn checkout http://svn.vicidial.org/vicidial/trunk vicidial-trunk
cd vicidial-trunk
perl install.pl

echo "=== [6/7] Configure astguiclient.conf ==="
cat > /etc/astguiclient.conf <<CONFEOF
PATHhome => /usr/share/astguiclient
PATHlogs => /var/log/astguiclient
PATHagi => /var/lib/asterisk/agi-bin
PATHweb => /var/www/html
PATHsounds => /var/lib/asterisk/sounds
PATHagi_log => /var/log/astguiclient
DB_server => ${MAIN_SERVER_IP}
DB_database => asterisk
DB_login => cron
DB_password => ${DB_VICIDIAL_PASS}
DB_port => 3306
VARserver_ip => ${THIS_SERVER_IP}
ASTERISKserver_ip => ${THIS_SERVER_IP}
enable_sip => 1
CONFEOF

chmod 640 /etc/astguiclient.conf

echo "=== [7/7] Register this server in VICIdial DB ==="
mysql -h ${MAIN_SERVER_IP} -u cron -p${DB_VICIDIAL_PASS} asterisk <<EOF
INSERT IGNORE INTO servers (server_id, server_description, server_ip, active, asterisk_version)
VALUES ('ast-${THIS_SERVER_IP}', 'Asterisk Node ${THIS_SERVER_IP}', '${THIS_SERVER_IP}', 'Y', '20');

INSERT IGNORE INTO server_updater SET server_ip='${THIS_SERVER_IP}', last_update='';
EOF

systemctl enable asterisk
systemctl start asterisk

echo ""
echo "======================================================"
echo "Asterisk node ${THIS_SERVER_IP} installation COMPLETE!"
echo ""
echo "Test: asterisk -rv"
echo "NEXT: Configure SIP trunk and extensions on main admin UI"
echo "======================================================"
