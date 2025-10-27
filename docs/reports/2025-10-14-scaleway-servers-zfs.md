# 2025-10-14 Scaleway servers ZFS

Christian installed new servers on our new scaleway bay.

He did a base install using Proxmox iso.
He only configured the rpool, zpool to hold the system (in mirror-0).

He also configured zpool for the NVME but he then did some exchange of NVME between servers.
(to mix pro and non pro SSD to have "pro" security on two servers).

So as we looked at the servers they were in bad shape on the zpool side.

Here is some notes about we did with Christian.

## Fixing SSD pools

On scaleway-01 and scaleway-03 we had the nvme-pool stalled.
On both server, only the pro-SSD was setup correctly.

What we did:
* remove the faulty drive `zpool detach rpool <drive-name>`
* upgrade the rpool zpool, because we moved from proxmox8 to proxmox9 on scaleway-01
  `zfs upgrade rpool`
* prepare partition on the drive by mimicking the first drive.
  `parted /dev/<first-device> unit s print` gives us the existing part.
  We just have to recreate them [^parted-print].
* get the id of the NVME using `ls -l /dev/disk/by-id/|grep <device name>`
  where device-name is say nvme1n1p2
* add it to the pool. Note that we must attach it to the existing drive
  as we don't have a specific vdev:  
  `zpool attach rpool <eisting> nvme-TS4TMTE250S_I209080271-part3`

Now we have our rpool in good shape again `zpool status` tells us so,
but we need to make the second disk bootable, as the first.

For this, in proxmox, there is a special tool.

We just have to run (here for `nvme0n1p2`, the boot partition for `nvme0n1`):
```bash
proxmox-boot-tool format  /dev/nvme0n1p2 --force
proxmox-boot-tool init  /dev/nvme0n1p2
proxmox-boot-tool clean
```

[^parted-print]: this looks like:
```
parted /dev/nvme2n1 unit s print 
Model: TS4TMTE250S (nvme)
Disk /dev/nvme2n1: 7814037168s
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags: 

Number  Start     End         Size        File system  Name   Flags
1      34s       2048s       2015s                    grub   bios_grub
2      4096s     1953791s    1949696s    fat32        boot   boot, esp
3      1953792s  537108479s  535154688s  zfs          rpool
```
and can be recreated with:
```bash
parted /dev/nvme2n1 mklabel gpt
parted /dev/nvme2n1 mkpart primary 34s 2048s
parted /dev/nvme2n1 mkpart primary fat32 4096s 1953791s
parted /dev/nvme2n1 mkpart primary zfs 1953792s 535154688s
set 1 bios_grub=on
set 2 boot=on
set 2 esp=on
name 1 grub
name 2 boot
name 3 rpool
```

## Creating HDD pools

We have 6 disk on each server.

We decide to go for a raidz2-0 meaning we have two disks of redondancy.

ZFS pools are simply created with:
```bash
zpool create zfs-hdd -o ashift=12 raidz2 sda sdb sdc sdd sde sdf -f
```

## Dist upgrade

While at it we did a dist-upgrade on all servers.

## Turning mitigations off

Since we are only running our software on the servers
(there is no hosting of other projects),
we can turn off mitigations for attacks like spectre,
to regain some CPU performance.

So Christian edited `/etc/default/grub` to have:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet mitigations=off"
```
and then run:
```bash
proxmox-boot-tool refresh
```
(and not `sudo update-grub` as on a normal debian distribution)