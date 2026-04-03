#!/bin/bash
# Run on vicidial-main: fixes astguiclient.conf DB password on ast nodes
# Usage: bash postinstall_fix_nodes.sh <db_pass>
# Must be run as root (has SSH access to ast nodes)

DB_PASS="${1:-Vic1d!al2026Secure}"

for NODE_IP in 10.10.0.11 10.10.0.12; do
  echo "=== Fixing $NODE_IP ==="
  ssh -o StrictHostKeyChecking=no root@${NODE_IP} "
    # Fix DB password in astguiclient.conf
    sed -i 's|^VARDB_pass=.*|VARDB_pass=${DB_PASS}|' /etc/astguiclient.conf
    echo 'VARDB_pass line is now:'
    grep VARDB_pass /etc/astguiclient.conf
    
    # Verify Asterisk is running
    systemctl is-active asterisk && echo 'Asterisk: RUNNING' || echo 'Asterisk: NOT running'
    asterisk -rx 'core show version' 2>/dev/null || echo 'Asterisk not responding'
  "
done

echo "=== Done fixing nodes ==="
