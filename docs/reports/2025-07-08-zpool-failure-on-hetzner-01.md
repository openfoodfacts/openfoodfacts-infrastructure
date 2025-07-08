# 2025-07-08 zpool failure on hetzner-01

## Symptoms

On 01/07 we got an email
```
ZFS has finished a scrub:

   eid: 890194
 class: scrub_finish
  host: hetzner-01
  time: 2025-07-01 02:05:56+0200
  pool: hdd-zfs
 state: ONLINE
status: One or more devices could not be used because the label is missing or
	invalid.  Sufficient replicas exist for the pool to continue
	functioning in a degraded state.
action: Replace the device using 'zpool replace'.
   see: https://openzfs.github.io/openzfs-docs/msg/ZFS-8000-4J
  scan: scrub repaired 0B in 02:05:56 with 0 errors on Tue Jul  1 02:05:56 2025
config:

	NAME                              STATE     READ WRITE CKSUM
	hdd-zfs                           ONLINE       0     0     0
	  raidz1-0                        ONLINE       0     0     0
	    wwn-0x5000c500e961b797-part5  ONLINE       0     0     0
	    wwn-0x5000c500e961b651-part5  ONLINE       0     0     0
	    wwn-0x5000c500e96221dc-part5  ONLINE       0     0     0
	    wwn-0x5000c500e96109e0-part5  ONLINE       0     0     0
	cache
	  nvme0n1                         UNAVAIL      0     0     0
	  nvme1n1                         UNAVAIL      0     0     0

errors: No known data errors
```

The cache is shown as unavailable.

I Logged in on the server and `zpool status` shows exactly the same thing.

## First try
I didn't see what was wrong.

I tried to remediate in simple way, telling zpool to just use it as a replaced disk:

```bash
zpool replace hdd-zfs nvme0n1
  /dev/nvme0n1 is in use and contains a unknown filesystem.
```

maybe removing and adding again
```bash
zpool remove hdd-zfs nvme0n1
zpool remove hdd-zfs nvme1n1
zpool add hdd-zfs cache nvme0n1 nvme1n1
  /dev/nvme0n1 is in use and contains a unknown filesystem.
  /dev/nvme1n1 is in use and contains a unknown filesystem.
```
still stuck.

## Analysis

The `lsblk` commands shows:
```
...
nvme1n1     259:0    0 953,9G  0 disk
├─nvme1n1p1 259:4    0 953,9G  0 part
│ └─md0       9:0    0     4G  0 raid1
└─nvme1n1p9 259:5    0     8M  0 part
nvme0n1     259:1    0 953,9G  0 disk
├─nvme0n1p1 259:2    0 953,9G  0 part
│ └─md0       9:0    0     4G  0 raid1
└─nvme0n1p9 259:3    0     8M  0 part
```

The problem is the md0 raid1 part.
The partition is already usedo for a raid device, md0.

Indeed it's used by the system as swap.
This is due to hetzner default configuration…

I will remove this.

## Removing the raid1 partition

removing swap:
swapoff -a

Edited the /etc/fstab to remove:
```conf
/dev/md/0
  UUID=0ee5226a-3a64-4521-93d2-d246411289db none swap sw 0 0
```

