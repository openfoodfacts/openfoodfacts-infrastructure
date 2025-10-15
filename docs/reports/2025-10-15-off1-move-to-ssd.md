 # 2025-10-15 off1 move to SSD

We have a problem with a disk on off1, and it puts containers at risk.

We have identified, that while `hdd-zfs` pool is at risk,
with one disk already offline and another having SMART alerts.
the `rpool` is in `mirror-0` and can survive a second disk loss.

## Analysis

Looking at currently CT, there are:
```
MID       Status     Lock         Name
100        stopped                 proxy
102        running                 mongodb
104        running                 keycloak
115        stopped                 off-query
```

The proxy was used as an attempt to serve images but is not active.
off-query have been moved to Moji.

So the real important CT are:
- mongodb
- keycloak

Both of them have volumes on `hdd-zfs` and `zfs-nvme`:
```bash
cat /etc/pve/lxc/10{2,4}.conf |grep -P 'mp\d|rootfs'
mp0: zfs-nvme:subvol-102-disk-0,mp=/mongo,mountoptions=noatime,size=96G
rootfs: zfs-hdd:subvol-102-disk-0,mountoptions=noatime,size=64G
mp0: zfs-nvme:subvol-104-disk-0,mp=/var/lib/docker/volumes,mountoptions=noatime,size=50G
rootfs: zfs-hdd:subvol-104-disk-0,mountoptions=noatime,size=40G
```

Looking at volume size on `hdd-zfs` (`64G` + `40G`),
and available size on `zfs-nvme`:
```bash
# zpool list -v zfs-nvme
NAME          SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
zfs-nvme     1.81T   398G  1.42T        -         -    42%    21%  1.00x    ONLINE  -
  nvme0n1p1  1.82T   398G  1.42T        -         -    42%  21.5%      -    ONLINE
logs             -      -      -        -         -      -      -      -  -
  nvme1n1p1  6.71G  15.2M  6.49G        -         -     0%  0.22%      -    ONLINE
```
there is no problem to move those `zfs-hdd` volumes to `zfs-nvme`.

## Doing it

Doing it first for container 102.

1. let's first sync data to zfs-nvme using syncoid:

   ```bash
   syncoid zfs-hdd/pve/subvol-102-disk-0 zfs-nvme/pve/subvol-102-disk-1
   ```
   (took around 15 minutes)

2. Then in a quick move:
   ```bash
    # sync a last time
   syncoid zfs-hdd/pve/subvol-102-disk-0 zfs-nvme/pve/subvol-102-disk-1
   # stop container
   pct stop 102
   # sync again
   syncoid zfs-hdd/pve/subvol-102-disk-0 zfs-nvme/pve/subvol-102-disk-1
   # change config
   vim /etc/pve/lxc/102.conf
   ... change zfs-hdd:subvol-102-disk-0 to zfs-nvme:subvol-102-disk-1 ...
   # start container
   pct start 102
   ```

We have no need to change sanoid configuration to take snapshots
for the new volume (instead of the old one),
because the recursive configuration on zfs-nvme/pve applies.

Same for syncoid backups, they are included on remote machines
thanks to recursive option.


**Note**: there was a reboot of whole server between those operations,
but I don't know why …

Now for 104:

1. let's first sync data to zfs-nvme using syncoid:

   ```bash
   syncoid zfs-hdd/pve/subvol-104-disk-0 zfs-nvme/pve/subvol-104-disk-1
   ```
   (took around 2 minutes)

2. Then in a quick move:
   ```bash
    # sync a last time
   syncoid zfs-hdd/pve/subvol-104-disk-0 zfs-nvme/pve/subvol-104-disk-1
   # stop container
   pct stop 104
   # sync again
   syncoid zfs-hdd/pve/subvol-104-disk-0 zfs-nvme/pve/subvol-104-disk-1
   # change config
   vim /etc/pve/lxc/104.conf
   ... change zfs-hdd:subvol-104-disk-0 to zfs-nvme:subvol-104-disk-1 ...
   # start container
   pct start 104
   ```
