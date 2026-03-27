# 2025-02-26 Moving redis to scaleway

We have [already moved MongoDB service to scaleway](./2026-01-15-moving-mongodb-to-scaleway.md)
and as a byproduct,
we installed a scaleway-docker-prod VM
with openfoodfacts-shared-serivces deployed on it.

The goal is now to migrate redis on scaleway

## Getting data backup on scaleway-02

Currently redis and postgres are on off2,
and backed on scaleway-01.
So we need to get a backup of thos on scaleway-02.

To do this, I will also get the volumes I want from off2/pve backups on scaleway-02.
First create destination datasets and copy them from scaleway-01, to avoid charging off2
```bash
zfs create zfs-hdd/off-backups/off2-zfs-hdd
zfs create zfs-hdd/off-backups/off2-zfs-hdd/pve
zfs create zfs-hdd/off-backups/off2-zfs-nvme
zfs create zfs-hdd/off-backups/off2-zfs-nvme/pve

# redis data
time syncoid --no-sync-snap --no-privilege-elevation scaleway02operator@scaleway-01.infra.openfoodfacts.org:zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-122-disk-1 zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-122-disk-1
# postgres data
time syncoid --no-sync-snap --no-privilege-elevation scaleway02operator@scaleway-01.infra.openfoodfacts.org:zfs-nvme/off-backups/off2-zfs-nvme/pve/subvol-120-disk-0 zfs-hdd/off-backups/off2-zfs-nvme/pve/subvol-120-disk-0
```

After that I modified the syncoid configuration to fetch new data from off2.
See commit [92afa16f](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/92afa16f99f8e5aa0fadd81be9512ac95d5ac087).


## Testing Redis with backup data

On off2, Redis is installed in the proxmox container 122.

`pct config 122` shows us we have a disk for redis data:
```
mp0: zfs-hdd:subvol-122-disk-1,mp=/var/lib/redis,backup=1,mountoptions=noatime,size=5G
```
We can look at the content:
```bash
ls -l /zfs-hdd/pve/subvol-122-disk-1
```
and we can see we only have the dump.rdb file (and eventually a temporary one).

Now on scaleway-docker-prod VM we can look at `/var/lib/docker/volumes/off_shared_redisdata/_data#` and see it's the same. The db stands there, it is owned by `999:1000` (`ls -ln`)

So in theory we can use a clone of a snapshot backup of redis
to test the new redis instance on scaleway is working.
The problem is that Virtiofs does not allow to do this on a mounted Virtiofs dataset…
So we will have to use rsync.

### Rsync data

To do this:

I stop the redis container in scaleway-docker-prod:
```bash
cd /home/off/shared-org
sudo -u off docker compose stop redis
```
Remove the data:
```bash
rm -rf /var/lib/docker/volumes/off_shared_redisdata/_data/*
```

On scaleway-02 copy the data:
```
time rsync -a --info=progress2 --chown 999:1000 --delete \
  /zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-122-disk-1/.zfs/snapshot/autosnap_2026-02-26_16:00:33_hourly/ \
  /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_redisdata/_data/
# real 0m2,715s
```
It's fast !

Then restart service on scaleway-docker-prod:
```bash
cd /home/off/shared-org
sudo -u off docker compose start redis
```

### Testing

We can verify if our stream as last data (at the time of the snapshot):
```bash
sudo -u off docker compose exec redis redis-cli
127.0.0.1:6379> XINFO STREAM product_updates
...
19) "last-entry"
20) 1) "1772121552510-0"
    2)  1) "timestamp"
        2) "1772121552"
...
```
and `date -d @1772121552 -u` correspond to `Thu Feb 26 15:59:12 UTC 2026`
which is about the date of our snapshot.
So it's working properly !

## Proxying redis with stunnel

It already configured scaleway stunnel server
([commit f2c50990e](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/f2c50990e9c38322661a594b27362eede0cd0885))
while [moving mongodb](./2026-01-15-moving-mongodb-to-scaleway.md)


## Branching stunnel client to our services


We configure on off2 stunnel client ([commit cd7408cd](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/cd7408cd834af1e1d90fba2a401a9b229a4c1345))
It wast tested from current redis container on off2 using redis-cli !

We configure on off2 stunnel client ([commit 5434c20c223](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/5434c20c223428ff953ff8f9033c0436b61ed81f))
It wast tested from current mongo container on off1 using mongo client !

Grep hep me find where to add the new redis to stunnel clients:
```bash
grep -P '(213.36.253.214|proxy2).*6379' -r confs/ --include=off.conf
confs/ovh-stunnel-client/stunnel/off.conf:connect = proxy2.openfoodfacts.org:6379
confs/moji-stunnel-client/stunnel/off.conf:connect = proxy2.openfoodfacts.org:6379
confs/scaleway-stunnel-client/stunnel/off.conf:connect = 213.36.253.214:6379
```

