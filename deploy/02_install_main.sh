#!/bin/bash
# ============================================================
# VICIdial Main Server Install Script
# Runs on: vicidial-main (10.10.0.10) — Ubuntu 22.04 LTS
# Role: Web interface + MySQL database + Asterisk
# ============================================================

set -e  # Exit on any error

# ---- EDIT THESE BEFORE RUNNING ----
MAIN_SERVER_IP="10.10.0.10"
AST1_SERVER_IP="10.10.0.11"
AST2_SERVER_IP="10.10.0.12"
EXTERNAL_IP="YOUR_EXTERNAL_IP_HERE"   # From 01_gce_setup.sh output
DB_ROOT_PASS="CHANGE_ME_STRONG_PASSWORD"
DB_VICIDIAL_PASS="CHANGE_ME_VICIDIAL_PASSWORD"
ADMIN_USER="6666"
ADMIN_PASS="CHANGE_ME_ADMIN_PASSWORD"

echo "=== [1/10] System update ==="
apt-get update -y && apt-get upgrade -y

echo "=== [2/10] Installing base dependencies ==="
apt-get install -y \
  build-essential \
  wget curl git subversion unzip \
  ntp \
  screen \
  sox libsox-fmt-all \
  apache2 \
  php8.1 php8.1-mysql php8.1-cli php8.1-curl php8.1-gd php8.1-mbstring php8.1-xml \
  libapache2-mod-php8.1 \
  mysql-server-8.0 mysql-client-8.0 \
  perl \
  libdbi-perl libdbd-mysql-perl \
  libnet-telnet-perl \
  libproc-processtable-perl \
  libtime-hires-perl \
  lame mpg123 \
  ploticus \
  sipsak \
  vim htop iftop

echo "=== [3/10] Installing Perl CPAN modules ==="
cpan -fi \
  Net::Server \
  Mail::Sendmail \
  Spreadsheet::WriteExcel \
  Spreadsheet::ParseExcel \
  OLE::Storage_Lite \
  Unicode::Map \
  Jcode \
  Digest::SHA1

echo "=== [4/10] Configuring PHP ==="
PHP_INI="/etc/php/8.1/apache2/php.ini"
# Set memory limit to 512M (we have 32GB RAM)
sed -i 's/memory_limit = .*/memory_limit = 512M/' $PHP_INI
# Allow file uploads
sed -i 's/file_uploads = .*/file_uploads = On/' $PHP_INI
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' $PHP_INI
sed -i 's/post_max_size = .*/post_max_size = 64M/' $PHP_INI

echo "=== [5/10] Configuring MySQL ==="
# Secure MySQL and create VICIdial database
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASS}';
CREATE DATABASE IF NOT EXISTS asterisk;
CREATE USER IF NOT EXISTS 'cron'@'localhost' IDENTIFIED BY '${DB_VICIDIAL_PASS}';
CREATE USER IF NOT EXISTS 'cron'@'%' IDENTIFIED BY '${DB_VICIDIAL_PASS}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'cron'@'localhost';
GRANT ALL PRIVILEGES ON asterisk.* TO 'cron'@'%';
CREATE USER IF NOT EXISTS 'vicidial'@'localhost' IDENTIFIED BY '${DB_VICIDIAL_PASS}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'vicidial'@'localhost';
FLUSH PRIVILEGES;
EOF

# MySQL performance tuning for 32GB RAM
cat >> /etc/mysql/mysql.conf.d/mysqld.cnf <<MYSQLEOF

# VICIdial tuning
innodb_buffer_pool_size = 8G
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 2
max_connections = 500
thread_cache_size = 50
table_open_cache = 2000
MYSQLEOF

systemctl restart mysql

echo "=== [6/10] Installing Asterisk 20 LTS ==="
cd /usr/src
# Install build dependencies for Asterisk
apt-get install -y \
  libasound2-dev libssl-dev libxml2-dev libncurses5-dev \
  uuid-dev libjansson-dev libsqlite3-dev libedit-dev \
  libspandsp-dev libsrtp2-dev dahdi-linux dahdi-tools \
  libpri-dev

wget -q "https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz"
tar xzf asterisk-20-current.tar.gz
ASTERISK_DIR=$(ls -d asterisk-20.*/ | head -1)
cd /usr/src/$ASTERISK_DIR

# Download MP3 support
contrib/scripts/get_mp3_source.sh

./configure --with-jansson-bundled
make menuselect.makeopts
# Enable app_macro (required by VICIdial), res_parking
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

echo "=== [7/10] Checkout VICIdial from SVN (latest stable) ==="
cd /usr/src
svn checkout http://svn.vicidial.org/vicidial/trunk vicidial-trunk
cd vicidial-trunk

# Run the VICIdial installer
perl install.pl

echo "=== [8/10] Import VICIdial MySQL schema ==="
mysql -u root -p${DB_ROOT_PASS} asterisk < /usr/src/vicidial-trunk/bin/MySQL_AST_CREATE_tables.sql

# Insert server configuration (update IPs)
sed -i "s/10.10.10.15/${MAIN_SERVER_IP}/g" /usr/src/vicidial-trunk/extras/first_server_install.sql
mysql -u root -p${DB_ROOT_PASS} asterisk < /usr/src/vicidial-trunk/extras/first_server_install.sql

# Set server's Asterisk version in DB
mysql -u root -p${DB_ROOT_PASS} asterisk -e \
  "UPDATE servers SET asterisk_version='20' WHERE server_ip='${MAIN_SERVER_IP}';"

echo "=== [9/10] Configure astguiclient.conf ==="
cat > /etc/astguiclient.conf <<CONFEOF
PATHhome => /usr/share/astguiclient
PATHlogs => /var/log/astguiclient
PATHagi => /var/lib/asterisk/agi-bin
PATHweb => /var/www/html
PATHsounds => /var/lib/asterisk/sounds
PATHagi_log => /var/log/astguiclient
DB_server => localhost
DB_database => asterisk
DB_login => cron
DB_password => ${DB_VICIDIAL_PASS}
DB_port => 3306
VARserver_ip => ${MAIN_SERVER_IP}
ASTERISKserver_ip => ${MAIN_SERVER_IP}
enable_sip => 1
CONFEOF

chmod 640 /etc/astguiclient.conf

echo "=== [10/10] Configure Apache & enable site ==="
# Set document root
sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html|' /etc/apache2/sites-available/000-default.conf

# Create VICIdial Apache config
cat > /etc/apache2/conf-available/vicidial.conf <<APACHECONF
<Directory /var/www/html>
    Options -Indexes +FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
APACHECONF

a2enconf vicidial
a2enmod rewrite headers

# Set correct permissions
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

systemctl enable apache2 mysql asterisk
systemctl restart apache2

echo ""
echo "======================================================"
echo "vicidial-main installation COMPLETE!"
echo ""
echo "Admin panel:  http://${EXTERNAL_IP}/vicidial/admin.php"
echo "             (user: ${ADMIN_USER}, pass: set in admin panel)"
echo ""
echo "NEXT STEPS:"
echo "1. Copy SSH key to vicidial-ast1 and vicidial-ast2"
echo "2. Run 03_install_asterisk_node.sh on each Asterisk server"
echo "3. Copy /usr/src/vicidial-trunk to both Asterisk servers"
echo "======================================================"
