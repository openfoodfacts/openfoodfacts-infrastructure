# Preprod crash 2021 12

## What happens

* zfs storage on OVH2 was full
* this blocks the restart of two VM : *dockers (200)* and *dockers-prod (201)*

## Why this happens
* probably because of resize of partition the day before on both machine,
  this makes snapshot diverge and take much more space.
  (see [2021-12-21-disk-extension](`./2021-12-21-disk-extension.md`))
* out of space on zfs, blocks machine because proxmox needs to snapshot memory

## What was done

The same day:

* rollback VM *dockers (200)* to its snapshoted version
* removed *dockers-prod (201)* snapshot
* extension of disk space for this VM *dockers (200)* was reduced from 400G to 300G (this is still a 50G improvment over the previous size for dockers VM)

The day after:

* removed the efficientnet.tar.gz in /home/off/robotoff-ann-net as it was already untared in the ann_data folder
* hard reboot of VM *dockers (200)*
* resized partition to 300G following [previous operating mode](`./2021-12-21-disk-extension.md`)