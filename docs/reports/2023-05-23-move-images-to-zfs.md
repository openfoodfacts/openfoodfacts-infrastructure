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
   3. replace by a symlink that point to the synced folder on the ZFS dataset (mounted on off1)
   4. rsync again to be sure we didn't miss anything

   At the end we will have a product images folder full of symlinks.

4.  At this point we can replace move the image folder ot image.old and NFS mount the ZFS dataset as image

We have two script implementing that for products that we can transform for images. They are in `scripts/zfs/migration.sh` and `scripts/zfs/migration-ean8.sh`

## Doing it

### Verifications before reversing current syncing

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
We will suppose that it's because of `atime` (access time) which must be stored.

### Reverse current syncing

#### Configuring

On ovh3, I will use sanoid but with the synced data format:

```conf
# /etc/sanoid/sanoid.conf
…
[rpool/off/images]
  use_template=synced_data
  recursive=no
…
```

On off, I will use sanoid with normal format:

```conf
# /etc/sanoid/sanoid.conf
…
[zfs-hdd/off/images]
  use_template=prod_data
  recursive=no
…
```

And configure syncoid to replicate to ovh3

```conf
# /ect/sanoid/syncoid-args.conf
…
--no-sync-snap zfs-hdd/off/images root@ovh3.openfoodfacts.org:rpool/off/images
…
```

#### Failing

Let's try a run of syncoid:
```
syncoid --no-sync-snap zfs-hdd/off/images root@ovh3.openfoodfacts.org:rpool/off/images
NEWEST SNAPSHOT: 20230523165657
INFO: no snapshots on source newer than 20230523165657 on target. Nothing to do, not syncing.
```
So I wait until next snapshoting… (10 min later).
And it's catastrophic: OVH3 nginx is not capable of serving images anymore !
And in fact syncoid service is blocked (because of a problem on ovh3 that makes it reboot…).

This made me think I should add a TimeoutStartSec to syncoid for such case (eg. 6h).

After stoping the stalled syncoid, I wait for the next run.

It's catastrophic, OVH3 does not serve images anymore. Looking at processes I see a `zfs rollback` on `rpool/off/images` and it's normal since syncoid tries to put it on last snapshot before syncing. But in the meantime, NGINX does not have access to images… and it seems to take a long time to happen.

#### Disabling atime on ovh3

I decided to disable atime on ovh3 to see if it make the writes stops.

On ovh3 ([useful resource](https://www.unixtutorial.org/zfs-performance-basics-disable-atime/)):

```bash
$ zfs set atime=off rpool/off/images
$ # verifying
$ zfs get atime rpool/off/images
NAME              PROPERTY  VALUE  SOURCE
rpool/off/images  atime     off    local
$ mount |grep rpool/off/images
rpool/off/images on /rpool/off/images type zfs (rw,noatime,xattr,noacl)
```

I then take a snapshot:
```bash
TIMESTAMP=$(date +%Y%m%d%H%M%S)
zfs snapshot rpool/off/images@$TIMESTAMP
```

Now it seems nothing is written anymore on the disk:
```bash
$ zfs list -po written rpool/off/images
WRITTEN
      0
```

So the guess about atime was right.

I synced back to off2:

```
zfs send -i rpool/off/images@20230523165657 rpool/off/images@20230531083016 |ssh off2.openfoodfacts.org zfs recv zfs-hdd/off/images -F
```

#### syncing with syncoid

Now that we have a stable ZFS on ovh3 we can activate the syncoid sync.

### NFS Mount off2 ZFS dataset on off1

Let's mount the images images ZFS volume from off2 to off1.

I first install nfs server on off2 and enable nfs sharing on my dataset:

```bash
apt install nfs-kernel-server
```

```bash
zfs set sharenfs="rw=@10.0.0.1/32" zfs-hdd/off/images
```

Then on off1,

To install NFS, I add to update the sources list in `/etc/apt/sources.list` and replace `fr2.ftp.debian.org` by `archive.debian.org`

Then
```
apt update
apt install nfs-common
```

Trying to mount
```bash
mkdir /mnt/off2
mkdir /mnt/off2/off-images
mount -t nfs -o rw "10.0.0.2:/zfs-hdd/off/images"  /mnt/off2/off-images
ls /mnt/off2/off-images
```

Adding to `/etc/fstab`:
```bash
…
# off2 NFS mounts
10.0.0.2:/zfs-hdd/off/images    /mnt/off2/off-images    nfs     rw,nolock,nofail      0       0
…
```

### Testing rsync

Doing rsync manually for one folder to see the time it takes. Taking some 3?? code. It shows it was fast enough on second pass.

### Running script

I use migration.sh and wrote `scripts/zfs/migration-images.sh` and copied it to off1.

Running it works fine. But it had to be relaunched several time because sometime rsync did end up with non zero error.

EAN8 are the longest to migrate due to their sequentiality.

It took around 6 days.

### Switching old folder for new folder

EAN8 folders continually get created, so I ended up with a single command to do last syncs and change the link to the NFS mount:
```bash
./migration-images.sh && \
./migration-images.sh && \
unlink /srv/off/html/images/products && \
ln -s /mnt/off2/off-images/products /srv/off/html/images/products
```

and do a last check that we have no non migrated directory left:
```bash
find /srv2/off/html/images/products.old/ -maxdepth 1 -type d -not -name '*.old'
```