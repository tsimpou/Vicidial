#!/bin/bash
# intertelecom_setup.sh
# Run on vicidial-main to apply Intertelecom SIP trunk
# Usage: sudo bash /tmp/intertelecom_setup.sh

set -u

MAIN_IP="10.10.0.10"
AMI_PASS="AmiV1c1d@l2026"

echo "=== [1/4] Updating VICIdial DB carrier record ==="
mysql asterisk << 'SQLEOF'
INSERT INTO vicidial_server_carriers
  (carrier_id, carrier_name, registration_string, template_id, account_entry, protocol, dialplan_entry, server_ip, active, carrier_description, user_group)
VALUES (
  'INTERTELECOM',
  'Intertelecom',
  'register =>IT313340:U4fDkH0cu35V@sip.intertelecom.gr:5070',
  'INTERTELECOM',
  '[intertelecom]\ntype=peer\nhost=sip.intertelecom.gr\nusername=IT313340\nfromuser=IT313340\nsecret=U4fDkH0cu35V\nport=5070\ninsecure=port,invite\ndisallow=all\nallow=alaw,ulaw\ncontext=trunkinbound\nnat=yes\ntrustrpid=yes\nsendrpid=yes\nprogressinband=yes\nqualify=yes',
  'SIP',
  'exten => _9930XXXXXX.,1,AGI(agi://127.0.0.1:4577/call_log)\nexten => _9930XXXXXX.,2,Dial(SIP/intertelecom/${EXTEN:2},,To)\nexten => _9930XXXXXX.,3,Hangup',
  '10.10.0.10',
  'Y',
  'Intertelecom SIP Trunk - Greece',
  '---ALL---'
)
ON DUPLICATE KEY UPDATE
  registration_string = VALUES(registration_string),
  account_entry       = VALUES(account_entry),
  dialplan_entry      = VALUES(dialplan_entry),
  active              = VALUES(active);

-- Remove old numeric-ID placeholder if present
DELETE FROM vicidial_server_carriers WHERE carrier_id='5004';

SELECT carrier_id, carrier_name, active, registration_string FROM vicidial_server_carriers WHERE carrier_name='Intertelecom';
SQLEOF

echo ""
echo "=== [2/4] Writing sip.conf peer entry ==="

# Backup
cp /etc/asterisk/sip.conf /etc/asterisk/sip.conf.bak.$(date +%Y%m%d%H%M%S)

# Remove old intertelecom block if exists, then append fresh
python3 - << 'PYEOF'
import re, sys

with open('/etc/asterisk/sip.conf', 'r') as f:
    content = f.read()

# Remove existing [intertelecom] block
content = re.sub(r'\[intertelecom\][^\[]*', '', content, flags=re.DOTALL)

# Remove existing register line for intertelecom
lines = [l for l in content.splitlines() if 'intertelecom.gr' not in l]
content = '\n'.join(lines)

# Add register line in [general] section
if 'register =>IT313340' not in content:
    content = re.sub(
        r'(\[general\][^\[]*)',
        lambda m: m.group(0).rstrip() + '\nregister =>IT313340:U4fDkH0cu35V@sip.intertelecom.gr:5070\n',
        content,
        count=1,
        flags=re.DOTALL
    )

peer_block = """
; --- Intertelecom SIP Trunk ---
[intertelecom]
type=peer
host=sip.intertelecom.gr
username=IT313340
fromuser=IT313340
secret=U4fDkH0cu35V
port=5070
insecure=port,invite
disallow=all
allow=alaw,ulaw
context=trunkinbound
nat=yes
trustrpid=yes
sendrpid=yes
progressinband=yes
qualify=yes
; --- end Intertelecom ---
"""

content = content.rstrip() + '\n' + peer_block

with open('/etc/asterisk/sip.conf', 'w') as f:
    f.write(content)

print("sip.conf updated OK")
PYEOF

echo ""
echo "=== [3/4] Writing extensions.conf dialplan for trunkinbound + outbound ==="

python3 - << 'PYEOF'
import re

with open('/etc/asterisk/extensions.conf', 'r') as f:
    content = f.read()

# Build the dialplan blocks
trunkinbound_block = """
; --- Intertelecom inbound ---
[trunkinbound]
exten => _X.,1,Answer()
exten => _X.,2,AGI(agi://127.0.0.1:4577/call_log)
exten => _X.,3,Goto(default,${EXTEN},1)
"""

outbound_block = """
; --- Intertelecom outbound (prefix 99 + 30XXXXXXXXX) ---
exten => _9930XXXXXX.,1,AGI(agi://127.0.0.1:4577/call_log)
exten => _9930XXXXXX.,2,Dial(SIP/intertelecom/${EXTEN:2},,To)
exten => _9930XXXXXX.,3,Hangup
"""

# Remove old entries
content = re.sub(r'; --- Intertelecom inbound ---\[trunkinbound\][^\[]*', '', content, flags=re.DOTALL)
content = re.sub(r'; --- Intertelecom outbound[^\n]*\n(exten => _9930[^\n]*\n){3}', '', content, flags=re.DOTALL)

# Add trunkinbound context if not present
if '[trunkinbound]' not in content:
    content = content.rstrip() + '\n' + trunkinbound_block

# Add outbound dialplan to [default] context
if '_9930XXXXXX.' not in content:
    content = re.sub(
        r'(\[default\][^\[]*)',
        lambda m: m.group(0).rstrip() + '\n' + outbound_block.strip() + '\n',
        content,
        count=1,
        flags=re.DOTALL
    )

with open('/etc/asterisk/extensions.conf', 'w') as f:
    f.write(content)

print("extensions.conf updated OK")
PYEOF

echo ""
echo "=== [4/4] Reloading Asterisk SIP + dialplan ==="
asterisk -rx "sip reload"
sleep 2
asterisk -rx "dialplan reload"
sleep 2

echo ""
echo "=== Checking SIP registration status ==="
asterisk -rx "sip show registry"

echo ""
echo "=== Checking intertelecom peer ==="
asterisk -rx "sip show peer intertelecom"

echo ""
echo "=== INTERTELECOM SETUP COMPLETE ==="
