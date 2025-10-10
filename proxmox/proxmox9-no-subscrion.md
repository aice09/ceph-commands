# Proxmox 9 No-Subscription Setup

This guide explains how to convert a Proxmox 9 installation from the enterprise subscription repository to the **no-subscription repositories**. This allows full system updates without a paid subscription.

## Current Situation

By default, Proxmox 9 uses enterprise repositories which require a subscription. You likely have:

| File | Purpose | Status |
|------|---------|--------|
| `debian.sources` | Debian base repositories | ✅ Correct |
| `pve-enterprise.sources` | Proxmox Enterprise repo | ❌ Subscription required, should be replaced |
| `ceph.sources` | Ceph Enterprise repo | ❌ Subscription required, should be replaced |

---

## ✅ What to Change

Replace:

- `pve-enterprise.sources` → `pve-no-subscription`
- `ceph.sources` → Ceph no-subscription repo

---

### 🧩 Step 1: Replace `pve-enterprise.sources`

Edit the file:

```
nano /etc/apt/sources.list.d/pve-enterprise.sources
```
Replace all contents with:

```
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
```

### 🧩 Step 2: Replace ceph.sources
Edit the file:

```
nano /etc/apt/sources.list.d/ceph.sources
```
Replace all contents with:

```
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
```
### 🧩 Step 3: Update System
Run:
```
apt update && apt full-upgrade -y
```
Expected output:

```
Hit:1 http://download.proxmox.com/debian/pve trixie pve-no-subscription
Hit:2 http://download.proxmox.com/debian/ceph-squid trixie no-subscription
```
References:
- https://pve.proxmox.com/wiki/Package_Repositories
