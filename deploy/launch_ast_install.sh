#!/bin/bash
# Wrapper to launch install in background
nohup sudo bash /home/User/install_ast_node.sh "$1" "$2" "$3" > /home/User/ast_install.log 2>&1 &
echo $! > /home/User/ast_install.pid
echo "Install started with PID $(cat /home/User/ast_install.pid)"
sleep 3
echo "First few log lines:"
head -5 /home/User/ast_install.log 2>/dev/null || echo "Log not created yet"
