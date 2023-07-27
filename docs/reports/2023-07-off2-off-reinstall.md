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
--no-sync-snap zfs-hdd/obf root@ovh3.openfoodfacts.org:rpool/obf
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

### Copying other data


I rsync cache data and other data on ofF2:

```bash
# cache
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/{build-cache,tmp,debug,new_images} /zfs-hdd/off/cache/
# for off-pro I don't copy new_images as it's really full and non working ! (takes 18m)
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off-pro/{build-cache,tmp,debug} /zfs-hdd/off-pro/cache/
# other
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/{deleted.images,deleted_products,deleted_products_images,data,exports,imports} /zfs-hdd/off/
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off-pro/{deleted.images,deleted_products,deleted_products_images,data,imports} /zfs-hdd/off-pro/
# html/data
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/html/data/ /zfs-hdd/off/html_data
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/html/{dump,files,exports} /zfs-hdd/off/html_data/

time rsync --info=progress2 -a -x 10.0.0.1:/srv/off-pro/html/data/ /zfs-hdd/off-pro/html_data
time rsync --info=progress2 -a -x 10.0.0.1:/srv/off/html/files /zfs-hdd/off/html_data/
```
It took less than 3 min.

I already add them to `/etc/sanoid/syncoid-args.conf` so sync will happen.

And on ovh3 add them to `sanoid.conf` with `synced_data` template


## Creating Containers

