#!/bin/bash
cd /opt/iso-build/admin
lb binary > /tmp/iso_logs/admin_b4.log 2>&1
echo BUILD_EXIT:$? >> /tmp/iso_logs/admin_b4.log