I connected scaleway redis on ovh, using a temporary port (until migration),
and tested it using docker staging vm:
```bash
docker run --rm -ti redis:7.2-alpine redis-cli  -h 10.1.0.113 -p 6381
10.1.0.113:6381> XINFO STREAM product_updates
 1) "length"
 2) (integer) 10000000
 3) "radix-tree-keys"
 4) (integer) 375238
 5) "radix-tree-nodes"
 6) (integer) 792738
...
```

I did the same on Moji, using docker prod 2 to test it.


## Switch procedure

1. Stop new Redis:
   Log on scaleway-docker-prod:
   ```bash
   sudo -u off -i
   cd /home/off/shared-org
   docker compose stop redis
   ```
3. Stop old redis on off2, pct 122
   ```bash
   pct enter 122
   systemctl stop redis-server.service
   ```
2. Copy redis data for migration
   - On off2 as root, take a snapshot
     ```bash
     zfs snapshot zfs-hdd/pve/subvol-122-disk-1@2026-02-before-move-to-scaleway
     ```
   - On scaleway-02, as root run syncoid on this specific backup
     ```bash
     syncoid --no-sync-snap --no-privilege-elevation scaleway02operator@off2.openfoodfacts.org:zfs-hdd/pve/subvol-122-disk-1 zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-122-disk-1
     ```
   - and still on scaleway-02, as root, rsync redis data
     ```bash
     time ionice -n 0 time rsync -a --info=progress2 --chown 999:1000 --delete \
        /zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-122-disk-1/.zfs/snapshot/2026-02-before-move-to-scaleway/ \
        /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_redisdata/_data/
     # verify
     ls -l /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_redisdata/_data/
     ```
4. Migrate
   - start new redis. On scaleway-docker-prod
     ```bash
     sudo -u off -i
     cd /home/off/shared-org
     docker compose start redis
     ```
   - change redis configuration on off and [restart services](https://openfoodfacts.github.io/openfoodfacts-server/dev/how-to-release/):
     ```
     sudo -u off vim /srv/$HOSTNAME/lib/ProductOpener/Config2.pm
     ...
     $redis_url = "10.1.0.105:6379";
     ...
     sudo systemctl stop apache2 && sudo systemctl start apache2
     [[ "$HOSTNAME" = off ]] && sudo systemctl stop apache2@priority && sudo systemctl start apache2@priority
     sudo systemctl restart cloud_vision_ocr@$HOSTNAME.service minion@$HOSTNAME.service redis_listener@$HOSTNAME.service
     ```
   - IMPORTANT: verify it's working by making an edit on off, and verify products_update stream !
     - make your change
     - on scaleway-docker-prod, in `/home/off/shared-org`:
       ```bash
       sudo -u off docker compose exec redis redis-cli
       127.0.0.1:6379> XINFO STREAM product_updates
       ```
       and `date -d @<timestamp> -u` to see if it's recent one.
   - change redis configuration on all opff / obf / opf (as for oof above)
   - swap new and old redis on stunnel-client at moji
     ```bash
     # on osm45 as root
     pct enter 101
     vim /etc/stunnel/off.conf
     ...
     # swap port 27017 and 27018 in accept = 
     ...
     systemctl restart stunnel@off.service
    ```
  - check robotoff health is ok https://robotoff.openfoodfacts.org/api/v1/health
    and off-query health as well https://query.openfoodfacts.org/health
  - same as for moji on ovh stunnel-client
5. Do stuff that comes after:
   - commit stunnel client config changes and push
   - stop redis container on off2
   - celebrate :tada:


## POST-MORTEM note: openfoodfacts-auth forgotten

One week after the change, I realized that openfoodfacts-auth was using redis,
but I forgot to change its configuration during migration…

This is now done…

## Task list
2. [DONE]~~clone~~ test rsync prod redis dataset backup and use it as docker volume dataset
   * change ownership
5. [DONE] config stunnel server server on scaleway for mongo / postgres / redis
4. [DONE] config stunnel client (off2, other tunnels, search in configs)
   and verify service is accessible for off / obf / opf etc. and other services that needs it
   * [DONE] off2 --> scaleway
   * [DONE] moji --> scaleway
   * [DONE] ovh --> scaleway
6. [DONE] write switch procedure:
7. [DONE] switch !
7. [DONE] sync of redis data to scaleway-03 + hetzner (or somewhere)
8. [DOING] expose exporters of scaleway + add monitoring deployment