I created a CT for OFF followings [How to create a new Container](../promox.md#how-to-create-a-new-container) it went all smooth.
I choosed a 30Gb disk, 0B swap, 8 Cores and 40 Gb memory.

Note that my first container creation failed because unable to mount the ZFS volume ("zfs dataset is busy"…), I had to destroy the dataset and re-create the container.

I also [configure postfix](../mail#postfix-configuration) and tested it.

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
juin 12 16:18:34 obf systemd[1]: geoipupdate.service: Succeeded.
juin 12 16:18:34 obf systemd[1]: Finished Weekly GeoIP update.
juin 12 16:18:34 obf systemd[1]: geoipupdate.service: Consumed 3.231s CPU time.
…
```


### Clone off as off-pro

I then shutdow the obf VM and clone it as off-pro.

After cloning I changes to 4 cores and 6 Gb memory. change network IP address settings before starting.


### Installing packages

On off and off-pro

```bash
sudo apt install -y apache2 apt-utils cpanminus g++ gcc less libapache2-mod-perl2 make gettext wget imagemagick graphviz tesseract-ocr libtie-ixhash-perl libwww-perl libimage-magick-perl libxml-encoding-perl libtext-unaccent-perl libmime-lite-perl libcache-memcached-fast-perl libjson-pp-perl libclone-perl libcrypt-passwdmd5-perl libencode-detect-perl libgraphics-color-perl libbarcode-zbar-perl libxml-feedpp-perl liburi-find-perl libxml-simple-perl libexperimental-perl libapache2-request-perl libdigest-md5-perl libtime-local-perl libdbd-pg-perl libtemplate-perl liburi-escape-xs-perl libmath-random-secure-perl libfile-copy-recursive-perl libemail-stuffer-perl liblist-moreutils-perl libexcel-writer-xlsx-perl libpod-simple-perl liblog-any-perl liblog-log4perl-perl liblog-any-adapter-log4perl-perl libgeoip2-perl libemail-valid-perl libmath-fibonacci-perl libev-perl libprobe-perl-perl libmath-round-perl libsoftware-license-perl libtest-differences-perl libtest-exception-perl libmodule-build-pluggable-perl libclass-accessor-lite-perl libclass-singleton-perl libfile-sharedir-install-perl libnet-idn-encode-perl libtest-nowarnings-perl libfile-chmod-perl libdata-dumper-concise-perl libdata-printer-perl libdata-validate-ip-perl libio-compress-perl libjson-maybexs-perl liblist-allutils-perl liblist-someutils-perl libdata-section-simple-perl libfile-which-perl libipc-run3-perl liblog-handler-perl libtest-deep-perl libwant-perl libfile-find-rule-perl liblinux-usermod-perl liblocale-maketext-lexicon-perl liblog-any-adapter-tap-perl libcrypt-random-source-perl libmath-random-isaac-perl libtest-sharedfork-perl libtest-warn-perl libsql-abstract-perl libauthen-sasl-saslprep-perl libauthen-scram-perl libbson-perl libclass-xsaccessor-perl libconfig-autoconf-perl libdigest-hmac-perl libpath-tiny-perl libsafe-isa-perl libspreadsheet-parseexcel-perl libtest-number-delta-perl libdevel-size-perl gnumeric libreadline-dev libperl-dev
```


## Mounting volumes

In our target production we will have everything in off2,
so we cross mount their products and images volumes.

We will change config for opff, opf and obf at migration time.

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
mp7: /zfs-hdd/obf/products,mp=/mnt/obf/products
mp8: /zfs-hdd/obf/images,mp=/mnt/obf/images
mp9: /zfs-hdd/opff/products,mp=/mnt/opff/products
mp10: /zfs-hdd/opff/images,mp=/mnt/opff/images
mp11: /zfs-hdd/opf/products,mp=/mnt/opf/products
mp12: /zfs-hdd/opf/images,mp=/mnt/opf/images
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


for off-pro we don't need to cross mount the other platforms, editing `/etc/pve/lxc/114.conf`:
```conf
mp0: /zfs-hdd/off-pro,mp=/mnt/off-pro
mp1: /zfs-nvme/off-pro/products,mp=/mnt/off-pro/products
mp2: /zfs-hdd/off/users,mp=/mnt/off-pro/users
mp3: /zfs-hdd/off/orgs,mp=/mnt/off-pro/orgs
mp4: /zfs-hdd/off-pro/images,mp=/mnt/off-pro/images
mp5: /zfs-hdd/off-pro/html_data,mp=/mnt/off-pro/html_data
mp6: /zfs-hdd/off-pro/cache,mp=/mnt/off-pro/cache
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

To remedy that, on obf and opf, using pct enter 111/2, we will also create off user:
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

Contrary to obf, opf and opff we don't have to do this, as we know we are on the last version !

### Finding difference with prod

diff -r -u  --exclude "logs/" --exclude "html/images/products/" --exclude "html/data" --exclude="html/illustrations" --exclude "html/files" --exclude "html/exports"  --exclude "scripts/*.csv" --exclude "deleted.images" --exclude "tmp/" --exclude "new_images/" --exclude="build-cache" --exclude="debug" --exclude="node_modules" --exclude="node_modules.old" --exclude="users" --exclude="lists" --exclude="data" --exclude="orgs" --exclude="html/images/products" --exclude=".git" /home/off/openfoodfacts-server /srv/off > /tmp/off-diff.patch

### symlinks to mimic old structure
Now we create symlinks to mimic old structure:

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




## Setting up services


### NGINX for OBF and OPF (inside container)


Installed nginx `sudo apt install nginx`.

Removed default site `sudo unlink /etc/nginx/sites-enabled/default`

On off2, Copied production nginx configuration of off1:
```
# base configs
sudo scp 10.0.0.1:/etc/nginx/sites-enabled/off /zfs-hdd/pve/subvol-113-disk-0/srv/off/conf/nginx/sites-available/
sudo scp 10.0.0.1:/etc/nginx/sites-enabled/off-pro /zfs-hdd/pve/subvol-114-disk-0/srv/off-pro/conf/nginx/sites-available/
# other config files
sudo scp 10.0.0.1:/etc/nginx/{expires-no-json-xml.conf,snippets/off.cors-headers.include} /zfs-hdd/pve/subvol-113-disk-0/srv/off/conf/nginx/snippets/
sudo scp 10.0.0.1:/etc/nginx/{expires-no-json-xml.conf,snippets/off.cors-headers.include} /zfs-hdd/pve/subvol-114-disk-0/srv/off-pro/conf/nginx/snipets/
sudo scp 10.0.0.1:/etc/nginx/mime.types /zfs-hdd/pve/subvol-113-disk-0/srv/off/conf/nginx/
sudo scp 10.0.0.1:/etc/nginx/mime.types /zfs-hdd/pve/subvol-114-disk-0/srv/off-pro/conf/nginx/
sudo chown 1000:1000 -R  /zfs-hdd/pve/subvol-113-disk-0/srv/off/conf/
sudo chown 1000:1000 -R  /zfs-hdd/pve/subvol-114-disk-0/srv/off-pro/conf
```

I added /srv/off/conf/nginx/conf.d/log_format_realip.conf (on off), same for off-pro, with same content as the one on off-prof (it's now in git).

Then made symlinks:
* For off:
  ```bash
  sudo ln -s /srv/off/conf/nginx/sites-available /etc/nginx/sites-enabled/off
  sudo ln -s /srv/off/conf/nginx/snippets/expires-no-json-xml.conf /etc/nginx/snippets
  sudo ln -s /srv/off/conf/nginx/snippets/off.cors-headers.include /etc/nginx/snippets
  sudo ln -s /srv/off/conf/nginx/conf.d/log_format_realip.conf /etc/nginx/conf.d
  sudo rm /etc/nginx/mime.types
  sudo ln -s /srv/off/conf/nginx/mime.types /etc/nginx/
  ```
* For off-pro:
  ```bash
  sudo ln -s /srv/off-pro/conf/nginx/sites-available /etc/nginx/sites-enabled/off-pro
  sudo ln -s /srv/off-pro/conf/nginx/snippets/expires-no-json-xml.conf /etc/nginx/snippets
  sudo ln -s /srv/off-pro/conf/nginx/snippets/off.cors-headers.include /etc/nginx/snippets
  sudo ln -s /srv/off-pro/conf/nginx/conf.d/log_format_realip.conf /etc/nginx/conf.d
  sudo rm /etc/nginx/mime.types
  sudo ln -s /srv/off-pro/conf/nginx/mime.types /etc/nginx/
  ```

On off and off-pro Modified their configuration to remove ssl section, change log path and access log format, and to set real_ip_resursive options (it's all in git)

test it:
```bash
sudo nginx -t
```

## installing a postgresql container

## installing a memcached container




## Production switch


### Procedure for switch of off and off-pro from off1 to off2 (Still TODO)

**NOTE**: we do both in a row because we don't want to deal with NFS for off / off-pro communication

**WARNING**: finish writing it before running it !!!

1. change TTL for openfoodfacts domains (including pro) to a low value in DNS

1. shutdown:
   * off on **off2** `sudo systemctl stop apache2 nginx`
   * off-pro on **off2** `sudo systemctl stop apache2 nginx`

1. on off1 comment users and orgs sync in crontab

1. Rync all data (on off2):
  ```bash
  date && \
  sudo rsync --info=progress2 -a -x 10.0.0.1:/srv/off/html/images/products/  /zfs-hdd/off/images/products/ && \
  sudo rsync --info=progress2 -a -x 10.0.0.1:/srv/off/html/data/  /zfs-hdd/off/html_data/ && \
  sudo rsync --info=progress2 -a -x 10.0.0.1:/srv/off/deleted.images/ /zfs-hdd/off/deleted.images/  && \

  **FIXME** add more !

  sudo rsync --info=progress2 -a -x 10.0.0.1:/srv/off/users/ /zfs-hdd/off/users/  && \
  sudo rsync --info=progress2 -a -x 10.0.0.1:/srv/off/orgs/ /zfs-hdd/off/orgs/  && \
  date
  ```
  off/cache is skipped, nothing of interest.

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

3. change DNS to point to new machine

3. Rsync and zfs sync again (see above)

   rsync took **FIXME** minutes

4. avoid mistake by renaming dirs
   ```bash
   # move old prod
   mv /srv/off /srv/off.old
   mv /srv/off-pro /srv/off-pro.old
   ```

4. ensure migrations works using mounts for off2 apps, and point to new user folder:
   * edit 110 to 112 mount points to mount off volumes (products and users) instead of NFS shares, by editing `/etc/pve/lxc/11{0..2}.conf`
   * restart 110 to 112: `for num in 11{0..2}; do  pct reboot $num; done`
   * save your new settings to git folder: `for num in 11{0..2}; do cp /etc/pve/lxc/$num.conf /opt/openfoodfacts-infrastructure/confs/off2/pve/lxc_$num.conf; done`

5. start :
   * off on container off2/113 (off): `sudo systemctl start apache2 nginx`
   * off-pro  on container off2/114 (off-pro): `sudo systemctl start apache2 nginx`

6. check it works (remember to also clean your /etc/hosts if you modified it for tests)

6. disable off and off-pro service on off1:
   - `systemctl disable apache2@off`
   - `systemctl disable apache2@off-pro`
   - `unlink /etc/nginx/sites-enabled/off && unlink /etc/nginx/sites-enabled/off-pro && sytemctl reload nginx` (if not already done)

6. **FIXME** think what else to remove

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
**FIXME**: add more

### Checks after five days

- check OCR is working
- check syncs happens
**FIXME**: add more