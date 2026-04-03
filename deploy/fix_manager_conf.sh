#!/bin/bash
# Fix manager.conf on all Asterisk nodes to add all required VICIdial AMI users
# Run as root on vicidial-main
# The standard VICIdial AMI usernames are: cron, cronupdate, cronlisten, cronsend

AMI_PASS="AmiV1c1d@l2026"
ALL_NODES=("127.0.0.1" "10.10.0.11" "10.10.0.12")
NODE_IPS=("10.10.0.11" "10.10.0.12")

AMI_USERS_BLOCK='
[cronupdate]
secret=AmiV1c1d@l2026
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
permit=10.10.0.0/255.255.255.0
read=system,call,log,verbose,command,agent,user,originate
write=system,call,log,verbose,command,agent,user,originate

[cronlisten]
secret=AmiV1c1d@l2026
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
permit=10.10.0.0/255.255.255.0
read=system,call,log,verbose,command,agent,user,originate
write=system,call,log,verbose,command,agent,user,originate

[cronsend]
secret=AmiV1c1d@l2026
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
permit=10.10.0.0/255.255.255.0
read=system,call,log,verbose,command,agent,user,originate
write=system,call,log,verbose,command,agent,user,originate'

echo "=== Fixing main server manager.conf ==="
echo "$AMI_USERS_BLOCK" >> /etc/asterisk/manager.conf
asterisk -rx "manager reload"
echo "Main server: done"

for NODE_IP in "${NODE_IPS[@]}"; do
  echo "=== Fixing $NODE_IP manager.conf ==="
  ssh -o StrictHostKeyChecking=no root@${NODE_IP} "
    cat >> /etc/asterisk/manager.conf << 'ENDBLOCK'
${AMI_USERS_BLOCK}
ENDBLOCK
    asterisk -rx 'manager reload'
    asterisk -rx 'manager show users'
  "
  echo "$NODE_IP: done"
done

echo ""
echo "=== Verifying AMI authentication ==="
sleep 2
perl -e "
use Net::Telnet;
for my \$host ('127.0.0.1', '10.10.0.11', '10.10.0.12') {
  my \$t = new Net::Telnet(Timeout=>5, Errmode=>'return');
  \$t->open(\$host, 5038);
  \$t->waitfor('/Asterisk Call Manager\//');
  my \$ver = \$t->getline(Errmode=>'return', Timeout=>1);
  \$t->print('Action: Login\nUsername: cronsend\nSecret: ${AMI_PASS}\n');
  my \$r = \$t->waitfor('/Authentication accepted/', Errmode=>'return', Timeout=>5);
  print \"\$host: \", \$r ? 'AUTH OK' : 'AUTH FAILED', \"\n\";
  \$t->close();
}
"
