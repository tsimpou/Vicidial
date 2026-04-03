#!/bin/bash
# Configure vicidial-main MySQL to accept connections from ast1/ast2
# Add ast1 and ast2 as VICIdial satellite servers
# Generate conference rooms for 50+ agents

echo "=== Step 1: MySQL remote access for ast1 and ast2 ==="
sudo mysql -u root << 'SQL'
-- Allow cron user from ast1
CREATE USER IF NOT EXISTS 'cron'@'10.10.0.11' IDENTIFIED BY 'Vic1d!al2026Secure';
GRANT ALL PRIVILEGES ON asterisk.* TO 'cron'@'10.10.0.11';

-- Allow cron user from ast2
CREATE USER IF NOT EXISTS 'cron'@'10.10.0.12' IDENTIFIED BY 'Vic1d!al2026Secure';
GRANT ALL PRIVILEGES ON asterisk.* TO 'cron'@'10.10.0.12';

FLUSH PRIVILEGES;
SQL
echo "MySQL users created"

echo ""
echo "=== Step 2: Add ast1 and ast2 servers to VICIdial DB ==="
sudo mysql -u root asterisk << 'SQL'
INSERT IGNORE INTO servers 
  (server_id, server_description, server_ip, active, asterisk_version, max_vicidial_trunks, local_gmt, telnet_host, telnet_port, ASTERISKrestartCMD)
VALUES 
  ('ast1','Asterisk Node 1','10.10.0.11','Y','20','100','0.0','localhost','5038','sudo /sbin/service asterisk restart'),
  ('ast2','Asterisk Node 2','10.10.0.12','Y','20','100','0.0','localhost','5038','sudo /sbin/service asterisk restart');
SQL

echo "Servers added:"
sudo mysql -u root asterisk -e "SELECT server_id, server_description, server_ip, active, max_vicidial_trunks FROM servers;"

echo ""
echo "=== Step 3: Add server_updater entries ==="
sudo mysql -u root asterisk << 'SQL'
INSERT IGNORE INTO server_updater (server_ip, last_update) VALUES 
  ('10.10.0.11', NOW()),
  ('10.10.0.12', NOW());
SQL

echo ""
echo "=== Step 4: Generate conference rooms (8600001-8600300) for 50+ agents ==="
# Generate 300 conference rooms - enough for 50 agents with 3 channels each (agent, customer, 3way)

python3 -c "
rooms = []
for i in range(1, 301):
    room = 8600000 + i
    rooms.append(f\"INSERT IGNORE INTO vicidial_conferences (conf_exten,conf_name,server_ip,extension_digit,conf_secret,user_group,active) VALUES ('{room}','conf{room}','10.10.0.10','0','0','---ALL---','Y');\")
    # Also add for ast1
    rooms.append(f\"INSERT IGNORE INTO vicidial_conferences (conf_exten,conf_name,server_ip,extension_digit,conf_secret,user_group,active) VALUES ('{room}','conf{room}','10.10.0.11','0','0','---ALL---','Y');\")
    # Also add for ast2
    rooms.append(f\"INSERT IGNORE INTO vicidial_conferences (conf_exten,conf_name,server_ip,extension_digit,conf_secret,user_group,active) VALUES ('{room}','conf{room}','10.10.0.12','0','0','---ALL---','Y');\")

print('\n'.join(rooms))
" | sudo mysql -u root asterisk

echo "Conference rooms added:"
sudo mysql -u root asterisk -e "SELECT COUNT(*) as total_conf_rooms FROM vicidial_conferences;"

echo ""
echo "=== Step 5: Check MySQL bind-address (must allow remote connections) ==="
grep -i 'bind-address' /etc/mysql/mysql.conf.d/mysqld.cnf || grep -ri 'bind-address' /etc/mysql/

echo ""
echo "=== Step 6: If MySQL is listening only on 127.0.0.1, fix it ==="
# Check current bind
BIND=$(sudo mysql -u root -e "SHOW VARIABLES LIKE 'bind_address';" 2>/dev/null | grep bind | awk '{print $2}')
echo "MySQL bind_address: $BIND"

if [ "$BIND" = "127.0.0.1" ] || [ "$BIND" = "localhost" ]; then
    echo "Fixing MySQL to listen on all interfaces..."
    sudo sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
    sudo systemctl restart mysql
    sleep 3
    echo "MySQL restarted"
fi

echo ""
echo "=== Done! ==="
echo "Run 'bash ~/status_check.sh' to verify"
