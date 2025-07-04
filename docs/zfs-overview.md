# ZFS overview

## Why

We use a lot ZFS for our data for it's reliability and incredible capabilities. The most important feature is data synchronization through snapshots. Clone also enables to easily have same data as production for tests.

## Learning resources


To learn about ZFS, see [the onboarding made by Christian](reports/2023-02-24-zfs-introduction.md)

Also See [OpenZFS official documentation](https://openzfs.github.io/openzfs-docs/)
it's very complete, but it's a bit hard to navigate.
* [misc man page section](https://openzfs.github.io/openzfs-docs/man/master/7/index.html)  contains a lot of useful information on properties and features
* [Basic Concepts](https://openzfs.github.io/openzfs-docs/Basic%20Concepts/index.html) is a good place to return to from time to time to grab concepts better
* [Man pages on system administration commands](https://openzfs.github.io/openzfs-docs/man/master/8/index.html) are really useful
* [Performance and Tuning](https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/index.html) is also valuable to dig in some options

[Proxmox ZFS documentation](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#chapter_zfs) and [Wiki](https://pve.proxmox.com/wiki/ZFS_on_Linux#sysadmin_zfs_special_device) is another valuable resource.

Tutorial about ZFS snapshots and clone: https://ubuntu.com/tutorials/using-zfs-snapshots-clones#1-overview

A good cheat-sheet: https://blog.mikesulsenti.com/zfs-cheat-sheet-and-guide/


## Some useful commands

* [`zpool status`](https://openzfs.github.io/openzfs-docs/man/master/8/zpool-status.8.html) to see eventual errors
* [`zpool list -v`](https://openzfs.github.io/openzfs-docs/man/master/8/zpool-list.8.html) to see all device

  **Note**: there is a quirk with ALLOC which is different for mirror pools and raidz pools.
  On the first it's allocated space to datasets, on the second it's used space.

* [`zfs list -r`](https://openzfs.github.io/openzfs-docs/man/master/8/zfs-list.8.html) to get all datasets and their mountpoints

* [`zpool iostat`](https://openzfs.github.io/openzfs-docs/man/master/8/zpool-iostat.8.html) to see stats about read / write. `zpool iostat -vl 5` is particularly useful,
  `zpool iostat -w` helps you understand the time taken by data to be read / written.

* [`zpool history`](https://openzfs.github.io/openzfs-docs/man/master/8/zpool-history.8.html) list all operations done on a pool

* `zpool list -o name,size,usedbysnapshots,allocated` see space allocated (equivalent to `df`)

  **Note**: `df` on a dataset does not really work because free space is shared between the datasets.
  You can still see datasets usage by using:
  ```bash
  zfs list -o zfs list -o name,used,usedbydataset,usedbysnapshots,available -r <pool_name>
  ```

* [`zdb`](https://openzfs.github.io/openzfs-docs/man/master/8/zdb.8.html) is also worth knowing (`zdb -s <poolname>` for example)

## Some Fine-Tuning

We use compression on a lot of our datasets (`compression=on`).

You can set `primarycache=metadata` for volumes with large number of files,
that are not critical to read fast. (eg. Images on off container, or backups from other servers).

In [Munin](./munin.md) `ZFS ARC - Hit ratio`  the `ZFS Arc Efficiency` gives you an idea of how well ZFS caching is performing.


## Proxmox

Proxmox uses ZFS to replicate containers and VMs between servers. It also use it to backup data.

Note: we progressively abandon Proxmox ZFS replication in favor of using sanoid/syncoid.

## Using sanoid

We use sanoid / syncoid to sync ZFS datasets between servers (also to back them up).

See [sanoid](./sanoid.md)

## How to create a zpool

Ensure disks are not mounted and available (eg using `lsblk`).
You can eventually split them into different partitions if needed.

Just create the pool with the resources:

`zpool create <pool_name> <pool-type> <device1> <device2> ...`

For pool name use something like zfs-something (zfs-hdd, zfs-nvme, etc.)

For pool-type, use the one that's needed: none (no mention), mirror, raidz.

You may add a [cache](https://openzfs.github.io/openzfs-docs/man/master/7/zpoolconcepts.7.html#Cache_Devices) and / or a [log device](https://openzfs.github.io/openzfs-docs/man/master/7/zpoolconcepts.7.html#log).


## How to NFS mount a zfs dataset

ZFS directly integrate to NFS server.

To have a dataset shared in NFS, you have to set sharenf property to allowed addresses and other options.

Example:
* `zfs set sharenfs="rw=@10.0.0.0/28,no_root_squash" <pool_name>/<dataset_name>`
* `zfs set sharenfs="rw=@10.0.0.1/32,rw=@10.1.0.200/32,no_root_squash" <pool_name>/<dataset_name>`


**Very important**: always filter on a internal sub network, otherwise your Dataset is exposed to the internet !!!

Beware that all descendant inherit the property and will also be shared.

## How to replace a disk in zpool

To replace a disk in a zpool.

* Get a list of devices using `zpool status <pool_name>`

* Put the disk offline: `zpoool <pool_name> offline <device_name>` (eg `zpool rpool offline sdf`)

* Replace the disk physically

* Ask zpool to replace the drive: `zpool <pool_name> replace /dev/<device_name>` (eg `zpool rpool replace /dev/sdf`)

* verify disk is back and being resilvered:
  ```bash
  zpool status <pool_name>
  …
   state: DEGRADED
  status: One or more devices is currently being resilvered.  The pool will
          continue to function, possibly in a degraded state.
  action: Wait for the resilver to complete.
    scan: resilver in progress since …
  …
              replacing-5  DEGRADED     0     0     0
              old        OFFLINE      0     0     0
              sdf        ONLINE       0     0     0  (resilvering)
  ```

* after resilver finishes, you can eventually run a scrub: `zpool scrub <pool_name>`


## How to Sync ZFS datasets


To Sync ZFS you just take snapshots on the source at specific intervals (we use cron jobs).
You then use [zfs-send](https://openzfs.github.io/openzfs-docs/man/8/zfs-send.8.html) an [zfs-recv](https://openzfs.github.io/openzfs-docs/man/8/zfs-recv.8.html) through ssh to sync the distant server (send snapshots).

### Doing it automatically

We normally do it using [sanoid and syncoid](./sanoid.md)

Proxmox might also do it as part of corosync to replicate containers across cluster.

### Doing it manually

```bash
zfs send <previous-snap> <dataset_name>@$<last-snap> \
  | ssh <hostname> zfs recv <target_dataset_name> -F
```


ZFS sync of sto files from off1 to off2:
* see [sto-products-sync.sh](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/scripts/off1/sto-products-sync.sh)


You also have to clean snapshots from time to time to avoid retaining too much useless data.

On ovh3: [snapshot-purge.sh](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/scripts/ovh3/snapshot-purge.sh)


## How to Docker mount a zfs dataset

If ZFS dataset is on same machine we can use bind mounts to mount a folder in a ZFS partition.

For distant machines, ZFS datasets can be exposed as NFS partition. Docker as an integrated driver to mount distant NFS as volumes.


## How to Mount datasets in a proxmox container

To mount dataset in a proxmox container you have:
* to use a shared disk on proxmox
* or to mount them as bind volumes

### Use a shared disk on proxmox

(not really experimented yet, but it could have the advantage to enable replication)

On your VM/CT, in resource, add a disk.

Add the mountpoint to your disk and declare it shared.

In another VM/CT, add the same disk.


### mount dataset  as bind volumes

See: https://pve.proxmox.com/wiki/Linux_Container#_bind_mount_points

and https://pve.proxmox.com/wiki/Unprivileged_LXC_containers


Edit `/etc/pve/lxc/<container_id>.conf` and ad volumes with mount point.

For example:

```
# volumes
mp0: /zfs-hdd/opff,mp=/mnt/opff
mp1: /zfs-hdd/opff/products/,mp=/mnt/opff/products
mp2: /zfs-hdd/off/users/,mp=/mnt/opff/users
mp3: /zfs-hdd/opff/images,mp=/mnt/opff/images
mp4: /zfs-hdd/opff/html_data,mp=/mnt/opff/html_data
mp5: /zfs-hdd/opff/cache,mp=/mnt/opff/cache
```

**Important**: if you have nested mount points, the order is very important. First the outermost, then the inner ones.

To take changes in account, you have to reboot: `pct reboot <container_id>`

### Getting uids and gids right

LXC maps uids inside the container to specific ids outside, most of the time by adding a large value. It's a way to ensure security.

If you want to have file belonging to say uid 1000 in the zfs mount, you will have to tweak it:

We edit /etc/subuid and /etc/subgid to add `root:1000:10`. This allow container started by root to map ids 1000 to their same ids on system.

Edit `/etc/pve/lxc/<machine_id>.conf` conf to add sub_id exceptions:

```
# uid map: from uid 0 map 999 uids (in the ct) to the range starting 100000 (on the host)
# so 0..999 (ct) → 100000..100999 (host)
lxc.idmap = u 0 100000 999
lxc.idmap = g 0 100000 999
# we map 10 uid starting from uid 1000 onto 1000, so 1000..1010 → 1000..1010
lxc.idmap = u 1000 1000 10
lxc.idmap = g 1000 1000 10
# we map the rest of 65535 from 1010 upto 101010, so 1010..65535 → 101010..165535
lxc.idmap = u 1011 101011 64525
lxc.idmap = g 1011 101011 64525
```
