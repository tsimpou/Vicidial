#!/bin/bash
# Run on vicidial-main: push VICIdial files and configs to all satellite nodes
# Usage: sudo bash push_vicidial_to_nodes.sh
# Requires: SSH keys to ast nodes are configured (main -> ast1/ast2)

DB_PASS="Vic1d!al2026Secure"
MAIN_IP="10.10.0.10"
NODES=("10.10.0.11" "10.10.0.12")

for NODE_IP in "${NODES[@]}"; do
  echo ""
  echo "========================================="
  echo "=== Deploying VICIdial to $NODE_IP  ==="
  echo "========================================="

  echo "--- Step 1: Copy AGI files ---"
  scp -o StrictHostKeyChecking=no -r /var/lib/asterisk/agi-bin/*.agi \
    root@${NODE_IP}:/var/lib/asterisk/agi-bin/ 2>&1 | tail -3
  scp -o StrictHostKeyChecking=no -r /var/lib/asterisk/agi-bin/*.pl \
    root@${NODE_IP}:/var/lib/asterisk/agi-bin/ 2>/dev/null | tail -2 || true

  echo "--- Step 2: Copy bin scripts ---"
  ssh -o StrictHostKeyChecking=no root@${NODE_IP} "mkdir -p /usr/share/astguiclient"
  scp -o StrictHostKeyChecking=no /usr/share/astguiclient/*.pl \
    root@${NODE_IP}:/usr/share/astguiclient/ 2>&1 | tail -3

  echo "--- Step 3: Set permissions and write config ---"
  ssh -o StrictHostKeyChecking=no root@${NODE_IP} "
    chmod +x /var/lib/asterisk/agi-bin/*.agi 2>/dev/null || true
    chmod +x /var/lib/asterisk/agi-bin/*.pl 2>/dev/null || true
    chmod +x /usr/share/astguiclient/*.pl 2>/dev/null || true
    mkdir -p /var/log/astguiclient
    chmod 777 /var/log/astguiclient

    # Write astguiclient.conf with correct DB password
    cat > /etc/astguiclient.conf << 'CONF'
PATHhome=/usr/share/astguiclient
PATHlogs=/var/log/astguiclient
PATHagi=/var/lib/asterisk/agi-bin
PATHweb=/var/www/html
PATHsounds=/var/lib/asterisk/sounds
PATHagi_log=/var/log/astguiclient
VARDB_server=${MAIN_IP}
VARDB_database=asterisk
VARDB_user=cron
VARDB_pass=${DB_PASS}
VARDB_port=3306
VARserver_ip=${NODE_IP}
ASTERISKserver_ip=${NODE_IP}
VARasterisk_pass=AmiV1c1d@l2026
enable_sip=1
CONF
    chmod 644 /etc/astguiclient.conf
    echo 'Config written.'
    grep -E 'VARDB_pass|VARserver_ip' /etc/astguiclient.conf
  "

  echo "--- Step 4: Setup satellite crontab ---"
  ssh -o StrictHostKeyChecking=no root@${NODE_IP} "
    (crontab -l 2>/dev/null | grep -v 'astguiclient'; echo '### VICIDIAL satellite node keepalive'
    echo '* * * * * /usr/share/astguiclient/ADMIN_keepalive_ALL.pl >> /var/log/astguiclient/ADMIN_keepalive_ALL.log 2>&1'
    echo '* * * * * /usr/share/astguiclient/AST_conf_update.pl >> /var/log/astguiclient/AST_conf_update.log 2>&1'
    echo '*/5 * * * * /usr/share/astguiclient/AST_cleanup_agent_log.pl >> /var/log/astguiclient/AST_cleanup_agent_log.log 2>&1') | crontab -
    echo 'Crontab lines: '\$(crontab -l | wc -l)
  "

  echo "--- Step 5: Verify ---"
  ssh -o StrictHostKeyChecking=no root@${NODE_IP} "
    echo 'AGI files: '\$(ls /var/lib/asterisk/agi-bin/*.agi 2>/dev/null | wc -l)
    echo 'Bin scripts: '\$(ls /usr/share/astguiclient/*.pl 2>/dev/null | wc -l)
    systemctl is-active asterisk && echo 'Asterisk: RUNNING' || echo 'Asterisk: NOT RUNNING'
    asterisk -rx 'core show version' 2>/dev/null || true
  "
done

echo ""
echo "=== All nodes deployed ==="
