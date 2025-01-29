# 2024-10-30 OVH3 backups

We need an intervention to change a disk on ovh3.

We still have very few backups for OVH services.

Before the operation, I want to at least have replication of OVH backups on the new MOJI server.

We previously tried to do it while keeping replication, but it does not work well.
[see 2024-09-30 ovh3 backups](./2024-09-30-ovh3-backups.md)

So here is what we are going to do:
* remove replication and let sanoid / syncoid deal with replication to ovh3
  * we will have less snapshots on the ovh1/ovh2 side and we will use a replication snapshot
    to avoid relying on a common existing snapshot made by syncoid

Note that we don't replicate between ovh1 and ovh2 because we have very few space left on disks.

## Changing sanoid / syncoid config and removing replication

First because we won't use replication anymore, we have to create the ovh3operator on ovh1 and ovh2,
and as we want to use replication snapshot, we have to use corresponding rights for ZFS,
See [Sanoid / creating operator on PROD_SERVER](../sanoid.md#creating-operator-on-prod_server)

I also add to link zfs command in /usr/bin: `ln -s /usr/sbin/zfs /usr/bin`

For each VM / CT separately I did:
* disable replication
* I didn't have to change syncoid policy on ovh1/2
* on ovh3
  * configure sanoid policy from replicated_volumes to a regular synced_data one
  * use syncoid to sync the volume and configure add the line to syncoid-args (using a specific snapshot)

I tried with CT 130 (contents) first. I tried the syncoid command manually:
```bash
syncoid --no-privilege-elevation ovh3operator@10.0.0.1:rpool/subvol-130-disk-0 rpool/subvol-130-disk-0
```
I did some less important CT and VM: 113, 140, 200 and decided to wait until next day to control everything is ok.

The day after, I did the same for CT 101, 102, 103, 104,105, 106, 108, 202 and 203 on ovh1,
and 107, 110 and 201 on ovh2.

I removed 109 120

I also removed sync of CT 107 to ovh1 (because we are nearly out of disk space) and removed the volume there.

## Syncing between ovh1 and ovh2

We have two VMs that are really important to replicate (but using syncoid) from ovh1 to ovh2.

So I [created an ovh2operator on ovh1](../sanoid.md#creating-operator-on-prod_server)

I installed the syncoid systemd service and enabled it.
Same for `sanoid_check`.

I added synced_data template to sanoid.conf to use it for synced volumes.
I removed volume 101 and 102 and manually synced them from ovh1 to ovh2.
Then I added them to `syncoid-args.conf`.

## Removing dump backups on ovh1/2

We also decided to remove dump backups on ovh1/2/3.

Going in proxmox interface, Datacenter, Backup, I disabled backups.

## Removing replication snapshots

On ovh1, ovh2, ovh3 I removed the __replicate_ snapshots.

```bash
zfs list -r -t snap -o name rpool|grep __replicate_
zfs list -r -t snap -o name rpool|grep __replicate_|xargs -n 1  zfs destroy
```

Also on osm45
```bash
zfs list -r -t snap -o name hdd-zfs/off-backups/ovh3-rpool|grep __replicate_
zfs list -r -t snap -o name hdd-zfs/off-backups/ovh3-rpool|grep __replicate_|xargs -n 1  zfs destroy
```

I did the same for vz_dump snapshots, as now backups are no more active.


## Checking syncs on osm45 (Moji)

We don't need to use a sanoid specific snapshot on moji anymore so we changes the sanoid.conf
to use --no-sync-snap option for every volumes but backups (which is not handled by sanoid on ovh3 side).

Syncs seems ok.

One day after we cleaned the old remaining syncoid snapshots on osm45:
```bash
# verify that we have snapshots after the syncoid one
zfs list hdd-zfs/off-backups/ovh3-rpool -t snap -r -o name -H|grep -A 3  @syncoid_osm45|grep -v ovh3-rpool/backups@
# clean
zfs list hdd-zfs/off-backups/ovh3-rpool -t snap -r -o name -H|grep @syncoid_osm45|grep -v ovh3-rpool/backups@|xargs -n 1 -r zfs destroy
```

And on ovh3:
```bash
# verify
zfs list rpool -t snap -r -o name -H|grep @syncoid_osm45|grep -v backups@
# destroy
zfs list rpool -t snap -r -o name -H|grep @syncoid_osm45|grep -v backups@|xargs -n 1 -r zfs destroy
```

## Related commits

Commits of configurations changes on ovh1, ovh2, ovh3:

* [feat: some more hourly snapshots on ovh1](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/fd68c17ee2e929703ec364cbffae2d9bf7861d15)
* [feat: using syncoid to sync data from ovh1/2](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/2a4a413e38827e30a844f85c3e7416fdcfd998a1)
* [feat(ovh1): sanoid install](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/9d915e0e02afbcd0ce4addd30fb7c9b9d35d5a41)
* [feat: some more hourly snapshots on ovh2](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/91d89ef5cc900776b4498a4193aee6dc4a5af075)
* [feat: sync some ovh1 volumes](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/47ecab46bcb1b11188d4fecf732ae6adec37054a)
* [fix: do not use a sync snap to sync from ovh3 anymore](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/8426727bef1ef55a2c5b233233c484b4177fdcc9)