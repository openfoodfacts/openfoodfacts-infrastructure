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


## Instable NFS


After this NFS server seems instable, and staging gets stuck while reading at files.

### Moving off backups to their own folder

It might be because a lot of datasets are exposed,
as they are under *backups* and inherit its *sharenfs* property (which is needed on backups for proxmox to push files).

So I decided to create a new dataset (acting as a parent only) off-backups and move our datasets there. I will do this on every server off1/off2/ovh3 to be consistent.
(another option was to create a backups/pve dataset, but I prefer to keep proxmox as vanilla as possible).

I comment all line in `/etc/sanoid/syncoid-arg.conf` on ovh3/off2/off1 referring to backups.

Wait for current running syncoid services to finish on all server.

Move around things on all servers:

off1:
```bash
# see what to move
zfs list -r -t filesystem -d 1 zfs-hdd/backups
# create parent
zfs create zfs-hdd/off-backups
# move
for DS in off2-pve off2-pve-nvme off2-rpool; do zfs rename zfs-hdd/backups/$DS zfs-hdd/off-backups/$DS; done
# verify
zfs list -r -t filesystem zfs-hdd/off-backups
```

off2:
```bash
# see what to move
zfs list -r -t filesystem -d 1 zfs-hdd/backups
# create parent
zfs create zfs-hdd/off-backups
# move
for DS in mongodb off1-pve off1-pve-nvme off1-rpool off2; do zfs rename zfs-hdd/backups/$DS zfs-hdd/off-backups/$DS; done
# verify
zfs list -r -t filesystem zfs-hdd/off-backups
```

ovh3:
```bash
# see what to move
zfs list -r -t filesystem -d 1 rpool/backups
# create parent
zfs create rpool/off-backups
# move
# note: keep monitoring-volumes and robotoff under backups as they need sharenfs
for DS in off1-pve off1-pve-nvme off1-raphael off1-rpool off2-nvme-pve off2-pve off2-rpool; do echo $DS; zfs rename rpool/backups/$DS rpool/off-backups/$DS; done
# verify
zfs list -r -t filesystem rpool/off-backups
```

On off1, off2 and ovh3 add off-backups to sanoid.conf.

Then wait for off-backups to have snapshots:
```bash
zfs list -t snap zfs-hdd/off-backups
```

And change syncoid config to use off-backups on all servers.
See commits [`a8210a6303bf70ea3debe8a1f4d80e3638cc6711` , `1ea7e6a2b19f53f2d7cdc56dd983faa86ed2cb8c` and `b1232edfc861b91ae39ed33461a4a298ab5c8a95`](https://github.com/openfoodfacts/openfoodfacts-infrastructure/compare/1b38ff513f8c85aa6e8e3250b0f5e1929ce5ebf7..a8210a6303bf70ea3debe8a1f4d80e3638cc6711)

Finally on ovh3 update nfs shares:
```bash
zfs unshare -a
zfs share -a
# it's down so start
systemctl restart nfs-server
```

### Moving clones out of rpool/off

The above operation did not solve the problem.
It appears that indeed the problem might not be the NFS server,
but instead the clones folders are unmounted after some times.
It might be linked to syncoid / sanoid being run.

So I decided to move those folders outside of off/rpool,
this way they are out of sanoid recursive directives.

I have to:
* rename `rpool/off/clone` to `rpool/staging-clones`
  also this is an occasion to add off/ prefix to clones,
  to prepare having more clones for opf/obf/opff etc. staging.
  (not for orgs and users as they are shared)
* change volumes on staging to point to those

On ovh3 renaming:
```bash
zfs rename rpool/off/clones rpool/staging-clones
zfs rename rpool/staging-clones/images rpool/staging-clones/off-images
zfs rename rpool/staging-clones/{,off-}products
# reset nfs shares, I'm not sure but it seems the only way to remove old shares
# is to remove this file
rm /etc/exports.d/zfs.exports
zfs share -a
systemctl reload nfs-server.service
```