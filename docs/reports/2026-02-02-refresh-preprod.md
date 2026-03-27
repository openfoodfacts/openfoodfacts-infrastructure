# 2026-02-02 refresh preprod

We need to refresh products in preprod.

This means:
* refreshing MongoDB
* refreshing products clones

* TODO: refreshing off query ?

## Refreshing products clones

I logged on docker staging VM as off, and run:
```bash
cd /home/off/off-net
docker compose stop
```

I logged on OVH3 as root and run:
```bash
/opt/openfoodfacts-infrastructure/scripts/ovh3/maj-clones-nfs-VM-dockers.sh
```

then back in the docker staging VM:
```bash
docker compose start
```

## Refreshing MongoDB

On OVH3 as root I can see what was the origin of the products clone, and the snapshot time:
```bash
 zfs get origin rpool/staging-clones/off-products
NAME                               PROPERTY  VALUE                                                  SOURCE
rpool/staging-clones/off-products  origin    rpool/off/products@autosnap_2026-02-02_00:01:49_daily  -
```

So I will take the corresponding snapshot for mongodb data,
which on OVH3 are in `/rpool/off-backups/off1-pve-nvme/subvol-102-disk-0/`
```bash
# find corresponding backup
zfs list -t snap rpool/off-backups/off1-pve-nvme/subvol-102-disk-0|grep 2026-02-02_00
  rpool/off-backups/off1-pve-nvme/subvol-102-disk-0@autosnap_2026-02-02_00:00:38_daily    3.92G    
```

Going on staging docker VM as off, I stop the mongodb.
```bash
cd shared-net
docker compose stop mongodb
```

I also checked space is sufficient:
```
df -h /var/lib/docker/volumes
  Filesystem      Size  Used Avail Use% Mounted on
  /dev/sda1       423G  285G  118G  71% /var/lib/docker/volumes
du -sh /var/lib/docker/volumes/off_shared_mongodb_data/_data/
```

Now I rsync data from OVH3, for this I use `ssh -A` to connect to OVH3,
and then
```bash
# preserve env to SSH AGENT
sudo -E bash
# rsync with proxyjump
# beware to use db/ in the origin !
rsync -e 'ssh -J 10.0.0.1' -a --chown 999:999 --delete --info=progress2 /rpool/off-backups/off1-pve-nvme/subvol-102-disk-0/.zfs/snapshot/autosnap_2026-02-02_00:00:38_daily/db/ 10.1.0.200:/var/lib/docker/volumes/off_shared_mongodb_data/_data/
```

I tried to speed things a bit, by on OVH3 and on off staging VM,
getting rsync process and doing a `ionice -n 0 -p <pid>`
but it's not very fast (around 12MB/s).
It took 50 minutes…

Then restart the service on the docker staging VM, as off:
```bash
cd /home/off/shared-net
docker compose start mongodb
```


Note: it should be possible to use the same technic to update postgresql for off-query…