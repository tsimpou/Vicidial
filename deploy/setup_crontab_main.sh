#!/bin/bash
# Setup VICIdial crontab on main server (has web + asterisk)

CRONTAB_CONTENT='### VICIDIAL keepalive scripts
* * * * * /usr/share/astguiclient/ADMIN_keepalive_ALL.pl >> /var/log/astguiclient/ADMIN_keepalive_ALL.log 2>&1
* * * * * /usr/share/astguiclient/AST_conf_update.pl >> /var/log/astguiclient/AST_conf_update.log 2>&1
* * * * * /usr/share/astguiclient/ADMIN_keepalive_ALL.pl --GSM >> /var/log/astguiclient/ADMIN_keepalive_ALL_GSM.log 2>&1

### VICIdial auto-dialer
* * * * * /usr/share/astguiclient/AST_VDauto_dial.pl >> /var/log/astguiclient/AST_VDauto_dial.log 2>&1

### Inbound calls to VICIdial
* * * * * /usr/share/astguiclient/AST_VDauto_dial_INBOUND.pl >> /var/log/astguiclient/AST_VDauto_dial_INBOUND.log 2>&1

### Agent log cleanup
*/5 * * * * /usr/share/astguiclient/AST_cleanup_agent_log.pl >> /var/log/astguiclient/AST_cleanup_agent_log.log 2>&1

### Hopper loader (fills call queue)
* * * * * /usr/share/astguiclient/AST_VDhopper_check.pl >> /var/log/astguiclient/AST_VDhopper_check.log 2>&1

### Statistics update
*/5 * * * * /usr/share/astguiclient/AST_agent_day.pl >> /var/log/astguiclient/AST_agent_day.log 2>&1

### DB optimization (weekly Sunday 3am)
0 3 * * 0 /usr/share/astguiclient/AST_DB_optimize.pl >> /var/log/astguiclient/AST_DB_optimize.log 2>&1

### Archive log tables (daily 2am)
0 2 * * * /usr/share/astguiclient/ADMIN_archive_log_tables.pl >> /var/log/astguiclient/ADMIN_archive_log_tables.log 2>&1

### Timeclock auto logout (hourly)
0 * * * * /usr/share/astguiclient/ADMIN_timeclock_auto_logout.pl >> /var/log/astguiclient/ADMIN_timeclock_auto_logout.log 2>&1

### Dead callback purge (daily 4am)
0 4 * * * /usr/share/astguiclient/AST_DB_dead_cb_purge.pl >> /var/log/astguiclient/AST_DB_dead_cb_purge.log 2>&1

### Audio recording compression and upload
*/5 * * * * /usr/share/astguiclient/AST_CRON_audio_1_move_mix.pl >> /var/log/astguiclient/AST_CRON_audio_1.log 2>&1
'

# Create the log directory
sudo mkdir -p /var/log/astguiclient
sudo chmod 777 /var/log/astguiclient

# Install the crontab for root
echo "$CRONTAB_CONTENT" | sudo crontab -
echo "Crontab installed:"
sudo crontab -l
