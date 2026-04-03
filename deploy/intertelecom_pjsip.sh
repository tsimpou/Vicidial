#!/bin/bash
# intertelecom_pjsip.sh
# Configure Intertelecom as PJSIP trunk on vicidial-main
# Run as: sudo bash /tmp/intertelecom_pjsip.sh

set -u

echo "=== [1/4] Updating VICIdial DB carrier (protocol=PJSIP) ==="
mysql asterisk << 'SQLEOF'
INSERT INTO vicidial_server_carriers
  (carrier_id, carrier_name, registration_string, template_id, account_entry, protocol,
   globals_string, dialplan_entry, server_ip, active, carrier_description, user_group)
VALUES (
  'INTERTELECOM',
  'Intertelecom',
  '',
  'INTERTELECOM',
  '',
  'PJSIP',
  '',
  'exten => _9930XXXXXX.,1,AGI(agi://127.0.0.1:4577/call_log)\nexten => _9930XXXXXX.,2,Dial(PJSIP/${EXTEN:2}@intertelecom,,To)\nexten => _9930XXXXXX.,3,Hangup',
  '10.10.0.10',
  'Y',
  'Intertelecom SIP Trunk - Greece',
  '---ALL---'
)
ON DUPLICATE KEY UPDATE
  registration_string = VALUES(registration_string),
  account_entry       = VALUES(account_entry),
  protocol            = VALUES(protocol),
  dialplan_entry      = VALUES(dialplan_entry),
  active              = VALUES(active);

DELETE FROM vicidial_server_carriers WHERE carrier_id='5004';

SELECT carrier_id, carrier_name, protocol, active FROM vicidial_server_carriers WHERE carrier_name='Intertelecom';
SQLEOF

echo ""
echo "=== [2/4] Writing Intertelecom PJSIP config ==="

# Remove any old intertelecom include
sed -i '/^#include.*intertelecom/d' /etc/asterisk/pjsip.conf

# Write the intertelecom trunk file
cat > /etc/asterisk/pjsip_intertelecom.conf << 'PJSIPEOF'
; ============================================================
; Intertelecom SIP Trunk (PJSIP)
; IT313340 @ sip.intertelecom.gr:5070
; ============================================================

; --- Auth ---
[intertelecom-auth]
type=auth
auth_type=userpass
username=IT313340
password=U4fDkH0cu35V

; --- AOR (Address of Record) ---
[intertelecom-aor]
type=aor
contact=sip:sip.intertelecom.gr:5070
qualify_frequency=30

; --- Endpoint ---
[intertelecom]
type=endpoint
context=trunkinbound
transport=transport-udp
disallow=all
allow=alaw
allow=ulaw
outbound_auth=intertelecom-auth
aors=intertelecom-aor
from_user=IT313340
from_domain=sip.intertelecom.gr
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
trust_id_inbound=yes
send_rpid=yes
send_pai=yes

; --- Outbound Registration ---
[intertelecom-reg]
type=registration
transport=transport-udp
outbound_auth=intertelecom-auth
server_uri=sip:sip.intertelecom.gr:5070
client_uri=sip:IT313340@sip.intertelecom.gr:5070
retry_interval=60
max_retries=10
contact_user=IT313340
expiration=3600
PJSIPEOF

# Add include to pjsip.conf if not already there
if ! grep -q 'pjsip_intertelecom.conf' /etc/asterisk/pjsip.conf; then
  echo '' >> /etc/asterisk/pjsip.conf
  echo '#include pjsip_intertelecom.conf' >> /etc/asterisk/pjsip.conf
  echo "Added #include to pjsip.conf"
else
  echo "#include already present"
fi

echo ""
echo "=== [3/4] Updating extensions.conf dialplan ==="

python3 - << 'PYEOF'
import re

with open('/etc/asterisk/extensions.conf', 'r') as f:
    content = f.read()

# Remove old SIP/intertelecom entries
content = re.sub(r'.*SIP/intertelecom.*\n', '', content)

# Remove old PJSIP outbound entries for intertelecom
content = re.sub(
    r'; --- Intertelecom outbound[^\n]*\n(exten => _9930[^\n]*\n)+',
    '',
    content,
    flags=re.DOTALL
)

outbound = """
; --- Intertelecom outbound (prefix 99+30XXXXXXXXX -> PJSIP) ---
exten => _9930XXXXXX.,1,AGI(agi://127.0.0.1:4577/call_log)
exten => _9930XXXXXX.,2,Dial(PJSIP/${EXTEN:2}@intertelecom,,To)
exten => _9930XXXXXX.,3,Hangup
"""

trunkinbound = """
; --- Intertelecom inbound ---
[trunkinbound]
exten => _X.,1,Answer()
exten => _X.,2,AGI(agi://127.0.0.1:4577/call_log)
exten => _X.,3,Goto(default,${EXTEN},1)
"""

# Add trunkinbound if missing
if '[trunkinbound]' not in content:
    content = content.rstrip() + '\n' + trunkinbound

# Add outbound in [default]
if '_9930XXXXXX.' not in content:
    if '[default]' in content:
        content = re.sub(
            r'(\[default\][^\[]*)',
            lambda m: m.group(0).rstrip() + '\n' + outbound.strip() + '\n',
            content,
            count=1,
            flags=re.DOTALL
        )
    else:
        content += '\n[default]\n' + outbound.strip() + '\n'

with open('/etc/asterisk/extensions.conf', 'w') as f:
    f.write(content)

print("extensions.conf updated OK")
PYEOF

echo ""
echo "=== [4/4] Reloading Asterisk PJSIP + dialplan ==="
asterisk -rx "module reload res_pjsip.so"
sleep 3
asterisk -rx "module reload res_pjsip_registrar.so"
sleep 1
asterisk -rx "dialplan reload"
sleep 2

echo ""
echo "=== PJSIP registration status ==="
asterisk -rx "pjsip show registrations"

echo ""
echo "=== PJSIP endpoint status ==="
asterisk -rx "pjsip show endpoint intertelecom"

echo ""
echo "=== INTERTELECOM PJSIP SETUP COMPLETE ==="
