# ============================================================
# VICIdial Self-Hosted — Deployment Guide
# Google Cloud Platform | 50+ Agents | Greek SIP Trunk
# ============================================================

## Αρχιτεκτονική

```
[Agent Browsers] ──HTTPS──► [vicidial-main] 10.10.0.10 (ext IP: X.X.X.X)
                                    │ MySQL (:3306)
                             ┌──────┴──────┐
                    [vicidial-ast1]   [vicidial-ast2]
                     10.10.0.11        10.10.0.12
                             └──────┬──────┘
                                  SIP/RTP
                             [Greek SIP Provider]
```

## Βήματα Εκτέλεσης

### Βήμα 1: Εγκατάσταση gcloud CLI
Κατέβασε από: https://cloud.google.com/sdk/docs/install
Τρέξε: `gcloud auth login` και `gcloud auth application-default login`

### Βήμα 2: GCE Infrastructure
```bash
# Άνοιξε deploy/01_gce_setup.sh
# Άλλαξε: PROJECT_ID, BILLING_ACCOUNT
# Τρέξε:
bash deploy/01_gce_setup.sh
# Σημείωσε το External IP που εκτυπώνεται!
```

### Βήμα 3: Main Server Setup
```bash
# SSH στο vicidial-main:
gcloud compute ssh vicidial-main --zone=europe-west1-b

# Upload και τρέξε το script:
gcloud compute scp deploy/02_install_main.sh vicidial-main:~ --zone=europe-west1-b
ssh vicidial-main
# Άλλαξε τις μεταβλητές στην αρχή του script
nano 02_install_main.sh
bash 02_install_main.sh
```

### Βήμα 4: Asterisk Nodes Setup (παράλληλα)
```bash
# Για ast1:
gcloud compute scp deploy/03_install_asterisk_node.sh vicidial-ast1:~ --zone=europe-west1-b
gcloud compute ssh vicidial-ast1 --zone=europe-west1-b -- \
  "THIS_SERVER_IP=10.10.0.11 bash 03_install_asterisk_node.sh"

# Για ast2 (αλλαξε το IP):
gcloud compute scp deploy/03_install_asterisk_node.sh vicidial-ast2:~ --zone=europe-west1-b
gcloud compute ssh vicidial-ast2 --zone=europe-west1-b -- \
  "THIS_SERVER_IP=10.10.0.12 bash 03_install_asterisk_node.sh"
```

### Βήμα 5: Asterisk Configs
```bash
# Copy configs σε ΟΛΑ τα Asterisk servers (main + ast1 + ast2)
for HOST in vicidial-main vicidial-ast1 vicidial-ast2; do
  gcloud compute scp deploy/asterisk_configs/* ${HOST}:/etc/asterisk/ --zone=europe-west1-b
done

# ΣΗΜΑΝΤΙΚΟ: Ανοίξε /etc/asterisk/sip.conf σε κάθε server και ρύθμισε:
#   externip=YOUR_EXTERNAL_IP
#   Τα SIP provider credentials

# Ανοίξε /etc/asterisk/manager.conf και ρύθμισε:
#   secret=STRONG_PASSWORD (ίδιος σε όλους)

# Restart Asterisk παντού
for HOST in vicidial-main vicidial-ast1 vicidial-ast2; do
  gcloud compute ssh $HOST --zone=europe-west1-b -- "systemctl restart asterisk"
done
```

### Βήμα 6: Crontab
```bash
for HOST in vicidial-main vicidial-ast1 vicidial-ast2; do
  gcloud compute scp deploy/04_setup_crontab.sh ${HOST}:~ --zone=europe-west1-b
  gcloud compute ssh $HOST --zone=europe-west1-b -- "bash 04_setup_crontab.sh"
done
```

### Βήμα 7: HTTPS & Finalize
```bash
gcloud compute scp deploy/05_https_and_finalize.sh vicidial-main:~ --zone=europe-west1-b
gcloud compute ssh vicidial-main --zone=europe-west1-b -- "bash 05_https_and_finalize.sh"
```

### Βήμα 8: Manual Admin Setup (Browser)
Άνοιξε: `http://[EXTERNAL_IP]/vicidial/admin.php`
- Login: `6666` / `1234` → **Άλλαξε αμέσως!**
- Servers: Πρόσθεσε ast1 (10.10.0.11) και ast2 (10.10.0.12)
- Carriers: Πρόσθεσε SIP trunk
- Phones: Δημιούργησε extensions για agents
- Users: Δημιούργησε agent accounts
- Campaigns: Πρώτη εκστρατεία

---

## Passwords Checklist
- [ ] MySQL root: `DB_ROOT_PASS` στο `02_install_main.sh`
- [ ] MySQL vicidial user: `DB_VICIDIAL_PASS` (ίδιο σε όλα τα scripts)
- [ ] Asterisk AMI: `secret` στο `manager.conf`
- [ ] VICIdial admin: αλλαγή μετά το πρώτο login
- [ ] Agent softphone passwords: στο admin UI

## Κόστος GCE (εκτίμηση)
| VM | Τύπος | ~Μηνιαίο κόστος |
|---|---|---|
| vicidial-main | e2-standard-8 | ~$200 |
| vicidial-ast1 | e2-standard-4 | ~$100 |
| vicidial-ast2 | e2-standard-4 | ~$100 |
| Δίσκοι (SSD) | 250GB total | ~$43 |
| Egress traffic | ~500GB/μήνα | ~$50 |
| **Σύνολο** | | **~$493/μήνα** |

## Υπερέχει έναντι VsDialer γιατί:
- Πλήρης έλεγχος κώδικα + DB
- Δεν πληρώνεις per-agent license
- Μπορείς να τρέξεις σε δικό σου hardware αν θες
- 100% open source (GPLv2)

## Troubleshooting
```bash
# Έλεγχος Asterisk status
asterisk -rv

# Logs VICIdial
tail -f /var/log/astguiclient/AST_VDauto_dial.log

# MySQL connectivity test
mysql -h 10.10.0.10 -u cron -p asterisk -e "SELECT COUNT(*) FROM vicidial_users;"

# SIP trunk registration
asterisk -rx "sip show registry"

# Active calls
asterisk -rx "core show channels"
```
