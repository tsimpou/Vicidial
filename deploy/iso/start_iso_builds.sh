#!/bin/bash
# start_iso_builds.sh - runs on GCP server to start both ISO builds
rm -rf /opt/iso-build/admin /opt/iso-build/agent
mkdir -p /tmp/iso_logs

nohup bash /tmp/build_admin_iso.sh > /tmp/iso_logs/admin.log 2>&1 &
ADMIN_PID=$!
echo "Admin ISO PID: $ADMIN_PID"

nohup bash /tmp/build_agent_iso.sh > /tmp/iso_logs/agent.log 2>&1 &
AGENT_PID=$!
echo "Agent ISO PID: $AGENT_PID"

echo "$ADMIN_PID" > /tmp/iso_logs/admin.pid
echo "$AGENT_PID" > /tmp/iso_logs/agent.pid

echo "Both builds started. Monitor with:"
echo "  tail -f /tmp/iso_logs/admin.log"
echo "  tail -f /tmp/iso_logs/agent.log"
