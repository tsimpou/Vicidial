#!/bin/bash
# ============================================================
# VICIdial GCE Infrastructure Setup
# Run this from your local machine AFTER gcloud auth login
# Edit the variables below before running
# ============================================================

# ---- EDIT THESE ----
PROJECT_ID="vicidial-prod"          # GCE Project ID (lowercase, hyphens ok)
REGION="europe-west1"               # Belgium - closest to Greece with good latency
ZONE="europe-west1-b"
BILLING_ACCOUNT=""                  # Leave empty if already set via console

# ---- DO NOT EDIT BELOW (unless you know what you're doing) ----
VPC_NAME="vicidial-vpc"
SUBNET_NAME="vicidial-subnet"
SUBNET_RANGE="10.10.0.0/24"

echo "=== Step 1: Create project ==="
gcloud projects create $PROJECT_ID --name="VICIdial Production"
gcloud config set project $PROJECT_ID

# Link billing if provided
if [ -n "$BILLING_ACCOUNT" ]; then
  gcloud billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT
fi

# Enable required APIs
echo "=== Step 2: Enable APIs ==="
gcloud services enable compute.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com

echo "=== Step 3: Create VPC network ==="
gcloud compute networks create $VPC_NAME \
  --subnet-mode=custom \
  --bgp-routing-mode=regional

gcloud compute networks subnets create $SUBNET_NAME \
  --network=$VPC_NAME \
  --region=$REGION \
  --range=$SUBNET_RANGE

echo "=== Step 4: Create firewall rules ==="

# SSH - only from your admin IPs (EDIT THIS IP)
gcloud compute firewall-rules create allow-ssh-admin \
  --network=$VPC_NAME \
  --direction=INGRESS \
  --priority=1000 \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=vicidial-server
# NOTE: Replace 0.0.0.0/0 with your static office IP for better security

# HTTP/HTTPS for agent web interface
gcloud compute firewall-rules create allow-web \
  --network=$VPC_NAME \
  --direction=INGRESS \
  --priority=1000 \
  --action=ALLOW \
  --rules=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=vicidial-web

# SIP from Greek provider (UPDATE with actual provider IP range)
gcloud compute firewall-rules create allow-sip \
  --network=$VPC_NAME \
  --direction=INGRESS \
  --priority=1000 \
  --action=ALLOW \
  --rules=udp:5060,tcp:5060 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=vicidial-asterisk
# NOTE: Replace 0.0.0.0/0 with your SIP provider's IP range

# RTP voice ports
gcloud compute firewall-rules create allow-rtp \
  --network=$VPC_NAME \
  --direction=INGRESS \
  --priority=1000 \
  --action=ALLOW \
  --rules=udp:10000-20000 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=vicidial-asterisk

# Internal: all traffic between VICIdial servers
gcloud compute firewall-rules create allow-internal \
  --network=$VPC_NAME \
  --direction=INGRESS \
  --priority=1000 \
  --action=ALLOW \
  --rules=all \
  --source-ranges=$SUBNET_RANGE

echo "=== Step 5: Reserve static external IP for main server ==="
gcloud compute addresses create vicidial-main-ip \
  --region=$REGION

EXTERNAL_IP=$(gcloud compute addresses describe vicidial-main-ip --region=$REGION --format="get(address)")
echo "External IP for vicidial-main: $EXTERNAL_IP"
echo ">>> Write this down! You need it for SIP provider registration <<<"

echo "=== Step 6: Create VMs ==="

# Main server: Web + MySQL
gcloud compute instances create vicidial-main \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=e2-standard-8 \
  --network=$VPC_NAME \
  --subnet=$SUBNET_NAME \
  --private-network-ip=10.10.0.10 \
  --address=$EXTERNAL_IP \
  --boot-disk-size=150GB \
  --boot-disk-type=pd-ssd \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --tags=vicidial-server,vicidial-web \
  --metadata=startup-script='#!/bin/bash
    apt-get update -y
    hostnamectl set-hostname vicidial-main'

# Asterisk server 1
gcloud compute instances create vicidial-ast1 \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=e2-standard-4 \
  --network=$VPC_NAME \
  --subnet=$SUBNET_NAME \
  --private-network-ip=10.10.0.11 \
  --no-address \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-ssd \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --tags=vicidial-server,vicidial-asterisk \
  --metadata=startup-script='#!/bin/bash
    apt-get update -y
    hostnamectl set-hostname vicidial-ast1'

# Asterisk server 2
gcloud compute instances create vicidial-ast2 \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=e2-standard-4 \
  --network=$VPC_NAME \
  --subnet=$SUBNET_NAME \
  --private-network-ip=10.10.0.12 \
  --no-address \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-ssd \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --tags=vicidial-server,vicidial-asterisk \
  --metadata=startup-script='#!/bin/bash
    apt-get update -y
    hostnamectl set-hostname vicidial-ast2'

echo ""
echo "======================================================"
echo "Infrastructure created!"
echo "Main server external IP: $EXTERNAL_IP"
echo "Internal IPs:"
echo "  vicidial-main : 10.10.0.10"
echo "  vicidial-ast1 : 10.10.0.11"
echo "  vicidial-ast2 : 10.10.0.12"
echo ""
echo "NEXT STEP: Run 02_install_main.sh on vicidial-main"
echo "======================================================"
