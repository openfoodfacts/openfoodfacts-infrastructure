# 2024-01-03 MongoDB migration on off3

## Context

To [upgrade off2](./2023-02-17-off2-upgrade.md), we moved MongoDB to a VM kindly provided by Open Street Map France (VM codename off3) on a server located in the same datacenter.

We Then moved all the stuff from off1 to off2. We then [upgrade off1](./2023-12-08-off1-upgrade.md).

It's now time to move back MongoDB instance to the upgraded off1 server. It will be installed in a container as we now use [proxmox](../proxmox.md)

## Creating a container

We followed usual procedure to [create a proxmox container](../proxmox.md#how-to-create-a-new-container):
* of id 102
* choosed a debian 10 (**important**: org version of mongodb 4.4 is not available in newly debian versions)
* default storage on zfs-hdd (for system) 30Gb, noatime
* add another storage mountpoint 0, on zfs-nvme mounted as /mongo with 96 Gb, noatime
* 15 cores
* memory 131072 Mb (128 Gb), no swap

Before running the ctpostinstall script, I had to change buster in sources list to oldoldstable.

I also [configured email](../mail.md#postfix-configuration) in the container.

I also immediately created a off user for it to have id 1000.

## Installing MongoDB

We follow [MongoDB 4.4 install procedure](https://www.mongodb.com/docs/v4.4/tutorial/install-mongodb-on-debian/)


```bash
sudo apt-get install gnupg curl
curl -fsSL https://pgp.mongodb.com/server-4.4.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg \
   --dearmor
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt-get update
sudo apt-get install -y mongodb-org

sudo systemctl daemon-reload
sudo systemctl enable mongod
sudo systemctl start mongod
# verify
sudo systemctl status mongod
```

## cloning repos

### Infrastructure repository

Create root ssh key: `ssh-keygen -t ed25519 -C "root@mongodb"`

Added root ssh pub key (`cat /root/.ssh/id_ed25519.pub`) as a [deploy key to github infrastructure repository](https://github.com/openfoodfacts/openfoodfacts-infrastructure/settings/keys)


Cloned
```bash
cd /opt
git clone git@github.com:openfoodfacts/openfoodfacts-infrastructure.git
```

### OFF server repository

We need Product Opener repository to get scripts we need to run routinely.

We can't use the same certificate for the git repository…

Create root ssh key: `ssh-keygen -t ed25519 -C "root+off-server@mongodb" -f /root/.ssh/github_off-server -N ''`

Added root ssh pub key (`cat /root/.ssh/github_off-server.pub`) as a [deploy key to github server repository](https://github.com/openfoodfacts/openfoodfacts-server/settings/keys)

Modified git config to use right key to connect to the repository:

```bash
vim /root/.ssh/config
...
Host github.com-off-server
  Hostname github.com
  IdentityFile=/root/.ssh/github_off-server
```

Cloned:

```bash
cd /opt
git clone git@github.com-off-server:openfoodfacts/openfoodfacts-server.git
```


## Setting up

First I copied the off1 root public certificate to authorized_keys on off3, and ssh once to validate the key.

I stopped mongodb: `systemctl stop mongod`


Then I prepared the directory for mongodb data:

```bash
mkdir /mongo/db
chown mongodb:mongodb /mongo/db
rmdir /var/lib/mongodb
ln -s /mongo/db /var/lib/mongodb
```

Copied mongodb config from off3. On off1, as well as logrotate configs:

```bash
# mongodb config
rsync 10.0.0.3:/etc/mongod.conf /zfs-hdd/pve/subvol-102-disk-0/opt/openfoodfacts-infrastructure/confs/mongodb/
# logrotate configs
rsync 10.0.0.3:"/etc/logrotate.d/mongo*" /zfs-hdd/pve/subvol-102-disk-0/opt/openfoodfacts-infrastructure/confs/mongodb/logrotate.d/
```


Linked the config:
```bash
mv /etc/mongod.conf{,.dist}
ln -s /opt/openfoodfacts-infrastructure/confs/mongodb/mongod.conf /etc/mongod.conf
ln -s /opt/openfoodfacts-infrastructure/confs/mongodb/logrotate.d/mongod /etc/logrotate.d/
ln -s /opt/openfoodfacts-infrastructure/confs/mongodb/logrotate.d/mongo_refresh_tags /etc/logrotate.d/
```

And restart mongodb `systemctl start mongod`

And check `systemctl start mongod`

### setting up cron jobs

On off3 we launched some mongodb scripts (namely `refresh_products_tags.js`) but they now disapeared from the product opener repository as we don't need them any more thanks to openfoodfacts-query project (see [openfoodfacts-server commit 90180247f](https://github.com/openfoodfacts/openfoodfacts-server/commit/90180247fe23cedcdcc32249fdb9d7b25bf6051d))

Still we need the product_tags collections for obf, opf and opff.

**TODO:**
The right solution is to add mongo shell on their respective containers and call `refresh_products_tags.js` with `gen_feeds_daily_*.sh`.




## Migrating data for a test

### trying with a simple rsync (does not works)

We stop mongodb in mongodb container.

We use rsync from off2 to get data from off3:

```bash
# beware we are on zfs-nvme dataset
# we also map off and mongodb username and groupname to 100108 and 100116
# (corresponding to mongodb user/group in mongodb container)
time rsync -a --delete-delay --usermap=mongodb:100108,off:100108 --groupmap=mongodb:100116,off:100116 10.0.0.3:/mongo/db/ /zfs-nvme/pve/subvol-102-disk-0/db/
```
(it took 15 min).


Then I restarted mongodb.

Got an error `variable MONGODB_CONFIG_OVERRIDE_NOFORK == 1, overriding \"processManagement.fork\" to false`.

This [thread is interesting](https://stackoverflow.com/a/76293801/2886726).
With `systemctl cat mongod` I can see that I have `MONGODB_CONFIG_OVERRIDE_NOFORK` set on new container and not on old VM.

See also [MongoDB doc stating](https://www.mongodb.com/docs/manual/reference/configuration-options/#file-format):

> The Linux package init scripts included in the official MongoDB packages depend on specific values for systemLog.path, storage.dbPath, and processManagement.fork. If you modify these settings in the default configuration file, mongod may not start.

The MONGODB_CONFIG_OVERRIDE_NOFORK was introduced by https://jira.mongodb.org/browse/SERVER-74845

Strangely in mongod.conf we keep default value which should be false...

Finally I [saw in the code](https://github.com/mongodb/mongo/blob/r4.4.27/src/mongo/db/server_options_server_helpers.cpp#L132) that the message was just a log / warning not an error…

But in `/var/log/mongodb/mongod.log` I found:
```
"msg":"ERROR: Cannot write pid file to {path_string}: {errAndStr_second}","attr":{"path_string":"/var/run/mongodb/mongod.pid","errAndStr_second":"No such file or directory"}
```

I removed the specific directive for pid file in mongod.conf and restarted mongodb.

Now I can see:
```json
{"t":{"$date":"2024-01-04T16:33:33.069+00:00"},"s":"W",  "c":"STORAGE",  "id":22271,   "ctx":"initan
dlisten","msg":"Detected unclean shutdown - Lock file is not empty","attr":{"lockFile":"/mongo/db/mo
ngod.lock"}}
{"t":{"$date":"2024-01-04T16:33:33.069+00:00"},"s":"I",  "c":"STORAGE",  "id":22270,   "ctx":"initan
dlisten","msg":"Storage engine to use detected by data files","attr":{"dbpath":"/mongo/db","storageE
ngine":"wiredTiger"}}
{"t":{"$date":"2024-01-04T16:33:33.069+00:00"},"s":"W",  "c":"STORAGE",  "id":22302,   "ctx":"initan
dlisten","msg":"Recovering data from the last clean checkpoint."}
...
file:WiredTigerHS.wt, hs_access: __wt_block_read_off, 286: WiredTigerHS.wt: potential hardware
 corruption, read checksum error for 4096B block at offset 36864: block header checksum of 0xe91e380
0 doesn't match expected checksum of 0xd10d51e"}}
...
lot of errors
...
```
so thi is a problem of copy.

Indeed it is [stated by documentation](https://www.mongodb.com/docs/manual/core/backups/#back-up-with-cp-or-rsync):
> you can copy the files directly using cp, rsync, or a similar tool. Since copying multiple files is not an atomic operation, you must stop all writes to the mongod before copying the files.


I'm not able to stop mongodb for just a test, so I will first setup other things like stunnel.

## Setting up stunnel

see [2024-01-04 Setting up stunnel](./2024-01-04-setting-up-stunnel.md)

## Cron job for tags collection generation on opf / opff / obf

Before we directly had a script on the crontab of mongodb server to generate tags collection.

But it disappeared from off main version.

We now will launch those tasks from the different servers, it is more logical and flexible.

On each container: off, opf and opff

* install mongosh: `sudo apt install mongodb-mongosh`

## Migration procedure

* stop mongodb on mongodb container: `systemctl stop mongodb`
* rsync MongoDB data from off3 to mongodb container. On off1, as root:
  ```bash
  time rsync -a --delete-delay --usermap=mongodb:100108,off:100108 --groupmap=mongodb:100116,off:100116 10.0.0.3:/mongo/db/ /zfs-nvme/pve/subvol-102-disk-0/db/
  ```
  (took 15 min 56s)
* warn slack users
* stop mongodb on off3: `systemctl stop mongod`
* rsync again (same command as above) (took 6 min 42s)
* (during sync)
  * change configuration for product opener
    * on off, off-pro
      * edit /srv/$HOSTNAME/lib/ProductOpener/Config2.pm
      * `sudo systemctl restart apache2.service cloud_vision_ocr@$HOSTNAME.service minion@HOSTNAME.service`
    * on opf, opff, obf:
      * edit /srv/$PROJECT/lib/ProductOpener/Config2.pm
      * `sudo systemctl restart apache2.service`
  * change configuration for off-query-org and robotoff-org to point to 10.1.0.101:27017 (ovh1 proxy):
    * going to corresponding directory
    * editing .env
    * `sudo -u off docker-compose down && sudo -u off docker-compose up -d`
* start mongodb on mongodb container (keep off3 down)
* verify it's working on off
* disable mongod on off3
* merge PR to change mongodb configuration of off-query and robotoff