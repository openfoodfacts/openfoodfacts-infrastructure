# ZFS overview

## Why

We use a lot ZFS for our data for it's reliability and incredible capabilities. The most important feature is data synchronization through snapshots. Clone also enables to easily have same data as production for tests.

## Learning resources

To learn about ZFS, see [the onboarding made by Christian](reports/2023-02-24-zfs-introduction.md)

See also [OpenZFS official documentation](https://openzfs.github.io/openzfs-docs/)

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

## Docker mount

If ZFS dataset is on same machine we can use bind mounts to mount a folder in a ZFS partition.

For distant machines, ZFS datasets can be exposed as NFS partition. Docker as an integrated driver to mount distant NFS as volumes.