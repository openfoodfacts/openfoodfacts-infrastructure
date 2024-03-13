# 2024-03 separate HDD on docker VMs

We have docker VMs for staging and production.
Disk are quite big. They use ext4 over a zfs in block mode (as proposed by promox).
To keep things manageable, in case we have to switch server,
I propose to split data from system. It might also help with backups.

## Staging docker

I go on proxmox interface and on 200 VM (docker-staging),

I will follow official documentation: https://pve.proxmox.com/wiki/QEMU/KVM_Virtual_Machines#qm_hard_disk

As it would be hard to move all docker data to a new disk while it's constantly changing,
I will do the reverse: move system data to the other disk.

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

We now need to create boot partition with grub, for this we will chroot:
```bash
for dir in sys proc dev; do mount --bind /$dir /mnt/new-root/$dir; done
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
UUID=0735de86-3c78-417f-b097-125585008b23 /   ext4 errors=remount-ro 0 1
...
```

and the boot option on ovh1:
```bash
# note: this could also be done in the interface
sudo qm set 200 --boot order="scsi2;ide2;net0"
```

Ask also the VM to boot on /dev/sdb1