-- Intertelecom SIP carrier configuration for VICIdial
-- Credentials from screenshot: IT313340 / U4fDkH0cu35V

-- Check existing record
SELECT carrier_id, carrier_name, server_ip, active FROM vicidial_server_carriers WHERE carrier_name='Intertelecom';

-- Update or insert the Intertelecom carrier
INSERT INTO vicidial_server_carriers 
  (carrier_id, carrier_name, registration_string, template_id, account_entry, protocol, dialplan_entry, server_ip, active, carrier_description, user_group)
VALUES (
  'INTERTELECOM',
  'Intertelecom',
  'register =>IT313340:U4fDkH0cu35V@sip.intertelecom.gr:5070',
  'INTERTELECOM',
  '[intertelecom]\ntype=peer\nhost=sip.intertelecom.gr\nusername=IT313340\nfromuser=IT313340\nsecret=U4fDkH0cu35V\nport=5070\ninsecure=port,invite\ndisallow=all\nallow=alaw,ulaw\ncontext=trunkinbound\nnat=yes\ntrustrpid=yes\nsendrpid=yes\nprogressinband=yes\nqualify=yes',
  'SIP',
  'exten => _9930XXXXXX.,1,AGI(agi://127.0.0.1:4577/call_log)\nexten => _9930XXXXXX.,2,Dial(SIP\/intertelecom\/${EXTEN:2},,To)\nexten => _9930XXXXXX.,3,Hangup',
  '10.10.0.10',
  'Y',
  'Intertelecom SIP Trunk - Greece',
  '---ALL---'
)
ON DUPLICATE KEY UPDATE
  carrier_name        = VALUES(carrier_name),
  registration_string = VALUES(registration_string),
  account_entry       = VALUES(account_entry),
  protocol            = VALUES(protocol),
  dialplan_entry      = VALUES(dialplan_entry),
  server_ip           = VALUES(server_ip),
  active              = VALUES(active),
  carrier_description = VALUES(carrier_description);

-- Also remove placeholder record with numeric ID 5004 if it exists and differs
DELETE FROM vicidial_server_carriers WHERE carrier_id='5004' AND carrier_name='Intertelecom';

-- Verify
SELECT carrier_id, carrier_name, server_ip, active, registration_string FROM vicidial_server_carriers WHERE carrier_name='Intertelecom';
