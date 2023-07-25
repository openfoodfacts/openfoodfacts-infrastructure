# 2023-06-07 OFF and OFF-pro reinstall on off2

We will follow closely what we did for [OPFF reinstall on off2](./2023-03-14-off2-opff-reinstall.md).
Refer to it if you need more explanation on a step.
Also following [OPF and OBF reinstall on off2](./2023-06-07-off2-opf-obf-reinstall.md).


## Putting data in zfs datasets

### fixing a syslog bug

In syslog I saw a lot of `zfs error: cannot open 'zfs-nvme/pve': dataset does not exist`

I decided to fix it by creating this dataset:
```bash
zfs create zfs-nvme/pve
```


### creating datasets

Products and images datasets are already there, we create the other datasets.

```bash
SERVICE=off
zfs create zfs-hdd/$SERVICE/cache
zfs create zfs-hdd/$SERVICE/html_data
```
same for `off-pro`

but also created `images` for `off-pro`

```bash
zfs create zfs-hdd/off-pro/images
```

and change permissions:

```bash
sudo chown 1000:1000  /zfs-hdd/off{,-pro}/{,html_data,images,cache}
```

We also need to create off/orgs
```bash
zfs create zfs-hdd/off/orgs
sudo chown 1000:1000  /zfs-hdd/off/orgs
```


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

### Creating Containers

I created a CT for OFF followings [How to create a new Container](../promox.md#how-to-create-a-new-container) it went all smooth.
I choosed a 30Gb disk, 0B swap, 8 Cores and 40 Gb memory.

Note that my first container creation failed because unable to mount the ZFS volume ("zfs dataset is busy"…), I had to destroy the dataset and re-create the container.

I also [configure postfix](../mail#postfix-configuration) and tested it.

**Important:** do not create any user until you changed id maping in lxc conf (see [Mounting volumes](#mounting-volumes)). And also think about creating off user before any other user to avoid having to change users uids, off must have uid 1000.


#### Installing generic packages

I also installed generic packages:

```bash
sudo apt install -y apache2 apt-utils g++ gcc less make gettext wget vim
```


#### Geoip with updates

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


#### Clone off as off-pro

I then shutdow the obf VM and clone it as off-pro.

After cloning I changes to 4 cores and 6 Gb memory. change network IP address settings before starting.

#### Installing packages

#### Installing packages

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
