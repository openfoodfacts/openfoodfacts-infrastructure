# Disk extension for preprod and containers prod (ovh2)

We got alerts on low disk space on preprod VM (dockers (200) on ovh2)

We added disk space in proxmox to this machine and the container machine but we still add to make it available on the system side.

## Extending partition size

This is the commands we run to make it happens.

Install tools:

```
apt install parted etckeeper
```

The swap partition is after the main partition, so we will have to remove it, resize main partition and recreate it.

Turn swap off:
```
swapoff -a
```

Edit partition.

```
parted /dev/sda
# change unit to sectors
(parted) u
Unit?  [compact]? s
# print partition table
(parted) p
# note tha swap partition is to 534872062 536868863 (1996802 sectores in size)
# remove swap partitions
(parted) rm 5
(parted) rm 2
# print to check
# resize partition 1, leaving space for swap
r(parted) esizepart 1 -1996802
# recreate swap
(parted) mkpart
Partition type?  primary/extended? primary
File system type?  [ext2]? linux-swap
Start? 836864000
End? -1s
(parted) quit
```

> :pencil: Note:
> 1. we switch units to sectors because
>    it helps having better aligned partitions
>    (by multiples of 2048 in this case)
> 2. The swap partition was on an extended partition,
>    but we put it back as a simple partition

We recreated swap, now we have to format it:
```
format swap
mkswap /dev/sda2
```

show new uids:
```
blkid

/dev/sda1: UUID="082b4523-f4d6-4d39-b5dd-48c5bdba2541" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="1a39b366-01"
/dev/sr0: BLOCK_SIZE="2048" UUID="2021-08-14-10-10-00-00" LABEL="Debian 11.0.0 amd64 n" TYPE="iso9660" PTUUID="3c15dbf8" PTTYPE="dos"
/dev/sda2: UUID="f8e99f04-88eb-4550-9308-10a470175e45" TYPE="swap" PARTUUID="1a39b366-02"
```

Change /etc/fstab accordingly (`sda1` UUID did not change, only swap changed):

```
# / was on /dev/sda1 during installation
UUID=082b4523-f4d6-4d39-b5dd-48c5bdba2541 /               ext4    errors=remount-ro 0       1
# swap was on /dev/sda2 during installation
UUID=f8e99f04-88eb-4550-9308-10a470175e45 none            swap    sw              0       0
```


We should have booked our operation in etckeeper (not done actualy, etckeeper was not yet installed)
```
etckeeper commit "changed partition size
```

Now we resized the partition, but we have to resize the filesystem. Let's resize sda1:
```
resize2fs /dev/sda1
```

Reactivate swap:
```
swapon -a
```

Let's see our changes:

```
df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       392G  223G  151G  60% /
```