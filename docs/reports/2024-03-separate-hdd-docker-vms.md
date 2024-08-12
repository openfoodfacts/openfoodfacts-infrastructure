# 2024-03 separate HDD on docker VMs

We have docker VMs for staging and production.
Disk are quite big. They use ext4 over a zfs in block mode (as proposed by proxmox).
To keep things manageable, in case we have to switch server,
I propose to split data from system. It might also help with backups.

## Staging docker

I go on proxmox interface and on 200 VM (docker-staging),

I will follow official documentation: https://pve.proxmox.com/wiki/QEMU/KVM_Virtual_Machines#qm_hard_disk

As it would be hard to move all docker data to a new disk while it's constantly changing,
I will do the reverse: move system data to the other disk.

### Check needed disk space

I have to know disk space I need. To measure space taken by docker volumes,
I struggle with `du` to finally find the problem was with nfs mounted volumes,
that some reasons are blocking processes for ever…, 
even with the `-x` flag to du (which means not to cross filesystem boundary) …
So I exclude them:
```bash
$ cd /var/lib/docker
$ du -x --exclude volumes/po_orgs --exclude volumes/po_product_images --exclude volumes/po_products --exclude volumes/po_users --exclude volumes/po_podata volumes -sh
261G    volumes
$ df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       423G  324G   80G  81% /
```
So I need a 80 to 100G file system for system (better put a bit more so 96Gb is a good idea).

### Create disk


