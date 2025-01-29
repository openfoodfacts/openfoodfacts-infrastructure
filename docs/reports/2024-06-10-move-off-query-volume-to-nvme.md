# Move off query volume to NVME

On off1, the off-query container (115) has a docker volume mounted on the zfs-hdd:

mp0: zfs-hdd:subvol-115-disk-1,mp=/var/lib/docker/volumes,backup=1,size=200G

We want to move it to use NVME instead.

## Adding a mount point on zfs-nvme

I use the Proxmox web interface, in the Resources tab, I click "Add" and "Mount point"
I set the storage to zfs-nvme and put the same size (200 Gb) as the existing volume on zfs-hdd (although most of it is unused, so we could reduce it).
It is initially mounted at `/var/lib/docker/volumes-copy` to be able to copy the old data at `/var/lib/docker/volumes`

Note: to add a mount point, we first need to remove the protection in the Options tab.

This results in this mount point:

mp1: zfs-nvme:subvol-115-disk-0,mp=/var/lib/docker/volumes-copy,backup=1,size=200G

## Initial copy of docker volume

While off-query is running, we do a first initial copy:

```bash
root@off-query:/var/lib/docker# time rsync -av volumes/ volumes-copy/ --delete
```

It takes 25 minutes to copy 29 Gb, which seems very slow...

## Unwanted reboot of off1

In the minutes following the end of the copy, the off1 host rebooted by itself!

## Second copy of docker volume

We stop off-query on container 115:

```bash
root@off-query:/home/off/off-query-org# docker ps
CONTAINER ID   IMAGE                                                                                    COMMAND                  CREATED      STATUS          PORTS                                       NAMES
fc762df2e0d9   ghcr.io/openfoodfacts/openfoodfacts-query:sha-7347d944245cc17af4a87b3e704e01c1d0aa7575   "docker-entrypoint.s…"   6 days ago   Up 40 minutes   0.0.0.0:5511->5510/tcp, :::5511->5510/tcp   off-query-query-1
a009d86d0656   postgres:12-alpine                                                                       "docker-entrypoint.s…"   6 days ago   Up 50 minutes   5432/tcp                                    off-query-query_postgres-1
root@off-query:/home/off/off-query-org# docker compose stop
[+] Stopping 2/2
 ✔ Container off-query-query-1           Stopped                                                          10.7s
 ✔ Container off-query-query_postgres-1  Stopped                                                           0.4s
root@off-query:/home/off/off-query-org# docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

Then we rsync the files again, and it still takes 24 minutes...

```bash
root@off-query:/var/lib/docker# time rsync -av volumes/ volumes-copy/ --delete

sent 95,432,268,044 bytes  received 6,940 bytes  66,111,724.96 bytes/sec
total size is 95,464,577,931  speedup is 1.00

real 24m3.366s
user 1m16.587s
sys 3m11.589s
```

## Second unwanted reboot of off1

In the minutes following the end of the copy, the off1 host rebooted by itself again!

## Switch volumes

On the off1 host, I edit /etc/pve/lxc/115.conf to switch the volumes

mp0: zfs-hdd:subvol-115-disk-1,mp=/var/lib/docker/volumes,backup=1,size=200G
mp1: zfs-nvme:subvol-115-disk-0,mp=/var/lib/docker/volumes-copy,backup=1,size=200G

becomes:

mp0: zfs-hdd:subvol-115-disk-1,mp=/var/lib/docker/volumes-old,backup=1,size=200G
mp1: zfs-nvme:subvol-115-disk-0,mp=/var/lib/docker/volumes,backup=1,size=200G

## Reboot the container

I reboot the container, and verify that off-query works, from my laptop:

```bash
curl -d '[{"$match": {"countries_tags": "en:north-korea"}},{"$group":{"_id":"$brands_tags"}}]' -H "Content-Type: application/json" https://query.openfoodfacts.org/aggregate
[{"_id":"alnatura","count":"1"},{"_id":"balconi","count":"1"},{"_id":"beretta","count":"1"},{"_id":"frankly-juice","count":"1"},{"_id":"great-value","count":"1"},{"_id":"hungry-planet","count":"1"},{"_id":"jinga","count":"1"},{"_id":"tost","count":"1"},{"_id":"u","count":"1"}]
```

## Detach old volume on zfs-hdd

In the Proxmox interface, I detach the old volume, reboot the container, and check that off-query works fine.

## Add back the protection on container 115

