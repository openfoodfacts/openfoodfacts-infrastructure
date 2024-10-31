# 2024-10-30 OVH3 backups

We need an intervention to change a disk on ovh3.

We still have very few backups for OVH services.

Before the operation, I want to at least have replication of OVH backups on the new MOJI server.

We previously tried to do it while keeping replication, but it does not work well.

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

We would not need to use a sanoid specific snapshot on moji anymore, but I'll leaved it like it for now !

Syncs seems ok.