# 2026-07-01 Open Prices down

On 30/06/2026, Stephane and Christian did an intervention at the Scaleway datacenter to:
* move off1 and off2 to the new bay (where they will become scaleway-04 and scaleway-05)
* try to install a GPU on scaleway-03 and set IPMI

This required a shutdown / restart of scaleway-03.
After that Open Prices was down (it is deployed on scaleway-docker-prod-2 which is on scaleway-03)

## Analysis

The morning after, Raphaël investigated
and found that the docker volume for the postgresql was gone.
He recreated one, but this was not a good idea.

Indeed the docker volumes are a Virtiofs mount of a specific dataset,
and the postgresql volume is a different dataset (lying on nvme) mounted inside the docker volumes dataset (and thus still visible through virtiofs).
See `qm-201-virtiofs-docker-volumes` virtiofs identifier,
corresponding to `zfs-hdd/virtiofs/qm-201/docker-volumes`
mounted at `/var/lib/docker/volumes`,
and `zfs-nvme/virtiofs/qm-201-open_prices_postgres-data`
mounted at `/var/lib/docker/volumes/open_prices_postgres-data`.

The real problem was that though zfs showed the postgres data zfs dataset
as mounted (`zfs get mounted zfs-nvme/virtiofs/qm-201-open_prices_postgres-data`),
it was not visible at the mountpoint.
So we supposed that the problem was that it was mounted before the parent dataset (docker volumes,
corresponding to `zfs-hdd/virtiofs/qm-201/docker-volumes`).

Indeed it was impossible to unmount the dataset with `zfs umount` even with `-f`,
and even after unmounting the docker volumes dataset.

So there was no solution without a reboot,
but we also need to ensure that, at reboot, the mount order would be followed.

After some research (with some help from glm2.5),
we found that zfs does create a mount order based on file mount point hierarchy,
but by default it does so automatically only if the mounts are in the same zpool.
But there is a tool in linux to get them in the right order: 

## Resolution

It took a while to find the right way to do it (mainly because of some misleading statements from glm2.5 which made me ending up looking at the code of the zedlet to understand). 
I just wrote the conclusion in [Virtiofs, Important note when you mount datasets from other zpool](../explanation/software/virtiofs.md#inter-zpool-mounts)
