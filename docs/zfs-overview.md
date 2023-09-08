# ZFS overview

## Why

We use a lot ZFS for our data for it's reliability and incredible capabilities. The most important feature is data synchronization through snapshots. Clone also enables to easily have same data as production for tests.

## Learning resources

To learn about ZFS, see [the onboarding made by Christian](reports/2023-02-24-zfs-introduction.md)

See also [OpenZFS official documentation](https://openzfs.github.io/openzfs-docs/) 
and [Proxmox ZFS documentation](https://pve.proxmox.com/wiki/ZFS_on_Linux#sysadmin_zfs_special_device)

Tutorial about ZFS snapshots and clone: https://ubuntu.com/tutorials/using-zfs-snapshots-clones#1-overview


## Some useful commands

* `zpool status` to see eventual errors
* `zpool list -v` to see all device

  **Note**: there is a quirk with ALLOC which is different for mirror pools and raidz pools.
  On the first it's allocated space to datasets, on the second it's used space.

* `zfs list -r` to get all datasets and their mountpoints
  3. zpool list -v list all devices

## Proxmox

Proxmox uses ZFS to replicate containers and VMs between servers. It also use it to backup data.

## Using sanoid

We use sanoid / syncoid to sync ZFS datasets between servers (also to back them up).

See [sanoid](./sanoid.md)

## Sync

To Sync ZFS you just take snapshots on the source at specific intervals (we use cron jobs).
You then use [zfs-send](https://openzfs.github.io/openzfs-docs/man/8/zfs-send.8.html) an [zfs-recv](https://openzfs.github.io/openzfs-docs/man/8/zfs-recv.8.html) through ssh to sync the distant server (send snapshots).

```bash
zfs send <previous-snap> <dataset_name>@$<last-snap> \
  | ssh <hostname> zfs recv <target_dataset_name> -F
```


ZFS sync of sto files from off1 to off2:
* see [sto-products-sync.sh](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/scripts/off1/sto-products-sync.sh)





You also have to clean snapshots from time to time to avoid retaining too much useless data.

On ovh3: [snapshot-purge.sh](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/scripts/ovh3/snapshot-purge.sh)


**FIXME** explain sanoid

## Docker mount

If ZFS dataset is on same machine we can use bind mounts to mount a folder in a ZFS partition.

For distant machines, ZFS datasets can be exposed as NFS partition. Docker as an integrated driver to mount distant NFS as volumes.


## Mounting datasets in a proxmox container

To move dataset in a proxmox container you have to mount them as bind volumes.

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
