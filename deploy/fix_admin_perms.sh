#!/bin/bash
echo "=== Admin User 6666 Permissions ==="
sudo mysql -u root asterisk -e "SELECT user,pass,user_level,user_group,vicidial_admin FROM vicidial_users WHERE user='6666';" 2>/dev/null

echo ""
echo "=== Admin User Group ==="
sudo mysql -u root asterisk -e "SELECT user_group,add_campaigns FROM vicidial_user_groups WHERE user_group=(SELECT user_group FROM vicidial_users WHERE user='6666');" 2>/dev/null

echo ""
echo "=== Fixing admin user 6666: full permissions ==="
sudo mysql -u root asterisk -e "
UPDATE vicidial_users SET 
  user_level=9,
  user_group='ADMIN',
  vicidial_admin='Y'
WHERE user='6666';" 2>/dev/null

# Make sure ADMIN group has all campaign permissions
sudo mysql -u root asterisk -e "
UPDATE vicidial_user_groups SET 
  add_campaigns='Y',
  delete_campaigns='Y',
  modify_campaigns='Y'
WHERE user_group='ADMIN';" 2>/dev/null

echo "Done - verify:"
sudo mysql -u root asterisk -e "SELECT user,user_level,user_group,vicidial_admin FROM vicidial_users WHERE user='6666';" 2>/dev/null
sudo mysql -u root asterisk -e "SELECT user_group,add_campaigns,delete_campaigns,modify_campaigns FROM vicidial_user_groups WHERE user_group='ADMIN';" 2>/dev/null
