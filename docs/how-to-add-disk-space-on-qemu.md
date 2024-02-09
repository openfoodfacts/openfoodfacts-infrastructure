# How to add disk space on a Qemu VM

Sometimes you need to add space to a qemu VM disk.

Remember to try first to clean unneaded file if possible !

Also check the available space on the host.

Use NFS mount of a directory (eg from ovh3) for backups.

This doc is following https://pve.proxmox.com/wiki/Resize_disks

## Without swap

Example: adding 90GB on VM for docker prod (201) and disk scsi0

On host: `sudo qm resize 201 scsi0 +90G`

On VM:
```bash
parted /dev/sda
(parted) print
...
Number  Start   End    Size   Type     File system  Flags
 1      1049kB  557GB  557GB  primary  ext4         boot
...
(parted) resizepart 1 
Warning: Partition /dev/sda1 is being used. Are you sure you want to continue?
Yes/No? y
End?  [557GB]? 100%
(parted) p
...
Number  Start   End    Size   Type     File system  Flags
 1      1049kB  672GB  672GB  primary  ext4         boot
...
(parted) quit

sudo resize2fs /dev/sda1
...
The filesystem on /dev/sda1 is now 164101888 (4k) blocks long.

df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       616G  363G  225G  62% /
```

## When we have swap

Example: adding 8GB on VM for monitoring (203) and disk scsi0

On host: `sudo qm resize 203 scsi0 +8G`

On VM:
```bash
sudo parted /dev/sda
(parted) print
Model: QEMU QEMU HARDDISK (scsi)
Disk /dev/sda: 42,9GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags: 

Number  Start   End     Size    Type      File system     Flags
 1      1049kB  33,3GB  33,3GB  primary   ext4            boot
 2      33,3GB  34,4GB  1022MB  extended
 5      33,3GB  34,4GB  1022MB  logical   linux-swap(v1)
 (parted) quit
```

We have a problem because of swap. We must deactivate swap, remove swap partition and extended partition, augment our main partition, recreate extended and swap partition !

```bash
# deactivate swap
$ sudo swapoff -a
# remove partition in parted, augment main partition, recreate them
$ sudo parted /dev/sda
(parted) rm 5
(parted) rm 2
(parted) print
...
Number  Start   End     Size    Type     File system  Flags
 1      1049kB  33,3GB  33,3GB  primary  ext4         boot
...
(parted) help resizepart
(parted) resizepart 1 41,3GB
(parted) mkpart extended
Start? 41,3GB
End? 100%
(parted) mkpart logical linux-swap 41,3GB 100%
(parted) quit
# resize partition
$ sudo resize2fs /dev/sda1
resize2fs 1.46.2 (28-Feb-2021)
Filesystem at /dev/sda1 is mounted on /; on-line resizing required
old_desc_blocks = 4, new_desc_blocks = 5
The filesystem on /dev/sda1 is now 10082751 (4k) blocks long.
```

Now we have to re-enable swap, but UUID for partition have changed, so we have to edit `/etc/fstab` first.

```bash
# prepare swap
$ sudo mkswap /dev/sda5
Setting up swapspace version 1, size = 1,5 GiB (1648357376 bytes)
no label, UUID=431b8e8e-0691-471c-be8b-2c1039321142
# edit /etc/fstab to point to new UUID
$ sudo vim /etc/fstab
...
# swap was on /dev/sda5 during installation
UUID=431b8e8e-0691-471c-be8b-2c1039321142 none            swap    sw              0       0
/dev/sr0        /media/cdrom0   udf,iso9660 user,noauto     0       0
...
# tell systemd
$ sudo systemctl daemon-reload
# remount swap
sudo swapon -a

```
