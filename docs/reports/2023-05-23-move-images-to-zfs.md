# 2023-05-23 move Images to ZFS

We want to move images of open food facts from a normal storage on off1 to a ZFS dataset on off2, replicated on ovh3.

We want to move to ZFS because it makes it really easy to backup thanks to ZFS snapshot and syncing capabilities.
It was already done for products.

## Strategy

The strategy is the following

1. first reverse current syncing of ZFS so that ovh3 is synced from off2
2. mount image dataset on off1 thanks to NFS (NB: use nolock option)
3. for each top level folders
   1. rsync the folder to the ZFS dataset
   2. move the folder to a new name (xxx.old)
   3. replace by a symblink that point to the synced folder on the ZFS dataset (mounted on off1)
   4. rsync again to be sure we didn't miss anything

   At the end we will have a product images folder full of symlinks.

4.  At this point we can replace move the image folder ot image.old and NFS mount the ZFS dataset as image

We have two script implementing that for products that we can transform for images. They are in `scripts/zfs/migration.sh` and `scripts/zfs/migration-ean8.sh`

## Doing it

### reverse current syncing

I first verify if off2 is in sync with ovh3:
```bash
(off2)$ sudo zfs list -t snapshot zfs-hdd/off/images
...
zfs-hdd/off/images@20230220220000  1.75G      -     9.70T  -
zfs-hdd/off/images@20230221070000  1.61G      -     9.70T  -
zfs-hdd/off/images@20230221183000   232K      -     9.70T  -
```
```bash
(ovh3)$ sudo zfs list -t snapshot rpool/off/images
...
rpool/off/images@20230221070000  2.21G      -     10.1T  -
rpool/off/images@20230221183000  6.76G      -     10.1T  -
rpool/off/images@20230516083018  22.3G      -     10.1T  -
```
It's not, we miss one snapshot, so we must sync.

Sync from ovh3 (we had to use -F)
```
zfs send -i rpool/off/images@20230221183000 rpool/off/images@20230516083018 |ssh off2.openfoodfacts.org zfs recv zfs-hdd/off/images -F
```

I also see that last snapshot on ovh3 has not all modifications:

```bash
$ zfs list -po written rpool/off/images
    WRITTEN
24130245744
$ zfs get -Hr written rpool/off/images
rpool/off/images	written	22.5G	-
...
```
So I create a snapshot and redo the sync operation
```bash
TIMESTAMP=$(date +%Y%m%d%H%M%S)
zfs snapshot rpool/off/images@$TIMESTAMP
zfs send -i rpool/off/images@20230516083018 rpool/off/images@$TIMESTAMP |ssh off2.openfoodfacts.org zfs recv zfs-hdd/off/images -F
```

But after that, on ovh3 the dataset keeps continuing being written at !


I use migration.sh and wrote `scripts/zfs/migration-images.sh` and copied it to off1.

