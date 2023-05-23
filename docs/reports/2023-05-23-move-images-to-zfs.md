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

I use migration.sh and wrote `scripts/zfs/migration-images.sh` and copied it to off1.
