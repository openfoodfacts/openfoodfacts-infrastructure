# 2024-09-30 OVH3 backups (wrong approach)


**VERY IMPORTANT:** this approach does not work and at the time of writing, we are on the way to change the way we do it.


We need an intervention to change a disk on ovh3.

We still have very few backups for OVH services.

Before the operation, I want to at least have replication of OVH backups on the new MOJI server.

Ideally I would like to use sanoid for every kind of backups, but I don't want to disrupt the current setup, as I don't have the time to.

What I wanted to do:
* add sanoid managed snapshots to current volumes replications of ovh1 / ovh2 containers and VMs
* add sanoid managed snapshots to current volumes ovh3 containers + add a backup of ovh3 system (it's not on ZFS)
* synchronize all those ZFS to MOJI, it may need some tweaking because of the replication snapshot, which should not be replicated.

This is not feasible ! Because of the replication. The replication must start from last replication snapshot and cannot be done in reverse.


What we can do instead:
* add sanoid snapshots on the ovh1 / ovh2 servers
* let replication of the container sync those snapshots to ovh3
* keep very few snapshots (1 or 2) on the ovh1/ ovh2 side (we have very few space left)
* keep snapshots for longer on the ovh3 side

## Moving replication to a pve sub dataset (abandonned)

**NOTE:** finally **not done**, because I didn't succeed to make it work, and was not really confident about the procedure.

Currently we have a replication landing in `/rpool`, 
this is annoying because it does not enable to configure sanoid
using recursive property (which would also ensure new volumes are under sanoid control).
So I would like to move them to pve.


To do this:
- first, 106 replication was stalled for a long time, I deleted the replication job and re-created it.
- Using the interface, I first disabled replication of all vm containers to ovh3.
  It can also be done using `pvesr disable <id>`
- I also stopped the two containers on ovh3 (100 (Munin) and 150 (gdrive-backup)).

- I then created a new dataset: `zfs create rpool/pve`
- Then I changed  `/etc/pve/storage.cfg` to change the pool and mountpoint of the rpool storage
- I tried to move a first replication by using `zfs rename` to move a subvol from `rpool` to `rpool/pve` and then re-enabled the replication… but it failed with a zfs allow/unallow error. 
- As I was not able to understand the error (there was no particular allowed user before (as showned by `zfs allow rpool`)), **I stepped back**:
  - disable replication on the container where I did re-enabled it
  - rename the volume back to a child of `rpool`
  - restored `/etc/pve/storage.cfg` to its original state



## Adding sanoid snapshots to replicated volumes

## Adding sanoid on ovh1 and ovh2

I installed sanoid using the .deb that was on ovh3:
```bash
apt install libcapture-tiny-perl libconfig-inifiles-perl pv lzop mbuffer
dpkg -i /opt/sanoid_2.2.0_all.deb
```

I then:
* created the email on failure unit
* personalized the sanoid systemctl unit

```bash
cd /opt/openfoodfacts-infrastructure/confs/$HOSTNAME
mkdir -p systemd/system
cd systemd/system
ln -s ../../../common/systemd/system/email-failures\@.service .
ln -s ../../../common/systemd/system/sanoid.service.d .

ln -s /opt/openfoodfacts-infrastructure/confs/$HOSTNAME/systemd/system/email-failures\@.service /etc/systemd/system
ln -s /opt/openfoodfacts-infrastructure/confs/$HOSTNAME/systemd/system/sanoid.service.d /etc/systemd/system
systemctl daemon-reload
```

Then I added the sanoid.conf telling to snapshot the volumes but keeping only 2 snapshots
and snapshot once an hour.

Then we activate:
```bash
ln -s /opt/openfoodfacts-infrastructure/confs/$HOSTNAME/sanoid/sanoid.conf /etc/sanoid/
systemctl enable --now sanoid.timer
```

## Configuring sanoid on ovh3

On ovh3 we want to keep more snapshots than on ovh1 and ovh2.
So we configure sanoid to do so.

## Syncing to MOJI

On Moji, we don't currently sync data from ovh3.

I [setup an operator account](../sanoid.md#how-to-setup-synchronization-without-using-root) on ovh3 for moji.

Created the syncoid-args.conf file.

I did a first sync using:
```bash
grep -v "^#" syncoid-args.conf | while read -a sync_args;do [[ -n "$sync_args" ]] && time syncoid  "${sync_args[@]}" </dev/null;done
```

Setup syncoid service and timer, and enable them.

## Side fix: fixing vm 200 replication

VM 200 (docker staging) was stalled on ovh1.

I tried to remove the replication job but it failed.
To remove it I did:
`pvesr delete 200-0 -force`
and it worked.

I then recreated the replication job.

## Side fix: removing old volumes

There are volumes remaining on ovh3 of containers that were deleted.

To get an idea of the container it was from, I can cat the `/etc/hostname`. 
For example, for container 112:
```bash
cat /rpool/subvol-112-disk-0/etc/hostname 
mongo2
```

```bash
for num in 109 115 116 117 119 120 122;do echo $num; cat /rpool/subvol-$num-disk-0/etc/hostname;done
109
slack
115
robotoff-dev
116
mongo-dev
117
tensorflow-xp
119
robotoff-net
120
impact-estimator
122
off-net2
``

I did destroy the following volumes:
```bash
# slack
zfs destroy rpool/subvol-109-disk-0 -r
# mongo2
zfs destroy rpool/subvol-112-disk-0 -r
# robotoff-dev
zfs destroy rpool/subvol-115-disk-0 -r
# mongo-dev
zfs destroy rpool/subvol-116-disk-0 -r
# tensorflow-xp
zfs destroy rpool/subvol-117-disk-0 -r
# robotoff-net
zfs destroy rpool/subvol-119-disk-0 -r
# impact estimator
zfs destroy rpool/subvol-120-disk-0 -r
# off-net2
zfs destroy rpool/subvol-122-disk-0 -r
```

