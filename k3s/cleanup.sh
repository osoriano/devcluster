#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "$0")"

echo "Backing up data"
./backups/backup.sh

echo "Uninstalling cluster"
/usr/local/bin/k3s-uninstall.sh

# Reset firewall. Cilium currently fails to reconcile with the old rules present after uninstalling k3s
# References:
# - https://serverfault.com/questions/200635/best-way-to-clear-all-iptables-rules
# - https://www.digitalocean.com/community/tutorials/a-deep-dive-into-iptables-and-netfilter-architecture
echo "Resetting iptables"
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -F
sudo iptables -X

sudo ip6tables -P INPUT ACCEPT
sudo ip6tables -P FORWARD ACCEPT
sudo ip6tables -P OUTPUT ACCEPT
sudo ip6tables -t nat -F
sudo ip6tables -t mangle -F
sudo ip6tables -F
sudo ip6tables -X
