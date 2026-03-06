# 2025-03-05 Moving Postgres to scaleway

We have [already moved MongoDB service to scaleway](./2026-01-15-moving-mongodb-to-scaleway.md) and [redis as well](./2026-03-05-moving-postgres-to-scaleway.md)
and as a byproduct,
we installed a scaleway-docker-prod VM
with openfoodfacts-shared-services deployed on it.

The goal is now to migrate postgres on scaleway.

Since [redis migration](./2026-03-05-moving-postgres-to-scaleway.md) We already have:
* off2 postgres data backups on scaleway-02
* stunnel server configured

## Testing Postgres with backup data

On off2, Postgres is installed in the proxmox container 120.

`pct config 120` shows us we have a disk for postgres data:
```
mp0: zfs-nvme:subvol-120-disk-0,mp=/var/lib/postgresql/,backup=1,mountoptions=noatime,size=15G
```
We can look at the content:
```bash
ls -l /zfs-nvme/pve/subvol-120-disk-0
```
There are two folders, one for v13 data (deprecated) and on for v17 data.
`/zfs-nvme/pve/subvol-120-disk-0/17/main/` is the folder containing data.

Now on scaleway-docker-prod VM we can look at `/var/lib/docker/volumes/off_shared_pg_data/_data#` and see it's the same. The db stands there, it is owned by `70:70` (`ls -ln`)

So in theory we can use a clone of a snapshot backup of postgres data disk
to test the new postgres instance on scaleway is working.
The problem is that Virtiofs does not allow to do this on a mounted Virtiofs dataset…
So we will have to use rsync.

### Rsync data

To do this:

I stop the postgres container in scaleway-docker-prod:
```bash
cd /home/off/shared-org
sudo -u off docker compose stop postgresql
```
Remove the data:
```bash
rm -rf /var/lib/docker/volumes/off_shared_pg_data/_data/*
# nothing now
ls -la /var/lib/docker/volumes/off_shared_pg_data/_data/
```

On scaleway-02 copy the data for a recent snapshot:
```bash
time rsync -a --info=progress2 --chown 70:70 --delete \
  /zfs-hdd/off-backups/off2-zfs-nvme/pve/subvol-120-disk-0/.zfs/snapshot/autosnap_2026-03-05_15:01:20_hourly/17/main/ \
  /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_pg_data/_data/
# real    0m30,261s
```
It's fast enough !

Then restart service on scaleway-docker-prod:
```bash
cd /home/off/shared-org
sudo -u off docker compose start postgresql
```

### Testing

We can verify it's working, beware though to use the production password
(**FIXME:** which is currently not the one written in the off-shared .env file):
```bash
sudo -u off docker compose exec postgresql psql -h localhost -U off -W minion
minion=> select created, task from minion_jobs order by created desc limit 3;
            created            |               task                
-------------------------------+-----------------------------------
 2026-03-05 04:09:30.74804+00  | update_export_status_for_csv_file
 2026-03-05 04:09:30.744297+00 | import_csv_file
 2026-03-05 04:09:30.736734+00 | export_csv_file
(3 rows)
minion=> exit
```
We got fresh enough data, so it's working properly !

### Testing keycloak DB

I can also test a connection, as I will do with keycloak.

For that, on scaleway-docker-prod, I use a separate container to launch psql,
and connect the way openfoodfacts-auth will connect:
```bash
docker run --rm -ti postgres:17-alpine psql  -h 10.13.1.200 -U keycloak -W keycloak
```
but I got a
```bash
psql: error: connection to server at "10.13.1.200", port 5432 failed: FATAL:  password authentication failed for user "keycloak"
```

Looking at postgres logs, I have:
```
postgresql-1  | 2026-03-05 16:55:41.074 UTC [122] FATAL:  password authentication failed for user "keycloak"
postgresql-1  | 2026-03-05 16:55:41.074 UTC [122] DETAIL:  User "keycloak" does not have a valid SCRAM secret.
postgresql-1  |     Connection matched file "/var/lib/postgresql/data/pg_hba.conf" line 100: "host all all all scram-sha-256"
```

Hopefully I found a resource on this: https://www.crunchydata.com/blog/how-to-upgrade-postgresql-passwords-to-scram

To check SCRAM, I used:
On off2, in container 120, I did a:
```
sudo -u postgres psql
SELECT
    rolname, rolpassword ~ '^SCRAM-SHA-256\$' AS has_upgraded
FROM pg_authid
WHERE rolcanlogin;
  rolname  | has_upgraded 
-----------+--------------
 bootstrap | f
 postgres  | 
 off       | t
 keycloak  | f
(4 rows)
```

We can see that `off` is already in SCRAM, so that's safe to also move keycloak
(as Perl code might have been the one not supporting it).

On off2, in container 120, I did a:
```
sudo -u postgres psql
SET password_encryption = 'scram-sha-256';
\password keycloak
\password bootstrap
```

