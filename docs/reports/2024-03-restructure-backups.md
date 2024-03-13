# 2024-03 Restructure backups

## Pull off2 from ovh3

We already started having better backups,
see [Configuring snapshots and syncoid in 2023-12-08 off1 upgrade](./2023-12-08-off1-upgrade.md#configuring-snapshots-and-syncoid).

But we are still pushing synchronizations from off2 to ovh3 as root, which is bad in term of permissions.

We already have the ovh3operator created on off2.

On ovh3, test connecting with ssh:
```bash
ssh ovh3operator@off2.openfoodfacts.org
```
it works.

Verify delegation to ovh3operator
```bash
$ zfs allow zfs-hdd
---- Permissions on zfs-hdd ------------------------------------------
Local+Descendent permissions:
        user off1operator hold,send
        user ovh3operator hold,send
$ zfs allow zfs-nvme
---- Permissions on zfs-nvme -----------------------------------------
Local+Descendent permissions:
        user off1operator hold,send
        user ovh3operator hold,send
$ zfs allow rpool
---- Permissions on rpool --------------------------------------------
Local+Descendent permissions:
        user off1operator hold,send
        user ovh3operator hold,send
```

It's all we need.

I then in /etc/sanoid/syncoid-args.conf,
* I comment some lines on off2
* Wait for syncoid service to finish
* test the command manually from ovh3
* I create the lines on ovh3 syncoid-args.conf
* I wait for the sync to verify it's working

off dataset was not synced, so we have a problem, we have to sync it in a new location,
move sub datasets to it, and rename it.

```bash
syncoid --no-sync-snap --no-privilege-elevation ovh3operator@off2.openfoodfacts.org:zfs-hdd/off rpool/off-new
for sub in cache html_data images logs orgs products users;do zfs rename rpool/off/$sub rpool/off-new/$sub;done
# after stopping docker compose off-net on staging
systemctl restart nfs-server  # because it might hinder moving clones
zfs rename rpool/off/clones rpool/off-new/clones
zfs rename rpool/off rpool/off-old
zfs rename rpool/off-new rpool/off
zfs list -r rpool/off-old  # verify
# resync manually, all folders
syncoid --no-sync-snap --no-privilege-elevation --recursive ovh3operator@off2.openfoodfacts.org:zfs-hdd/off rpool/off
```

I have a problem with products as there was a old dataset of products in zfs-hdd/off/products
which have been synchronized… so I'm not able to sync again with zfs-nvme/off/products.
I will destroy the old products dataset on off2, and resync it completely on ovh3.
Before destroy I will move it temporarily to be sure !

On off2
```bash
zfs rename zfs-hdd/off/products zfs-hdd/off-products-old
```

**NOTE:** strangely this brings `/mnt/off/products` (mount point of `zfs-nvme/off/products`)
to be unavailable in off container…
leading to open food facts being unavailable…
I had to reboot the Container.
It does not bring the same problem in obf/opf/opff where folder was mounted…
I think the problem might be because `/zfs-hdd/off` was mounted in off container
and `zfs rename` touched a subdirectory that was mounted over in off container…

On ovh3
```bash
zfs rename rpool/off/products rpool/off-products-old
```

I then did the sync on ovh3:
```bash
syncoid --no-sync-snap --no-privilege-elevation --recursive ovh3operator@off2.openfoodfacts.org:zfs-nvme/off/products rpool/off/products
```

As for off-pro we have to move off-pro root:


```bash
syncoid --no-sync-snap --no-privilege-elevation ovh3operator@off2.openfoodfacts.org:zfs-hdd/off-pro rpool/off-pro-new
for sub in cache html_data images logs products ;do zfs rename rpool/off-pro/$sub rpool/off-pro-new/$sub;done
zfs rename rpool/off-pro rpool/off-pro-old
zfs rename rpool/off-pro-new rpool/off-pro
zfs list -r rpool/off-pro-old  # verify

# resync manually, all folders
syncoid --no-sync-snap --no-privilege-elevation --recursive ovh3operator@off2.openfoodfacts.org:zfs-hdd/off-pro rpool/off-pro
```

And for the rest I just continued adding pull configs and testing them manually.

New configs are in commits `5c531c2ca9306f836cde0a561ad272cf9f37851d` and `1b38ff513f8c85aa6e8e3250b0f5e1929ce5ebf7`.
