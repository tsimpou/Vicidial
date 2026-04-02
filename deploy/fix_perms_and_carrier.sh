#!/bin/bash
echo "=== Setting full admin permissions for user 6666 ==="

sudo mysql -u root asterisk << 'SQL'
UPDATE vicidial_users SET 
  delete_users='1',
  delete_user_groups='1',
  delete_lists='1',
  delete_campaigns='1',
  delete_ingroups='1',
  delete_remote_agents='1',
  load_leads='1',
  campaign_detail='1',
  ast_admin_access='1',
  ast_delete_phones='1',
  delete_scripts='1',
  modify_leads='1',
  hotkeys_active='1',
  change_agent_campaign='1',
  vicidial_recording='1',
  vicidial_transfers='1',
  delete_filters='1',
  alter_agent_interface_options='1',
  delete_call_times='1',
  modify_call_times='1',
  modify_users='1',
  modify_campaigns='1',
  modify_lists='1',
  modify_scripts='1',
  modify_filters='1',
  modify_ingroups='1',
  modify_usergroups='1',
  modify_remoteagents='1',
  modify_servers='1',
  view_reports='1',
  modify_inbound_dids='1',
  delete_inbound_dids='1',
  download_lists='1',
  export_reports='1',
  delete_from_dnc='1',
  modify_shifts='1',
  modify_phones='1',
  modify_carriers='1',
  modify_labels='1',
  modify_statuses='1',
  modify_voicemail='1',
  modify_audiostore='1',
  modify_moh='1',
  modify_tts='1',
  modify_contacts='1',
  modify_email_accounts='1',
  access_recordings='1',
  modify_colors='1',
  modify_auto_reports='1',
  modify_ip_lists='1',
  ignore_ip_list='1',
  modify_custom_dialplans='1',
  modify_languages='1',
  user_level=9
WHERE user='6666';
SQL

echo "Done. Verifying:"
sudo mysql -u root asterisk -e "SELECT user,user_level,modify_campaigns,delete_campaigns,modify_servers,modify_carriers FROM vicidial_users WHERE user='6666';"

echo ""
echo "=== Setting up Intertelecom SIP trunk ==="
# Add Intertelecom as a PJSIP carrier in VICIdial
# Carrier will appear in Admin -> Carriers
sudo mysql -u root asterisk << 'SQL2'
INSERT IGNORE INTO vicidial_server_carriers 
  (carrier_id, carrier_name, active, server_ip, protocol, registration_string, 
   account_entry, globals_string, dialplan_entry, template_id, carrier_description)
VALUES 
  ('INTERTELECOM', 'Intertelecom Greece', 'Y', '0.0.0.0', 'PJSIP',
   '',
   '[intertelecom-trunk]\ntype=endpoint\ncontext=default\ndisallow=all\nallow=ulaw\nallow=alaw\noutbound_auth=intertelecom-auth\naors=intertelecom-aor\ntransport=transport-udp\nfrom_domain=REPLACE_WITH_INTERTELECOM_HOST\n\n[intertelecom-auth]\ntype=auth\nauth_type=userpass\nusername=REPLACE_WITH_USERNAME\npassword=REPLACE_WITH_PASSWORD\n\n[intertelecom-aor]\ntype=aor\ncontact=sip:REPLACE_WITH_INTERTELECOM_HOST\nqualify_frequency=30\n\n[intertelecom-reg]\ntype=registration\ntransport=transport-udp\noutbound_auth=intertelecom-auth\nserver_uri=sip:REPLACE_WITH_INTERTELECOM_HOST\nclient_uri=sip:REPLACE_WITH_USERNAME@REPLACE_WITH_INTERTELECOM_HOST\nretry_interval=60',
   '',
   'exten => _X.,1,Dial(PJSIP/${EXTEN}@intertelecom-trunk)',
   '',
   'Intertelecom Greece SIP trunk - configure username/password in admin panel');
SQL2

echo "Carrier added. Verify:"
sudo mysql -u root asterisk -e "SELECT carrier_id, carrier_name, active, protocol FROM vicidial_server_carriers;"
