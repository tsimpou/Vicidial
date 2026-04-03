#!/bin/bash
# Kill stalled install, clean up, and restart
THIS_IP="${1:-10.10.0.11}"
MAIN_IP="${2:-10.10.0.10}"
DB_PASS="${3:-Vic1d!al2026Secure}"

echo "=== Cleanup: killing any stalled install processes ==="
pkill -9 -f install_ast_node 2>/dev/null || true
pkill -9 -f wget 2>/dev/null || true

echo "=== Testing internet access via Cloud NAT ==="
wget -T 10 -q -O /tmp/test_conn.txt https://downloads.asterisk.org/pub/telephony/asterisk/ 2>&1
if [ $? -eq 0 ]; then
  echo "Internet access: OK"
  rm -f /tmp/test_conn.txt
else
  echo "Internet access: FAILED - will use alternate method"
fi

echo "=== Cleaning old artifacts ==="
rm -f /usr/src/asterisk-20.tar.gz

echo "=== Relaunching install ==="
nohup bash ~/install_ast_node.sh "$THIS_IP" "$MAIN_IP" "$DB_PASS" > ~/ast_install.log 2>&1 &
echo "Relaunched with PID $!"
