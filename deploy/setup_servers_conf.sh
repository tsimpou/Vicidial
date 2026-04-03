#!/bin/bash
echo "=== Adding ast1 and ast2 servers to VICIdial ==="

sudo mysql -u root asterisk << 'SQL'
INSERT IGNORE INTO servers 
  (server_id, server_description, server_ip, active, asterisk_version, max_vicidial_trunks, 
   local_gmt, telnet_host, telnet_port, ASTmgrUSERNAME, ASTmgrSECRET,
   active_asterisk_server, generate_vicidial_conf, rebuild_conf_files,
   outbound_calls_per_second, conf_engine)
VALUES 
  ('ast1','Asterisk Node 1','10.10.0.11','Y','20',100,'0.00','localhost',5038,'cron','AmiV1c1d@l2026','Y','Y','Y',5,'CONFBRIDGE'),
  ('ast2','Asterisk Node 2','10.10.0.12','Y','20',100,'0.00','localhost',5038,'cron','AmiV1c1d@l2026','Y','Y','Y',5,'CONFBRIDGE');

INSERT IGNORE INTO server_updater (server_ip, last_update) VALUES 
  ('10.10.0.11', NOW()),
  ('10.10.0.12', NOW());
SQL

echo "Servers in DB:"
sudo mysql -u root asterisk -e "SELECT server_id, server_ip, active, max_vicidial_trunks, conf_engine FROM servers;"

echo ""
echo "=== Adding 300 conference rooms for all 3 servers ==="

python3 << 'PYEOF'
import subprocess

sql_lines = []
for i in range(1, 301):
    room = 8600000 + i
    for server_ip in ['10.10.0.10', '10.10.0.11', '10.10.0.12']:
        sql_lines.append(
            f"INSERT IGNORE INTO vicidial_conferences (conf_exten, server_ip) VALUES ({room}, '{server_ip}');"
        )

sql = '\n'.join(sql_lines)
result = subprocess.run(
    ['sudo', 'mysql', '-u', 'root', 'asterisk'],
    input=sql, capture_output=True, text=True
)
if result.returncode == 0:
    print(f"Inserted {len(sql_lines)} conference room entries")
else:
    print("Error:", result.stderr[:500])
PYEOF

echo "Conference rooms in DB:"
sudo mysql -u root asterisk -e "SELECT COUNT(*) as total, server_ip FROM vicidial_conferences GROUP BY server_ip ORDER BY server_ip;"

echo ""
echo "=== Also update main server conf_engine to CONFBRIDGE ==="
sudo mysql -u root asterisk -e "UPDATE servers SET conf_engine='CONFBRIDGE', ASTmgrSECRET='AmiV1c1d@l2026', ASTmgrUSERNAME='cron', max_vicidial_trunks=100 WHERE server_ip='10.10.0.10';"
echo "Done"
