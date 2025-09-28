#!/bin/bash
set -euo pipefail

# Host to IP mapping
declare -A HOST_MAP=(
  ["tunnel-vm"]="192.168.1.101/24"
  ["k8s-master1"]="192.168.1.111/24"
  ["k8s-master2"]="192.168.1.112/24"
  ["k8s-master3"]="192.168.1.113/24"
  ["k8s-worker1"]="192.168.1.121/24"
  ["k8s-worker2"]="192.168.1.122/24"
)

# Gateway
GATEWAY="192.168.1.1"

# Hosts file entries
HOSTS_BLOCK=$(cat <<EOF
192.168.1.101 tunnel-vm
192.168.1.111 k8s-master1
192.168.1.112 k8s-master2
192.168.1.113 k8s-master3
192.168.1.121 k8s-worker1
192.168.1.122 k8s-worker2
EOF
)

# Detect hostname
HOSTNAME_CURRENT=$(hostname)
echo "Detected hostname: $HOSTNAME_CURRENT"

# Step 1: Update /etc/hosts
echo "Updating /etc/hosts..."
cp /etc/hosts /etc/hosts.bak.$(date +%F-%T)
sed -i '/tunnel-vm/d;/k8s-master1/d;/k8s-master2/d;/k8s-master3/d;/k8s-worker/d;/k8s-worker1/d' /etc/hosts
echo "$HOSTS_BLOCK" >> /etc/hosts

# Step 2: Update hostname + static IP if in map
if [[ -v HOST_MAP[$HOSTNAME_CURRENT] ]]; then
    NEW_IP=${HOST_MAP[$HOSTNAME_CURRENT]}
    echo "Setting static IP for $HOSTNAME_CURRENT → $NEW_IP"

    # Find the primary interface
    IFACE=$(nmcli device status | awk '$2=="ethernet" && $3=="connected" {print $1; exit}')
    echo "Using interface: $IFACE"

    # Set hostname
    echo "Updating hostname..."
    hostnamectl set-hostname "$HOSTNAME_CURRENT"

    # Configure static IP via nmcli
    nmcli con mod "$IFACE" ipv4.addresses "$NEW_IP"
    nmcli con mod "$IFACE" ipv4.gateway "$GATEWAY"
    nmcli con mod "$IFACE" ipv4.dns "8.8.8.8 1.1.1.1"
    nmcli con mod "$IFACE" ipv4.method manual
    nmcli con up "$IFACE"

    echo "✅ Hostname + Static IP applied successfully"
    echo "   Hostname   : $HOSTNAME_CURRENT"
    echo "   IP Address : $NEW_IP"
    echo "   Gateway    : $GATEWAY"
    echo "   Interface  : $IFACE"
else
    echo "⚠️ Hostname $HOSTNAME_CURRENT not in HOST_MAP. No IP changes made."
fi
