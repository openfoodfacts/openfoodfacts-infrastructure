# Moji - Post-installation & backup sync

## Robotoff - NFS share

We perform Robotoff DB backup in a ZFS dataset, shared using NFS between the host and the `docker-prod-2` VM.

I installed NFS server on host (moji):

```bash
apt install nfs-kernel-server
```

I shared `hdd-zfs/backups/robotoff` dataset through NFS with `docker-prod-2` VM:

```bash
zfs set sharenfs=rw=@10.3.0.200/32,no_root_squash hdd-zfs/backups/robotoff
```

On `docker-prod-2` , I created a docker volume named `robotoff_backup` :

```bash
docker volume create --driver local --opt type=nfs --opt o=addr=10.0.0.45,nolock,soft,rw --opt device=:/hdd-zfs/backups/robotoff robotoff_backup
```

`10.0.0.45` is the internal IP address of the host (osm45). 

A systemd service and timer was added and activated (in `/etc/systemd/system/robotoff_db_backup.{service,timer}` to be launched every day at 8PM.

## Snapshot with Sanoid & synchro with Syncoid

Sanoid was installed on host (osm45), and snapshots were configured [as follow](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/confs/moji/sanoid/sanoid.conf).

Next, we need to pull automatically snapshots from osm45 to ovh3 using syncoid. I created an `ovh3operator` user on moji server and [followed the instructions](https://openfoodfacts.github.io/openfoodfacts-infrastructure/sanoid/#how-to-setup-synchronization-without-using-root) to allow ovh3 to pull snapshots.

As osm45 server is not directly accessible from ovh3 (we have to jump through an OSM proxy to reach it), I used the `off` user on the OSM proxy to reach moji server.

I added the public SSH key of root@OVH3 on OSM proxy (`off` user) and on osm45 (`ovh3operator` user).

Synchronization is performed periodically by `syncoid.service` and works well with the new configuration.