**Important**: At this point I should have snapshoted ! (sadly, I didn't)

First I changed SCSI controller to "VirtIO SCSI single".

Added a disk that will become the root fs:
* 96 Gb
* IOthread checked
* SSD emulation checked
* checked backup (for now)

**Important**: Later I had to change to 142G, because after copy there was not enough space left…

I shutdown the server.

I changed IOThread and SSD emulation option to "on" for the original disk.

I started the VM.

(it's a good occasion to verify if all docker went up, [it was not the case](https://github.com/openfoodfacts/taxonomy-editor/pull/435)).

### Format and copy data

In the VM, format the new disk with parted,
we have to use msdos label type because it's the way we have to do it in QEMU[^msdos_label],
don't forget to add the boot flag:

[^msdos_label]: yes I did it all first with gpt label, and had to restart from scratch…

```bash
parted /dev/sdb mklabel msdos
parted /dev/sdb mkpart primary ext4 0% 100%
parted /dev/sdb set 1 boot on
parted /dev/sdb print
```

Format it: `mkfs.ext4 /dev/sdb1`

I temporarily mount the new disk on /mnt/:
```bash
mkdir /mnt/new-root
mount /dev/sdb1 /mnt/new-root
ls /mnt/new-root/  # to verify
```

Copy system:
```bash
rsync --info=progress2 -a -x --exclude=/var/lib/docker --exclude=/mnt / /mnt/new-root/
```

### Make new disk bootable

We now need to create boot partition with grub, for this we will chroot:
```bash
for dir in sys proc dev; do mount --bind /$dir /mnt/new-root/$dir; done
ls -l /mnt/new-root/{sys,proc,dev}
chroot /mnt/new-root/
grub-install /dev/sdb
update-grub
exit
```

Now we will change fstab to mount the new disk as /, on dockers-staging:
```bash
# get UUID
lsblk -o NAME,UUID
vim /etc/fstab
...
UUID=082b4523-f4d6-4d39-b5dd-48c5bdba2541 /var/lib/docker/volumes               ext4    errors=remount-ro 0       1
UUID=d011de06-4050-473e-b322-a7fddeb5e369 /   ext4 errors=remount-ro 0 1
...
```

and the boot option on ovh1:
```bash
# note: this could also be done in the interface
sudo qm set 200 --boot order="scsi2;ide0;net0"
```

Also (and I learned that the hard way), We have to remove the boot label to disk sda1,
otherwise grub will choose to boot on it, and with a contrary `/etc/fstab`, it will be a mess [^incident_on_boot]

```bash
parted /dev/sda toggle 1 boot
# verify
parted /dev/sda print
# verify we already add the boot flag to sdb, so no need to do it again.
parted /dev/sdb print
```



### Switch

A final rsync
```bash
rsync --info=progress2 -a -x --exclude=/var/lib/docker/volumes --exclude=/mnt / /mnt/new-root/
```

NOW we should have snapshoted again !

**Reboot !**

Just after reboot, we have to quickly move around volumes data so that docker can find them again. As root:
```bash
cd /var/lib/docker/volumes
mkdir oldsys
mv * oldsys
mv oldsys/var/lib/docker/volumes/* .
# a docker daemon restart can't harm
systemctl restart docker
```

Now better **reboot** again.

### Verify

Then verify every service is restarted or restart them…

On ovh1 I can verify my snapshot is there: `zfs list -t snap  rpool/vm-200-disk-0`

Then we can clean up everything in `/var/lib/docker/volumes/oldsys/`.



[^incident_on_boot] First time I reboot, I had /dev/sda1 with boot flag.
When I ssh on the VM, I wanted to move things to oldsys in the new /var/lib/docker/volumes disk.
But this immediatly remove me all /bin executables !
I had to reboot on a debian CD, use proxmox console and launch rescue mode to fix it. I was able to mount on /dev/sdb1 as it was ready, and put back things where they were, then snapshot (because I haven't before…), and try again…


## Production docker

### Getting space

#### removing wild-ecoscore container

This is an old container with metabase that was created long ago.
I will reclaim it's 14G !

I first shutdown the 111 container.

I first disable the replication to ovh3 on the container.
I then move the volume on ovh3:
```bash
zfs rename rpool/subvol-111-disk-0 rpool/backups/wild-ecoscore-111
zfs set sharenfs=off rpool/backups/wild-ecoscore-111
```

I then go to options to remove protection.

Then I use proxmox interface to remove wild-ecoscore,
purging from jobs, and removing  unreferenced disks owned by guest

#### Removing 202 replication

202 is replicated from ovh1 to ovh2 and ovh3.
This is not such a critical service to have this, while we lack disk space.

I proxmox interface, I removed the replication of 202 to ovh2.

I then verified the 202 replication data from ovh2 in zfs disk VM Disks was removed.

I'm left with:
```
rpool                     680G   211G      144K  /rpool
```

### Snapshot

I snapshot current 201 volume on two sides:
* on ovh3:
  * I go on proxmox ui, in 201 replication and schedule an immediate sync
  * as soon as it is done, on ovh3  `zfs snapshot rpool/vm-201-disk-0@2023-03-21-pre-disk-split`
  * I can verify:
    * `zfs list -r -t snap rpool/vm-201-disk-0`
* on ovh2 (through proxmox interface). it also add memory, but it's very slow (31 minutes) !

After that I got:
```
NAME                                                USED  AVAIL     REFER  MOUNTPOINT
rpool                                               757G   135G      144K  /rpool
```

It' seems a bit too thigh…

I removed a snapshot on CT 108 and CT 107…

I'm still with a lot of space used on rpool…

So I decided to remove the snapshot and go without it !

### Create disk

First I changed SCSI controller to "VirtIO SCSI single".

Added a disk that will become the root fs:
* 144 Gb
* IOthread checked
* SSD emulation checked
* checked backup (for now)

I changed IOThread and SSD emulation option to "on" for the original disk.

I shutdown the server.
I started the VM.

(it's a good occasion to verify if all docker went up, [it was not the case](https://github.com/openfoodfacts/taxonomy-editor/pull/435)).

### Format and copy data

In the VM, format the new disk with parted,
we have to use msdos label type because it's the way we have to do it in QEMU[^msdos_label],
don't forget to add the boot flag:

[^msdos_label]: yes I did it all first with gpt label, and had to restart from scratch…

```bash
lsblk  # see disks
parted /dev/sdb mklabel msdos
parted /dev/sdb mkpart primary ext4 0% 100%
parted /dev/sdb set 1 boot on
parted /dev/sdb print
```

Format it: `mkfs.ext4 /dev/sdb1`

I temporarily mount the new disk on /mnt/:
```bash
mkdir /mnt/new-root
mount /dev/sdb1 /mnt/new-root
ls /mnt/new-root/  # to verify we have a lost+found
lsblk # verify sdb1 is mounted
```

Copy system:
```bash
rsync --info=progress2 -a -x --exclude=/var/lib/docker/volumes --exclude=/mnt / /mnt/new-root/
```

### Make new disk bootable

We have to remove the boot label to disk sda1,
otherwise grub will choose to boot on it, and with a contrary `/etc/fstab`, it will be a mess

```bash
parted /dev/sda toggle 1 boot
# verify
parted /dev/sda print
# verify we already add the boot flag to sdb, so no need to do it again.
parted /dev/sdb print
```


We now need to create boot partition with grub, for this we will chroot:
```bash
for dir in sys proc dev; do mount --bind /$dir /mnt/new-root/$dir; done
ls -l /mnt/new-root/{sys,proc,dev}
chroot /mnt/new-root/
grub-install /dev/sdb
update-grub
exit
```

Now we will change fstab to mount the new disk as /, on dockers-staging:
```bash
# get UUID
lsblk -o NAME,UUID
vim /etc/fstab
...
# / was on /dev/sda1 during installation
# is now docker volumes
UUID=d0530e16-522c-4d56-8c97-1ac57b50f6b2 /var/lib/docker/volumes               ext4    errors=remount-ro 0       1
# / is sdb
UUID=0f1987db-6e22-456e-8e62-3d24d722a599 /   ext4 errors=remount-ro 0 1
...
```

and the boot option on ovh1:
```bash
# note: this could also be done in the interface
sudo qm set 201 --boot order="scsi1;ide2;net0"
```



### Switch

A final replication and snapshot on ovh3

A final rsync
```bash
rsync --info=progress2 -a -x --exclude=/var/lib/docker/volumes --exclude=/mnt / /mnt/new-root/
```

NOW we should have snapshoted again !

**Reboot !**

Just after reboot, we have to quickly move around volumes data so that docker can find them again. As root:
```bash
cd /var/lib/docker/volumes
mkdir oldsys
mv * oldsys
mv oldsys/var/lib/docker/volumes/* .
# a docker daemon restart can't harm
systemctl restart docker
```

1st time it failed again and I had to reboot on Debian cd, go in rescue mode

Now better **reboot** again.


## Monitoring docker


### Snapshot

I snapshot current 201 volume on two sides:
* on ovh3:
  * I go on proxmox ui, in 201 replication and schedule an immediate sync
  * as soon as it is done, on ovh3  `zfs snapshot rpool/vm-201-disk-0@2023-03-21-pre-disk-split`