removed the raid definition ([thanks to this doc](https://serverok.in/delete-mdadm-raid))

```bash
mdadm --detail /dev/md0
  /dev/md0:
            Version : 1.2
      Creation Time : Wed Nov 13 18:11:32 2024
          Raid Level : raid1
          Array Size : 4189184 (4.00 GiB 4.29 GB)
      Used Dev Size : 4189184 (4.00 GiB 4.29 GB)
        Raid Devices : 2
      Total Devices : 2
        Persistence : Superblock is persistent

        Update Time : Sun Jun 15 03:09:22 2025
              State : clean 
      Active Devices : 2
    Working Devices : 2
      Failed Devices : 0
      Spare Devices : 0

  Consistency Policy : resync

                Name : rescue:0
                UUID : 58a64854:d6c1d6fe:e51fe77e:015ee514
              Events : 43

      Number   Major   Minor   RaidDevice State
        0     259        4        0      active sync   /dev/nvme1n1p1
        1     259        2        1      active sync   /dev/nvme0n1p1
```

Stoping it:

```bash
mdadm --stop /dev/md0
  mdadm: stopped /dev/md0
mdadm --zero-superblock /dev/nvme0n1p1
mdadm --zero-superblock /dev/nvme1n1p1
```
Commented `/etc/mdadm/mdadm.conf` to comment md0 definition
```conf
# md/0 commented by ALEX 2025-07-08
#ARRAY /dev/md/0  metadata=1.2 UUID=58a64854:d6c1d6fe:e51fe77e:015ee514 name=rescue:0
#ARRAY /dev/md/0  metadata=1.2 UUID=9f1bc769:faeb7829:2b78488c:e20e3b71 name=rescue:0
```

Removed partitions on /dev/nvme0n1 and /dev/nvme1n1
```bash
wipefs /dev/nvme1n1
  DEVICE  OFFSET       TYPE UUID LABEL
  nvme1n1 0x200        gpt       
  nvme1n1 0xee77a55e00 gpt       
  nvme1n1 0x1fe        PMBR      
wipefs -a /dev/nvme1n1
  /dev/nvme1n1: 8 bytes were erased at offset 0x00000200 (gpt): 45 46 49 20 50 41 52 54
  /dev/nvme1n1: 8 bytes were erased at offset 0xee77a55e00 (gpt): 45 46 49 20 50 41 52 54
  /dev/nvme1n1: 2 bytes were erased at offset 0x000001fe (PMBR): 55 aa
  /dev/nvme1n1: calling ioctl to re-read partition table: Success
wipefs -a /dev/nvme0n1
  /dev/nvme0n1: 8 bytes were erased at offset 0x00000200 (gpt): 45 46 49 20 50 41 52 54
  /dev/nvme0n1: 8 bytes were erased at offset 0xee77a55e00 (gpt): 45 46 49 20 50 41 52 54
  /dev/nvme0n1: 2 bytes were erased at offset 0x000001fe (PMBR): 55 aa
  /dev/nvme0n1: calling ioctl to re-read partition table: Success
```

## Remounting the cache

Now that we have removed the raid device and wiped the disk,
they should be available for ZFS to use.

```bash
zpool add hdd-zfs cache nvme0n1 nvme1n1
```

It worked:
```bash
zpool status
	pool: hdd-zfs
	state: ONLINE
	scan: scrub repaired 0B in 02:05:56 with 0 errors on Tue Jul  1 02:05:56 2025
	config:

		NAME                              STATE     READ WRITE CKSUM
		hdd-zfs                           ONLINE       0     0     0
		raidz1-0                        ONLINE       0     0     0
			wwn-0x5000c500e961b797-part5  ONLINE       0     0     0
			wwn-0x5000c500e961b651-part5  ONLINE       0     0     0
			wwn-0x5000c500e96221dc-part5  ONLINE       0     0     0
			wwn-0x5000c500e96109e0-part5  ONLINE       0     0     0
		cache
		nvme0n1                         ONLINE       0     0     0
		nvme1n1                         ONLINE       0     0     0

	errors: No known data errors
```

Now a reboot to verify it's restarting correctly.

```bash
# reboot
```

## Still not working on boot

But it's not working:
```bash
zpool status
	pool: hdd-zfs
	state: ONLINE
	status: One or more devices could not be used because the label is missing or
		invalid.  Sufficient replicas exist for the pool to continue
		functioning in a degraded state.
	action: Replace the device using 'zpool replace'.
	see: https://openzfs.github.io/openzfs-docs/msg/ZFS-8000-4J
	scan: scrub repaired 0B in 02:05:56 with 0 errors on Tue Jul  1 02:05:56 2025
	config:

		NAME                              STATE     READ WRITE CKSUM
		hdd-zfs                           ONLINE       0     0     0
		raidz1-0                        ONLINE       0     0     0
			wwn-0x5000c500e961b797-part5  ONLINE       0     0     0
			wwn-0x5000c500e961b651-part5  ONLINE       0     0     0
			wwn-0x5000c500e96221dc-part5  ONLINE       0     0     0
			wwn-0x5000c500e96109e0-part5  ONLINE       0     0     0
		cache
		nvme0n1                         FAULTED      0     0     0  corrupted data
		nvme1n1                         FAULTED      0     0     0  corrupted data

	errors: No known data errors
```

lsblk seems ok:
```bash
lsblk
	...
	nvme1n1     259:0    0 953,9G  0 disk
	├─nvme1n1p1 259:2    0 953,9G  0 part
	└─nvme1n1p9 259:3    0     8M  0 part
	nvme0n1     259:1    0 953,9G  0 disk
	├─nvme0n1p1 259:4    0 953,9G  0 part
	└─nvme0n1p9 259:5    0     8M  0 part
```

(The two partitions per device is expected, it's the way zfs formats full disks)

```bash
zpool remove hdd-zfs nvme0n1
zpool remove hdd-zfs nvme1n1
	(failed reverse-i-search)`add cac': user^Cd config-op sudo
zpool add hdd-zfs cache nvme0n1 nvme1n1
```
Works.

I reboot again, I'm in the previous situation again…

## Changing cache definition to use device ids

Christian proposed to change the zpool cache definition to use the device full ids instead of the simple device name.
It might be that on reboot, nvme disk don't always get the same short name.

To get the full name we can use:

```
ls -l /dev/disk/by-id/|grep "nvme"
...
nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NF0WB06047_1-part1 -> ../../nvme1n1p1
...
nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NF0WB06046_1-part1 -> ../../nvme0n1p1
```

let's use those names:
```bash
zpool remove hdd-zfs nvme0n1
zpool remove hdd-zfs nvme1n1
zpool add hdd-zfs cache nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NF0WB06046-part1 nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NF0WB06047-part1
```

After a reboot, it still works as expected 🎉 !

I also changed ansible definition of the ZFS pool to use the full device name.