# 2023-06-07 OPF and OBF reinstall on off2

We will follow closely what we did for [opff reinstall on off2](./2023-03-14-off2-opff-reinstall.md).
Refer to it if you need more explanation on a step.


## Putting data in zfs datasets

### creating datasets

Products dataset are already there, we create the other datasets.

```bash
zfs create zfs-hdd/obf/cache
zfs create zfs-hdd/obf/html_data
zfs create zfs-hdd/obf/images
zfs create zfs-hdd/opf/cache
zfs create zfs-hdd/opf/html_data
zfs create zfs-hdd/opf/images
```

and change permissions:

```bash
sudo chown 1000:1000  /zfs-hdd/o{b,p}f/{,html_data,images,cache}
```

### adding to sanoid conf

We do it asap, as we need some snapshots to be able to use syncoid.

We edit sanoid.conf to put our new datasets with `use_template=prod_data`.

We can launch the service immediately if we want: `systemctl start sanoid.service`


### migrating root datasets on ovh3

If we want to synchronize opf and obf root dataset, they have to be created by syncing from off2.
But as they already exists on ovh3, we have to create them, move products in them, and swap the old and the new one (avoiding doing so during a sync).

#### prepare

verify which datasets exists under the old root datasets on ovh3:

```bash
$ zfs list -r rpool/opf rpool/obf
NAME                 USED  AVAIL     REFER  MOUNTPOINT
rpool/obf           12.2G  23.9T      208K  /rpool/obf
rpool/obf/products  12.2G  23.9T     2.92G  /rpool/obf/products
rpool/opf           4.20G  23.9T      208K  /rpool/opf
rpool/opf/products  4.20G  23.9T     1.12G  /rpool/opf/products
```

as expected, only products have to be moved.

#### create new target datasets
On off2:

```bash
sudo syncoid --no-sync-snap zfs-hdd/opf  root@ovh3.openfoodfacts.org:rpool/opf-new
sudo syncoid --no-sync-snap zfs-hdd/obf  root@ovh3.openfoodfacts.org:rpool/obf-new
```
it's very fast.

#### move products to new dataset and swap datasets

```bash
zfs rename rpool/opf{,-new}/products && \
zfs rename rpool/opf{,-old} && \
zfs rename rpool/opf{-new,}

zfs rename rpool/obf{,-new}/products && \
zfs rename rpool/obf{,-old} && \
zfs rename rpool/obf{-new,}
```

#### setup sync

We can now sync them regularly by editing `/etc/sanoid/syncoid-args.conf`:

```conf
# opf
--no-sync-snap zfs-hdd/opf root@ovh3.openfoodfacts.org:rpool/opf
# obf
--no-sync-snap zfs-hdd/obf root@ovh3.openfoodfacts.org:rpool/obf
```

I also added it to `sanoid.conf` ovh3, but using synced template.


### Products

