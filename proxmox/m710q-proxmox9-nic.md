# Troubleshooting Intel I219-V Ethernet Controller on Linux/Proxmox 9


### Problem

On a Lenovo M710Q running a custom kernel (`6.14.8-2-pve`) [Proxmox VE 9.0](https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso/proxmox-ve-9-0-iso-installer), the Intel I219-V Ethernet controller is detected in `lspci`:
```
00:1f.6 Ethernet controller [0200]: Intel Corporation Ethernet Connection (2) I219-V [8086:15b8]
```

…but no corresponding network interface appears in `ip a`:


```
1: lo: <LOOPBACK,UP,LOWER_UP> ...
2: vmbr0: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
```

Even though `vmbr0` shows up, the physical NIC (eno1/enp1s0) is missing.


`dmesg | grep e1000e` shows:


```
e1000e 0000:00:1f.6: The NVM Checksum Is Not Valid
e1000e 0000:00:1f.6: probe with driver e1000e failed with error -5
```

### **Root cause:** 
Corrupted or invalid NVM/EEPROM on the NIC.


### Workarounds

Temporary Ethernet via USB adapter

- Plug in a USB-to-Ethernet adapter.
- Provides temporary network access to download firmware/tools.

Then bridge it to vmbr0, edit /etc/network/interfaces:
```
auto enx001122334455
iface enx001122334455 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.1.7/24
    gateway 192.168.1.1
    bridge-ports enx001122334455
    bridge-stp off
    bridge-fd 0
```

Then restart networking:
```
systemctl restart networking
```

## Resolution
- Reset NIC NVM

1. Download Intel BootUtil in InteL website [Intel® Ethernet Connections Boot Utility, Preboot Images, and EFI Drivers](https://www.intel.com/content/www/us/en/download/15755/intel-ethernet-connections-boot-utility-preboot-images-and-efi-drivers.html)
```bash
wget https://downloadmirror.intel.com/864513/Preboot.tar.gz
tar -xzf Preboot.tar.gz
cd APPS/BootUtil/Linux_x64
chmod +x ./bootutil64e
```
2. Attempt default configuration reset
```
sudo ./bootutil64e -NIC 1 -defcfg
```
Resets NIC EEPROM to defaults and corrects PXE words and NVM checksum issues.

3. Verify
```
dmesg | grep e1000e
ip a
```
4. Reboot
```
sudo reboot
```
After reboot, the Intel I219-V should appear as a normal interface (eno1/enp1s0).
You can remove the temporary USB adapter.

5. Update proxmox network and point to ethernet.
```
auto lo
iface lo inet loopback

iface enp0s31f6 inet manual

auto vmbr0
iface vmbr0 inet static
        address 192.168.1.7/24
        gateway 192.168.1.1
        bridge-ports enp0s31f6
        bridge-stp off
        bridge-fd 0

source /etc/network/interfaces.d/*
```
Then restart network
```
root@mushin:/etc/network# ifreload -a
root@mushin:/etc/network# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute
       valid_lft forever preferred_lft forever
2: enp0s31f6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master vmbr0 state UP group default qlen 1000
    link/ether e0:be:03:1d:54:bf brd ff:ff:ff:ff:ff:ff
    altname enxe0be031d54bf
4: vmbr0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether e0:be:03:1d:54:bf brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.7/24 scope global vmbr0
       valid_lft forever preferred_lft forever
    inet6 fe80::e2be:3ff:fe1d:54bf/64 scope link proto kernel_ll
```
References:
- [Network eth0 missing, "The NVM Checksum Is Not Valid" with Asus Maximus IX Hero desktop motherboard and Ubuntu 16.10](https://superuser.com/questions/1197908/network-eth0-missing-the-nvm-checksum-is-not-valid-with-asus-maximus-ix-hero)
- [How to repair the checksum of the non-volatile memory (NVM) of Intel Ethernet Controller I219-V of an ASUS laptop](https://superuser.com/questions/1104537/how-to-repair-the-checksum-of-the-non-volatile-memory-nvm-of-intel-ethernet-co/1190558#1190558)
