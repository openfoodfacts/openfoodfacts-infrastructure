# 2024-11-14 Server install at Hetzner

## How it works

On Hetzner console, to see servers you have to go in "Robot" menu.

You can put a ssh key in the [Hetzner > Robot > Server](https://robot.hetzner.com/server) > Key

Server is delivered in rescue mode.

From there we can launch a script to install the OS with `installimage` command.

Official documentation: https://docs.hetzner.com/robot/dedicated-server/operating-systems/installimage/

After analyzing the server, it prepares a configuration file for installation that can be modified according to your needs.

We need to change:
- disk for OS install
- the RAID type
- the partitionning
- the hostname

Note that we can't install the system on ZFS with this method as it is not supported by Hetzner installimage script ([as explained on their bug tracker](https://github.com/hetzneronline/installimage/issues/36)) 

## Configuration of "installimage" for a storage server

On storage servers, we have 4 SATA HHD and 2 NVMe SSD.

They do not seem to be able to boot on the NVMe disks.

The OS (debian 12/bookworm) will thus be installed on HDD, in RAID1 (miror) and in ext3/4 reserving 256Go for / as the rest will be allocated to the ZFS pool. We will then install promox on top of it.

We thus modify the configuration file as follows:


```conf
DRIVE1 /dev/sda
DRIVE2 /dev/sdb
DRIVE3 /dev/sdc
DRIVE4 /dev/sdd

SWRAID 1
SWRAIDLEVEL 1

HOSTNAME h1.openfoodfacts.org
```

The default partitioning must also be modified so that the / partition does not occupy the entire disk but 256G.

The rest of the configuration remains unchanged.

We can then launch install, it's very fast!

## Proxmox installation

See: https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_12_Bookworm

Nothing special, so:

```bash
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg 
apt update && apt full-upgrade -y
apt install proxmox-default-kernel -y
reboot
```

After restarting the server:

```bash
apt install proxmox-ve postfix open-iscsi chrony -y
apt remove linux-image-amd64 'linux-image-6.1*' -y
update-grub
apt remove os-prober -y
```

## Disabling portmapper (BSI)

```bash
systemctl stop rpcbind rpcbind.socket
systemctl disable rpcbind rpcbind.socket
```

([Source](https://www.bsi.bund.de/EN/Themen/Unternehmen-und-Organisationen/Cyber-Sicherheitslage/Reaktion/CERT-Bund/CERT-Bund-Reports/HowTo/Offene-Portmapper-Dienste/Offene-Portmapper-Dienste_node.html))

## ZFS Pool on storage serveurs

We create partitions on the remaining space of the HDD:


```bash
apt install parted -y

parted /dev/sda mkpart zfs hdd-zfs 280G 100%
parted /dev/sdb mkpart zfs hdd-zfs 280G 100%
parted /dev/sdc mkpart zfs hdd-zfs 280G 100%
parted /dev/sdd mkpart zfs hdd-zfs 280G 100%
```

ZFS Pool creation:

```bash
apt install zfsutils-linux zfs-dkms
/sbin/modprobe zfs
```

```bash
zpool create hdd-zfs -o ashift=12 raidz1 sda5 sdb5 sdc5 sdd5 cache nvme0n1 nvme1n1
zpool export hdd-zfs
zpool import hdd-zfs -d /dev/disk/by-id/
zfs set compress=on xattr=sa atime=off relatime=on hdd-zfs
```

## Installing proxmox

```bash
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
sha512sum /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
apt update
apt list --upgradable
apt full-upgrade
apt install proxmox-default-kernel
systemctl reboot
apt install proxmox-ve postfix open-iscsi chrony
apt remove linux-image-amd64 'linux-image-6.1*'
proxmox-boot-tool refresh
update-grub
apt remove os-prober
```

Checking:
```bash
systemctl status pve-cluster.service pve-firewall.service pvedaemon.service pveproxy.service
# if in a cluster, we would have issued: pvecm status
pct list
qm list
```

More tools installs:
```bash
apt install parted fail2ban molly-guard htop dstat
```

That's all folks !

## Installing alex key (2025-02-18)

As I needed my key on the server, I tried the rescue mode.

It seems the rescue boot did not succeed in recognizing Raid1 volumes correctly.
In /etc/mdadm/mdadm.conf, there where two dev/md/0 and two /dev/md/1.

```conf
# definitions of existing MD arrays
ARRAY /dev/md/0  metadata=1.2 UUID=58a64854:d6c1d6fe:e51fe77e:015ee514 name=rescue:0
ARRAY /dev/md/2  metadata=1.2 UUID=9f1bc769:faeb7829:2b78488c:e20e3b71 name=rescue:0
ARRAY /dev/md/3  metadata=1.2 UUID=04135134:6885bde9:0b43e847:f6ff479a name=rescue:1
ARRAY /dev/md/4  metadata=1.2 UUID=8b27df50:bc713e37:5c11f3b9:d71e8b8f name=rescue:2
```

I renamed the duplicate:

```conf
# definitions of existing MD arrays
ARRAY /dev/md/0  metadata=1.2 UUID=58a64854:d6c1d6fe:e51fe77e:015ee514 name=rescue:0
ARRAY /dev/md/1  metadata=1.2 UUID=9f1bc769:faeb7829:2b78488c:e20e3b71 name=rescue:0
ARRAY /dev/md/2  metadata=1.2 UUID=04135134:6885bde9:0b43e847:f6ff479a name=rescue:1
ARRAY /dev/md/3  metadata=1.2 UUID=8b27df50:bc713e37:5c11f3b9:d71e8b8f name=rescue:2
```

After this, I was able to run `mdadm --assemble --scan --verbose`.