They already are synced (cf. [opff reinstall on off2](./2023-03-14-off2-opff-reinstall.md#products-for-all-flavors))

### Users

We have nfs mount of the users folder of off1, and will use it


### Products images

We will do a rsync, that we will have to repeat when putting in production.

On off2 (in a screen), as root:

```bash
time rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/html/images/products  /zfs-hdd/obf/images && \
time rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/html/images/products  /zfs-hdd/opf/images
```
this took 80 and 30 minutes.


Then sync to ovh3:

```bash
time syncoid --no-sync-snap zfs-hdd/obf/images root@ovh3.openfoodfacts.org:rpool/obf/images
time syncoid --no-sync-snap zfs-hdd/opf/images root@ovh3.openfoodfacts.org:rpool/opf/images
```

After first sync (which took took 31 and 38 min),

I added it to /etc/syncoid-args.conf
```bash
--no-sync-snap zfs-hdd/obf/images root@ovh3.openfoodfacts.org:rpool/obf/images
--no-sync-snap zfs-hdd/opf/images root@ovh3.openfoodfacts.org:rpool/opf/images
```

I also added it to `sanoid.conf` ovh3, but using synced template.


### Other data

I rsync cache data and other data on ofF2:

```bash
# cache
time rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/{build-cache,tmp,debug,new_images} /zfs-hdd/opf/cache
time rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/{build-cache,tmp,debug,new_images} /zfs-hdd/obf/cache
# other
time rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/{deleted.images,data} /zfs-hdd/opf/
time rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/{deleted.images,data} /zfs-hdd/obf/
# html/data
time rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/html/data/ /zfs-hdd/opf/html_data
time rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/html/data/ /zfs-hdd/obf/html_data
```
It took less than 3 min.

Then start the sync for cache and html_data:
```bash
for target in {opf,obf}/{cache,html_data}; do time syncoid --no-sync-snap zfs-hdd/$target root@ovh3.openfoodfacts.org:rpool/$target; done
```

Add them to `/etc/sanoid/syncoid-args.conf`

And on ovh3 add them to `sanoid.conf` with `synced_data` template


## Creating Containers

I created a CT for obf followings [How to create a new Container](../proxmox.md#how-to-create-a-new-container) it went all smooth.
I choosed a 30Gb disk, 0B swap, 4 Cores and 6 Gb memory.

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
juin 12 16:18:34 obf systemd[1]: geoipupdate.service: Succeeded.
juin 12 16:18:34 obf systemd[1]: Finished Weekly GeoIP update.
juin 12 16:18:34 obf systemd[1]: geoipupdate.service: Consumed 3.231s CPU time.
…
```

### Clone obf as opf

I then shutdow the obf VM and clone it as opf.

After cloning I had to change network IP address settings before starting.

### Installing packages

On obf and opf

```bash
sudo apt install -y apache2 apt-utils cpanminus g++ gcc less libapache2-mod-perl2 make gettext wget imagemagick graphviz tesseract-ocr libtie-ixhash-perl libwww-perl libimage-magick-perl libxml-encoding-perl libtext-unaccent-perl libmime-lite-perl libcache-memcached-fast-perl libjson-pp-perl libclone-perl libcrypt-passwdmd5-perl libencode-detect-perl libgraphics-color-perl libbarcode-zbar-perl libxml-feedpp-perl liburi-find-perl libxml-simple-perl libexperimental-perl libapache2-request-perl libdigest-md5-perl libtime-local-perl libdbd-pg-perl libtemplate-perl liburi-escape-xs-perl libmath-random-secure-perl libfile-copy-recursive-perl libemail-stuffer-perl liblist-moreutils-perl libexcel-writer-xlsx-perl libpod-simple-perl liblog-any-perl liblog-log4perl-perl liblog-any-adapter-log4perl-perl libgeoip2-perl libemail-valid-perl libmath-fibonacci-perl libev-perl libprobe-perl-perl libmath-round-perl libsoftware-license-perl libtest-differences-perl libtest-exception-perl libmodule-build-pluggable-perl libclass-accessor-lite-perl libclass-singleton-perl libfile-sharedir-install-perl libnet-idn-encode-perl libtest-nowarnings-perl libfile-chmod-perl libdata-dumper-concise-perl libdata-printer-perl libdata-validate-ip-perl libio-compress-perl libjson-maybexs-perl liblist-allutils-perl liblist-someutils-perl libdata-section-simple-perl libfile-which-perl libipc-run3-perl liblog-handler-perl libtest-deep-perl libwant-perl libfile-find-rule-perl liblinux-usermod-perl liblocale-maketext-lexicon-perl liblog-any-adapter-tap-perl libcrypt-random-source-perl libmath-random-isaac-perl libtest-sharedfork-perl libtest-warn-perl libsql-abstract-perl libauthen-sasl-saslprep-perl libauthen-scram-perl libbson-perl libclass-xsaccessor-perl libconfig-autoconf-perl libdigest-hmac-perl libpath-tiny-perl libsafe-isa-perl libspreadsheet-parseexcel-perl libtest-number-delta-perl libdevel-size-perl gnumeric libreadline-dev libperl-dev
```

## Mounting volumes

In our target production we will have obf, opf and opff in off2,
so we cross mount their products and images volumes,
while keeping nfs volumes for off products, and mounting zfs images volume.

But as opff is already in prod, we don't change it now

### changing lxc confs

On off2, editing /etc/pve/lxc/11{1,2}.conf

So for obf:
```conf
mp0: /zfs-hdd/obf,mp=/mnt/obf
mp1: /zfs-hdd/obf/products/,mp=/mnt/obf/products
mp2: /mnt/off1/off-users,mp=/mnt/obf/users
mp3: /zfs-hdd/obf/images,mp=/mnt/obf/images
mp4: /zfs-hdd/obf/html_data,mp=/mnt/obf/html_data
mp5: /zfs-hdd/obf/cache,mp=/mnt/obf/cache
mp6: /mnt/off1/off-products,mp=/mnt/off/products
mp7: /zfs-hdd/off/images,mp=/mnt/off/images
mp8: /zfs-hdd/opff/products,mp=/mnt/opff/products
mp9: /zfs-hdd/opff/images,mp=/mnt/opff/images
mp10: /zfs-hdd/opf/products,mp=/mnt/opf/products
mp11: /zfs-hdd/opf/images,mp=/mnt/opf/images
…
lxc.idmap: u 0 100000 999
lxc.idmap: g 0 100000 999
lxc.idmap: u 1000 1000 10
lxc.idmap: g 1000 1000 10
lxc.idmap: u 1011 101011 64525
lxc.idmap: g 1011 101011 64525
```

```bash
pct reboot 111
```


So for opf:
```conf
mp0: /zfs-hdd/opf,mp=/mnt/opf
mp1: /zfs-hdd/opf/products/,mp=/mnt/opf/products
mp2: /mnt/off1/off-users,mp=/mnt/opf/users
mp3: /zfs-hdd/opf/images,mp=/mnt/opf/images
mp4: /zfs-hdd/opf/html_data,mp=/mnt/opf/html_data
mp5: /zfs-hdd/opf/cache,mp=/mnt/opf/cache
mp6: /mnt/off1/off-products,mp=/mnt/off/products
mp7: /zfs-hdd/off/images,mp=/mnt/off/images
mp8: /zfs-hdd/opff/products,mp=/mnt/opff/products
mp9: /zfs-hdd/opff/images,mp=/mnt/opff/images
mp10: /zfs-hdd/obf/products,mp=/mnt/obf/products
mp11: /zfs-hdd/obf/images,mp=/mnt/obf/images
…
lxc.idmap: u 0 100000 999
lxc.idmap: g 0 100000 999
lxc.idmap: u 1000 1000 10
lxc.idmap: g 1000 1000 10
lxc.idmap: u 1011 101011 64525
lxc.idmap: g 1011 101011 64525
```

```bash
pct reboot 112
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

### SSH problem

I add a problem with ssh connection being very long.
Looking at /var/log/syslog why logging in, I saw:
```log
systemd-logind.service: Failed to set up mount namespacing: /run/systemd/unit-root/proc: Permission denied
Jun 13 13:35:19 obf systemd[734]: systemd-logind.service: Failed at step NAMESPACE spawning /lib/systemd/systemd-logind: Permission denied
```
It seems to be related to recent versions of systemd needs nesting (see [here](https://forum.proxmox.com/threads/question-on-nested-option-lxc-container.86497/post-381450)) and so I enabled it by editing `/etc/pve/lxc/11{1,2}.conf`, adding `features: nesting=1`. It fixes the problem. (and indeed 110 was created with this setting on)

## Getting the code

### Copying production code

I started by copying current code from off1 to each container, while avoiding data. I put code in `/srv/opf-old/` and `/srv/obf-old/` so that I can easily compare to git code later on.

On off2 as root:
```bash
mkdir /zfs-hdd/pve/subvol-111-disk-0/srv/obf-old/
rsync -x -a --info=progress2 --exclude "logs/" --exclude "html/images/products/" --exclude "html/data" --exclude "deleted.images" --exclude "tmp/" --exclude "new_images/" --exclude="build-cache" off1.openfoodfacts.org:/srv/obf/ /zfs-hdd/pve/subvol-111-disk-0/srv/obf-old/
# there are some permissions problems
sudo chown 1000:1000 -R /zfs-hdd/pve/subvol-111-disk-0/srv/obf-old/

mkdir /zfs-hdd/pve/subvol-112-disk-0/srv/opf-old/
rsync -x -a --info=progress2 --exclude "logs/" --exclude "html/images/products/" --exclude "html/data" --exclude "deleted.images" --exclude "tmp/" --exclude "new_images/" --exclude="build-cache" off1.openfoodfacts.org:/srv/opf/ /zfs-hdd/pve/subvol-112-disk-0/srv/opf-old/
# there are some permissions problems
sudo chown 1000:1000 -R /zfs-hdd/pve/subvol-112-disk-0/srv/opf-old/
```
### Cloning off-server repository

First I create a key for off to access off-server repo:
```bash
sudo -u off ssh-keygen -f /home/off/.ssh/github_off-server -t ed25519 -C "off+off-server@obf.openfoodfacts.org"
sudo -u off vim /home/off/.ssh/config
…
# deploy key for openfoodfacts-server
Host github.com-off-server
        Hostname github.com
        IdentityFile=/home/off/.ssh/github_off-server
…
cat /home/off/.ssh/github_off-server.pub
```
Go to github add the obf pub key for off to [productopener repository](https://github.com/openfoodfacts/openfoodfacts-server/settings/keys) with write access:

Then clone repository, on obf:

```bash
sudo mkdir /srv/obf
sudo chown off:off /srv/obf
sudo -u off git clone git@github.com-off-server:openfoodfacts/openfoodfacts-server.git /srv/obf
```

Make it shared:
```bash
cd /srv/obf
sudo -u off git config core.sharedRepository true
sudo chmod g+rwX -R .
```

I will generaly work to modify / commit to the repository using my user alex, while using off only to push.
So as alex on obf:
```
git config --global --add safe.directory /srv/obf
git config --global --add author.name "Alex Garel"
git config --global --add author.email "alex@openfoodfacts.org"
git config --global --add user.name "Alex Garel"
git config --global --add user.email "alex@openfoodfacts.org"
```

Do the same on opf.

### Finding git commit for obf

`ls -ltr /srv/obf-old/{lib/ProductOpener/,cgi/}` seems to indicate to search commits around 2021-02-03

`git log --stat --before=2021-02-03` to search, the last seems to be ok: `7443d1c839150a21a1a0e14834aa8674b52c5f43`

We checkout this one in `/srv/obf` and try to see the differences with `obf-old`.
I do this on my computer because I want to use meld.

NB: I had to change permissions for /srv/obf-old/html/js/bak/countries and /srv/obf-old/lang:
`sudo chmod a+rX -R /srv/obf-old/html/js/bak/countries /srv/obf-old/lang/`

It's a hard work…

See [Annex files difference for obf in git vs server](#annex-files-difference-for-obf-in-git-vs-server)

Also I copied Config2.pm: `cp /srv/obf-old/lib/ProductOpener/Config2.pm lib/ProductOpener/`

Also copied `Users.pm` as it has some protection to spam.


### Finding git commit for opf

`ls -ltr /srv/opf-old/{lib/ProductOpener/,cgi/}` seems to indicate to search commits around 2020-05-30

`git log --stat --before=2020-05-30` to search, the last with taxonomy build seems to be ok: ~~`88573d0b4450af9fd3fe4c342f46255007cab3b2`~~ but it's not,
if we look at po file and `lang/opf/en/texts/data.html`, we should take `ccf9ce1d5f42fe58b1462a13b7ed7c52dc335f4f`

We checkout this one in `/srv/obf` and try to see the differences with `obf-old`.
I do this on my computer because I want to use meld.

NB: I had to change permissions for /srv/obf-old/html/js/bak/countries and /srv/obf-old/lang:
`sudo chmod a+rX -R /srv/obf-old/html/js/bak/countries /srv/obf-old/lang/`

It's a hard work…

See [Annex files difference for opf in git vs server](#annex-files-difference-for-opf-in-git-vs-server)


## Installing

We have git cloned our repository in `/srv/o{b,p}f`.


### symlinks to mimic old structure
Now we create symlinks to mimic old structure:

On obf, as root:
```bash
for site in o{f,p,pf}f;do \
  mkdir -p /srv/$site/html/images/ && \
  chown -R off:off -R /srv/$site/ && \

  ln -s /mnt/$site/products /srv/$site/products; ln -s /mnt/$site/images/products /srv/$site/html/images/products; \
done
ls -l /srv/o{f,p,pf}f/ /srv/$site/html/images
```
on opf, same with `o{f,b,pf}f`


### linking data

Unless stated otherwise operation are done with user off.

Create links for users and products

for obf
```bash
ln -s /mnt/obf/products /srv/obf/products
ln -s /mnt/obf/users /srv/obf/users
# old versions of Product opener needs users_emails.sto in /srv/xxx
ln -s /mnt/obf/users/users_emails.sto /srv/obf/users_emails.sto
# verify
ls -l /srv/obf/html/data /srv/obf/users_emails.sto /srv/obf/products /srv/obf/users
```

for opf
```bash
ln -s /mnt/opf/products /srv/opf/products
ln -s /mnt/opf/users /srv/opf/users
# old versions of Product opener needs users_emails.sto in /srv/xxx
ln -s /mnt/opf/users/users_emails.sto /srv/opf/users_emails.sto
# verify
ls -l /srv/opf/html/data /srv/opf/users_emails.sto /srv/opf/products /srv/opf/users
```

We have some permissions problems on some data, to fix this on off2:
```
sudo chown 1000:1000 -R /zfs-hdd/opf/html_data/ /zfs-hdd/obf/html_data/
```

Create links for data folders, also moving data to zfs datasets:

for obf:
```bash
# html data
mv /srv/obf/html/data/data-fields.txt /mnt/obf/html_data/
rmdir /srv/obf/html/data
ln -s /mnt/obf/html_data /srv/obf/html/data
# product images
rmdir /srv/obf/html/images/products/
# verify
ln -s /mnt/obf/images/products  /srv/obf/html/images/products
```


for opf:
```bash
# html data
mv /srv/opf/html/data/data-fields.txt /mnt/opf/html_data/
rmdir /srv/opf/html/data
ln -s /mnt/opf/html_data /srv/opf/html/data
# product images
rmdir /srv/opf/html/images/products/
# verify
ln -s /mnt/opf/images/products  /srv/opf/html/images/products
```

We also want to move Lang file and deleted.images in data folder but keep compatibility (it's an old version)

for obf:
```bash
# deleted.images
mv /srv/obf/deleted.images /mnt/obf/
ln -s  /{mnt,srv}/obf/deleted.images
mkdir /mnt/obf/data/
# note: specific file name
cp /srv/obf-old/Lang.openbeautyfacts.org.sto /mnt/obf/data/
ln -s /mnt/obf/data/Lang.openbeautyfacts.org.sto /srv/obf/
```

for opf:
```bash
# deleted.images
mv /srv/opf/deleted.images /mnt/opf/
ln -s  /{mnt,srv}/opf/deleted.images
mkdir /mnt/opf/data/
# note: specific file name
cp /srv/opf-old/Lang.openproductsfacts.org.sto /mnt/opf/data/
ln -s /mnt/opf/data/Lang.openproductsfacts.org.sto /srv/opf/
```


Create and link cache folders

for obf:
```bash
# build-cache (was non existent)
mkdir /mnt/obf/cache/build-cache
ln -s /mnt/obf/cache/build-cache /srv/obf/build-cache
ln -s /mnt/obf/cache/tmp /srv/obf/tmp
ln -s /mnt/obf/cache/debug /srv/obf/debug
ln -s /mnt/obf/cache/new_images /srv/obf/new_images
# verify
ls -l /srv/obf/tmp /srv/obf/debug /srv/obf/new_images /srv/obf/build-cache
```

for opf:
```bash
# build-cache (was non existent)
mkdir /mnt/opf/cache/build-cache
ln -s /mnt/opf/cache/build-cache /srv/opf/build-cache
ln -s /mnt/opf/cache/tmp /srv/opf/tmp
ln -s /mnt/opf/cache/debug /srv/opf/debug
ln -s /mnt/opf/cache/new_images /srv/opf/new_images
# verify
ls -l /srv/opf/tmp /srv/opf/debug /srv/opf/new_images /srv/opf/build-cache
```

We also want to move html/data/data-field.txt outside the data volume and link it, as user off.
```bash
cd srv/obf
mv html/data/data-field.txt html/data-field.txt
ln -s ../data-fields.txt html/data/data-fields.txt
```
And add the `html/data-field.txt` file to git.

Opf does not have it on prod, still we had to commit the removal of `html/data/data-fields.txt` to the repository


### linking logs

We want logs to go in /var/logs.

We will create a directory for instance (obf/opf) and also add links to nginx and apache2 logs.

for obf:
```bash
sudo mkdir /var/log/obf
sudo chown off:off -R /var/log/obf
sudo -u off rmdir /srv/obf/logs/
sudo -u off ln -s /var/log/obf /srv/obf/logs
sudo  -u off ln -s ../apache2 /var/log/obf
sudo -u off ln -s ../nginx /var/log/obf
```

for opf:
```bash
sudo mkdir /var/log/opf
sudo chown off:off -R /var/log/opf
sudo -u off rmdir /srv/opf/logs/
sudo -u off ln -s /var/log/opf /srv/opf/logs
sudo  -u off ln -s ../apache2 /var/log/opf
sudo -u off ln -s ../nginx /var/log/opf
```


Copy original `log.conf` and make it a symlink.

For obf:
```bash
cp /srv/obf-old/log.conf /srv/obf/conf/obf-log.conf
rm /srv/obf/log.conf
ln -s conf/obf-log.conf /srv/obf/log.conf
# verify
ls -l /srv/obf/log.conf
```

For opf:
```bash
cp /srv/opf-old/log.conf /srv/opf/conf/opf-log.conf
rm /srv/opf/log.conf
ln -s conf/opf-log.conf /srv/opf/log.conf
# verify
ls -l /srv/opf/log.conf
```

### copy and verify config links

For obf:

```bash
cp /srv/obf-old/lib/ProductOpener/Config2.pm /srv/obf/lib/ProductOpener/Config2.pm
ln -s SiteLang_obf.pm /srv/obf/lib/ProductOpener/SiteLang.pm
ln -s Config_obf.pm /srv/obf/lib/ProductOpener/Config.pm
# verify
ls -l /srv/obf/lib/ProductOpener/{SiteLang,Config,Config2}.pm
```
and for opf, SiteLang does not seems to exist !
```bash
cp /srv/opf-old/lib/ProductOpener/Config2.pm /srv/opf/lib/ProductOpener/Config2.pm
ln -s Config_opf.pm /srv/opf/lib/ProductOpener/Config.pm
# verify
ls -l /srv/opf/lib/ProductOpener/{SiteLang,Config,Config2}.pm
```

### Verify broken links

obf:
`sudo find /srv/obf-old -xtype l | xargs ls -l`,
see [Annex: obf broken links](#annex-obf-broken-links)

opf:
`sudo find /srv/opf-old -xtype l | xargs ls -l`,
see [Annex: opf broken links](#annex-opf-broken-links)


### Adding dists

For obf:

Create a folder for dist:
```bash
sudo mkdir /srv/obf-dist
sudo chown off:off -R /srv/obf-dist 
```

As off, transfer dists in it (as user off):
```bash
cp -r  /srv/obf-old/html/images/icons/dist /srv/obf-dist/icons
cp -r /srv/obf-old/html/css/dist  /srv/obf-dist/css
cp -r /srv/obf-old/html/js/dist  /srv/obf-dist/js
```

And use symbolic links in folders (as user off):

```bash
# first link for whole folder
ln -s /srv/obf-dist /srv/obf/dist
# relative links for the rest
ln -s ../../../dist/icons /srv/obf/html/images/icons/dist
ln -s ../../dist/css /srv/obf/html/css/dist
ln -s ../../dist/js /srv/obf/html/js/dist
# verify
ls -l  /srv/obf/dist /srv/obf/html/{images/icons,css,js}/dist
```

Same for opf:

Create a folder for dist:
```bash
sudo mkdir /srv/opf-dist
sudo chown off:off -R /srv/opf-dist
```

As off, transfer dists in it (as user off):
```bash
cp -r  /srv/opf-old/html/images/icons/dist /srv/opf-dist/icons
cp -r /srv/opf-old/html/css/dist  /srv/opf-dist/css
cp -r /srv/opf-old/html/js/dist  /srv/opf-dist/js
```

And use symbolic links in folders (as user off):

```bash
# first link for whole folder
ln -s /srv/opf-dist /srv/opf/dist
# relative links for the rest
ln -s ../../../dist/icons /srv/opf/html/images/icons/dist
ln -s ../../dist/css /srv/opf/html/css/dist
ln -s ../../dist/js /srv/opf/html/js/dist
ls -l  /srv/opf/dist /srv/opf/html/{images/icons,css,js}/dist
```

### Adding openfoodfacts-web

We have some content that we want to take from openfoodfacts-web (also because shared with off). So we want to clone it.

#### Cloning repo

Note that I add to make two deploys keys as explained in [github documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#using-multiple-repositories-on-one-server) and use a specific ssh_config hostname for openfoodfacts-web:

Create new key, as off:
```bash
# deploy key for openfoodfacts-web
ssh-keygen -t ed25519 -C "off+off-web@obf.openfoodfacts.org" -f /home/off/.ssh/github_off-web
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

Do the same for opf

#### Linking content

We clearly want obf lang folder to come from off-web:

for obf (as off):
```bash
rm -rf /srv/obf/lang/obf/
ln -s /srv/openfoodfacts-web/lang/obf/ /srv/obf/lang/obf
```

for opf (as off):
```bash
rm -rf /srv/opf/lang/opf/
ln -s /srv/openfoodfacts-web/lang/opf/ /srv/opf/lang/opf
```

We then will link press, contacts, term of use (as user off)
```bash
# USE WITH CARE !
cd /srv/obf/lang
for FNAME in contacts.html press.html terms-of-use.html; do \
  for LANG in $(ls -d ?? ??_*); do \
    FILE_PATH=$LANG/texts/$FNAME;
    if [[ -e /srv/openfoodfacts-web/lang/$FILE_PATH ]]; then \
        rm $FILE_PATH; \
        ln -s /srv/openfoodfacts-web/lang/$FILE_PATH $FILE_PATH; \
    fi; \
  done; \
done;
```

We can verify with:
```bash
ls -l */texts/{contacts,press,terms-of-use}.html
```

Same for opf.

We keep the rest as is for now.


### Linking logo images

No need of it for obf, logo names are handled by `SiteLang_obf.pm` and `po/openbeautyfacts/??.po`

No need of it for opf neither, logo names are handled by `po/openbeautyfacts/??.po`

### Changing logo

On OBF:

We want to use the new logo. We uploaded a new version as:
- openbeautyfacts-logo.svg
- openbeautyfacts-logo-178x150.png
- openbeautyfacts-logo-356x300.png
- openbeautyfacts-logo-712x600.png

And the want to link every versions to them. For that we run.

```bash
cd /srv/obf/html/images/misc/
for f in openbeautyfacts-logo-??.svg;do rm $f;ln -s openbeautyfacts-logo.svg $f;done
for f in openbeautyfacts-logo-??-178x150.png;do rm $f && ln -s openbeautyfacts-logo-178x150.png $f;done
for f in openbeautyfacts-logo-??-356x300.png;do rm $f && ln -s openbeautyfacts-logo-356x300.png $f;done
for f in openbeautyfacts-logo-??-712x600.png;do rm $f && ln -s openbeautyfacts-logo-712x600.png $f;done
for f in openbeautyfacts-logo-??.png;do rm $f && ln -s openbeautyfacts-logo-178x150.png $f;done
rm openbeautyfacts-logo-zh-CN-712x600.png && ln -s openbeautyfacts-logo-712x600.png openbeautyfacts-logo-zh-CN-712x600.png
```


On OPF:

We want to use the new logo. We uploaded a new version as:
- openproductsfacts-logo.svg
- openproductsfacts-logo-178x150.png
- openproductsfacts-logo-356x300.png
- openproductsfacts-logo-712x600.png

And the want to link every versions to them. For that we run.

```bash
cd /srv/opf/html/images/misc/
for f in openproductsfacts-logo-??.svg;do rm $f;ln -s openproductsfacts-logo.svg $f;done
for f in openproductsfacts-logo-??-178x150.png;do rm $f && ln -s openproductsfacts-logo-178x150.png $f;done
for f in openproductsfacts-logo-??-356x300.png;do rm $f && ln -s openproductsfacts-logo-356x300.png $f;done
for f in openproductsfacts-logo-??-712x600.png;do rm $f && ln -s openproductsfacts-logo-712x600.png $f;done
for f in openproductsfacts-logo-??.png;do rm $f && ln -s openproductsfacts-logo-178x150.png $f;done
rm openproductsfacts-logo-zh-CN-712x600.png && ln -s openproductsfacts-logo-712x600.png openproductsfacts-logo-zh-CN-712x600.png
```


### Installing CPAN

First add `Apache2::Connection::XForwardedFor` and `Apache::Bootstrap` to cpanfile

```bash
cd /srv/obf
sudo apt install libapache2-mod-perl2-dev
sudo cpanm --notest --quiet --skip-satisfied --installdeps .
```


## Setting up services


### NGINX for OBF and OPF (inside container)

Installed nginx `sudo apt install nginx`.

Removed default site `sudo unlink /etc/nginx/sites-enabled/default`

On off2, Copied production nginx configuration of off1:
```
# base configs
sudo scp 10.0.0.1:/etc/nginx/sites-enabled/obf /zfs-hdd/pve/subvol-111-disk-0/srv/obf/conf/nginx/sites-available/
sudo scp 10.0.0.1:/etc/nginx/sites-enabled/opf /zfs-hdd/pve/subvol-112-disk-0/srv/opf/conf/nginx/sites-available/
# other config files
sudo scp 10.0.0.1:/etc/nginx/{expires-no-json-xml.conf,snippets/off.cors-headers.include} /zfs-hdd/pve/subvol-111-disk-0/srv/obf/conf/nginx/snippets/
sudo scp 10.0.0.1:/etc/nginx/{expires-no-json-xml.conf,snippets/off.cors-headers.include} /zfs-hdd/pve/subvol-112-disk-0/srv/opf/conf/nginx/snipets/
sudo scp 10.0.0.1:/etc/nginx/mime.types /zfs-hdd/pve/subvol-111-disk-0/srv/obf/conf/nginx/
sudo scp 10.0.0.1:/etc/nginx/mime.types /zfs-hdd/pve/subvol-112-disk-0/srv/opf/conf/nginx/
sudo chown 1000:1000 -R  /zfs-hdd/pve/subvol-111-disk-0/srv/obf/conf/
sudo chown 1000:1000 -R  /zfs-hdd/pve/subvol-112-disk-0/srv/opf/conf
```

I added /srv/obf/conf/nginx/conf.d/log_format_realip.conf (on obf), same for opf, with same content as the one on opff (it's now in git).

Then made symlinks:
* For obf:
  ```bash
  sudo ln -s /srv/obf/conf/nginx/sites-available /etc/nginx/sites-enabled/obf
  sudo ln -s /srv/obf/conf/nginx/snippets/expires-no-json-xml.conf /etc/nginx/snippets
  sudo ln -s /srv/obf/conf/nginx/snippets/off.cors-headers.include /etc/nginx/snippets
  sudo ln -s /srv/obf/conf/nginx/conf.d/log_format_realip.conf /etc/nginx/conf.d
  sudo rm /etc/nginx/mime.types
  sudo ln -s /srv/obf/conf/nginx/mime.types /etc/nginx/
  ```
* For opf:
  ```bash
  sudo ln -s /srv/opf/conf/nginx/sites-available /etc/nginx/sites-enabled/opf
  sudo ln -s /srv/opf/conf/nginx/snippets/expires-no-json-xml.conf /etc/nginx/snippets
  sudo ln -s /srv/opf/conf/nginx/snippets/off.cors-headers.include /etc/nginx/snippets
  sudo ln -s /srv/opf/conf/nginx/conf.d/log_format_realip.conf /etc/nginx/conf.d
  sudo rm /etc/nginx/mime.types
  sudo ln -s /srv/opf/conf/nginx/mime.types /etc/nginx/
  ```

On obf and opf Modified their configuration to remove ssl section, change log path and access log format, and to set real_ip_resursive options (it's all in git)

test it:
```bash
sudo nginx -t
```


### Apache

On obf and opf we start by removing default config and disabling mpm_event in favor of mpm_prefork, and change logs permissions
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


On obf:
* Add configuration for obf in sites enabled
  ```bash
  sudo ln -s /srv/obf/conf/apache-2.4/sites-available/obf.conf /etc/apache2/sites-enabled/
  ```
* link `mpm_prefork.conf` to a file in git, identical as the one in production
  ```bash
  sudo rm /etc/apache2/mods-available/mpm_prefork.conf
  sudo ln -s /srv/obf/conf/apache-2.4/obf-mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf
  ```
* use customized ports.conf for obf (8002)
  ```bash
  sudo rm /etc/apache2/ports.conf
  sudo ln -s /srv/obf/conf/apache-2.4/obf-ports.conf /etc/apache2/ports.conf
  ```

On opf:
* Add configuration for opf in sites enabled
  ```bash
  sudo ln -s /srv/opf/conf/apache-2.4/sites-available/opf.conf /etc/apache2/sites-enabled/
  ```
* link `mpm_prefork.conf` to a file in git, identical as the one in production
  ```bash
  sudo rm /etc/apache2/mods-available/mpm_prefork.conf
  sudo ln -s /srv/opf/conf/apache-2.4/opf-mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf
  ```
* use customized ports.conf for opf (8003)
  ```bash
  sudo rm /etc/apache2/ports.conf
  sudo ln -s /srv/opf/conf/apache-2.4/opf-ports.conf /etc/apache2/ports.conf
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

#### Problem when restarting apache2 on obf

In `/var/log/apache2/error.log`
```
Could not load taxonomy: /srv/obf/taxonomies/inci_functions.result.sto
```
repairing:
```bash
cp /srv/obf-old/taxonomies/inci_functions* /srv/obf/taxonomies/
```

### creating systemd units for timers jobs

We install mailx

```bash
sudo apt install mailutils
```

We copy the units from opff branch.

```bash
git checkout origin/opff-main conf/systemd/
git add conf/systemd/
git commit -a -m "build: added systemd units"
```
and link them at system level
```bash
declare -x PROJ_NAME=opf
sudo ln -s /srv/$PROJ_NAME/conf/systemd/gen_feeds\@.timer /etc/systemd/system
sudo ln -s /srv/$PROJ_NAME/conf/systemd/gen_feeds\@.service /etc/systemd/system
sudo ln -s /srv/$PROJ_NAME/conf/systemd/gen_feeds_daily\@.service /etc/systemd/system
sudo ln -s /srv/$PROJ_NAME/conf/systemd/gen_feeds_daily\@.timer /etc/systemd/system
sudo ln -s /srv/$PROJ_NAME/conf/systemd/email-failures\@.service /etc/systemd/system
# account for new services
sudo systemctl daemon-reload
```

Test failure notification is working:

```bash
sudo systemctl start email-failures@gen_feeds__$PROJ_NAME.service
```

Test systemctl gen_feeds services are working:

```bash
sudo systemctl start gen_feeds_daily@$PROJ_NAME.service
sudo systemctl start gen_feeds@$PROJ_NAME.service
```

Activate systemd units:

```bash
sudo systemctl enable gen_feeds@$PROJ_NAME.timer
sudo systemctl enable gen_feeds_daily@$PROJ_NAME.timer
sudo systemctl daemon-reload
```


### Adding failure notification for apache and nginx in systemd

We can add the on failure notification we created for timers to apache2.service and nginx.service.
We can get them from opff (at the time of writting it's on a specific branch)

```bash
declare -x PROJ_NAME=obf
cd /srv/$PROJ_NAME
sudo -u off git checkout origin/opff-reinstall-fixes -- conf/systemd/{apache2.service.d,nginx.service.d}
sudo ln -s /srv/opff/conf/systemd/nginx.service.d /etc/systemd/system/
sudo ln -s /srv/opff/conf/systemd/apache2.service.d /etc/systemd/system/
sudo systemctl daemon-reload
```


### log rotate perl logs

```bash
declare -x PROJ_NAME=obf
```


We get `conf/logrotate/apache` from opff and install it:

```bash
cd /srv/$PROJ_NAME
sudo -u off git checkout origin/opff-main -- conf/logrotate/apache2
sudo rm /etc/logrotate.d/apache2
sudo ln -s /srv/$PROJ_NAME/conf/logrotate/apache2 /etc/logrotate.d/apache2
# logrotate needs root ownerships
sudo chown root:root /srv/$PROJ_NAME/conf/logrotate/apache2
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
sudo apt install  mongodb-database-tools
```

### Test with curl

for obf:
```bash
declare -x DOMAIN_NAME=openbeautyfacts
declare -x PORT_NUM=8002
```

for opf:
```bash
declare -x DOMAIN_NAME=openproductsfacts
declare -x PORT_NUM=8003
```


```bash
curl localhost:$PORT_NUM/cgi/display.pl --header "Host: fr.$DOMAIN_NAME.org"
```

Nginx call
```bash
curl localhost --header "Host: fr.$DOMAIN_NAME.org"
```

### Using Matomo instead of google analytics

Copied configuration from OPFF and adapted with site id after creation of sites in Matomo.



## Reverse proxy configuration

### certbot wildcard certificates using OVH DNS

We already install `python3-certbot-dns-ovh` so we just need to add credentials.

```bash
$ declare -x DOMAIN_NAME=openbeautyfacts
```

Generate credential, following https://eu.api.ovh.com/createToken/

Using (for obf):
* name: `off proxy openbeautyfacts.org`
* description: `nginx proxy on off2 for openbeautyfacts.org`
* validity: `unlimited`
* GET `/domain/zone/`
  (note: the last `/` is important !)
* GET/PUT/POST/DELETE `/domain/zone/openbeautyfacts.org/*`

and we put config file in `/root/.ovhapi/openbeautyfacts.org` and `/root/.ovhapi/openproductsfacts.org`
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

### Create site config

In the git repository, we copied the openpetfoodfacts config and changed names to the right domain.

Then we linked them:
```bash
sudo ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/nginx/openbeautyfacts.org /etc/nginx/sites-enabled/
sudo ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/nginx/openproductsfacts.org /etc/nginx/sites-enabled/
# test
nginx -t
systemctl restart nginx
```

## Testing


To test my installation I added this to `/etc/hosts` on my computer:
```conf
213.36.253.214 fr.openbeautyfacts.org world-fr.openbeautyfacts.org static.openbeautyfacts.org images.openbeautyfacts.org world.openbeautyfacts.org
213.36.253.214 fr.openproductsfacts.org world-fr.openproductsfacts.org static.openproductsfacts.org images.openproductsfacts.org world.openproductsfacts.org
```

And it works at first try :tada: !

## Production switch


### Procedure for switch of obf off1 to off2

1. change TTL for openbeautyfacts domains to a low value in DNS

1. enable NFS sharing of needed datasets:

   ```bash
   sudo zfs set sharenfs=on zfs-hdd/obf/products
   sudo zfs set sharenfs=on zfs-hdd/obf/images
   ```

1. shutdown obf on **off2**
   `sudo systemctl stop apache2 nginx`

1. Rync all data (on off2):
  ```bash
  date && \
  sudo rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/html/images/products/  /zfs-hdd/obf/images/products/ && \
  sudo rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/html/data/  /zfs-hdd/obf/html_data/ && \
  sudo rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/deleted.images/ /zfs-hdd/obf/deleted.images/  && \
  date
  ```
  obf/cache is skipped, nothing of interest.

  it took 17min

4. products sync:
   - remove obf from sync products script
   - do a zfs send of only obf products with a modified version of the script

2. shutdown obf on both side
   on off1: `sudo systemctl stop apache2@obf` and `unlink /etc/nginx/sites-enabled/obf && systemctl reload nginx`

3. change DNS to point to new machine

3. Rsync and zfs sync again

   rsync took 8 minutes

4. ensure migrations works using NFS for off1 apps:
   ```bash
   # move old prod
   mv /srv/obf /srv/obf.old
   # create dirs
   mkdir -p /srv/obf/products /srv/obf/html/images/products
   chown off:off -R /srv/obf
   ```
   then change /etc/fstab to mount off1 there:
   ```conf
   # mount of opff zfs datasets via NFS to enable products migrations
   10.0.0.2:/zfs-hdd/obf/products	/srv/obf/products	nfs	rw,nolock	0	0
   10.0.0.2:/zfs-hdd/obf/images/products	/srv/obf/html/images/products	nfs	rw,nolock	0	0
   ```
   and mount:
   ```bash
   mount /srv/obf/products
   mount /srv/obf/html/images/products
   ```

4. ensure migrations works using mounts for off2 apps:
   * edit 110 and 112 mount points to mount obf volumes instead of NFS shares, by editing `/etc/pve/lxc/11{0,2}.conf`
   * save your new settings to git folder: `cp /etc/pve/lxc/110.conf /opt/openfoodfacts-infrastructure/confs/off2/pve/lxc_110.conf` and `cp /etc/pve/lxc/112.conf /opt/openfoodfacts-infrastructure/confs/off2/pve/lxc_112.conf`
   * restart 110 and 112: `sudo pct reboot 110; sudo pct reboot 112`

5. start obf on container off2/111 (obf): `sudo systemctl start apache2 nginx`
6. check it works (remember to also clean your /etc/hosts if you modified it for tests)
6. disable obf service on off1:
   - `systemctl disable apache2@obf`
   - `unlink /etc/nginx/sites-enabled/obf && sytemctl reload nginx` (if not already done)

7. remove obf from snapshot-purge.sh on ovh3 (now handled by sanoid)
8. on off2 and ovh3 modify sanoid configuration to have obf/products handled by sanoid and synced to ovh3
9. don't forget to test that it still works after that

10. off1 cleanup:
    - remove obf gen feeds from `/srv/off/scripts/gen_all_feeds.sh` and `/srv/off/scripts/gen_all_feeds_daily.sh`
    - remove or comment `/etc/logrotate.d/apache2-obf`

11. off2 cleanup:
    - remove the NFS mounts of off1 obf data


### Procedure for switch of opf off1 to off2

1. change TTL for openproductsfacts domains to a low value in DNS

1. enable NFS sharing of needed datasets:

   ```bash
   sudo zfs set sharenfs=on zfs-hdd/opf/products
   sudo zfs set sharenfs=on zfs-hdd/opf/images
   ```

1. shutdown opf on **off2**
   `sudo systemctl stop apache2 nginx`

1. Rync all data (on off2):
  ```bash
  date && \
  sudo rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/html/images/products/  /zfs-hdd/opf/images/products/ && \
  sudo rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/html/data/  /zfs-hdd/opf/html_data/ && \
  sudo rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/deleted.images/ /zfs-hdd/opf/deleted.images/  && \
  date
  ```
  opf/cache is skipped, nothing of interest.

4. products sync:
   - remove opf from sync products script
   - do a zfs send of only opf products with a modified version of the script

   rsync took 7 min.

2. shutdown opf on both side
   on off1: `sudo systemctl stop apache2@opf` and `unlink /etc/nginx/sites-enabled/opf && systemctl reload nginx`


3. change DNS to point to new machine

3. Rsync and zfs sync again

   rsync took 2 min

4. ensure migrations works using NFS for off1 apps:
   ```bash
   # move old prod
   mv /srv/opf /srv/opf.old
   # create dirs
   mkdir -p /srv/opf/products /srv/opf/html/images/products
   chown off:off -R /srv/opf
   ```
   then change /etc/fstab to mount off1 there:
   ```conf
   # mount of opff zfs datasets via NFS to enable products migrations
   10.0.0.2:/zfs-hdd/opf/products	/srv/opf/products	nfs	rw,nolock	0	0
   10.0.0.2:/zfs-hdd/opf/images/products	/srv/opf/html/images/products	nfs	rw,nolock	0	0
   ```
   and mount:
   ```bash
   mount /srv/opf/products
   mount /srv/opf/html/images/products
   ```

4. ensure migrations works using mounts for off2 apps:
   * edit 110 and 111 mount points to mount opf volumes instead of NFS shares, by editing `/etc/pve/lxc/11{0,1}.conf`
   * save your new settings to git folder: `cp /etc/pve/lxc/110.conf /opt/openfoodfacts-infrastructure/confs/off2/pve/lxc_110.conf` and `cp /etc/pve/lxc/111.conf /opt/openfoodfacts-infrastructure/confs/off2/pve/lxc_111.conf`
   * restart 110 and 111: `sudo pct reboot 110;sudo pct reboot 111`

5. start opf on container off2/112 (opf): `sudo systemctl start apache2 nginx`
6. check it works (remember to also clean your /etc/hosts if you modified it for tests)
6. disable opf service on off1:
   - `systemctl disable apache2@opf`
   - `unlink /etc/nginx/sites-enabled/opf && sytemctl reload nginx` (if not already done)

7. remove opf from snapshot-purge.sh on ovh3 (now handled by sanoid)
8. on off2 and ovh3 modify sanoid configuration to have opf/products handled by sanoid and synced to ovh3
9. don't forget to test that it still works after that

10. off1 cleanup:
    - remove opf gen feeds from `/srv/off/scripts/gen_all_feeds.sh` and `/srv/off/scripts/gen_all_feeds_daily.sh`
    - remove or comment `/etc/logrotate.d/apache2-opf`

11. off2 cleanup:
    - remove the NFS mounts of off1 opf data



## Annex: obf broken links

### TODO

```
# to be handled by creating symlinks to off-web
lang/??/texts/contacts.html -> /srv/off/lang/??/texts/contacts.html
lang/??/texts/press.html -> /srv/off/lang/??/texts/presskit.html

```

### DONE

```
products -> /rpool/obf/products
users -> /srv/off/users
users_emails.sto -> /srv/off/users_emails.sto

# updated in git
html/robots.txt -> /srv/off/html/robots.txt
```


### WONTFIX

```
# javascript
html/bower_components -> /srv/obf/node_modules/@bower_components
html/js-old/jquery-interestingviews-selectclip.js -> /home/off-fr/cgi/jquery-interestingviews-selectclip.js
html/js-old/product.js -> /home/off-fr/cgi/product.js
html/js/bak2/jquery-interestingviews-selectclip.js -> /home/off-fr/cgi/jquery-interestingviews-selectclip.js
html/js/bak2/jquery.rotate.js -> jQueryRotateCompressed.2.1.js
html/js/bak2/jquery.tagsinput.css -> xoxco-jQuery-Tags-Input-6d2b1d3/jquery.tagsinput.css
html/js/bak2/jquery.tagsinput.js -> xoxco-jQuery-Tags-Input-6d2b1d3/jquery.tagsinput.js
html/js/jquery-interestingviews-selectclip.js -> /home/off-fr/cgi/jquery-interestingviews-selectclip.js

# off fr
lang/es/tags/labels.txt -> /home/off-fr/cgi/labels.es.txt
lang/fr/tags/categories.txt -> /home/off-fr/cgi/categories.txt
lang/fr/tags/labels.txt -> /home/off-fr/cgi/labels.txt
ingredients/additifs/authorized_additives.txt -> /home/off-fr/cgi/authorized_additives.pl
ingredients/additifs/extract_additives.pl -> /home/off-fr/cgi/extract_additives.pl

```


## Annex: opf broken links

### TODO

```
# to be handled by creating symlinks to off-web
lang/??/texts/contacts.html -> /srv/off/lang/??/texts/contacts.html
lang/??/texts/press.html -> /srv/off/lang/??/texts/presskit.html
```

### DONE

```
products -> /rpool/opf/products
users -> /srv/off/users
users_emails.sto -> /srv/off/users_emails.sto
```



### WONTFIX

```
html/bower_components -> ../node_modules/@bower_components
html/images/misc/android-apk.svg -> /srv/opf/html/images/misc/android-apk-40x135.svg
html/robots.txt -> /srv/off/html/robots.txt
```

## Annex: files difference for obf in git vs server

**TO DECIDE**
```
cgi/
  madenearme.pl
  madenearyou.pl
```


**DONE different**
```
templates/donate_banner.tt.html
```

**DONE missing**
```
html/
  robots-disallow.txt
  .well-known
html/.well-known/
  assetlinks.json
html/images/misc/
  obf-favicon.png
  obf-logo-en.white.2200x1800.png
  obf-logo-en.white.220x180.png
  obf-logo-fr.blanc.2200x1800.png
  obf-logo-fr.blanc.220x180.png
  openbeautyfacts-logo-de-178x150.png
  openbeautyfacts-logo-de-356x300.png
  openbeautyfacts-logo-es-356x300.png
  openbeautyfacts-logo-it-178x150.png
  openbeautyfacts-logo-it-356x300.png
  openbeautyfacts-logo-pl-178x150.png
  openbeautyfacts-logo-pl-356x300.png
  openbeautyfacts-logo-pt-356x300.png
  openbeautyfacts-logo-ru-178x150.png
  openbeautyfacts-logo-ru-356x300.png
html/images/misc/microsoft
  Chinese-Traditional.svg
  Czech.svg
  Dutch.svg
  Finnish.svg
  German.svg
  Hebrew.svg
  Hungarian.svg
  Japanese_get it from MS_864X312.svg
  Korean.svg
  microsoft
  Portuguese-Portugal.svg
  Russian.svg
  Slovak.svg
  Slovenian.svg
  Turkish.svg
  Vietnamese.svg
lib/ProductOpener
  SiteQuality_off.pm
po/common
  nl_be.po
  pt_pt.po
po/tags
  nl_be.po
  pt_pt.po
```

**TODO**
```
lang/**/texts/
  open-beauty-hunt.html
  open-beauty-facts-mobile-app.html
lang/fr/texts
  missions_list.html

index/ # put in cache
  categories_nutriments_per_country.??.sto
  countries
  countries_points.sto
  ambassadors_countries_points.sto
  ambassadors_users_points.sto
```

**TODO differently**
```
log
log.conf

products
users
users_emails.sto

scripts: ProductOpener
lib/ProductOpener
  SiteQuality.pm
  SiteLang.pm
```


**WONTFIX missing**
```
css
js
missions.sto
texts
test
translate
html/js:
  dist
  autoresize.jquery.min.js ?
  canvas-to-blob.min.js
  carouFredSel
  datatables.js
  countries
html:
  index.obf.shtml
  index.shtml
  index.txt
  make_static.sh
  md5sum
html/images/misc
  additives.new.html
  additives.old.html
  apps
  a.338x72.png
  ajax-loader.gif
  android-apk.112x40.png
  android-apk.131x47.png
  android-apk-old.svg
  b.338x72.png
  c.338x72.png
  d.338x72.png
  e.338x72.png
  google-play-badge-svg-master
html/images/icons
  egg.svg
  egg.white.96x96.png
  egg.white.svg
  leaf.svg
  leaf.white.96x96.png
  leaf_white.svg
  monkey_happy.svg
  monkey_happy.white.96x96.png
  monkey_happy.white.svg
  monkey_uncertain.svg
  monkey_uncertain.white.96x96.png
  monkey_uncertain.white.svg
  monkey_unhappy.svg
  monkey_unhappy.white.96x96.png
  monkey_unhappy.white.svg
html/images/lang/en/labels  # WON'T FIX food labels
  doca-rioja.121x90.png
  do-manzanilla-sanlucar-de-barrameda.54x90.png
  do-montilla-moriles.145x90.png
  do-navarra.77x90.png
  do-toro.108x90.png
  eg-oko-verordnung.110x90.svg
  ohne-gentechnik.90x90.svg
  pdo-arroz-de-calasparra.74x90.png
  pdo-arroz-de-valencia.90x90.png
  pdo-azafran-de-la-mancha.78x90.png
  pdo-chufa-de-valencia.52x90.png
  pdo-estepa.76x90.png
  pdo-montes-de-granada.91x90.png
  pdo-montes-de-toledo.64x90.png
  pdo-pasas-de-malaga.72x90.png
  pdo-pera-de-lleida.34x90.png
  pdo-peras-de-rincon-de-soto.88x90.png
  pdo-pimenton-de-la-vera.52x90.png
  pdo-pimenton-de-murcia.78x90.png
  pdo-sierra-de-segura.133x90.png
  pdo-vinagre-de-jerez.54x90.png
  pgi-alubia-de-la-baneza-leon.120x90.png
  pgi-berenjena-de-almagro.40x90.png
  pgi-esparrago-de-navarra.85x90.png
  pgi-garbanzo-de-fuentesauco.160x90.png
  pgi-lenteja-de-la-armuna.95x90.png
  pgi-lenteja-pardina-de-tierra-de-campos.120x90.png
  pgi-mazapan-de-toledo.96x90.png
  pgi-pemento-do-couto.142x90.png
  pgi-platano-de-canarias.128x90.png
  pgi-turron-de-alicante.74x90.png
  pgi-turron-de-jijona.74x90.png
  real-california-milk-90x90.png
cgi/:
  product-multilingual.js
  profile.plpo/common
  nl_be.po
  pt_pt.po
po/tags
  nl_be.po
  pt_pt.po

lib/
  startup.pl

packager-codes/
  FR-merge.csv

po/common
  common-web.pot
po/openfoodfacts:
  nl_be.po
po/openpetfoodfacts
  nl_be.po
scss:
  app.scss
  templates
```

## Annex files difference for opf in git vs server


**TO DECIDE**
```
html/images/banners/donate/
  donate-banner.independent.fr.1600x300.png
  donate-banner.research.fr.1600x300.png
  donate-banner.personal.fr.1600x300.png

html/
  countries.html
  langs.html
  products_countries.html
translate/
  categories.ru.txt
  ingredients.ru.txt
```


**TODO**
```
lang/
```



**DONE missing**
```
.well-known/assetlinks.json
/home/alex/docker/tmp/opf-old/html/images/misc/microsoft/
  Chinese-Traditional.svg
  Czech.svg
  Dutch.svg
  Finnish.svg
  German.svg
  Hebrew.svg
  Hungarian.svg
  Korean.svg
  Portuguese-Portugal.svg
  Russian.svg
  Slovak.svg
  Slovenian.svg
  Turkish.svg
  Vietnamese.svg
lib/ProductOpener
  SiteQuality.pm
cgi/
  madenearme.pl
  madenearyou.pl
```

**DONE modified**
```
html/products_countries.js # contains "Open Products Facts"
madenearme/
  madenearme-fr.html
  madenearme-uk.html
```


**TODO differently**
```
html/css/dist/
htm/icons/dist
html/js/dist
lib/ProductOpener
  Config.pm  # link
  Config2.pm  # local only
  SiteQuality.pm  # link

index/*.sto  # generated files to put in cache
po/site-specific  # link
Lang.openproductsfacts.org.sto
```

**WONTFIX modified**
```
emb_codes/villes-geo-france-galichon-20130208.csv
dump/*
html/files/tagline-off.json
lib/ProductOpener/Config_opff.pm
po/ # small changes
```

**WONTFIX missing**
```
fonts/icons/*
html/lang/de/labels/*.png  # renamed or moved to en
html/lang/fr/labels/*.png

html/images/misc/google-play-badge-svg-master  # made a zip sent to pierre

html/images/misc/
  android-apk-40x135.svg
  android-apk-old.svg
  android-apk.112x40.png
  android-apk.131x47.png
html/js/
  barcode
  cropper-20150415
  jquery.tagsinput.20150416
  jquery.imgareaselect-0.9.8
  jquery.autocomplete.20150416
  jquery-ui-1.11.4
  gnuwilliam-jQuery-Tags-Input-a648557
  lang/*
  xoxco-jQuery-Tags-Input-6d2b1d3
  zeroclipboard
  ZeroClipboard.js
  ZeroClipboard.swf
  autoresize.jquery.min.js
  canvas-to-blob.min.js
  datatables.js
  jquery.form.js.old
  jquery.iframe-transport.js
  jquery.iframe-transport.min.js
  jquery.imgareaselect-0.9.8.zip
  jquery.autoresize.js
  jquery.cookie.js
  jquery.cookie.js.js
  jquery.cookie.min.js
  jquery.fileupload-ip.js
  jquery.fileupload-ip.min.js
  jquery.fileupload.js
  jquery.fileupload.min.js
  highcharts.js
  highcharts.js.2.2.5
  highcharts.js.3.0.1
  highcharts.js.4.0.4
  jQueryRotateCompressed.2.1.js
  jquery.rotate.js
  jquery.transit.min.js
  load-image.min.js
  mColorPicker.js
  mColorPicker_min.js
  mColorPicker_min.js.old
  master
  zeroclipboard-1.0.7.tar
mediawiki/*  # seems out of place
node_modules/  # no nodes
packager-codes/
scripts/
  # dead code
  fix_code_stored_as_number.pl
  fix_countries_removed_by_yuka.pl
  fix_deleted_products.pl
  fix_leading_zeros.pl
  fix_product.pl
  fix_product2.pl
  franprix.pl
  gen_categories_stats.pl
  gen_top_tags.pl
  import_xxx.sh
  nutrinet_libelles.pl
  nutrinet_libelles2.pl
  po2jqueryi18.pl
  remove_deleted_products_form_db.pl
  test_addifitfs.pl
  update_texts_from_wiki.pl
  update_users.pl
  upload_photos.pl
  upload_photos_2016_franprix.pl
  upload_photos_2018_liege.pl
  upload_photos_foodvisor.sh
  upload_photos_saintelucie_maisonduthe.sh
  upload_photos_scanparty_rotterdam_1.sh
  upload_photos_scanparty_rotterdam_ekoplaza.sh
t/sitequality.t # renamed
```

