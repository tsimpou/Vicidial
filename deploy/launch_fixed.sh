#!/bin/bash
cp /tmp/install_ast_node_new.sh /root/install_ast_node.sh
nohup bash /root/install_ast_node.sh "$1" "$2" "$3" > /root/ast_install.log 2>&1 &
echo "Launched PID $!"