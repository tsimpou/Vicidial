#!/bin/bash
# ============================================================
# VICIdial HTTPS + Post-install Setup
# Run on: vicidial-main ONLY
# Sets up: Let's Encrypt SSL, SSH key exchange, recording backup
# ============================================================

set -e

# ---- EDIT THESE ----
DOMAIN="vicidial.yourdomain.com"      # Your domain pointing to external IP
ADMIN_EMAIL="admin@yourdomain.com"
EXTERNAL_IP="YOUR_EXTERNAL_IP_HERE"
GCS_BUCKET="your-recordings-bucket"  # Google Cloud Storage bucket name
AST1_IP="10.10.0.11"
AST2_IP="10.10.0.12"

echo "=== [1/5] Install Let's Encrypt (Certbot) ==="
apt-get install -y certbot python3-certbot-apache

# Only run if domain is set (not just an IP)
if [ "$DOMAIN" != "vicidial.yourdomain.com" ]; then
  certbot --apache -d $DOMAIN --non-interactive --agree-tos -m $ADMIN_EMAIL
  # Auto-renewal
  echo "0 0,12 * * * root certbot renew --quiet" >> /etc/crontab
else
  echo "SKIPPING HTTPS — set DOMAIN variable to enable. Using HTTP for now."
  echo "Agents will access via http://${EXTERNAL_IP}/agc/vicidial.php"
fi

echo "=== [2/5] Generate SSH keys for inter-server communication ==="
if [ ! -f /root/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""
fi

echo ""
echo ">>> ADD THIS KEY TO /root/.ssh/authorized_keys ON ast1 AND ast2: <<<"
cat /root/.ssh/id_rsa.pub
echo ""
echo "Run this on each Asterisk server:"
echo "  mkdir -p /root/.ssh"
echo "  echo '$(cat /root/.ssh/id_rsa.pub)' >> /root/.ssh/authorized_keys"
echo "  chmod 600 /root/.ssh/authorized_keys"
echo ""
read -p "Press ENTER after adding the key to ast1 and ast2..."

# Test SSH connectivity
echo "=== Testing SSH to Asterisk nodes ==="
ssh -o StrictHostKeyChecking=no -o BatchMode=yes root@$AST1_IP "echo 'ast1 OK'" || echo "WARNING: Cannot SSH to ast1"
ssh -o StrictHostKeyChecking=no -o BatchMode=yes root@$AST2_IP "echo 'ast2 OK'" || echo "WARNING: Cannot SSH to ast2"

echo "=== [3/5] Set up Google Cloud Storage for recordings ==="
# Install gsutil if not present
if ! command -v gsutil &> /dev/null; then
  apt-get install -y google-cloud-cli
fi

# Create bucket (if not exists)
gsutil mb -l europe-west1 gs://$GCS_BUCKET || echo "Bucket may already exist, continuing..."
gsutil lifecycle set /dev/stdin gs://$GCS_BUCKET << 'LIFECYCLE'
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 365}
    }
  ]
}
LIFECYCLE

echo "=== [4/5] Configure recording upload to GCS ==="
# Override the FTP upload script to use GCS
cat > /usr/share/astguiclient/AST_CRON_audio_3_gcs.sh <<'GCSSCRIPT'
#!/bin/bash
# Upload compressed recordings to GCS
RECORDINGS_DIR="/var/spool/asterisk/monitor"
BUCKET="gs://your-recordings-bucket"
DONE_DIR="/var/spool/asterisk/monitor/uploaded"

mkdir -p $DONE_DIR

find $RECORDINGS_DIR -maxdepth 1 -name "*.gsm" -o -name "*.mp3" -o -name "*.wav" | while read file; do
  gsutil cp "$file" "$BUCKET/$(date +%Y/%m/%d)/" && mv "$file" "$DONE_DIR/"
done
GCSSCRIPT
chmod +x /usr/share/astguiclient/AST_CRON_audio_3_gcs.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "0 */4 * * * /usr/share/astguiclient/AST_CRON_audio_3_gcs.sh >> /var/log/astguiclient/gcs_upload.log 2>&1") | crontab -

echo "=== [5/5] Initial VICIdial admin setup instructions ==="
cat <<SETUP_INSTRUCTIONS

====================================================
Post-Install Manual Steps (do in browser)
====================================================

1. Open admin panel:
   http://${EXTERNAL_IP}/vicidial/admin.php
   Default login: user=6666, pass=1234 (CHANGE IMMEDIATELY)

2. Go to: Admin > Servers
   Verify vicidial-main (10.10.0.10) is listed
   Add vicidial-ast1 (10.10.0.11) as satellite server
   Add vicidial-ast2 (10.10.0.12) as satellite server

3. Go to: Admin > Carriers
   Add new carrier:
   - Name: greek-sip-trunk
   - Server IP: same as in sip.conf
   - Dial Prefix: leave blank or set 9 if needed
   - Protocol: SIP

4. Go to: Admin > DID Numbers
   Add your inbound DID numbers (e.g. 2103000000)
   Route to inbound group or IVR

5. Go to: Admin > Phones
   Add agent softphones (Zoiper/MicroSIP)
   Use extension numbers starting from 300

6. Go to: Admin > Users
   Create agent accounts
   Assign phone extensions

7. Go to: Admin > Campaigns
   Create your first campaign:
   - Upload lead list
   - Set dial method: RATIO or PREDICTIVE
   - Set dial ratio: start with 1.5 (adj. based on answer rate)
   - Set max calls: based on agent count

8. Go to: Admin > Inbound Groups
   Create group for inbound calls
   Assign agents

REMEMBER: Change default admin password FIRST!
====================================================
SETUP_INSTRUCTIONS
