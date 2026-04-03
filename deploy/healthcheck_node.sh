echo '=== Asterisk Versions ==='
asterisk -rx 'core show version'
echo ''
echo '=== Active Calls/Channels ==='
asterisk -rx 'core show channels count'
echo ''
echo '=== MySQL Connection ==='
mysql -u cron -p'Vic1d!al2026Secure' -h 127.0.0.1 asterisk -e 'SELECT COUNT(*) servers FROM servers' 2>&1 | tail -2
echo ''
echo '=== Crontab ==='
crontab -l | wc -l
echo 'cron lines'
echo ''
echo '=== Asterisk Service ==='
systemctl is-active asterisk