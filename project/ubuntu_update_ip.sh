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
  ["k8s-worker3"]="192.168.1.123/24"
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
192.168.1.123 k8s-worker3
EOF
)

# Detect hostname
HOSTNAME_CURRENT=$(hostname)

echo "Detected hostname: $HOSTNAME_CURRENT"

# Step 1: Ensure /etc/hosts has our block
echo "Updating /etc/hosts..."
cp /etc/hosts /etc/hosts.bak.$(date +%F-%T)
sed -i '/tunnel-vm/d;/k8s-master1/d;/k8s-master2/d;/k8s-master3/d;/k8s-worker/d;/k8s-worker1/d' /etc/hosts
echo "$HOSTS_BLOCK" >> /etc/hosts

# Step 2: Update IP + hostname if in map
if [[ -v HOST_MAP[$HOSTNAME_CURRENT] ]]; then
  NEW_IP=${HOST_MAP[$HOSTNAME_CURRENT]}
  echo "Setting static IP for $HOSTNAME_CURRENT → $NEW_IP"

  # Find default interface
  IFACE=$(ip route | awk '/default/ {print $5; exit}')
  echo "Using interface: $IFACE"

  # --- Set hostname (system + file) ---
  echo "Updating hostname..."
  hostnamectl set-hostname "$HOSTNAME_CURRENT"
  echo "$HOSTNAME_CURRENT" > /etc/hostname

  # --- Disable cloud-init network override ---
  echo "Disabling cloud-init network config..."
  mkdir -p /etc/cloud/cloud.cfg.d
  cat > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<EOF
network: {config: disabled}
EOF

  # --- Update netplan config ---
  NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"
  cp "$NETPLAN_FILE" "$NETPLAN_FILE.bak.$(date +%F-%T)"

  cat > "$NETPLAN_FILE" <<EOF
network:
    version: 2
    ethernets:
        $IFACE:
            dhcp4: no
            addresses:
              - $NEW_IP
            gateway4: $GATEWAY
            nameservers:
                addresses: [8.8.8.8, 1.1.1.1]
EOF

  # Apply changes immediately
  netplan apply

  echo "✅ Hostname + Static IP applied successfully"
  echo "   Hostname   : $HOSTNAME_CURRENT"
  echo "   IP Address : $NEW_IP"
  echo "   Gateway    : $GATEWAY"
  echo "   Interface  : $IFACE"
else
  echo "⚠️ Hostname $HOSTNAME_CURRENT not in HOST_MAP. No IP changes made."
fi
