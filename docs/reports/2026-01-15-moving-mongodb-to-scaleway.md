# 2025-01-15 Moving mongoDB to scaleway

We are moving MongoDB service to scaleway.

I decided to use docker compose deployement of off-shared service.

This is because, as already said [in this dicussion](https://github.com/openfoodfacts/openfoodfacts-infrastructure/discussions/586):
1. we use an old version, so if we want to deploy it on a recent proxmox we would need to do it in a VM (and not a container), while docker compose is feasible as it has less dependency on kernel (does not need to run system services as opposed to a container)
2. it's already running smoothly in staging and it makes things more consistent
3. thanks to virtiofs, docker volume can now be ZFS datasets and that's nice for backups, accessibility and so on

And because of this I decided to also deploy postgres and redis (though data migrations would be phased).

We also have the chance that current mongo has a separated volume for data (`subvol-102-disk-0`) (thanks to myself from the past). We might have to move things around (because instead of db/ we should have directly the data) and change owner, but that's a fast operation.

## Deploying scaleway docker prod

### Preparing scaleway docker prod

I just need to add the ZFS dataset for mongoDB data `off_shared_mongodb_data`
(I want to isolate them). We create it on nvme,
but we mount it at the right place so that it is visible in the VM

I will do the same for the redis and postgres data volume: `off_shared_pg_data`
`off_shared_redis_data` because I need both on SSD.

I did this setting using ansible with tags zfs
`ansible-playbook sites/proxmox-node.yml -l scaleway-02 --tags zfs`

I verified that the volume is visible and writable in the VM.

### Changing deploy script


I did:
- create a private key (`ssh-keygen -t ed25519 -C "root+off-shared-prod-key@openfoodfacts.org" -f off-shared-prod-key`)
- add it to off-passworld keepassX
- add a private key to github settings shared-org
- the public key will be added to ss_public_keys for continuous deployment role in `ansible/host_vars/scaleway-docker-prod/docker.yml` and run `ansible-playbook sites/docker_vm.yml -l scaleway-docker-prod --tags cd`

I also took the opportunity to add POSTGRES_PASSWORD using the one in production,
and add a PG_BOOTSTRAP_PASSWORD (randomly generated)

I also have to understand how to setup some variables.

On the current MongoDB container, I use `systemctl cat mongod.service`
to see that conf is in `/etc/default/mongod` and `/etc/mongod.conf`
and there are no real fine tunning, except a `MONGODB_CONFIG_OVERRIDE_NOFORK=1`
directly in the service definition.

See https://github.com/openfoodfacts/openfoodfacts-shared-services/pull/23 for the new deploy action.

## Deploying stunnel on the reverse proxy

We will need stunnel server so that services on off1/off2 as well on ovh / hetzner, etc.
connects to mongodb and redis.

This is not currently implemented in ansible so we added it.

It was quite easy.

We then configure the stunnel for mongodb, redis and postgres.


## Post-Mortem Note: on wrong volume name created (with a ZFS dataset)

I first created the volume with wrong name (redis_data instead of redisdata).

I fix that by editing in `ansible/host_vars/scaleway-02/proxmox.yml`,
adding:
```yaml
  - name: zfs-nvme/virtiofs/qm-200-off_shared_redis_data
    state: absent
  - name: zfs-nvme/virtiofs/qm-200-off_shared_redisdata
    properties:
      # we need to mount it in the right place for docker in the VM
      mountpoint: /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_redisdata
```
and replaying ``ansible-playbook sites/proxmox-node.yml -l scaleway-02 --tags zfs`

Still the deployment was failing with:
```
off_shared_redisdata/_data': failed to mount local volume: mount /srv/off/docker_data/off_shared_redisdata:/var/lib/docker/volumes/off_shared_redisdata/_data, flags: 0x1000: no such file or directory
```
This is because it might have initialized it before I mount the new ZFS (John did a commit in between).

To deal with it, `scaleway-docker-prod`:
```
# volume exists
$ docker volume list |grep off_shared_redisdata
local     off_shared_redisdata
# first try to remove
$ docker volume rm off_shared_redisdata
Error response from daemon: remove off_shared_redisdata: umount /var/lib/docker/volumes/off_shared_redisdata/_data, flags: 0x2: no such file or directory
# create the _data folder to make docker happy (otherwise it will refuse to remove the volume)
$ mkdir -p /var/lib/docker/volumes/off_shared_redisdata/_data
# remove the volume (it will fail because it can't remove the parent folder, but it's ok)
$ docker volume rm off_shared_redisdata
# it's not there anymore
$ docker volume list |grep off_shared_redisdata
# stop here, I will let the deploy script re-create it
```
We also have a similar yet different problem with pg_data volume (because of a if condition, we created it as if on staging where it is deported, while it should not).
So we apply the same fix.


## Testing MongoDB with backup data

### Trying the ZFS clone approach

My idea is to use the synced mongodb dataset backup,
clone it and use it in place of the current dataset.

So it should go like
1. stopped mongodb container on scaleway-docker-prod and remove it
2. move the current dataset corresponding to mongodb data and it's mountpoint.
3. create the clone of mongodb backup dataset and mount it in place of the old volume
4. restart mongodb container

But the problem is that step 2 does not work.
We need to unmount the volume to rename it, but it fails.

`zfs unmount zfs-nvme/virtiofs/qm-200-off_shared_mongodb_data` was giving
cannot unmount '/zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_mongodb_data': pool or dataset is busy.

`fuser /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_mongodb_data` told me it is hold by process 31711 which is the `/usr/libexec/virtiofsd` process holding it
(although the process acts on an upper folder).
From inside the VM, the `fuser /var/lib/docker/volumes/off_shared_mongodb_data` does not give any process.

I nevertheless tried `docker volume rm off_shared_mongodb_data`,

But I still can umount the zfs dataset.
I did a `kill -s SIGHUP 31711` but it killed the virtiofs process… (:bomb: I's a BAD IDEA !)
(also [it seems to be intended](https://gitlab.com/virtio-fs/virtiofsd/-/blob/89a24d1eb57d20b497c53a11cbf60a79b5655de4/src/main.rs#L541))
And now a `ls on the /var/lib/docker volume` in the VM is broken…
I had to do a stop (shutdown or restart where not working) and start the VM.
It makes all website down for some time…

(Note: I also tried a `sync; echo 3 > /proc/sys/vm/drop_caches` in the VM but it does not allow the unmounting either)

After reboot the dataset is unmounted, but at a very unconfortable cost of a production downtime.
This is because the same VM host auth.openfoodfacts.org (keycloak) which is now central to our operations…

So this is a warning that using virtiofs with a VM does not allow to do dataset manipulation while
the VM is up, it is something we must bare in mind !

This lead me to prefer a rsync based migration (using the local copy), than a syncoid one
(if that proves fast enough).

### Using rsync to test

First I shutdown the container in the VM (as off):
`docker compose stop mongodb`
and cleanup data (as root) (:warning: think twice before copy/paste!):
`rm -rf /var/lib/docker/volumes/off_shared_mongodb_data/_data/*`

So I will mount use a snapshot of my MongoDB backup but just to sync it on my current dataset.

I need launched mongodb container once to see the user id it will use for files.
After inspection, it uses `999:999`
(seen from inside the VM or from outside, as opposed to LXC, there is no id translation with VMs).

Indeed `/zfs-hdd/off-backups/off1-zfs-nvme/pve/subvol-102-disk-0/db/` as very different identifiers.

I can access snapshots directly thanks to the `.zfs/snapshot` folder at the root of the dataset.

I will use the penultimate snapshot.

So on the host I simply run:

```bash
time rsync -a --info=progress2 --chown 999:999 --delete \
  /zfs-hdd/off-backups/off1-zfs-nvme/pve/subvol-102-disk-0/.zfs/snapshot/autosnap_2026-01-29_13:00:10_hourly/db/ \
  /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_mongodb_data/_data/

 59.709.905.821 100%   78,70MB/s    0:12:03 (xfr#678, to-chk=0/682)  

real	12m3,710s
user	0m26,351s
sys	1m40,440s
```
I then rsync to the next snapshot (one hour later), to have a feeling of how much time it takes:

```bash
time rsync -a --info=progress2 --chown 999:999  --delete /zfs-hdd/off-backups/off1-zfs-nvme/pve/subvol-102-disk-0/.zfs/snapshot/autosnap_2026-01-29_14\:00\:33_hourly/db/   /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_mongodb_data/_data/

 46.586.665.782  78%   70,04MB/s    0:10:34 (xfr#186, to-chk=0/681)  

real	10m34,432s
user	0m20,231s
sys	1m16,518s
```

So it took as much time as the first copy… I just hope, on a 10 minutes stop it will be faster !
Still a 10 minutes down is acceptable.

### Testing

I restart the container in scaleway-docker-prod VM,
and try it:

```
docker compose exec mongodb mongo

show dbs
admin     0.000GB
config    0.004GB
local     0.000GB
obf       0.420GB
off      48.599GB
off-pro   5.744GB
ofsf      0.063GB
opf       0.172GB
opff      0.109GB
test      0.000GB
> show collections
orgs
products
products_obsolete
products_tags
recent_changes
> db.products.count()
4282169
> db.products_obsolete.count()
27822
> db.products_tags.count()
3026949
> db.recent_changes.count()
35435116
```

This all seems consistent.

## Modifying scaleway-docker-prod VM configuration

We now need far more power on this VM.

`lscpu` on scaleway-02 tells me we have:
```
CPU(s):                      96
  On-line CPU(s) list:       0-95
...
    Thread(s) per core:      2
    Core(s) per socket:      24
    Socket(s):               2
```
I will allocate 70 cpus to this VM for now.
As these is 24x2 thread per socket, I need to open at least 2 sockets of 35 cores.

I also augment the memory to min 128G, max 160G. (We need to keep memory for host for ZFS cache)

## Branching stunnel client to our services

We configure on off2 stunnel client ([commit 5434c20c223](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/5434c20c223428ff953ff8f9033c0436b61ed81f))
It wast tested from current mongo container on off1 using mongo client !

Grep hep me find where to add the new mongodb to stunnel clients:
```bash
rep -P '(213.36.253.214|proxy2)' -r confs/ --include=off.conf
confs/ovh-stunnel-client/stunnel/off.conf:connect = proxy2.openfoodfacts.org:27017
confs/ovh-stunnel-client/stunnel/off.conf:connect = proxy2.openfoodfacts.org:6379
confs/moji-stunnel-client/stunnel/off.conf:connect = proxy2.openfoodfacts.org:27017
confs/moji-stunnel-client/stunnel/off.conf:connect = proxy2.openfoodfacts.org:6379
confs/scaleway-stunnel-client/stunnel/off.conf:connect = 213.36.253.214:5432
confs/scaleway-stunnel-client/stunnel/off.conf:connect = 213.36.253.214:6379
```

So I need to do ovh and moji.
I will add it as a new service, when migration is done, I can just remove the old service,
and use the old service port for my new service.

I did it on moji [commit c1b2455112d](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/c1b2455112d374eaf46fe9870aa52deef618794d), serving on 27018. I tested  on docker prod2 VM using docker mongo client:
```bash
docker run -ti --rm mongo:4.4 mongo mongodb://10.3.0.101:27018/off
> db.products.count()
4282169
```

I did it on ovh [commit 1712d313f9](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/1712d313f9dae755ee48ab0f7f8d7bc695bc33f7), serving on 27018. I tested  on docker staging using docker mongo client:
```bash
docker run -ti --rm mongo:4.4 mongo mongodb://10.1.0.113:27018/off
> db.products.count()
4282169
```

## Switch procedure

1. Stop new MongoDB:
   Log on scaleway-docker-prod:
   ```bash
   sudo -u off -i
   cd /home/off/shared-org
   docker compose stop mongodb
   ```
2. Resync mongodb data before migration
   - On off1 as root, take a snapshot
     ```bash
     zfs snapshot zfs-nvme/pve/subvol-102-disk-0@2026-02-before-move-to-scaleway
     ```
   - On scaleway-02, as root run syncoid on this specific backup
     ```bash
     syncoid --no-sync-snap --no-privilege-elevation scaleway02operator@off1.openfoodfacts.org:zfs-nvme/pve/subvol-102-disk-0 zfs-hdd/off-backups/off1-zfs-nvme/pve/subvol-102-disk-0
     ```
   - and still on scaleway-02, as root, rsync mongodb data
     ```bash
     time ionice -n 0 rsync -a --info=progress2 --chown 999:999  --delete /zfs-hdd/off-backups/off1-zfs-nvme/pve/subvol-102-disk-0/.zfs/snapshot/2026-02-before-move-to-scaleway/db/   /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_mongodb_data/_data/
     ```
3. Stop old mongo on off1, pct 102
   ```bash
   pct enter 102
   systemctl stop mongod.service
   ```
4. Resync data
   - On off1 as root, take a snapshot
     ```bash
     zfs snapshot zfs-nvme/pve/subvol-102-disk-0@2026-02-after-move-to-scaleway
     ```
   - On scaleway-02, as root run syncoid on this specific backup
     ```bash
     syncoid --no-sync-snap --no-privilege-elevation scaleway02operator@off1.openfoodfacts.org:zfs-nvme/pve/subvol-102-disk-0 zfs-hdd/off-backups/off1-zfs-nvme/pve/subvol-102-disk-0
     ```
   - and still on scaleway-02, as root, rsync mongodb data
     ```bash
     time ionice -n 0 rsync -a --info=progress2 --chown 999:999  --delete /zfs-hdd/off-backups/off1-zfs-nvme/pve/subvol-102-disk-0/.zfs/snapshot/2026-02-after-move-to-scaleway/db/   /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_mongodb_data/_data/
     ```
   - start new mongo. On scaleway-docker-prod
     ```bash
     sudo -u off -i
     cd /home/off/shared-org
     docker compose start mongodb
     ```
   - change mongodb configuration on off and [restart services](https://openfoodfacts.github.io/openfoodfacts-server/dev/how-to-release/):
     ```
     sudo -u off vim /srv/$HOSTNAME/lib/ProductOpener/Config2.pm
     ...
     $mongodb_host = "10.1.0.103";
     ...
     sudo systemctl stop apache2 && sudo systemctl start apache2
     [[ "$HOSTNAME" = off ]] && sudo systemctl stop apache2@priority && sudo systemctl start apache2@priority
     sudo systemctl restart cloud_vision_ocr@$HOSTNAME.service minion@$HOSTNAME.service redis_listener@$HOSTNAME.service
     ```
   - IMPORTANT: verify it's working by issuing [a search](https://world.openfoodfacts.org/cgi/search.pl?search_terms=petits+bruns&search_simple=1&action=process) !
   - swap new and old mongo on stunnel-client at moji
     ```bash
     # on osm45 as root
     pct enter 101
     vim /etc/stunnel/off.conf
     ...
     # swap port 27017 and 27018 in accept = 
     ...
     systemctl restart stunnel@off.service
    ```
  - check robotoff healt is ok https://robotoff.openfoodfacts.org/api/v1/health
    and off-query health as well https://query.openfoodfacts.org/health
  - change mongodb configuration on all opff / obf / opf (as for oof above)
  - same as for moji on ovh stunnel-client
5. Do stuff that comes after:
   - commit stunnel client config changes and push
   - stop mongodb container on off1
   - celebrate :tada:

Note: first rsync took 12m0,202s, second resync took 11m52,720s…
it was not worth a 2 times sync…

## Task list
1. [DONE] modify docker compose of off-shared service
2. [DONE] modify ci deploy scripto  of off-shared service to deploy to scaleway
3. [DONE] create zfs datasets corresponding to docker volumes on scaleway-02 (ansible)
3. [DONE] deploy with CI on scaleway-02 for prod
2. [DONE]~~clone~~ test rsync prod mongo dataset backup and use it as docker volume dataset
   * change the /db path to  / (move files)
   * change ownership
5. [DONE] config stunnel server server on scaleway for mongo / postgres / redis
6. [DONE] augment VM config to use almost full node power
4. [DONE] config stunnel client (off2, other tunnels, search in configs)
   and verify service is accessible for off / obf / opf etc. and other services that needs it
   * [DONE] off2 --> scaleway
   * [DONE] moji --> scaleway
   * [DONE] ovh --> scaleway
6. [DONE] prepare for switch
   - write switch procedure:
     - stop new mongo
     - take a snapshot +  syncoid + rsync
     - stop old mongo
     - take a snapshot + syncoid + last rsync
     - start new mongo
     - switch o*f configs
     - replace old  stunnel client port for off-query / robotoff
7. [DONE] switch !
7. [DONE] sync of mongodb data to scaleway-03 + hetzner (or somewhere)
8. [DOING] expose exporters of scaleway + add monitoring deployment