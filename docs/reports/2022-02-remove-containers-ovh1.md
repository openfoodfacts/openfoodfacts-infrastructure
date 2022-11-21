# 2022-02 Removing some containers on ovh1

## Backups

On datacenter we have a backup menu --> click edit you can see the policies. We only have one.
We use snapshot mode as we are on ZFS, and we use ZSTD compression.
There also we configure which mail will be notified on errors.
Some VM maybe excluded because inactive

Backups goes in the backups disk resource (NFS mount of ovh3 zpool, NFS is integrated in ZFS).

If we click on it we can see the backups.

### Backup of a machine

115 backup is a bit old.
We do a manal backup.
We go on 115, backup tab, type `snapshot`, compression `ZSTD`.

Problem: It can't acquire global lock…
We see that there are no backup since quite a long date of ovh1 machine !
We also see that backup task on ovh1 have been failing for a while ! We didn't have mail, but ovh1 mail was not sending reliabely and more over the address where to send alerts was wrong (it was that of the CA).
It seems that there is an old blocked vzdump running since 2021 !.
We had to kill a lot of processes to get all down, and then remove /var/run/vzdump.{pid,lock}

We then had to remove a backup because we where above the limit of 4 backups

We then backup, it was a bit long (25 minutes).

## Removal of a VM

**Important**:
* Ensure you have backups for the machine before removal
* stop the machine

In options we edit protection to remove "Yes" if present.
In upper bar on the machine : More -> destroy
You then check "remove from tasks"

We had a failure because it cun't umount rpool/subvol-115-disk-0.

This maybe due to mounts inside it.

```
cat mtab |grep subvol
...
10.0.0.3:/rpool/off/images-clone /rpool/subvol-115-disk-0/mnt/images nfs4 rw,relatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.0.0.1,local_lock=none,addr=10.0.0.3 0 0
10.0.0.3:/rpool/off/products-clone /rpool/subvol-115-disk-0/mnt/products nfs4 rw,relatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.0.0.1,local_lock=none,addr=10.0.0.3 0 0
...
```

umount myself:

```
umount  /rpool/subvol-115-disk-0/mnt/images
umount  /rpool/subvol-115-disk-0/mnt/products
```

we check zfs / CT volumes, there is no more 115 volume, and we see the free space on the graph.

We also removed 110 machine. It was hard because of a process in status D (uninteruptible sleep). We had to reboot OVH1.

Side Note: we see that munin is down, it's because Christian monitor it from it's own munin.

**Important** remember to report changes to  https://docs.google.com/spreadsheets/d/19RePmE_-1V_He73fpMJYukEMjPWNmav1610yjpGKfD0/edit#gid=0



## Creating a VM

Right click on ovh1 "create VM) or use the button up right.

We prefer not to reuse an ip that:
* from 100 to 200 for lxc containers
* from 200 and up fot QEMU

### Creating a QEMU VM

* use the iso in backups

