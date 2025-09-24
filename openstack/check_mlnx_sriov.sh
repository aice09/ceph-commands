#!/bin/bash
# Mellanox + SR-IOV diagnostic script for OpenStack on Kubernetes
# Run on baremetal compute nodes (e.g., baremetal1, baremetal2)
# Copy the script to problematic node:
#scp check_mlnx_sriov.sh baremetal1:/root/
#scp check_mlnx_sriov.sh baremetal2:/root/
#Run it:
#chmod +x check_mlnx_sriov.sh
#./check_mlnx_sriov.sh
#It will print:
#NIC hardware & driver
#VF counts (SR-IOV)
#Kernel/IOMMU logs
#SR-IOV device plugin status
#Neutron agent pod logs

echo "=== Mellanox & SR-IOV Diagnostic Script ==="
NODE=$(hostname)
echo "Node: $NODE"
echo "------------------------------------------"

### 1. PCI Devices
echo ">> Checking Mellanox NICs..."
lspci | grep -i mell || echo "No Mellanox NICs found!"

### 2. Driver + Firmware
echo ">> Checking NIC driver and firmware..."
for iface in $(ls /sys/class/net | grep -E 'en|eth|mlx'); do
    echo "--- Interface: $iface ---"
    ethtool -i $iface 2>/dev/null | grep -E 'driver|version|firmware'
done

### 3. Kernel Modules
echo ">> Mellanox kernel modules..."
lsmod | grep mlx || echo "No Mellanox modules loaded!"

### 4. SR-IOV VF status
echo ">> SR-IOV VF counts..."
for iface in $(ls /sys/class/net | grep -E 'en|eth|mlx'); do
    if [ -f /sys/class/net/$iface/device/sriov_totalvfs ]; then
        total=$(cat /sys/class/net/$iface/device/sriov_totalvfs)
        num=$(cat /sys/class/net/$iface/device/sriov_numvfs)
        echo "$iface: $num/$total VFs enabled"
    fi
done

### 5. IOMMU / SR-IOV dmesg logs
echo ">> Checking dmesg for IOMMU/SR-IOV..."
dmesg | egrep -i 'DMAR|IOMMU|mlx|SR-IOV' | tail -n 20

### 6. Kubernetes SR-IOV Device Plugin
echo ">> Checking Kubernetes SR-IOV device plugin..."
kubectl get pods -n kube-system -o wide | grep sriov || echo "No SR-IOV device plugin pod found!"
kubectl logs -n kube-system $(kubectl get pods -n kube-system -o name | grep sriov | head -n1) --tail=20

### 7. Neutron SR-IOV Agent pod
echo ">> Checking Neutron SR-IOV agent..."
kubectl get pods -n openstack -o wide | grep sriov
for pod in $(kubectl get pods -n openstack -o name | grep sriov | grep $NODE); do
    echo "--- Logs from $pod ---"
    kubectl logs -n openstack $pod --tail=20
done

echo "------------------------------------------"
echo "Diagnostics complete for node: $NODE"
