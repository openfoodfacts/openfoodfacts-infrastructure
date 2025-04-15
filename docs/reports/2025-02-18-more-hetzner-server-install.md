# 2025-02-18 more hetzner server install

After [Christian installed first servers in november](./2024-11-14-hetzner-server-install.md), we didn't go ahead with installing other servers…
It's time to do so !

## Adding my ssh key

On Hetzner console, to see servers you have to go in "Robot" menu.

You can put a ssh key in the [Hetzner > Robot > Server](https://robot.hetzner.com/server) > Key

## Booting in rescue mode

Go on the [Hetzner > Robot > Server](https://robot.hetzner.com/server) page,
- go in *rescue* tab, use linux rescue mode, with your key.
- Then go in *reset* tab, ask for reset

Wait the server to be alive with `watch -n 5 nc -vz x.x.x.x 22`

Then ssh into it.

## Installing OS for compute server

Login on the server in rescue mode.

lsblk shows me the different disks, there are two 1.7T nvme disks (`nvme0n1` and `nvme1n1`).
I copied the proxmox8 configuration.

Sadly, we can't install the system on ZFS with this method as it is not supported by Hetzner installimage script ([as explained on their bug tracker](https://github.com/hetzneronline/installimage/issues/36)) 

I modified the installimage as follow:
```conf
# name of drive we got thanks to lsblk
DRIVE1 nvme0n1
DRIVE2 nvme1n1

# raid level 1
SWRAID 1
SWRAIDLEVEL 1

BOOTLOADER grub

# changed hostname
HOSTNAME hetzner2.openfoodfacts.org

# we want root part to be only 256G
PART swap swap 2G
PART /boot ext3 1024M
# needed for uefi boot
PART /boot/efi  esp          256M
PART /     ext4 256G
# use bookworm latest as proposed for proxmox8
IMAGE /root/images/Debian-bookworm-latest-amd64-base.tar.gz
```
