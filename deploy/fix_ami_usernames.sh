#!/bin/bash
# Fix manager.conf on all Asterisk nodes with the CORRECT VICIdial AMI usernames
# Rewrites the file from scratch to avoid any accumulated errors
# Run as root on vicidial-main

repair_manager_conf() {
  local BIND="$1"  # 127.0.0.1 for main, 0.0.0.0 for ast nodes
  
  cat > /etc/asterisk/manager.conf << 'EOF'
[general]
enabled=yes
port=5038
displayconnects=no
EOF
  echo "bindaddr=${BIND}" >> /etc/asterisk/manager.conf
  
  # VICIdial requires these specific AMI usernames
  for USER in cron updatecron listencron sendcron; do
    cat >> /etc/asterisk/manager.conf << EOF

[${USER}]
secret=AmiV1c1d@l2026
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
permit=10.10.0.0/255.255.255.0
read=system,call,log,verbose,command,agent,user,originate
write=system,call,log,verbose,command,agent,user,originate
EOF
  done
  
  asterisk -rx "manager reload"
  echo "Manager users:"
  asterisk -rx "manager show users"
}

echo "=== Fixing main server ==="
repair_manager_conf "127.0.0.1"
echo "Main server: done"

for NODE_IP in 10.10.0.11 10.10.0.12; do
  echo ""
  echo "=== Fixing $NODE_IP ==="
  ssh -o StrictHostKeyChecking=no root@${NODE_IP} "$(declare -f repair_manager_conf); repair_manager_conf 0.0.0.0"
  echo "$NODE_IP: done"
done

echo ""
echo "=== Testing AMI auth from main to all nodes ==="
for HOST in localhost 10.10.0.11 10.10.0.12; do
  for USER in cron sendcron listencron; do
    result=$(perl /tmp/test_ami.pl $HOST $USER 2>&1 | grep -E "Authentication|Response")
    echo "$HOST / $USER: $result"
  done
done

CORRECT_BLOCK='
[updatecron]
secret=AmiV1c1d@l2026
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
permit=10.10.0.0/255.255.255.0
read=system,call,log,verbose,command,agent,user,originate
write=system,call,log,verbose,command,agent,user,originate

[listencron]
secret=AmiV1c1d@l2026
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
permit=10.10.0.0/255.255.255.0
read=system,call,log,verbose,command,agent,user,originate
write=system,call,log,verbose,command,agent,user,originate

[sendcron]
secret=AmiV1c1d@l2026
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
permit=10.10.0.0/255.255.255.0
read=system,call,log,verbose,command,agent,user,originate
write=system,call,log,verbose,command,agent,user,originate'

fix_manager() {
  local HOST=$1
  local IS_LOCAL=$2

  echo "Fixing manager.conf on: $HOST"

  if [ "$IS_LOCAL" = "1" ]; then
    # Remove old wrong entries
    sed -i '/\[cronupdate\]/{N;N;N;N;N;N;N;N;d}' /etc/asterisk/manager.conf 2>/dev/null || true
    sed -i '/\[cronlisten\]/{N;N;N;N;N;N;N;N;d}' /etc/asterisk/manager.conf 2>/dev/null || true
    sed -i '/\[cronsend\]/{N;N;N;N;N;N;N;N;d}' /etc/asterisk/manager.conf 2>/dev/null || true
    # Also remove any duplicate sendcron/updatecron/listencron
    # Add correct entries
    echo "$CORRECT_BLOCK" >> /etc/asterisk/manager.conf
    asterisk -rx "manager reload"
    asterisk -rx "manager show users"
  else
    ssh -o StrictHostKeyChecking=no root@${HOST} "
      # Remove old wrong entries
      sed -i '/\[cronupdate\]/,/^\[/{ /^\[cronupdate\]/d; /^\[./b; d }' /etc/asterisk/manager.conf 2>/dev/null || true
      sed -i '/\[cronlisten\]/,/^\[/{ /^\[cronlisten\]/d; /^\[./b; d }' /etc/asterisk/manager.conf 2>/dev/null || true
      sed -i '/\[cronsend\]/,/^\[/{ /^\[cronsend\]/d; /^\[./b; d }' /etc/asterisk/manager.conf 2>/dev/null || true
      echo '$CORRECT_BLOCK' >> /etc/asterisk/manager.conf
      asterisk -rx 'manager reload'
      asterisk -rx 'manager show users'
    "
  fi
  echo "$HOST done"
}

echo "=== Fixing main server (localhost) ==="
fix_manager localhost 1

echo "=== Fixing ast1 ==="
fix_manager 10.10.0.11 0

echo "=== Fixing ast2 ==="
fix_manager 10.10.0.12 0

echo ""
echo "=== Testing AMI login with sendcron ==="
perl /tmp/test_ami.pl localhost sendcron
perl /tmp/test_ami.pl 10.10.0.11 sendcron
perl /tmp/test_ami.pl 10.10.0.12 sendcron
