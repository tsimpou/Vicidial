#!/bin/bash
# ============================================================
# VICIdial Crontab Setup
# Run on ALL servers (main + ast1 + ast2)
# Installs the required cron jobs for VICIdial to function
#
# Usage: bash 04_setup_crontab.sh
# ============================================================

set -e

SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Setting up crontab for server: $SERVER_IP"

# VICIdial scripts path (set by install.pl)
VICI_PATH="/usr/share/astguiclient"

# Ensure log directory exists
mkdir -p /var/log/astguiclient

# Write crontab for root
crontab -l 2>/dev/null > /tmp/vicidial_cron || true

cat >> /tmp/vicidial_cron <<'CRONEOF'
# ============================================================
# VICIdial Required Cron Jobs
# ============================================================

# System time sync check (every 5 min)
*/5 * * * * /usr/sbin/ntpdate -u pool.ntp.org > /dev/null 2>&1

# --- KEEPALIVE SCRIPTS (run every minute) ---
# Auto-dialer daemon keepalive
* * * * * /usr/bin/perl /usr/share/astguiclient/AST_VDauto_dial.pl --keepalive >> /var/log/astguiclient/AST_VDauto_dial.log 2>&1
# Conference update
* * * * * /usr/bin/perl /usr/share/astguiclient/AST_conf_update.pl --keepalive >> /var/log/astguiclient/AST_conf_update.log 2>&1
# Keepalive all scripts
* * * * * /usr/bin/perl /usr/share/astguiclient/ADMIN_keepalive_ALL.pl >> /var/log/astguiclient/ADMIN_keepalive.log 2>&1

# --- AGENT STATS (every minute) ---
* * * * * /usr/bin/perl /usr/share/astguiclient/AST_agent_day.pl >> /var/log/astguiclient/AST_agent_day.log 2>&1

# --- CLEANUP SCRIPTS (every hour) ---
0 * * * * /usr/bin/perl /usr/share/astguiclient/AST_cleanup_agent_log.pl >> /var/log/astguiclient/cleanup.log 2>&1

# --- DATABASE MAINTENANCE ---
# Dead callback purge (daily at 2am)
0 2 * * * /usr/bin/perl /usr/share/astguiclient/AST_DB_dead_cb_purge.pl >> /var/log/astguiclient/dead_cb.log 2>&1
# Database optimize (Sunday at 3am)
0 3 * * 0 /usr/bin/perl /usr/share/astguiclient/AST_DB_optimize.pl >> /var/log/astguiclient/db_optimize.log 2>&1
# GMT offset update (daily at midnight)
0 0 * * * /usr/bin/perl /usr/share/astguiclient/ADMIN_adjust_GMTnow_on_leads.pl >> /var/log/astguiclient/gmt_adjust.log 2>&1

# --- RECORDING MANAGEMENT ---
# Move recordings for compression (every 2 hours)
0 */2 * * * /usr/bin/perl /usr/share/astguiclient/AST_CRON_audio_1_move_mix.pl >> /var/log/astguiclient/audio_move.log 2>&1
# Compress recordings (every 3 hours, offset by 30min)
30 */3 * * * /usr/bin/perl /usr/share/astguiclient/AST_CRON_audio_2_compress.pl >> /var/log/astguiclient/audio_compress.log 2>&1

# --- INBOUND CALL TIME CHECKS ---
* * * * * /usr/bin/perl /usr/share/astguiclient/AST_VDauto_dial.pl --inbound_check >> /var/log/astguiclient/inbound_check.log 2>&1

# --- LOG ROTATION (daily at 4am) ---
0 4 * * * /usr/bin/perl /usr/share/astguiclient/ADMIN_restart_roll_logs.pl >> /var/log/astguiclient/roll_logs.log 2>&1

CRONEOF

crontab /tmp/vicidial_cron
rm /tmp/vicidial_cron

echo "Crontab installed. Verifying:"
crontab -l | grep -v "^#" | grep -v "^$"

echo ""
echo "======================================================"
echo "Crontab setup COMPLETE for $SERVER_IP"
echo "======================================================"
