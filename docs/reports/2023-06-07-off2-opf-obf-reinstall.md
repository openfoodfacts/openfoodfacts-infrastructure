# 2023-06-07 OPF and OBF reinstall on off2

We will follow closely what we did for [opff reinstall on off2](./2023-03-14-off2-opff-reinstall.md).
Refer to it if you need more explanation on a step.


## Putting data in zfs datasets

### creating datasets

Products dataset are already there, we create the other datasets.

```bash
zfs create zfs-hdd/obf/cache
zfs create zfs-hdd/obf/html_data
zfs create zfs-hdd/obf/images
zfs create zfs-hdd/opf/cache
zfs create zfs-hdd/opf/html_data
zfs create zfs-hdd/opf/images
```

and change permissions:

```bash
sudo chown 1000:1000  /zfs-hdd/o{b,p}f/{,html_data,images,cache}
```

### adding to sanoid conf

We do it asap, as we need some snapshots to be able to use syncoid.

We edit sanoid.conf to put our new datasets with `use_template=prod_data`.

We can launch the service immediately if we want: `systemctl start sanoid.service`


### migrating root datasets on ovh3

If we want to synchronize opf and obf root dataset, they have to be created by syncing from off2.
But as they already exists on ovh3, we have to create them, move products in them, and swap the old and the new one (avoiding doing so during a sync).

#### prepare

verify which datasets exists under the old root datasets on ovh3:

```bash
$ zfs list -r rpool/opf rpool/obf
NAME                 USED  AVAIL     REFER  MOUNTPOINT
rpool/obf           12.2G  23.9T      208K  /rpool/obf
rpool/obf/products  12.2G  23.9T     2.92G  /rpool/obf/products
rpool/opf           4.20G  23.9T      208K  /rpool/opf
rpool/opf/products  4.20G  23.9T     1.12G  /rpool/opf/products
```

as expected, only products have to be moved.

#### create new target datasets
On off2:

```bash
sudo syncoid --no-sync-snap zfs-hdd/opf  root@ovh3.openfoodfacts.org:rpool/opf-new
sudo syncoid --no-sync-snap zfs-hdd/obf  root@ovh3.openfoodfacts.org:rpool/obf-new
```
it's very fast.

#### move products to new dataset and swap datasets

```bash
zfs rename rpool/opf{,-new}/products && \
zfs rename rpool/opf{,-old} && \
zfs rename rpool/opf{-new,}

zfs rename rpool/obf{,-new}/products && \
zfs rename rpool/obf{,-old} && \
zfs rename rpool/obf{-new,}
```

#### setup sync

We can now sync them regularly by editing `/etc/sanoid/syncoid-args.conf`:

```conf
# opf
--no-sync-snap zfs-hdd/opf root@ovh3.openfoodfacts.org:rpool/opf
# obf
--no-sync-snap zfs-hdd/obf root@ovh3.openfoodfacts.org:rpool/obf
```

I also added it to `sanoid.conf` ovh3, but using synced template.


### Products

They already are synced (cf. [opff reinstall on off2](./2023-03-14-off2-opff-reinstall.md#products-for-all-flavors))

### Users

We have nfs mount of the users folder of off1, and will use it


### Products images

We will do a rsync, that we will have to repeat when putting in production.

On off2 (in a screen), as root:

```bash
time rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/html/images/products  /zfs-hdd/obf/images && \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/html/images/products  /zfs-hdd/opf/images
```
this took 80 and 30 minutes.


Then sync to ovh3:

```bash
time syncoid --no-sync-snap zfs-hdd/obf/images root@ovh3.openfoodfacts.org:rpool/obf/images
time syncoid --no-sync-snap zfs-hdd/opf/images root@ovh3.openfoodfacts.org:rpool/opf/images
```

After first sync (which took took 31 and 38 min),

I added it to /etc/syncoid-args.conf
```bash
--no-sync-snap zfs-hdd/obf/images root@ovh3.openfoodfacts.org:rpool/obf/images
--no-sync-snap zfs-hdd/opf/images root@ovh3.openfoodfacts.org:rpool/opf/images
```

I also added it to `sanoid.conf` ovh3, but using synced template.


### Other data

I rsync cache data and other data on ofF2:

```bash
# cache
time rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/{build-cache,tmp,debug,new_images} /zfs-hdd/opf/cache
time rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/{build-cache,tmp,debug,new_images} /zfs-hdd/obf/cache
# other
time rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/{deleted.images,data} /zfs-hdd/opf/
time rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/{deleted.images,data} /zfs-hdd/obf/
# html/data
time rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/html/data /zfs-hdd/opf/html_data
time rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/html/data /zfs-hdd/obf/html_data
```
It took less than 3 min.

Then start the sync for cache and html_data:
```bash
for target in {opf,obf}/{cache,html_data}; do time syncoid --no-sync-snap zfs-hdd/$target root@ovh3.openfoodfacts.org:rpool/$target; done
```

Add them to `/etc/sanoid/syncoid-args.conf`

And on ovh3 add them to `sanoid.conf` with `synced_data` template

