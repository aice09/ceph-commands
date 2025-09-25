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

# Step 1: Ensure /etc/hosts has our block
echo "Updating /etc/hosts..."
# Backup first
cp /etc/hosts /etc/hosts.bak.$(date +%F-%T)
# Remove existing lines of these hosts
sed -i '/tunnel-vm/d;/k8s-master1/d;/k8s-master2/d;/k8s-master3/d;/k8s-worker/d;/k8s-worker1/d' /etc/hosts
# Append new block
echo "$HOSTS_BLOCK" >> /etc/hosts

# Step 2: Update IP if hostname matches
if [[ -v HOST_MAP[$HOSTNAME_CURRENT] ]]; then
  NEW_IP=${HOST_MAP[$HOSTNAME_CURRENT]}
  echo "Setting IP for $HOSTNAME_CURRENT → $NEW_IP"

  # Find default interface
  IFACE=$(ip route | awk '/default/ {print $5; exit}')
  echo "Using interface: $IFACE"

  # Apply new IP (clears old first to avoid duplicates)
  ip addr flush dev "$IFACE"
  ip addr add "$NEW_IP" dev "$IFACE"
  ip route add default via "$GATEWAY" dev "$IFACE"

  echo "✅ IP updated successfully"
else
  echo "⚠️ Hostname $HOSTNAME_CURRENT not in list. No IP changes made."
fi
