#!/bin/bash
echo "=== SERVICES ==="
systemctl is-active asterisk mysql apache2 cron

echo "=== ASTERISK ==="
sudo asterisk -rx "core show version"

echo "=== PJSIP TRANSPORTS ==="
sudo asterisk -rx "pjsip show transports" | head -6

echo "=== WEB INTERFACE ==="
admin_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/vicidial/admin.php -u 6666:1234)
agent_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/agc/vicidial.php -u 6666:1234)
echo "admin.php: HTTP $admin_code"
echo "vicidial.php (agent): HTTP $agent_code"

echo "=== DB TABLES ==="
sudo mysql -u root asterisk -e "SELECT COUNT(*) as total_tables FROM information_schema.tables WHERE table_schema='asterisk';" 2>/dev/null

echo "=== CRONTAB ==="
sudo crontab -l | wc -l

echo "=== DISK/MEM ==="
df -h / | tail -1
free -h | grep Mem

echo "=== ACCESS URL ==="
echo "VICIdial Admin: http://34.79.89.1/vicidial/admin.php"
echo "Agent Interface: http://34.79.89.1/agc/vicidial.php"
echo "Login: 6666 / 1234"
