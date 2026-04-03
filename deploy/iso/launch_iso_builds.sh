#!/bin/bash
# =================================================================
# launch_iso_builds.sh
# Master script to start BOTH ISO builds on the GCP server
#
# Run from your LOCAL machine from the deploy/iso/ directory:
#   cd C:\Users\User\Vicidial\deploy\iso
#   bash launch_iso_builds.sh
#
# Or in PowerShell:
#   cd C:\Users\User\Vicidial\deploy\iso
#   bash launch_iso_builds.sh
#
# After builds complete, download:
#   gcloud compute scp vicidial-main:/opt/vicidial-isos/vicidial-admin.iso .
#   gcloud compute scp vicidial-main:/opt/vicidial-isos/vicidial-agent.iso .
# =================================================================

GCLOUD="$LOCALAPPDATA/Google/Cloud SDK/google-cloud-sdk/bin/gcloud"
PROJECT="vicidial-prod-2026"
ZONE="europe-west1-b"
SERVER="vicidial-main"

SCP="$GCLOUD compute scp --zone=$ZONE --project=$PROJECT"
SSH="$GCLOUD compute ssh $SERVER --zone=$ZONE --project=$PROJECT"

echo "=== Uploading ISO build scripts to $SERVER ==="
$SCP build_admin_iso.sh ${SERVER}:/tmp/build_admin_iso.sh
$SCP build_agent_iso.sh ${SERVER}:/tmp/build_agent_iso.sh

echo "=== Starting ADMIN ISO build in background ==="
$SSH "--command=nohup sudo bash /tmp/build_admin_iso.sh > /tmp/admin_iso_build.log 2>&1 & echo Built PID:\$!"

echo ""
echo "=== Starting AGENT ISO build in background ==="
$SSH "--command=nohup sudo bash /tmp/build_agent_iso.sh > /tmp/agent_iso_build.log 2>&1 & echo Agent PID:\$!"

echo ""
echo "=== Builds started in background ==="
echo ""
echo "Monitor progress:"
echo "  gcloud compute ssh $SERVER --zone=$ZONE --project=$PROJECT --command='sudo tail -20 /tmp/admin_iso_build.log'"
echo "  gcloud compute ssh $SERVER --zone=$ZONE --project=$PROJECT --command='sudo tail -20 /tmp/agent_iso_build.log'"
echo ""
echo "When complete, download ISOs:"
echo "  gcloud compute scp $SERVER:/opt/vicidial-isos/vicidial-admin.iso ."
echo "  gcloud compute scp $SERVER:/opt/vicidial-isos/vicidial-agent.iso ."
