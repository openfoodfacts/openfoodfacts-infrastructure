# 2023-06-07 OFF and OFF-pro reinstall on off2

We will follow closely what we did for [OPFF reinstall on off2](./2023-03-14-off2-opff-reinstall.md).
Refer to it if you need more explanation on a step.
Also following [OPF and OBF reinstall on off2](./2023-06-07-off2-opf-obf-reinstall.md).


## switching to right branch of off2 and ovh3

On ovh3 and off2 we will set the branch to `off2-off-reinstall` to have modifications synced.
```bash
cd /opt/openfoodfacts-infrastructure
git fetch
git checkout off2-off-reinstall
```

We will continuously push and pull on this branch.

## removing zfs-old and adding as cache to zfs-hdd

`nvme3n1p2` is in zfs-old and has no utility right  now.

```bash
zpool destroy zfs-old
```

But as `zfs-nvme` is in mirror it's no use adding it as a new  device there.

Instead we can add it as a cache to `zfs-hdd` to improve performance.

```bash
zpool add zfs-hdd cache nvme3n1p2
```

## installing a postgresql container

### Created CT

I created a CT for OFF followings [How to create a new Container](../proxmox.md#how-to-create-a-new-container) it went all smooth.

It's 120 (off-postgres)

I choosed a 20Gb disk on zfs-hdd, 0B swap, 2 Cores and 2 Gb memory.
I added a disk on zfs-nvme mounted on /var/lib/postgresql/ with 5Gb size and noatime option.

I did not create a user.

I also [configure postfix](../mail.md#postfix-configuration) and tested it.

### Installed Postgres

I simply used standard distribution package.

```bash
sudo apt install postgresql postgresql-contrib
```

Change `/etc/postgresql/*/main/postgresql.conf` to set `listen_addresses` to `*` (listen on all ip).

Change `/etc/postgresql/*/main/pg_hba.conf` to add:
```conf
# IPv4 local network connections:
host    all             all             10.0.0.1/8            md5
```

and restart postgresql

### create off user

On off1 we get user info:

```bash
sudo -u postgres pg_dumpall --globals-only   |less
...
CREATE ROLE off;
ALTER ROLE off WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD '******';
...
```

And we take relevant line to create off user in the container using `sudo -u postgres psql`.

### testing database restore

On off1, I did a dump of postgres minion database:

```bash
sudo -u postgres pg_dump -d minion --format=custom --file /tmp/$(date -Is -u)-minion.dump
```

On off2, we scp the file and restore it:

```bash
sudo scp 10.0.0.1:/tmp/2023-08-21T21:41:09+00:00-minion.dump /zfs-hdd/pve/subvol-120-disk-0/var/tmp/
```

and in the container:
```bash
sudo -u postgres pg_restore --create --clean -d postgres /var/tmp/2023-08-21T21:41:09+00:00-minion.dump
```
We have two errors, but they are expected.

## installing a memcached container

### Creating the container

I created a CT for OFF followings [How to create a new Container](../proxmox.md#how-to-create-a-new-container) it went all smooth.

It's 121 (off-memcached)
I choosed a 15Gb disk on zfs-hdd, 0B swap, 2 Cores and 4 Gb memory.

I also [configure postfix](../mail.md#postfix-configuration) and tested it.

I did not create a user.

### installing memcached

Inside container:

```bash
apt install memcached
```

### adding off-infrastructure repository

```bash
sudo ssh-keygen -f /root/.ssh/github_off-infra -t ed25519 -C "root-off-memcached-off-infra@openfoodfacts.org"
sudo vim /root/.ssh/config
…
# deploy key for openfoodfacts-infra
Host github.com-off-infra
        Hostname github.com
        IdentityFile=/root/.ssh/github_off-infra
…
cat /root/.ssh/github_off-infra.pub
```

Go to github add the off pub key for off to [off infra repository](https://github.com/openfoodfacts/openfoodfacts-infrastructure/settings/keys) with write access.

Then clone repo in /opt:
```bash
git clone git@github.com-off-infra:openfoodfacts/openfoodfacts-infrastructure.git /opt/openfoodfacts-infrastructure
```

### configuring memcached

We will use the file in git:

```bash
rm /etc/memcached.conf
ln -s /opt/openfoodfacts-infrastructure/confs/off-memcached/memcached.conf /etc/
systemctl restart memcached
```


## Putting data in zfs datasets

### fixing a syslog bug

In syslog I saw a lot of `zfs error: cannot open 'zfs-nvme/pve': dataset does not exist`

I decided to fix it by creating this dataset:
```bash
zfs create zfs-nvme/pve
```


### creating datasets

Products and images datasets are already there, we create the other datasets.
We also create a dataset for logs as they are big on off.

```bash
SERVICE=off
zfs create zfs-hdd/$SERVICE/cache
zfs create zfs-hdd/$SERVICE/html_data
zfs create zfs-hdd/$SERVICE/logs
```
same for `off-pro`

but also created `images` for `off-pro`

```bash
zfs create zfs-hdd/off-pro/images
```

and change permissions:

```bash
sudo chown 1000:1000  /zfs-hdd/off{,-pro}/{,html_data,images,cache,logs}
```

We also need to create off/orgs
```bash
zfs create zfs-hdd/off/orgs
sudo chown 1000:1000  /zfs-hdd/off/orgs
```


### adding to sanoid conf

We do it asap, as we need some snapshots to be able to use syncoid later on.

We edit sanoid.conf to put our new datasets with `use_template=prod_data`.

We can launch the service immediately if we want: `systemctl start sanoid.service`


### Moving products to vme zfs

#### creating datasets

Because of problems at server install, we have the products in `zfs-hdd` datasets while, at least for off and off-pro, we want them in `zfs-nvme`. This will improve performances.

So we will move products there.
To do this:

On off2, we create the new zfs datasets:
```bash
zfs create zfs-nvme/off
zfs create zfs-nvme/off/products
zfs create zfs-nvme/off-pro
zfs create zfs-nvme/off-pro/products
```

#### disabling sync

On off1, we temporarily disable sync to off2 by editing `$REMOTE` in `sto-products-sync.sh`.

On off1 we verify no send  to off2 is in progress `ps -elf|grep zfs.send`

#### copying datasets

On off2, we sync the `zfs-hdd` datasets to the `zfs-nvme` ones:
```bash
SERVICE=off
# get first and last snapshot
zfs list -t snap zfs-hdd/$SERVICE/products
zfs-hdd/off/products@20230417-0000  7.93G      -      300G  -
…
zfs-hdd/off/products@20230719-0930     0B      -      317G  -

# TIP from Christian Quest:
# * on sending side, use "-w" to send raw data (avoid compression etc.),
# * on receiving side, use -s to be able to restart from where you stopped if needed

# send first snapshot, this took about 5 hours (damn me, I didn't add the time…)
time zfs send -w zfs-hdd/$SERVICE/products@20230417-0000 | pv | zfs recv zfs-nvme/$SERVICE/products -s -F
# send all snapshots incrementally
time zfs send -w -I 20230417-0000 zfs-hdd/$SERVICE/products@20230719-0930 | pv | zfs recv zfs-nvme/$SERVICE/products -s
```

We do the same for `off-pro` (this time first snapshot was `20230418-0000` and last was `20230719-0930`)

#### enabling sync again

On off1, we change the  `sto-products-sync.sh`

* adding off2 IP back to`$REMOTE`
* using zfs-nvme instead of zfs-hdd

After some time we verify it's working.

#### changing containers mount points

As we did this operation, the lxc configuration for 113 and 114 where still using zfs-hdd mount points, we changed them to zfs-nvme for products.


### migrating root datasets on ovh3

If we want to synchronize off and off-pro root dataset, they have to be created by syncing from off2 to ovh3.
But as they already exists on ovh3, we have to create them, move products in them, and swap the old and the new one (avoiding doing so during a sync).

#### prepare

Verify which datasets exists under the old root datasets on ovh3:

```bash
$ zfs list -r rpool/off{,-pro}
NAME                        USED  AVAIL     REFER  MOUNTPOINT
rpool/off                  13.9T  21.8T      272K  /rpool/off
rpool/off-pro              34.2G  21.8T      216K  /rpool/off-pro
rpool/off-pro/products     34.2G  21.8T     25.0G  /rpool/off-pro/products
rpool/off/clones           1.89G  21.8T      224K  /rpool/off/clones
rpool/off/clones/images    1.22G  21.8T     10.1T  /rpool/off/clones/images
rpool/off/clones/orgs       272K  21.8T     51.4M  /rpool/off/clones/orgs
rpool/off/clones/products   678M  21.8T      411G  /rpool/off/clones/products
rpool/off/clones/users     5.32M  21.8T     3.10G  /rpool/off/clones/users
rpool/off/images           12.0T  21.8T     10.6T  /rpool/off/images
rpool/off/orgs             58.0M  21.8T     54.2M  /rpool/off/orgs
rpool/off/products         1.88T  21.8T      430G  /rpool/off/products
rpool/off/users            5.20G  21.8T     3.18G  /rpool/off/users
```

So we have to move products for off-pro, and for off we have to move products, images.

`users` and `orgs` are just rsynced backup from off1, so we don't have to move them, we will just keep them until we re-create the clones that use them.

The problem now will be to pass between ZFS synchronizations.

#### create new target datasets
On off2:

```bash
sudo syncoid --no-sync-snap zfs-hdd/off  root@ovh3.openfoodfacts.org:rpool/off-new
sudo syncoid --no-sync-snap zfs-hdd/off-pro  root@ovh3.openfoodfacts.org:rpool/off-pro-new
```
it's very fast.

#### move off-pro products to new dataset and swap datasets
on ovh3, we wait to have no off-pro sync running.

```bash
zfs rename rpool/off-pro{,-new}/products && \
zfs rename rpool/off-pro{,-old} && \
zfs rename rpool/off-pro{-new,}
```
zfs-hdd/off/cache       140K  23.9T      140K  /zfs-hdd/off/cache
zfs-hdd/off/html_data   140K  23.9T      140K  /zfs-hdd/off/html_data
zfs-hdd/off/images     11.4T  23.9T     10.3T  /zfs-hdd/off/images
zfs-hdd/off/logs        140K  23.9T      140K  /zfs-hdd/off/logs
zfs-hdd/off/orgs        140K  23.9T      140K  /zfs-hdd/off/orgs
zfs-hdd/off/products    898G  23.9T      317G  /zfs-hdd/off/products
zfs-hdd/off/users      3.73G  23.9T     2.32G  /zfs-hdd/off/users

#### moving off products and images to new dataset and swapping

As sync are taking a lot of time on products and images, we will disable them until we do the move…

On off2, temporarily edit `/etc/sanoid/syncoid-args.conf` to remove the line corresponding to images.
On off1, temporarily edit `sto-products-sync.sh` and disable ovh3 target.

Wait until current syncs finishes (sto-products-sync.sh run newer than config change on off1 and syncoid run newer than config change on off2).

Because of clones, we also have to shutdown the off staging container which use those datasets. On off staging container (on ovh1):
```bash
cd /home/off/off-net/
sudo -u off docker-compose stop
```

And remove clones on ovh3:

```bash
# need this to clean stalled NFS connections
systemctl restart nfs-server.service
zfs destroy rpool/off/clones/users
zfs destroy rpool/off/clones/products
zfs destroy rpool/off/clones/orgs
```

Then we do the move on ovh3:
```bash
zfs rename rpool/off{,-new}/products && \
zfs rename rpool/off{,-new}/images && \
zfs rename rpool/off{,-new}/clones && \
zfs rename rpool/off{,-old} && \
zfs rename rpool/off{-new,}
```

Now we can re-enable syncoid on off2 and sto-products-sync off1.


#### Recreating clones

**IMPORTANT**: Before re-creating users and orgs and recreating clones, I follow the step to add users and orgs to syncoid and rsync users and orgs from prod (so that we have something worthful) (see [copying users and orgs](#copying-users-and-orgs)).

I created the `off/clones` dataset and enable NFS share.
```bash
zfs create rpool/off/clones
zfs set sharenfs="rw=@10.0.0.1/32,rw=@10.1.0.200/32,no_root_squash" rpool/off/clones
```
Then I manually created the clones following the `maj-clones-nfs-VM-dockers.sh` script.

I then restart the docker compose on off-net.


#### setup sync

We can now sync them regularly by editing `/etc/sanoid/syncoid-args.conf`:

```conf
# off
--no-sync-snap zfs-hdd/opf root@ovh3.openfoodfacts.org:rpool/opf
# off-pro
--no-sync-snap zfs-hdd/$SERVICE root@ovh3.openfoodfacts.org:rpool/$SERVICE
```

I also added it to `sanoid.conf` ovh3, but using synced template.



### Copying users and orgs

I already have setup syncoid on off2 to sync users and orgs to ovh3:

On off2 (in a screen), as root:

```bash
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/users  /zfs-hdd/off/users && \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/orgs  /zfs-hdd/off/orgs
```
this took a few minutes.

I was lucky enough that syncoid just started at this very moment and let it finish.

After checking sync did happen correctly (`zfs list -t snap rpool/off/{orgs,users} && ls rpool/off/{orgs,users}`), we can also remove old `users` and `orgs` from the old off dataset on ovh3:
```bash
zfs destroy rpool/off-old/{users,orgs}
```
and as they were the last, also removed `rpool/off-old`

I also decided to temporarily do a regular rsync of users and orgs through a cron on off1.

I added it to root crontab on off1:

```conf
# rsync users and orgs to off2 every hour
48 * * * *	rsync -a /srv/off/users/ 10.0.0.2:/zfs-hdd/off/users/; rsync -a /srv/off/orgs/ 10.0.0.2:/zfs-hdd/off/orgs/
```

### Copying off-pro images

```bash
time rsync --info=progress2 -a -x 10.0.0.1:/srv2/off-pro/html/images/products /zfs-hdd/off-pro/images/
```

### Copying other data


I rsync cache data and other data on ofF2:

```bash
# cache
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/{build-cache,tmp,debug,new_images} /zfs-hdd/off/cache/
# for off-pro I don't copy new_images as it's really full and non working ! (takes 18m)
# don't copy export_files it's really transient data
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off-pro/{build-cache,tmp,debug} /zfs-hdd/off-pro/cache/
mkdir /zfs-hdd/off-pro/cache/new_imaqes
mkdir /zfs-hdd/off-pro/cache/export_files
mkdir /zfs-hdd/off/cache/export_files
mkdir /zfs-hdd/off/cache/export_files
mkdir /zfs-hdd/off/cache/export_files

chown -R 1000:1000 /zfs-hdd/off{,-pro}/cache

# data folder (we do not copy data from off-pro for it's shared with off)
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/data /zfs-hdd/off/
# other
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/{deleted.images,deleted_products,deleted_products_images} /zfs-hdd/off/
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off-pro/{deleted.images,deleted_private_products} /zfs-hdd/off-pro/
# imports are on srv2 and only for off
time rsync --info=progress2 -a -x 10.0.0.1:/srv2/off/imports /zfs-hdd/off/
# translations on off
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/translate /zfs-hdd/off/
# reverted_products on off
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/reverted_products /zfs-hdd/off/

# html/data, took 158 and 214 mins for off, fast for off-pro
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/html/data/ /zfs-hdd/off/html_data
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/html/{files,exports} /zfs-hdd/off/html_data/
# dump is on srv2
time rsync --info=progress2 -a -x 10.0.0.1:/srv2/off/html/dump /zfs-hdd/off/html_data/

time rsync --info=progress2 -a -x 10.0.0.1:/srv/off-pro/html/data/ /zfs-hdd/off-pro/html_data
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off-pro/html/files /zfs-hdd/off-pro/html_data/
# some folder that will be needed but are empty for now
mkdir /zfs-hdd/off/deleted_private_products
mkdir /zfs-hdd/off-pro/deleted_products
mkdir /zfs-hdd/off-pro/deleted_products_images
mkdir /zfs-hdd/off-pro/imports
mkdir /zfs-hdd/off-pro/reverted_products
mkdir /zfs-hdd/off-pro/translate
chown 1000:1000 /zfs-hdd/off/deleted_private_products /zfs-hdd/off-pro/{deleted_products,deleted_products_images,imports}
```

I already add them to `/etc/sanoid/syncoid-args.conf` so sync will happen.

And on ovh3 add them to `sanoid.conf` with `synced_data` template

### Copying secrets

We will put secrets in private data dir.

```bash
mkdir /zfs-hdd/off-pro/secrets

# ftp secrets for producers
rsync 10.0.0.1:/home/off/.netrc /zfs-hdd/off-pro/secrets

# ensure secrets
chown 1000:1000 -R /zfs-hdd/off-pro/secrets
chmod go-rwx -R /zfs-hdd/off-pro/secrets
```

### How much sugar data

We will put html files of How much sugar in html_data volume as those file are kind of data (they are generated by a script), and the sto in private data

```bash
mkdir -p /zfs-hdd/off/html_data/sugar/{en,fr}
rsync -a 10.0.0.1:/srv/sugar/html/ /zfs-hdd/off/html_data/sugar/en
rsync -a 10.0.0.1:/srv/sucres/html/ /zfs-hdd/off/html_data/sugar/fr
mkdir -p /zfs-hdd/off/data/sugar/{en,fr}
rsync -a 10.0.0.1:/srv/sugar/data/ /zfs-hdd/off/data/sugar/en/
rsync -a 10.0.0.1:/srv/sucres/data/ /zfs-hdd/off/data/sugar/fr/
rsync -a 10.0.0.1:/srv/sugar/logs/sugar_log /zfs-hdd/off/data/sugar/old_en_sugar_log
rsync -a 10.0.0.1:/srv/sucres/logs/sugar_log /zfs-hdd/off/data/sugar/old_fr_sucres_log
chown -R 1000:1000 /zfs-hdd/off/html_data/sugar /zfs-hdd/off/data/sugar/
```

### logs

We rsync old logs in a separate files

Old logs were copied to ovh3:/rpool/backups/off1/srv/off/logs


## Creating Containers

I created a CT for OFF followings [How to create a new Container](../proxmox.md#how-to-create-a-new-container) it went all smooth.
I choosed a 30Gb disk, 0B swap, 8 Cores and 40 Gb memory.

Note that my first container creation failed because unable to mount the ZFS volume ("zfs dataset is busy"…), I had to destroy the dataset and re-create the container.

I also [configure postfix](../mail.md#postfix-configuration) and tested it.

**Important:** do not create any user until you changed id maping in lxc conf (see [Mounting volumes](#mounting-volumes)). And also think about creating off user before any other user to avoid having to change users uids, off must have uid 1000.


### Installing generic packages

I also installed generic packages:

```bash
sudo apt install -y apache2 apt-utils g++ gcc less make gettext wget vim
```


### Geoip with updates

Installed geoip with updates, and copied `/etc/GeoIP.conf` from opff:
```bash
sudo apt install geoipupdate
vim /etc/GeoIP.conf
…
sudo chmod o-rwx /etc/GeoIP.conf
```

Test it:
```bash
sudo systemctl start geoipupdate.service
sudo systemctl status geoipupdate.service
…
juin 12 16:18:34 $SERVICE systemd[1]: geoipupdate.service: Succeeded.
juin 12 16:18:34 $SERVICE systemd[1]: Finished Weekly GeoIP update.
juin 12 16:18:34 $SERVICE systemd[1]: geoipupdate.service: Consumed 3.231s CPU time.
…
```


### Clone off as off-pro

I then shutdow the $SERVICE VM and clone it as off-pro.

After cloning I changes to 4 cores and 6 Gb memory. change network IP address settings before starting.


### Installing packages

On off and off-pro (taken from Dockerfile)

```bash
sudo  apt install -y \
   apache2 \
   apt-utils \
   cpanminus \
   g++ \
   gcc \
   less \
   libapache2-mod-perl2 \
   make \
   gettext \
   wget \
   imagemagick \
   graphviz \
   tesseract-ocr \
   lftp \
   gzip \
   tar \
   unzip \
   zip \
   libtie-ixhash-perl \
   libwww-perl \
   libimage-magick-perl \
   libxml-encoding-perl  \
   libtext-unaccent-perl \
   libmime-lite-perl \
   libcache-memcached-fast-perl \
   libjson-pp-perl \
   libclone-perl \
   libcrypt-passwdmd5-perl \
   libencode-detect-perl \
   libgraphics-color-perl \
   libbarcode-zbar-perl \
   libxml-feedpp-perl \
   liburi-find-perl \
   libxml-simple-perl \
   libexperimental-perl \
   libapache2-request-perl \
   libdigest-md5-perl \
   libtime-local-perl \
   libdbd-pg-perl \
   libtemplate-perl \
   liburi-escape-xs-perl \
   libmath-random-secure-perl \
   libfile-copy-recursive-perl \
   libemail-stuffer-perl \
   liblist-moreutils-perl \
   libexcel-writer-xlsx-perl \
   libpod-simple-perl \
   liblog-any-perl \
   liblog-log4perl-perl \
   liblog-any-adapter-log4perl-perl \
   libgeoip2-perl \
   libemail-valid-perl \
   libmath-fibonacci-perl \
   libev-perl \
   libprobe-perl-perl \
   libmath-round-perl \
   libsoftware-license-perl \
   libtest-differences-perl \
   libtest-exception-perl \
   libmodule-build-pluggable-perl \
   libclass-accessor-lite-perl \
   libclass-singleton-perl \
   libfile-sharedir-install-perl \
   libnet-idn-encode-perl \
   libtest-nowarnings-perl \
   libfile-chmod-perl \
   libdata-dumper-concise-perl \
   libdata-printer-perl \
   libdata-validate-ip-perl \
   libio-compress-perl \
   libjson-maybexs-perl \
   liblist-allutils-perl \
   liblist-someutils-perl \
   libdata-section-simple-perl \
   libfile-which-perl \
   libipc-run3-perl \
   liblog-handler-perl \
   libtest-deep-perl \
   libwant-perl \
   libfile-find-rule-perl \
   liblinux-usermod-perl \
   liblocale-maketext-lexicon-perl \
   liblog-any-adapter-tap-perl \
   libcrypt-random-source-perl \
   libmath-random-isaac-perl \
   libtest-sharedfork-perl \
   libtest-warn-perl \
   libsql-abstract-perl \
   libauthen-sasl-saslprep-perl \
   libauthen-scram-perl \
   libbson-perl \
   libclass-xsaccessor-perl \
   libconfig-autoconf-perl \
   libdigest-hmac-perl \
   libpath-tiny-perl \
   libsafe-isa-perl \
   libspreadsheet-parseexcel-perl \
   libtest-number-delta-perl \
   libdevel-size-perl \
   gnumeric \
   libreadline-dev \
   libperl-dev \
   libapache2-mod-perl2-dev
```


## Mounting volumes

In our target production we will have everything in off2,
so we cross mount their products and images volumes.

We will change config for opff, opf and $SERVICE at migration time.

### changing lxc confs

On off2.

So for off, editing `/etc/pve/lxc/113.conf`:
```conf
mp0: /zfs-hdd/off,mp=/mnt/off
mp1: /zfs-nvme/off/products,mp=/mnt/off/products
mp2: /zfs-hdd/off/users,mp=/mnt/off-pro/users
mp3: /zfs-hdd/off/orgs,mp=/mnt/off/orgs
mp4: /zfs-hdd/off/images,mp=/mnt/off/images
mp5: /zfs-hdd/off/html_data,mp=/mnt/off/html_data
mp6: /zfs-hdd/off/cache,mp=/mnt/off/cache
mp7: /zfs-hdd/$SERVICE/products,mp=/mnt/$SERVICE/products
mp8: /zfs-hdd/$SERVICE/images,mp=/mnt/$SERVICE/images
mp9: /zfs-hdd/opff/products,mp=/mnt/opff/products
mp10: /zfs-hdd/opff/images,mp=/mnt/opff/images
mp11: /zfs-hdd/opf/products,mp=/mnt/opf/products
mp12: /zfs-hdd/opf/images,mp=/mnt/opf/images
mp13: /zfs-hdd/off/logs,mp=/mnt/off/logs
mp14: /zfs-hdd/off-pro/cache/export_files,mp=/mnt/off-pro/cache/export_files
mp15: /zfs-hdd/off-pro/images,mp=/mnt/off-pro/images
…
lxc.idmap: u 0 100000 999
lxc.idmap: g 0 100000 999
lxc.idmap: u 1000 1000 10
lxc.idmap: g 1000 1000 10
lxc.idmap: u 1011 101011 64525
lxc.idmap: g 1011 101011 64525
```

```bash
pct reboot 113
```


for off-pro we don't need to cross mount the other platforms, but we need to share `off/data` folder !
and also `off/products` (because of `internal_code.sto`)
editing `/etc/pve/lxc/114.conf`:
```conf
mp0: /zfs-hdd/off-pro,mp=/mnt/off-pro
mp1: /zfs-nvme/off-pro/products,mp=/mnt/off-pro/products
mp10: /zfs-nvme/off/products,mp=/mnt/off/products
mp2: /zfs-hdd/off/users,mp=/mnt/off-pro/users
mp3: /zfs-hdd/off/orgs,mp=/mnt/off-pro/orgs
mp4: /zfs-hdd/off-pro/images,mp=/mnt/off-pro/images
mp5: /zfs-hdd/off-pro/html_data,mp=/mnt/off-pro/html_data
mp6: /zfs-hdd/off-pro/cache,mp=/mnt/off-pro/cache
mp7: /zfs-hdd/off/data,mp=/mnt/off-pro/data
mp8: /zfs-hdd/off-pro/sftp,mp=/mnt/off-pro/sftp
mp9: /zfs-hdd/off-pro/logs,mp=/mnt/off-pro/logs
…
lxc.idmap: u 0 100000 999
lxc.idmap: g 0 100000 999
lxc.idmap: u 1000 1000 10
lxc.idmap: g 1000 1000 10
lxc.idmap: u 1011 101011 64525
lxc.idmap: g 1011 101011 64525
```


```bash
pct reboot 114
```

**Warning**: after changing lxc idmap, the alex user which I already created, now as an id which is not mapped correctly. More over it was a mistake to create it immediatly as it have id 1000, which should be reserved to *off* user. This makes it impossible to log with ssh as .ssh/authorized_keys is not readable !

To remedy that, on $SERVICE and opf, using pct enter 111/2, we will also create off user:
```bash
usermod -u 1001 alex
groupmod -g 1001 alex
adduser --uid 1000 off
```
And then from off2, we will change ownership on the mounted ZFS dataset.
```bash
sudo chown 1001:1001 -R /zfs-hdd/pve/subvol-11{1,2}-disk-0/home/alex
```

### Create off user

This is the first user to create so that it got 1000 uid.

On off and off-pro

```bash
adduser off
```

## Getting the code


### Copying production code

I started by copying current code from off1 to each container, while avoiding data. I put code in `/srv/off-old/` and `/srv/off-pro-old/` so that I can easily compare to git code later on.


#### Verifying what to exclude

I first did the rsync but got the disks completely full ! So I gave a better look at disk usage on off1:

For off:
```bash
sudo du -sh -x /srv/off/*|sort -h
…
493M	/srv/off/taxonomies
606M	/srv/off/build-cache
662M	/srv/off/users  # this will go in zfs
878M	/srv/off/data  # this will go in zfs 
1.4G	/srv/off/lists  # those are html files generated on facets ?
3.0G	/srv/off/deleted.images  # if we keep them it should go it data
4.9G	/srv/off/debug
6.2G	/srv/off/scripts # see below
7.7G	/srv/off/tmp  # we can ditch, I suppose !
191G	/srv/off/html  # see below
1.8T	/srv/off/logs  # no need to carry arround --> SHOULD also be a specific volume… maybe in zfs ?

# what makes html so big ?
410M	/srv/off/html/js
844M	/srv/off/html/illustrations  # not in git
1001M	/srv/off/html/images  # a lot of files not in git
24G	/srv/off/html/files  # should be in data
165G	/srv/off/html/exports  # should be in data
# what makes htm/files so big ?
527M	/srv/off/html/files/mongod.20181230.log.gz
1003M	/srv/off/html/files/annotate
1.7G	/srv/off/html/files/debug
2.0G	/srv/off/html/files/presskit
4.5G	/srv/off/html/files/best_remap
5.9G	/srv/off/html/files/300.tar.gz
5.9G	/srv/off/html/files/products-20200324-890.tar.gz

# what makes scripts so big ?
102M	/srv/off/scripts/x
144M	/srv/off/scripts/scanbot.2020
485M	/srv/off/scripts/scanbot.old
868M	/srv/off/scripts/best_remap_202105_fr.filtered2.csv
951M	/srv/off/scripts/bak
1.3G	/srv/off/scripts/best_remap_202105_fr.filtered.csv
1.3G	/srv/off/scripts/best_remap_202105_fr.unfiltered.csv
```

For off-pro
```bash
sudo du -sh -x /srv/off-pro/*|sort -h

191M	/srv/off-pro/debug  # avoid it
273M	/srv/off-pro/node_modules.old # no need
276M	/srv/off-pro/node_modules # no need
295M	/srv/off-pro/build-cache # goes in zfs
364M	/srv/off-pro/html
885M	/srv/off-pro/new_images # should not be so big ! do not take it - we need the incron for it ?
1.4G	/srv/off-pro/export_files  # should go in zfs
7.6G	/srv/off-pro/deleted.images  # Not sure what to do
28G	/srv/off-pro/tmp  # ditch it !
47G	/srv/off-pro/logs  # no need, but logs should however go in zfs
60G	/srv/off-pro/import_files  # should be in data zfs volume
138G	/srv/off-pro/deleted_private_products
```

#### Copying code

On off2 as root:
```bash
mkdir /zfs-hdd/pve/subvol-113-disk-0/srv/off-old/
time rsync -x -a --info=progress2 --exclude "logs/" --exclude "html/images/products/" --exclude "html/data" --exclude="html/illustrations" --exclude "html/files" --exclude "html/exports"  --exclude "scripts/*.csv" --exclude "deleted.images" --exclude "tmp/" --exclude "new_images/" --exclude="build-cache" --exclude="debug" --exclude="node_modules" --exclude="node_modules.old" --exclude="users" --exclude="lists" --exclude="data" --exclude="orgs"  off1.openfoodfacts.org:/srv/off/ /zfs-hdd/pve/subvol-113-disk-0/srv/off-old/
# took 121m
# there are some permissions problems
time sudo chown 1000:1000 -R /zfs-hdd/pve/subvol-113-disk-0/srv/off-old/

mkdir /zfs-hdd/pve/subvol-114-disk-0/srv/off-pro-old/
time rsync -x -a --info=progress2 --exclude "logs/" --exclude "html/images/products/" --exclude "html/data" --exclude "html/" --exclude "deleted.images" --exclude "tmp/" --exclude "debug/" --exclude="node_modules" --exclude="node_modules.old"   --exclude "new_images/" --exclude="build-cache" --exclude="users" --exclude="orgs" --exclude="import_files" --exclude="deleted_private_products" --exclude="export_files" off1.openfoodfacts.org:/srv/off-pro/ /zfs-hdd/pve/subvol-114-disk-0/srv/off-pro-old/
# there are some permissions problems
time sudo chown 1000:1000 -R /zfs-hdd/pve/subvol-114-disk-0/srv/off-pro-old/
```


### Cloning off-server repository

First I create a key for off to access off-server repo:
```bash
# off or off-pro
SERVICE=off
sudo -u off ssh-keygen -f /home/off/.ssh/github_off-server -t ed25519 -C "off+off-server@$SERVICE.openfoodfacts.org"
sudo -u off vim /home/off/.ssh/config
…
# deploy key for openfoodfacts-server
Host github.com-off-server
        Hostname github.com
        IdentityFile=/home/off/.ssh/github_off-server
…
cat /home/off/.ssh/github_off-server.pub
```

Go to github add the off pub key for off to [productopener repository](https://github.com/openfoodfacts/openfoodfacts-server/settings/keys) with write access:

Then clone repository, on off:

```bash
sudo mkdir /srv/$SERVICE
sudo chown off:off /srv/$SERVICE
sudo -u off git clone git@github.com-off-server:openfoodfacts/openfoodfacts-server.git /srv/$SERVICE
sudo -u off git config pull.ff only
```

Make it shared:
```bash
cd /srv/$SERVICE
sudo -u off git config core.sharedRepository true
sudo chmod g+rwX -R .
```

I will generaly work to modify / commit to the repository using my user alex, while using off only to push.
So as alex on off / off-pro:
```
git config --global --add safe.directory /srv/$SERVICE
git config --global --add author.name "Alex Garel"
git config --global --add author.email "alex@openfoodfacts.org"
git config --global --add user.name "Alex Garel"
git config --global --add user.email "alex@openfoodfacts.org"
```

Do the same on off-pro.

### Finding git commit

Contrary to $SERVICE, opf and opff we don't have to do this, as we know we are on the last version !

### Finding difference with prod

diff -r -u  --exclude "logs/" --exclude "html/images/products/" --exclude "html/data" --exclude="html/illustrations" --exclude "html/files" --exclude "html/exports"  --exclude "scripts/*.csv" --exclude "deleted.images" --exclude "tmp/" --exclude "new_images/" --exclude="build-cache" --exclude="debug" --exclude="node_modules" --exclude="node_modules.old" --exclude="users" --exclude="lists" --exclude="data" --exclude="orgs" --exclude="html/images/products" --exclude=".git" /home/off/openfoodfacts-server /srv/off > /tmp/off-diff.patch


## Installing

### symlinks to mimic old structure

Now we create symlinks to mimic old structure so that we can move products between instances:

On off, as root:
```bash
for site in o{b,p,pf}f;do \
  mkdir -p /srv/$site/html/images/ && \
  chown -R off:off -R /srv/$site/ && \

  ln -s /mnt/$site/products /srv/$site/products; ln -s /mnt/$site/images/products /srv/$site/html/images/products; \
done
ls -l /srv/o{b,p,pf}f/ /srv/o{b,p,pf}f/html/images
```

We don't need it for off-pro


### linking data

Unless stated otherwise operation are done with user off.

Create links for users, orgs and products

```bash
# off or off-pro
SERVICE=off
ln -s /mnt/$SERVICE/products /srv/$SERVICE/products
ln -s /mnt/$SERVICE/users /srv/$SERVICE/users
ln -s /mnt/$SERVICE/orgs /srv/$SERVICE/orgs
# verify
ls -l /srv/$SERVICE/products /srv/$SERVICE/users /srv/$SERVICE/orgs /srv/$SERVICE/data
```

Create links for data folders:

```bash
# off or off-pro
SERVICE=off
# html data
mv /srv/$SERVICE/html/data/data-fields.* /mnt/$SERVICE/html_data/
rmdir /srv/$SERVICE/html/data
ln -s /mnt/$SERVICE/html_data /srv/$SERVICE/html/data
ln -s /mnt/$SERVICE/html_data/exports /srv/$SERVICE/html/exports
ln -s /mnt/$SERVICE/html_data/dump /srv/$SERVICE/html/dump
ln -s /mnt/$SERVICE/html_data/files /srv/$SERVICE/html/files
# product images
rm /srv/$SERVICE/html/images/products/.empty; rmdir /srv/$SERVICE/html/images/products/
ln -s /mnt/$SERVICE/images/products  /srv/$SERVICE/html/images/products
# verify
ls -ld /srv/$SERVICE/html/images/products /srv/$SERVICE/html/{data,exports,dump,files}
```

some direct links:
```bash
# off or off-pro
SERVICE=off

ln -s  /mnt/$SERVICE/deleted.images /srv/$SERVICE
ln -s  /mnt/$SERVICE/deleted_products /srv/$SERVICE
ln -s  /mnt/$SERVICE/deleted_products_images /srv/$SERVICE
ln -s  /mnt/$SERVICE/imports /srv/$SERVICE
ln -s  /mnt/$SERVICE/deleted_private_products /srv/$SERVICE
ln -s  /mnt/$SERVICE/reverted_products /srv/$SERVICE
ln -s  /mnt/$SERVICE/translate /srv/$SERVICE
ln -s  /mnt/$SERVICE/cache/debug /srv/$SERVICE/
ln -s  /mnt/$SERVICE/import_files /srv/$SERVICE/import_files
ln -s /mnt/$SERVICE/data /srv/$SERVICE/data
# verify
ls -l /srv/$SERVICE/{deleted.images,deleted_products,deleted_products_images,imports,deleted_private_products,reverted_products,translate,debug}
```

for off-pro we also need a link to `internal_code.sto`:
```bash
ln -s /mnt/off/products/internal_code.sto /srv/off-pro/products/
```

Create and link cache folders:

```bash
# off or off-pro
SERVICE=off
cd /srv/$SERVICE
rm build-cache/taxonomies/README.md; rmdir build-cache/taxonomies; rmdir build-cache
ln -s /mnt/$SERVICE/cache/build-cache /srv/$SERVICE/build-cache
ln -s /mnt/$SERVICE/cache/tmp /srv/$SERVICE/tmp
rm debug/.empty; rmdir debug
ln -s /mnt/$SERVICE/cache/debug /srv/$SERVICE/debug
ln -s /mnt/$SERVICE/cache/new_images /srv/$SERVICE/new_images
ln -s /mnt/$SERVICE/cache/export_files /srv/$SERVICE/export_files
# verify
ls -l /srv/$SERVICE/{build-cache,tmp,debug,new_images,export_files}
```

And on off, we need to be able to reach off-pro `export_files` and images:
```bash
# only for off !
sudo mkdir /srv/off-pro/
sudo chown off:off /srv/off-pro/
sudo -u off ln -s /mnt/off-pro/cache/export_files /srv/off-pro/export_files
sudo -u off mkdir /srv/off-pro/html
sudo -u off ln -s /mnt/off-pro/images /srv/off-pro/html/images
# verify
ls -l /srv/off-pro/export_files{,/} /srv/off-pro/images{,/}
```


We also want to move html/data/data-field.txt outside the data volume and link it, as user off.
```bash
# off or off-pro
SERVICE=off
cd srv/$SERVICE
mv html/data/data-field.txt html/data-field.txt
ln -s ../data-fields.txt html/data/data-fields.txt
```

### linking logs

We want logs to go in /var/logs and really in /mnt/off/logs .

We will create a directory for instance (off/off-pro) and also add links to nginx and apache2 logs.

```bash
# off or off-pro
SERVICE=off

# be sure to avoid having apache2 or nginx writing

sudo systemctl stop apache2 nginx
sudo -u off rm -rf /srv/$SERVICE/logs/

sudo mkdir /mnt/$SERVICE/logs/$SERVICE
sudo ln -s /mnt/$SERVICE/logs/$SERVICE /var/log/
sudo chown off:off -R /var/log/$SERVICE
sudo -u off ln -s /mnt/$SERVICE/logs/$SERVICE /srv/$SERVICE/logs

# also move nginx and apache logs
sudo mv /var/log/nginx /mnt/$SERVICE/logs
sudo mv /var/log/apache2 /mnt/$SERVICE/logs
sudo ln -s /mnt/$SERVICE/logs/nginx /var/log
sudo ln -s /mnt/$SERVICE/logs/apache2 /var/log

sudo  -u off ln -s ../apache2 /var/log/$SERVICE
sudo -u off ln -s ../nginx /var/log/$SERVICE

# verify
ls -l /srv/$SERVICE/logs /srv/$SERVICE/logs/ /var/log/{$SERVICE,nginx,apache2}
```

Copy original `log.conf` and `minion_log.conf` and make it a symlink.

```bash
# off or off-pro
SERVICE=off

mv /srv/$SERVICE-old/log.conf /srv/$SERVICE/conf/$SERVICE-log.conf
rm /srv/$SERVICE/log.conf
ln -s conf/$SERVICE-log.conf /srv/$SERVICE/log.conf
mv /srv/$SERVICE-old/minion_log.conf /srv/$SERVICE/conf/$SERVICE-minion_log.conf
rm /srv/$SERVICE/minion_log.conf
ln -s conf/$SERVICE-minion_log.conf /srv/$SERVICE/minion_log.conf
# verify
ls -l /srv/$SERVICE/{,minion_}log.conf 
```


### copy and verify config links

Config files:

```bash
# off or off-pro
SERVICE=off

cp /srv/$SERVICE-old/lib/ProductOpener/Config2.pm /srv/$SERVICE/lib/ProductOpener/Config2.pm
ln -s Config_off.pm /srv/$SERVICE/lib/ProductOpener/Config.pm
# verify
ls -l /srv/$SERVICE/lib/ProductOpener/{Config,Config2}.pm
```

Specific translations:
```bash
ln -s openfoodfacts /srv/$SERVICE/po/site-specific
```


### Verify broken links

`sudo find /srv/$SERVICE-old -xtype l | xargs ls -l`

On off-pro it reveals: `/srv/off-pro-old/index -> /srv/off/index`
but it's old stuff, it's now in `data/index`

### Adding dists

Create folders for dist:
```bash
# off or off-pro
declare -x SERVICE=off

sudo -E mkdir /srv/$SERVICE-dist
sudo -E chown off:off -R /srv/$SERVICE-dist
```

and unpack last dist release there (as user off):

```bash
wget https://github.com/openfoodfacts/openfoodfacts-server/releases/download/v2.15.0/frontend-dist.tgz -O /tmp/frontend-dist.tgz
tar xzf /tmp/frontend-dist.tgz -C /srv/$SERVICE-dist
```

And use symbolic links in folders (as user off):

```bash
# first link for whole folder
ln -s /srv/$SERVICE-dist /srv/$SERVICE/dist
# relative links for the rest
ln -s ../../../dist/icons /srv/$SERVICE/html/images/icons/dist
ln -s ../../../dist/attributes /srv/$SERVICE/html/images/attributes/dist
ln -s ../../dist/css /srv/$SERVICE/html/css/dist
ln -s ../../dist/js /srv/$SERVICE/html/js/dist
# verify
ls -l  /srv/$SERVICE/dist /srv/$SERVICE/html/{images/icons,images/attributesoovaf0fieKe|yae",css,js}/dist
```



### Adding openfoodfacts-web

#### Cloning repo

Note that I add to make two deploys keys as explained in [github documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#using-multiple-repositories-on-one-server) and use a specific ssh_config hostname for openfoodfacts-web:

Create new key, as off:
```bash
# off or off-pro
declare -x SERVICE=off

# deploy key for openfoodfacts-web
ssh-keygen -t ed25519 -C "off+off-web@$SERVICE.openfoodfacts.org" -f /home/off/.ssh/github_off-web
```

Add a specific host in ssh config
```conf
# /home/off/.ssh/config
Host github.com-off-web
    Hostname github.com
    IdentityFile=/home/off/.ssh/github_off-web
```

In github add the `/home/off/.ssh/github_off-web.pub` to deploy keys for openfoodfacts-web.

Cloning:
```bash
sudo mkdir /srv/openfoodfacts-web
sudo chown off:off /srv/openfoodfacts-web
sudo -u off git clone git@github.com-off-web:openfoodfacts/openfoodfacts-web.git /srv/openfoodfacts-web
```

#### Linking content

We clearly want off and off-pro lang folder to come from off-web:

```bash
ln -s /srv/openfoodfacts-web/lang /srv/$SERVICE/

# verify
ls -ld /srv/$SERVICE/lang
```

### Installing CPAN

```bash
cd /srv/off
sudo cpanm --notest --quiet --skip-satisfied "Apache::Bootstrap"
sudo cpanm --notest --quiet --skip-satisfied --installdeps .
```

## Fixing directory problems

We have a problem because some directory present in git are transformed to symlinks in production environement.
So this disallow making simple git pull to update code. Where this was one of the goal to maintain a clean deployment.

A solution to that is to remove those directory in the git. But to avoid complexifying usage, an idea is to centralize principal directory creation in the code itself.


## Setting up services

### Modify settings for memcached and postgresql

On off, edit `Config2.pm` to change:
* `$memd_servers` to 10.1.0.121
* `$server_options{minion_backend}{Pg}` to use 10.1.0.120 as the Postgres host

### NGINX for off and off-pro (inside their container)

Installed nginx `sudo apt install nginx`.

Removed default site `sudo unlink /etc/nginx/sites-enabled/default`

I added /srv/off/conf/nginx/conf.d/log_format_realip.conf (it's now in git).

Then made symlinks:
```bash
sudo ln -s /srv/$SERVICE/conf/nginx/sites-available/$SERVICE /etc/nginx/sites-enabled/
sudo ln -s /srv/$SERVICE/conf/nginx/snippets/expires-no-json-xml.conf /etc/nginx/snippets
sudo ln -s /srv/$SERVICE/conf/nginx/snippets/off.cors-headers.include /etc/nginx/snippets
sudo ln -s /srv/$SERVICE/conf/nginx/snippets/off.domain-redirects.include /etc/nginx/snippets
sudo ln -s /srv/$SERVICE/conf/nginx/snippets/off.locations-redirects.include /etc/nginx/snippets
sudo ln -s /srv/$SERVICE/conf/nginx/conf.d/log_format_realip.conf /etc/nginx/conf.d
sudo rm /etc/nginx/mime.types
sudo ln -s /srv/$SERVICE/conf/nginx/mime.types /etc/nginx/
# verify
ls -l /etc/nginx/sites-enabled/ /etc/nginx/snippets/ /etc/nginx/conf.d/log_format_realip.conf /etc/nginx/mime.types
```

On off and off-pro Modified their configuration to remove ssl section, change log path and access log format, and to set real_ip_resursive options (it's all in git)

test it:
```bash
sudo nginx -t
```

### Apache

We start by removing default config and disabling mpm_event in favor of mpm_prefork, and change logs permissions
```bash
sudo unlink /etc/apache2/sites-enabled/000-default.conf
sudo a2dismod mpm_event
sudo a2enmod mpm_prefork
sudo chown off:off -R /var/log/apache2 /var/run/apache2
```
and edit `/etc/apache2/envvars` to use off user:
```
#export APACHE_RUN_USER=www-data
export APACHE_RUN_USER=off
#export APACHE_RUN_GROUP=www-data
export APACHE_RUN_GROUP=off
```

* Add configuration in sites enabled
  ```bash
  sudo ln -s /srv/$SERVICE/conf/apache-2.4/sites-available/$SERVICE.conf /etc/apache2/sites-enabled/
  ```
* link `mpm_prefork.conf` to a file in git, identical as the one in production
  ```bash
  sudo rm /etc/apache2/mods-available/mpm_prefork.conf
  sudo ln -s /srv/$SERVICE/conf/apache-2.4/$SERVICE-mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf
  ```
* use customized ports.conf (8004 and 8014)
  ```bash
  sudo rm /etc/apache2/ports.conf
  sudo ln -s /srv/$SERVICE/conf/apache-2.4/$SERVICE-ports.conf /etc/apache2/ports.conf
  ```


test it in both container:
```bash
sudo apache2ctl configtest
```

We can restart apache2 then nginx:
```bash
sudo systemctl restart apache2
sudo systemctl restart nginx
```


### creating systemd units for timers gen feeds jobs and apache and nginx

We install mailx

```bash
sudo apt install mailutils
```

We copy the units from opff branch in the current branch.

```bash
git checkout origin/opff-main conf/systemd/
git add conf/systemd/
git commit -a -m "build: added systemd units"
```
and link them at system level
```bash
# off or off-pro
$SERVICE=off

sudo ln -s /srv/$SERVICE/conf/systemd/gen_feeds\@.timer /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/gen_feeds\@.service /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/gen_feeds_daily\@.service /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/gen_feeds_daily\@.timer /etc/systemd/system
# those are overides to get emails on failures
sudo ln -s /srv/$SERVICE/conf/systemd/apache2.service.d /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/nginx.service.d /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/email-failures\@.service /etc/systemd/system
# account for new services
sudo systemctl daemon-reload
```

Test failure notification is working:

```bash
sudo systemctl start email-failures@gen_feeds__$SERVICE.service
```

**TODO** Test systemctl gen_feeds services are working:

```bash
sudo systemctl start gen_feeds_daily@$SERVICE.service
sudo systemctl start gen_feeds@$SERVICE.service
```

**TODO** Activate systemd units:

```bash
sudo systemctl enable gen_feeds@$SERVICE.timer
sudo systemctl enable gen_feeds_daily@$SERVICE.timer
sudo systemctl daemon-reload
```

### creating systemd units for minions and OCR

For minions and process that send images to OCR, we simply link them:

```bash
sudo ln -s /srv/$SERVICE/conf/systemd/minion\@.service /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/cloud_vision_ocr\@.service /etc/systemd/system
sudo systemctl daemon-reload
```


**TODO** Activate systemd units:

```bash
sudo systemctl enable minion@$SERVICE.service
sudo systemctl enable cloud_vision_ocr@$SERVICE.service
sudo systemctl start minion@$SERVICE.service
sudo systemctl start cloud_vision_ocr@$SERVICE.service
```

**TODO** Test it's working

### log rotate perl logs

```bash
declare -x SERVICE=off
```


We get `conf/logrotate/apache` from opff in git repository:

```bash
sudo rm /etc/logrotate.d/apache2
sudo ln -s /srv/$SERVICE/conf/logrotate/apache2 /etc/logrotate.d/apache2
# logrotate needs root ownerships
sudo chown root:root /srv/$SERVICE/conf/logrotate/apache2
```

We can test with:
```bash
sudo logrotate /etc/logrotate.conf --debug
```

### Installing mongodb client

We need mongodb client to be able to export the database in gen_feeds.

I'll follow official doc for 4.4 https://www.mongodb.com/docs/v4.4/tutorial/install-mongodb-on-debian/,
but we are on bullseye, and we just want to install tools.

```bash
curl -fsSL https://pgp.mongodb.com/server-4.4.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg \
   --dearmor
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] http://repo.mongodb.org/apt/debian bullseye/mongodb-org/4.4 main" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt update
sudo apt install -y  mongodb-database-tools
```

### Test with curl

for off:
```bash
declare -x DOMAIN_NAME=openfoodfacts
declare -x PORT_NUM=8004
```

for off-pro:
```bash
declare -x DOMAIN_NAME=pro.openfoodfacts
declare -x PORT_NUM=8014
```


```bash
sudo systemctl restart nginx apache2
```


```bash
curl localhost:$PORT_NUM/cgi/display.pl --header "Host: fr.$DOMAIN_NAME.org"
```

Nginx call
```bash
curl localhost --header "Host: fr.$DOMAIN_NAME.org"
curl localhost/css/dist/app-ltr.css --header "Host: static.$DOMAIN_NAME.org"
```

### Nginx for madenearme on off

We want to serve madenearme websites from the off container using nginx.

It's the simplest way as it shares resources with off website.

I first reworked the madenearme nginx configuration file to support uk and fr as well at once.

Then linked config:

```bash
sudo ln -s /srv/off/conf/nginx/sites-available/madenearme /etc/nginx/sites-enabled/
# test
sudo nginx -t
# restart
sudo systemctl restart nginx
```

Test locally:

```bash
curl localhost --header "Host: madenear.me"
curl localhost/ --header "Host: cestemballepresdechezvous.fr"
curl localhost/ --header "Host: madenear.me.uk"
```


### Nginx for how much sugar on off

We want to serve how-much-sugar websites from the off container using nginx.

It's the simplest way as it shares resources with off website.

I first reworked the how-much-sugar nginx configuration file to support en and fr as well at once
and use the off public data directory (has html pages are generated, so considered data).

Then linked config:

```bash
sudo ln -s /srv/off/conf/nginx/sites-available/howmuchsugar /etc/nginx/sites-enabled/
# test
sudo nginx -t
# restart
sudo systemctl restart nginx
```

Test locally:

```bash
curl localhost --header "Host: howmuchsugar.in"
curl localhost/zest-sun-dried-tomato-paste-zest.html --header "Host: howmuchsugar
.in"
curl localhost/cgi/sugar_random.pl --header "Host: howmuchsugar.in"
curl localhost/ --header "Host: combiendesucres.fr"
curl localhost/cgi/sugar_random.pl --header "Host: combiendesucres.fr"
```

## Reverse proxy configuration

### certbot wildcard certificates using OVH DNS

We already install `python3-certbot-dns-ovh` so we just need to add credentials.

```bash
$ declare -x DOMAIN_NAME=openfoodfacts
```

**Note:** off-pro does not use the same wildcard certificate as off because *.pro.openfoodfacts.org is not in *.openfoodfacts.org. But it can use the same OVH credentials.

Generate credential, following https://eu.api.ovh.com/createToken/

Using (for off):
* name: `off proxy openfoodfacts.org`
* description: `nginx proxy on off2 for openfoodfacts.org`
* validity: `unlimited`
* GET `/domain/zone/`
  (note: the last `/` is important !)
* GET/PUT/POST/DELETE `/domain/zone/openfoodfacts.org/*`

and we put config file in `/root/.ovhapi/openfoodfacts.org`
```bash
$ mkdir /root/.ovhapi
$ vim /root/.ovhapi/$DOMAIN_NAME.org
...
$ cat /root/.ovhapi/$DOMAIN_NAME.org
# OVH API credentials used by Certbot
dns_ovh_endpoint = ovh-eu
dns_ovh_application_key = ***********
dns_ovh_application_secret = ***********
dns_ovh_consumer_key = ***********

# ensure no reading by others
$ chmod og-rwx -R /root/.ovhapi
```

Try to get a wildcard using certbot, we will choose to obtain certificates using a DNS TXT record, and use tech -at- off.org for notifications. We first try with `--test-cert`
```bash
$ certbot certonly --test-cert --dns-ovh --dns-ovh-credentials /root/.ovhapi/$DOMAIN_NAME.org -d $DOMAIN_NAME.org -d "*.$DOMAIN_NAME.org"
...
...
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/xxxxx.org/fullchain.pem
```
and then without `--test-cert`
```bash
$ certbot certonly --dns-ovh --dns-ovh-credentials /root/.ovhapi/$DOMAIN_NAME.org -d $DOMAIN_NAME.org -d "*.$DOMAIN_NAME.org"
...
...
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/xxxxx.org/fullchain.pem
...
```

For off-pro we use:

```bash
$ certbot certonly --dns-ovh --dns-ovh-credentials /root/.ovhapi/$DOMAIN_NAME.org -d pro.$DOMAIN_NAME.org -d "*.pro.$DOMAIN_NAME.org"
```

### Create site config for off and off-pro

In the git repository, we copied the openpetfoodfacts config and changed names to the right domain.

Then we linked them:
```bash
sudo ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/nginx/openfoodfacts.org /etc/nginx/sites-enabled/
sudo ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/nginx/pro.openfoodfacts.org /etc/nginx/sites-enabled/
# test
nginx -t
systemctl restart nginx
```


### Madenearme reverse proxy

#### create site configuration

We created the configuration and activate it:

```bash
sudo ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/nginx/madenear.me /etc/nginx/sites-enabled/
# test
sudo nginx -t
# reload config
sudo systemctl reload nginx
```

#### Generate certificates

We can't generate certificates with certbot while madenearme does not resolve to the right server…
and on old server, those are separate file, I don't want this here.
But to test it, I did a copy of those of off1, only for madenearme domain.

I tested it ok modifying my /etc/hosts to contain:
`213.36.253.214 madenear.me`


### How much sugar reverse proxy

#### create site configuration

We created the configuration and activate it:

```bash
sudo ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/nginx/howmuchsugar.in /etc/nginx/sites-enabled/
# test
sudo nginx -t
# reload config
sudo systemctl reload nginx
```

#### Generate certificates

We can't generate certificates with certbot while howmuchsugar.in does not resolve to the right server…
and on old server, those are separate file, I don't want this here.
But to test it, I did a copy of those of off1, only for howmuchsugar.in domain.

I tested it ok modifying my /etc/hosts to contain:
`213.36.253.214 howmuchsugar.in`



## Adding sftp to reverse proxy

We want to add the sftp server on the reveres proxy so we can use it's public IP.


### Add volume for data

We want a shared ZFS dataset for sftp data between the reverse proxy and off-pro container.

Create ZFS dataset, on off2:
```bash
sudo zfs create zfs-hdd/off-pro/sftp
# make top folders accessible to root inside a container (where id 0 is mapped to 100000)
chown 100000:100000 /zfs-hdd/off-pro/sftp/ /zfs-hdd/off-pro/sftp/*
```

We then change reverse proxy configuration (`/etc/pve/lxc/101.conf`) and off-pro (`/etc/pve/lxc/114.conf`) config to add a mount point. Somthing like `mp8: /zfs-hdd/off-pro/sftp,mp=/mnt/off-pro/sftp` (number after mp, depends on already existing one).

But we also need to remap ids in 101 so that id above 1000 to keep their id on the host.
So in `/etc/pve/lxc/101.conf`, we add similar sections as in the other containers.
As we add more users for sftp, we will reserve for a big number of account (all above 1000).

```conf
lxc.idmap: u 0 100000 999
lxc.idmap: g 0 100000 999
lxc.idmap: u 1000 1000 64536
lxc.idmap: g 1000 1000 64536
```
I also had to change `/etc/subuid` and `/etc/subgid`  to enable this, and have

```bash
root:1000:64536
```

After that we have to reboot both containers.
```bash
sudo pct reboot 101
sudo pct reboot 114
```

We verify it's working and we save config in off-infra project:
```bash
cd /opt/openfoodfacts-infrastructure/
for ct in $(ls /etc/pve/lxc/*.conf)
do
  num=$(basename $ct .conf)
  cp /etc/pve/lxc/$num.conf /opt/openfoodfacts-infrastructure/confs/off2/pve/lxc_$num.conf
done
cp /etc/pve/lxc/101.conf confs/off2/pve/lxc_101.conf
cp /etc/pve/lxc/114.conf confs/off2/pve/lxc_114.conf
git status 
…
```

### Rsync existing data from off1

on off2:
```bash
time rsync -a --info=progress2 10.0.0.1:/srv/sftp/ /zfs-hdd/off-pro/sftp/
# change root dirs permission to correspond to root inside container
chown 100000:100000 /zfs-hdd/off-pro/sftp/ /zfs-hdd/off-pro/sftp/*
```
it's quite fast.

### Configure sftp

In the reverse proxy container:
We create a config file for sftp in our repository and link it:

```bash
mkdir /opt/openfoodfacts-infrastructure/confs/proxy-off/sshd_config
touch /opt/openfoodfacts-infrastructure/confs/proxy-off/sshd_config/sftp
ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/sshd_config/sftp /etc/ssh/sshd_config.d/
```

We then edit the file, the same way as on off1

### Create sftp users

We want to re-create sftp users as they where on off1.
So instead of using command that creates them, we will copy them directly in /etc/passwd and /etc/groups in nginx proxy container. We also have to change their home directory.

First, on off1, I did verify we have same users in our sshd config by using:

```bash
grep "^Match User" /etc/ssh/sshd_config | cut -d " " -f 3| sort
grep /home/sftp /etc/passwd|cut -d ":" -f 1|sort
```

* sodebo is repeated in sshd_config, I fixed that.
* test is in /etc/passwd but not in sshd_config, so I removed it.


On off1:
```bash
grep /home/sftp /etc/passwd
```

I made a regexp to get all name and grep them from shadow and groups
```bash
exp=$(grep /home/sftp /etc/passwd|cut -d ":" -f 1|sort|tr  '\n' '|')
exp="("$exp"nonexistinguser)"

sudo grep -P "$exp" /etc/shadow
sudo grep -P "$exp" /etc/groups
```

We add the corresponding result on the reverse proxy to `/etc/passwd` and `/etc/shadow`,
using `vipw -p` and `vipw -s`.

We also have to change their home directory in `/etc/passwd` to point to the shared directory. We do so using `vipw -p` (in vi: `:%s!\/home\/sftp!\/mnt/off-pro/sftp!g`)

All those users are in sftponly group. So on reverse proxy we first add the group to `/etc/groups` using `vipw -g` (adding `sftponly:x:1006:`).
As this is the primary group for all those users, it is already set in `/etc/passwd` by previous edit


## Testing


To test my installation I added this to `/etc/hosts` on my computer:
```conf
213.36.253.214 fr.openfoodfacts.org world-fr.openfoodfacts.org static.openfoodfacts.org images.openfoodfacts.org world.openfoodfacts.org
213.36.253.214 fr.pro.openfoodfacts.org world-fr.pro.openfoodfacts.org static.pro.openfoodfacts.org images.pro.openfoodfacts.org world.pro.openfoodfacts.org
```




## Production switch

### TODO before switch

- **DONE** snapshot_purge should handle zfs/nvme !!!
- **DONE** handle sftp server… for imports --> on proxy to have direct network
- **DONE** handles html/files - should be in git ?
  - keep files in data
  - rename in git
    - keep tagline ?
    - keep ingredients analysis
  - link needed files there
  - move data/debug
- **DONE** move away things that are in html/files or do symlink for content that is in git ? Also files/debug for knowledge panels…
- **DONE** create ZFS dataset for `/var/log`
- **DONE** consider labelme deprecated. No data to recover it was on off2

- **DONE** is there anything to save for foodbattle ?
  - (done) code in /srv2/foodbattle
  - data in mongodb (none)
  - shared users folder with off
- **DONE** do we need as same as /root/scripts/renew_wildcard_certificates.sh on VM 101 (reverse proxy) on ovh1 ?
  - I don't think so, because certbot is able to handle this thanks to info in /etc/letsencrypt/renewal/openfoodfacts.org.conf

- **DONE** (alex): make agena and equadis imports run on off-pro side
  - (alex) modify scripts
  - (stephane) test xml_to_json.pl vs xml_to_json.js
  - (alex) make a specific systemd task for producers imports
  - **DONE** (alex) test scripts (up to the maximum) 

- **DONE** make a list of what we will rsync and what to backup from off1
  - we already have backup of /srv and /srv2 on ovh3 !

- **DONE** move madenearme*.htm and cestemballe*.html in ZFS and serve with nginx - or just serve them with nginx in container ?
  - (done) test map with reverse proxy
  - (done) make a specific systemd task for madenear.me generation
  - (done) install and test it

- **DONE** (alex) migrate howmanysugar
  - put html in html/data
  - it's ok if gen_sugar does not work
  - sugar_random and sugar_check should work (to fix)

- **DONE** have a well identified secrets directory for various secrets used by sh scripts (for those of perl, use Config2) --> see [Copying secrets](#copying-secrets)
  - ftp secrets (.netrc)

- **WONTFIX** do we need /srv/off/imports where to put it in new layout (not yet in Paths.pm)
  - We finally get rid of it

- **DONE:** migrate ip tables rules
  - on reverse proxy
  - (done) use fail2ban instead of iptables - see [How to use fail2ban to ban bots](../how-to-fail2ban-ban-bots.md)
  - (wontfix) we dont continue with the cron tail -n 10000 /srv/off/logs/access_log | grep search | /srv/off/logs/ban_abusive_ip.pl > /dev/null 2>&1 for now
  - NOTE: in parallel we are setting up rate limiting with nginx which could then be combined with fail2ban on 409 errors (easy to add to auth error bans)

- **WONTFIX** fix all scripts (eg. split_gs1_codeonline_json.pl) which use /srv/codeonline/imports as input and /srv2/off/codeonline/imports as output !
  - codeonline is obsolete --> moved to obsolete

- **DONE** what about zfs-old, can we add it to zfs-nvme ? (no)
  * see [removing zfs-old and adding as cache to zfs-hdd](#removing-zfs-old-and-adding-as-cache-to-zfs-hdd)

- **DONE** change my user uid/gid on off2 and create a off user with uid 1000
  to avoid ps -elf giving misleading information.
  * I ssh on off2 from off1 as root (because I will need to kill sshd process for alex)
  * change name and description: `usermod  -c "OFF service account" -l off alex` (after killing some processes though)
  * change group name `groupmod -n off alex` and remove from sudo `deluser off sudo`
  * `mkdir /home/off; cp /etc/skel/.* /home/off/; chown -R off:off /home/off; usermod -d /home/off off`
  * recreated my user `adduser alex` and change home owner `chown -R alex:alex /home/alex` and add to sudoers `adduser alex sudo`

- **WONTFIX** high fragmentation on ssd -- seems ok since it's not a problem for read and it will write back small files

- are we writting to lang/ ?
  * **WONTFIX** Missions.pm does --> we don't use it anymore ? however change the code to be sure (dying)
  * **WONTFIX** added a fixme to gen_sucres.pl and gen_sugar.pl
  * **DONE** gen_top_tags_per_country does --> move it to another folder (data/stats) and change display.pm logic

- (done) add export_producers_platform_data_to_public_database.sh to producers import task on off-pro (instead of a specific cron)

- **DOING** backup problem on 114
  - this seems to be a permission problem, fixed by Stephane

- **DOING** imports (to run on off-pro side):
  - **DONE** agena3000 (almost done - to test)
  - **DONE** equadis (almost done - to test)
  - **DONE** carrefour
    - modify to run on off-pro side + convert to new syntax + avoid having script inside sftp folder
  - fleurymichon deactivated (no data since 2021 - to be relaunched)
  - systemu is manual
  - casino was manual
  - bayard is a wip
  - intermarches is not auto but manual yet

- docs:
  - **FIXME** update all the documentation from install logs !
  - **TODO** migrate https://docs.google.com/document/d/1w5PpPB80knF0GR_nevWudz3zh7oNerJaQUJH0vIPjPQ/edit#heading=h.j4z4jdw3tr8r to this documentation

- **WONTFIX**  stress test VM on CPU and on Memory

- **DONE** schedule gen feeds smartly -- easy start off at 2am, the other platforms before

- **DONE** review the VM limits configurations
  * see https://docs.google.com/spreadsheets/d/19RePmE_-1V_He73fpMJYukEMjPWNmav1610yjpGKfD0/edit#gid=28709804
- **FIXME**: communicate on sftp IP change.
- **FIXME** see how to have rules to block ips for images nginx which is directly on off2
  - rate limit test running on off2
  - fail2ban might be a good idea

- **DOING** make a point on backup:
  * see what is in the backups of vz_dump: only the container disks
  + containers - on ZFS why don't we sync them on ovh3
  + eg imagine a fire at free - can we re-install ?
  - **DOING** syncing PVE volumes to OVH3

- **DONE** logrotate problem on nginx logs on reverse proxy

- **DONE** add alerting on logrotate failing


```
service: Failed to set up mount namespacing: /run/systemd/unit-root/proc: Permission denied
service: Failed at step NAMESPACE spawning /usr/sbin/logrotate: Permission denied

```


### Backup data

**FIXME**: list what we should backup

html/illustrations
scripts/*.csv
/srv2/backup ?

/home/off ?
/home/off ?
/home/off ?


#### code

- /home/scripts - already done in off-infrastructure
  - ftpbackup - obsolete (warning password inside)
  - remote_backup.sh - obsolete

#### users data

```bash
rsync -a --info=progress2 -x 10.0.0.1:/srv2/stephane /zfs-hdd/backups/off1-2023/srv2-stephane
rsync -a --info=progress2 -x 10.0.0.1:/srv2/teolemon /zfs-hdd/backups/off1-2023/srv2-teolemon
```


#### foodbatle

on off2:
```bash
mkdir /zfs-hdd/backups/off1-2023
rsync -a --info=progress2 -x 10.0.0.1:/srv2/foodbattle /zfs-hdd/backups/off1-2023/
```

I look at the mongodb but did not find any foodbattle databas


### Rsync data

This is the data rsync sequence:

off:

```bash
date ; \
echo "== users -- note: also done in crontab" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/users  /zfs-hdd/off/users ; \
echo "== orgs -- note: also done in crontab" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/orgs  /zfs-hdd/off/orgs ; \
echo "== some cache folders" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/{build-cache,tmp,debug,new_images} /zfs-hdd/off/cache/ ;\
echo "== data folders (shared with off-pro)" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/data /zfs-hdd/off/ ;\
echo "== other data" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/{deleted.images,deleted_products,deleted_products_images} /zfs-hdd/off/ ;\
echo "== imports for off" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv2/off/imports /zfs-hdd/off/ ;\
echo "== translations for off" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/translate /zfs-hdd/off/ ;\
echo "== reverted_products on off" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/reverted_products /zfs-hdd/off/ ;\
echo "== html/data" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/html/data/ /zfs-hdd/off/html_data ;\
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/html/{files,exports} /zfs-hdd/off/html_data/ ;\
time rsync --info=progress2 -a -x 10.0.0.1:/srv2/off/html/dump /zfs-hdd/off/html_data/ ;\
date
```

off-pro:

```bash
date ; \
echo "== pro images" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv2/off-pro/html/images/products /zfs-hdd/off-pro/images/ ;\
echo "== some cache folders" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off-pro/{build-cache,tmp,debug} /zfs-hdd/off-pro/cache/ ;\
echo "== other data" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off-pro/{deleted.images,deleted_private_products} /zfs-hdd/off-pro/ ;\
echo "== html/data" ; \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off-pro/html/data/ /zfs-hdd/off-pro/html_data ;\
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off-pro/html/files /zfs-hdd/off-pro/html_data/ ;\
echo "== sftp" ; \
time rsync -a --info=progress2 10.0.0.1:/srv/sftp/ /zfs-hdd/off-pro/sftp/ ;\
echo "== sugar" ; \
time rsync -a 10.0.0.1:/srv/sugar/logs/sugar_log /zfs-hdd/off/data/sugar/old_sugar_log ;\
date
```

This took a bit more than 6 hours on 2023-11-22.

Don't forget to also change ownership if needed

```bash
chown -R 1000:1000 /zfs-hdd/off{,-pro}/cache
```

### Procedure for switch of off and off-pro from off1 to off2

**NOTE**: we do both in a row because we don't want to deal with NFS for off / off-pro communication

**WARNING**: finish writing it before running it !!!


1. change TTL to a low value in DNS
  * **DONE** for openfoodfacts domains (including pro)
  * for madenear.me madenear.me.uk cestemballepresdechezvous and all other domains
  * for howmuchsugar.in combiendesucres.fr and all other domains

1. update the product to latest changes in `/srv/off` or `/srv/off-pro` and `/srv/openfoodfacts-web`

1. Redeploy the dist of off and off-pro on off2

1. verify differences between Config2 files (for off and off-pro) between off1 and off
   * I had to add `query_url` which is new

1. restart:

   * on off: `sudo systemctl restart apache2.service nginx.service cloud_vision_ocr@off.service minion@off.service`
   * on off-pro: `sudo systemctl restart apache2.service nginx.service cloud_vision_ocr@off-pro.service minion@off-pro.service`

1. do a last test:
   * I had to redo a `sudo cpanm --notest --quiet --skip-satisfied --installdeps .`
   * I forgot to run the build_lang and build_taxonomies scripts…
   * problem on pro platform for products without barcode: `internal_code.sto` not accessible on pro platform


1. shutdown:
   * off on **off2** `sudo systemctl stop apache2 nginx`
   * off-pro on **off2** `sudo systemctl stop apache2 nginx`

1. on off1 comment users and orgs rsync in crontab

1. Rync all data (on off2):
   see above  [Rsync data](#rsync-data)

4. products sync, on off1:
   - comment sto-products-sync.sh in root crontab
   - launch it a last time by hand

4. clean cron:
   - comment gen_all_feeds and gen_all_feeds_daily from crontab

2. shutdown off and off-pro on both side
   on off1:
   ```bash
   systemctl stop apache2@off
   systemctl stop apache2@off-pro
   unlink /etc/nginx/sites-enabled/off && unlink /etc/nginx/sites-enabled/off-pro && systemctl reload nginx
   ```

3. change DNS to point to new machine for openfoodfacts.org pro.openfoodfacts.org

3. Rsync and zfs sync again (see above)

4. ensure migrations works using mounts for off2 apps, and point to new user folder:
   * edit 110 to 112 mount points to mount off volumes (products and users) instead of NFS shares, by editing `/etc/pve/lxc/11{0..2}.conf`
   * restart 110 to 112: `for num in 11{0..2}; do  pct reboot $num; done`
   * save your new settings to git folder: `for num in 11{0..2}; do cp /etc/pve/lxc/$num.conf /opt/openfoodfacts-infrastructure/confs/off2/pve/lxc_$num.conf; done`

5. start :
   * off on container off2/113 (off): `sudo systemctl start apache2 nginx`
   * off-pro  on container off2/114 (off-pro): `sudo systemctl start apache2 nginx`

6. check it works (remember to also clean your /etc/hosts if you modified it for tests)

7. change DNS for madenear.me cestemballepresdechezvous.fr madenear.me.uk

7. regenerate the certificate for madenearme to have all domains:

   ```bash
   # test first
   certbot certonly --test-cert -d madenear.me -d cestemballepresdechezvous.fr -d madenear.me.uk
   # do it for real
   certbot certonly -d madenear.me -d cestemballepresdechezvous.fr -d madenear.me.uk
   ```

   (note: we had to change nginx site configuration and use web root authenticator)

7. change DNS for howmuchsugar.in combiendesucres.fr

7. regenerate the certificate for howmuchsugar.in to have all domains:

   ```bash
   # test first
   certbot certonly --test-cert -d howmuchsugar.in -d combiendesucres.fr
   # do it for real
   certbot certonly -d howmuchsugar.in -d combiendesucres.fr
   ```

   (note: we had to change nginx site configuration and use web root authenticator)

6. disable off and off-pro service on off1:
   - `systemctl disable apache2@off`
   - `systemctl disable apache2@off-pro`
   - **TODO** `unlink /etc/nginx/sites-enabled/off && unlink /etc/nginx/sites-enabled/off-pro && sytemctl reload nginx` (if not already done)

7. remove off and off-pro from snapshot-purge.sh on ovh3 (now handled by sanoid)
8. on off2 and ovh3 modify sanoid configuration to have off/products and off-pro/products handled by sanoid and synced to ovh3
9. don't forget to test that it still works after that

10. off1 cleanup:
    - remove or comment `/etc/logrotate.d/apache2-off`
    - remove or comment `/etc/logrotate.d/apache2-off-pro`

11. off2 cleanup:
    - remove the NFS mounts of off1 off and off-pro data


### Checks after one day

- check OCR is working
- check syncs happens
- check tag line is accessible (eg: https://world.openfoodfacts.org/files/tagline-off.json https://world.openfoodfacts.org/files/app/tagline/tagline-off-ios.json) even after removing those files from /srv/off/html/files/
**FIXME**: add more

see also: https://github.com/openfoodfacts/openfoodfacts-server/issues/9373

### Checks after five days

- check OCR is working
- check syncs happens
- check sftp still happens
**FIXME**: add more

### TODO after off1 re-install

- add replications

- add a restart of nginx in the certbot thing (or at night)
```
# restart nginx to reload SSL certs
0 11 * * * systemctl restart nginx
```

### TODO to have more things working
- add prometheus exporters to all machines:
  - for nginx on reverse proxy
  - for memcached on memcached container
  - for postgres on postgresql container
  - for apache on off/obf/opf/opff/off-pro

- **FIXME** put logs on zfs dataset for obf / opf / opff


- add go access report on reverse proxy
