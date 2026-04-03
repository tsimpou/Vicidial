#!/bin/bash
PUBKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDIaLNjiWtKrYqGqLnnhdOjrOopg9xiw1HZIetmhjcyQ+B/PnpFAXmu+TLwY8HOxj9tH+OP7Zr4wmJSm59DIIkykQ+dRxpusUm/nfkhcJUB8NL9cwUqJfU1C5DrVsKDcAwYPnt+14knG3AA0230rqXvg2W16kMfEDiTYRHDqQlOtNCQX12yVImMLKORyj2oIQ+j5CjspIRvlquR7//Qh8Bht1I8hBHlp24XRjH+MjjuAzgBOSsZF76UMBFLrW3p6sFGYstt66eHrUnc6BBckYy5VCuHL3eJKtHBH0WFoyGX9y3HMWWrf5Q2j4V/aAwCPO0SwVGui3o112+1kbqOBbhUlNtk3/zQPCZ2vq5EtdWQkZVMbXkv5oFHaYFuKVzaX7gIp4xDuX/JVTNZx4j0mD1vLow5NJ223U6YpjNwu//z+zYeMtg9PGxmui1xopF852Z0/Nuc/o51n4tRxMSH6sWdxZC6e3ZNLh8Ml+/w4LpnaM1ee8eLoQoS9bQlSYsme5xURgn5VVB88CPgRKfNFD3RxQxDe63N9OqQe2HwCYixey2PuvKA6aGP7au1WwpBc4YB9f8xaGduhiDSDpfI71wGCK58pBY+eSybn65uHmq9ysIrTfbgksuXBOwPFRGGb0l7AnjVLVWIk2wFmUKUzwGn/PxswyqB89JUOp0zECIt4w== root@vicidial-main"

echo "Adding main server SSH key to authorized_keys..."
sudo mkdir -p /root/.ssh
sudo chmod 700 /root/.ssh
echo "$PUBKEY" | sudo tee -a /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys
echo "Done. Key added."