I then wait for a new snapshot and synced again the new scaleway deployment.

I then tested I can connect, and this time it worked !

Note: the difference is because I just moved the data from the old instance,
not the config files… on old instance, the config file was allowing md5 connection,
but it's not the case in the new instance.

## Proxying postgresql with stunnel

Already done with [moving redis to scaleway](./2026-02-26-moving-redis-to-scaleway.md)

## Branching stunnel client to our services

As only product opener is using this postgres,
We only need to configure the stunnel from off2.

We already configure on off2 stunnel client ([commit cd7408cd](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/cd7408cd834af1e1d90fba2a401a9b229a4c1345))

To test it, I go on the current postgresql container on off2:
```
pct enter 120
psql -h 10.1.0.105 -U off -W minion
minion=> select created, task from minion_jobs order by created desc limit 3;
            created            |               task                
-------------------------------+-----------------------------------
 2026-03-05 04:09:30.74804+00  | update_export_status_for_csv_file
...
```

Grep confirms postgres is not used by other stunnel clients:
```bash
grep -P '(213.36.253.214|proxy2).*5432' -r confs/ --include=off.conf
confs/scaleway-stunnel-client/stunnel/off.conf:connect = 213.36.253.214:5432
```

## Switch procedure

1. Stop new Postgres:
   Log on scaleway-docker-prod:
   ```bash
   sudo -u off -i
   cd /home/off/shared-org
   docker compose stop postgresql
   ```
3. Stop old postgres on off2, pct 120
   ```bash
   pct enter 120
   systemctl stop postgresql@17-main.service
   ```
2. Copy postgres data for migration
   - On off2 as root, take a snapshot
     ```bash
     zfs snapshot zfs-nvme/pve/subvol-120-disk-0@2026-03-before-move-to-scaleway
     ```
   - On scaleway-02, as root run syncoid on this specific backup
     ```bash
     syncoid --no-sync-snap --no-privilege-elevation  scaleway02operator@off2.openfoodfacts.org:zfs-nvme/pve/subvol-120-disk-0 zfs-hdd/off-backups/off2-zfs-nvme/pve/subvol-120-disk-0

     ```
   - and still on scaleway-02, as root, rsync postgres data
     ```bash
     time ionice -n 0 rsync -a --info=progress2 --chown 70:70 --delete \
  /zfs-hdd/off-backups/off2-zfs-nvme/pve/subvol-120-disk-0/.zfs/snapshot/2026-03-before-move-to-scaleway/17/main/ \
  /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_pg_data/_data/
     # verify
     ls -l /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_pg_data/_data/
     ```
4. Migrate
   - start new postgres. On scaleway-docker-prod
     ```bash
     sudo -u off -i
     cd /home/off/shared-org
     docker compose start postgresql
     ```
   - change postgres configuration on openfoodfacts-auth instance on scaleway-docker-prod:
     ```bash
     sudo -u off -i
     cd /home/off/off-auth-org
     vim .env
     ...
     KC_DB_URL_HOST=10.13.1.200
     ...
     docker compose down && docker compose up -d
     ```

   - change postgres configuration on off and [restart services](https://openfoodfacts.github.io/openfoodfacts-server/dev/how-to-release/):
     ```
     sudo -u off vim /srv/$HOSTNAME/lib/ProductOpener/Config2.pm
     ...
        minion_backend => {'Pg' => 'postgresql://off:******@10.1.0.105/minion'},
     ...
     sudo systemctl stop apache2 && sudo systemctl start apache2
     [[ "$HOSTNAME" = off ]] && sudo systemctl stop apache2@priority && sudo systemctl start apache2@priority
     sudo systemctl restart cloud_vision_ocr@$HOSTNAME.service minion@$HOSTNAME.service redis_listener@$HOSTNAME.service
     ```
   - IMPORTANT: verify by creating (and removing later) a user on off,
     and verify:
     - it's working
     - in https://auth.openfoodfacts.org/admin/master/console/#/openfoodfacts/users you can see the new user
     - in minion table there is the welcome_user task
       ```
       sudo -u off -i
       cd /home/off/shared-org
       docker compose exec postgresql psql  -h localhost  -U off -W minion
       minion=> select * from minion_jobs where task='welcome_user' order by id desc limit 10;
     - you received an email for the new user
   - change redis configuration on all opff / obf / opf / off-pro (as for off above)
5. Do stuff that comes after:
   - stop postgres container on off2
   - celebrate :tada:


## Task list
2. [DONE]test rsync prod postgres dataset backup and use it as docker volume dataset
   * change ownership
5. [DONE] config stunnel server server on scaleway for postgres
4. [DONE] test keycloak can connect to new DB
4. [DONE] config stunnel client on off2 and verify service is accessible for off / obf / opf etc.
6. [DONE] write switch procedure:
7. [DONE] switch !
