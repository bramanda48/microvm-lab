#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

PHYS_IF="eth0"
TAP_DEV="microvm0"
TAP_IP_ADDRESS="172.20.0.1"
TAP_SUBNET_CIDR="24"

if ip link show "$TAP_DEV" > /dev/null 2>&1; then
  echo "Interface $TAP_DEV already created."
  ifconfig "$TAP_DEV"
  exit 1
fi

# Enable IP Forwarding
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# Create TAP interface
ip tuntap add dev "$TAP_DEV" mode tap
ip addr add "${TAP_IP_ADDRESS}/${TAP_SUBNET_CIDR}" dev "$TAP_DEV"
ip link set "$TAP_DEV" up

# Redirect traffic to tap interface
iptables -t nat -A POSTROUTING -o $PHYS_IF -j MASQUERADE
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i "$TAP_DEV" -o $PHYS_IF -j ACCEPT

echo "Interface $TAP_DEV has been created and is ready to be used by the VM."
ifconfig "$TAP_DEV"