# 2023-08-31 OFF2 products snapshots clean

We had an inode alert problem on off2 `zfs-nvme` ZFS pool from munin (in fact this is not a problem in ZFS itself) which in facts showed a disk space error on `zfs-nvme` ZFS pool.

Raphaël did some cleaning of snapshots to recover space.

Christian Quest signals that the snapshot_purge script on off2 (running thanks to cron) was not working correctly since it was targeting `zfs-hdd` instead off `zfs-nvme` for `off/products`.
I forgot to change that when I moved the dataset to zfs-nvme during [off install on off2](./2023-07-off2-off-reinstall.md).

It's also the occasion to stop it on opf and obf dataset and do some cleanup.


## Modifying the script

I modified the snapshot_purge script, rewrite it using a function, to be able to target the right ZFS pool depending on the dataset. I also removed the purge on opf and obf as we don't need it anymore (handled by sanoid).

I then launched it manually to verify it was working as expected.

## Purging snapshots for opf and obf

It's also the occasion to do some cleanup.

I used commands like:
```bash
# verify
zfs list -t snap zfs-hdd/opf/products -o name | grep '2023070[2-5]'
# remove
zfs list -t snap zfs-hdd/opf/products -o name | grep '2023070[2-5]'|xargs --verbose -n 1 zfs destroy
```
to selectively destroy old snpashots and only keep a few.

## Removing atime

Christian also reported that atime was on, while it might hinder performance. I turned it off on all products datasets:

```bash
zfs set atime=off zfs-nvme/off/products
zfs set atime=off zfs-nvme/off-pro/products
zfs set atime=off zfs-hdd/obf/products
zfs set atime=off zfs-hdd/opf/products
zfs set atime=off zfs-hdd/opff/products
```