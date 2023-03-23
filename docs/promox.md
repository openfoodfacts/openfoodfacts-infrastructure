# Proxmox

On ovh1 and ovh2 we use proxmox to manage VMs.

**TODO** this page is really incomplete !

## HTTP Reverse Proxy

The VM 101 is a http / https proxy to all services.

It has it's own bridge interface with a public facing ip.

See [Nginx reverse proxy](./nginx-reverse-proxy.md)


## Unlocking a VM

Sometimes you may get alerts in email telling backup failed on a VM because it is locked. (`CT is locked`)

This might be a temporary issue, so you should first verify in proxmox console if it's already resolved.

If not you can unlock it using this command:

```
pct unlock <vm-id>
```

## Storage

We use two type of storage: the NVME and zfs storage.
There are also mounts of zfs storage from ovh3.

**TODO** tell much more

### Adding space on a QEMU disk

following https://pve.proxmox.com/wiki/Resize_disks

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

## Creating a new VM

**TODO** (see wiki page)

## Loggin to a container or VM

Most of the time we use ssh to connect to containers and VM.

The [mkuser](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/scripts/proxmox-management/mkuser) script helps you create users using github keys.

For the happy few sudoers on the host, they can attach to containers using `lxc-attach -n <num>` where `<num>` is the VM number. This gives a root console in the container.


## Proxmox installation

Proxmox is installed from a bootable USB disk based on Proxmox VE iso, the way you would install a Debian.


## Some good practice

* when you have a specialized machine,
  try to make it so that people get in the right directory on pct enter
  Use bashrc for that (last command).

  Eg. for NGINX reverse proxy:
  `cd /etc/nginx/conf.d/`

* Default NGINX install creates sites-enabled etc. **FIXME** ask christian about it ?
