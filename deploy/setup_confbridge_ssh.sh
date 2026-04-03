#!/bin/bash
# Setup confbridge.conf for VICIdial
# Also setup SSH key exchange between servers

echo "=== Creating confbridge.conf ==="
cat > /etc/asterisk/confbridge.conf << 'CONF'
; ============================================================
; confbridge.conf - for VICIdial
; ============================================================

[general]

; Default user profile for agents
[default_user]
type=user
music_on_hold_when_empty=yes
music_on_hold_class=default
announce_user_count=no
announce_only_user=no
quiet=yes
dtmf_passthrough=yes

; Admin user profile (for monitoring)
[admin_user]
type=user
admin=yes
music_on_hold_when_empty=yes
quiet=yes
dtmf_passthrough=yes

; Default bridge profile
[default_bridge]
type=bridge
max_members=10
record_conference=no
internal_sample_rate=auto
mixing_interval=20
video_mode=none
CONF

echo "confbridge.conf written"
sudo asterisk -rx "module reload app_confbridge.so" 2>/dev/null || true

echo ""
echo "=== Creating SSH keys for inter-server communication ==="
# Generate SSH key if not exists
if [ ! -f /root/.ssh/id_rsa ]; then
    sudo ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
    echo "SSH key generated"
fi

sudo cat /root/.ssh/id_rsa.pub
echo ""
echo "Public key above — copy it to authorized_keys on ast1 and ast2"

echo ""
echo "=== Also check AMI connection to Asterisk ==="
# Test AMI
(echo -e "Action: Login\r\nUsername: cron\r\nSecret: AmiV1c1d@l2026\r\n\r\nAction: Command\r\nCommand: core show version\r\n\r\n"; sleep 2) | nc localhost 5038 | head -20
