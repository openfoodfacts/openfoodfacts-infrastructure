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
time rsync --info=progress2 -a -x 10.0.0.1:/srv/opf/html/data /zfs-hdd/opf/html_data
time rsync --info=progress2 -a -x 10.0.0.1:/srv/obf/html/data /zfs-hdd/obf/html_data
```
It took less than 3 min.

Then start the sync for cache and html_data:
```bash
for target in {opf,obf}/{cache,html_data}; do time syncoid --no-sync-snap zfs-hdd/$target root@ovh3.openfoodfacts.org:rpool/$target; done
```

Add them to `/etc/sanoid/syncoid-args.conf`

And on ovh3 add them to `sanoid.conf` with `synced_data` template


### Creating Containers

I created a CT for obf followings [How to create a new Container](../promox.md#how-to-create-a-new-container) it went all smooth.
I choosed a 30Gb disk, 0B swap, 4 Cores and 6 Gb memory.

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

#### Clone obf as opf

I then shutdow the obf VM and clone it as opf.

After cloning I had to change network IP address settings before starting.

#### Installing packages

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

## Getting the code

### Copying production code

I started by copying current code from off1 to each container, while avoiding data. I put code in `/srv/opf-old/` and `/srv/obf-old/` so that I can easily compare to git code later on.

On off2 as root:
```bash
mkdir /zfs-hdd/pve/subvol-111-disk-0/srv/obf-old/
rsync -x -a --info=progress2 --exclude "logs/" --exclude "html/images/products/" --exclude "html/data" --exclude "deleted.images" --exclude "tmp/" --exclude "new_images/" --exclude="build-cache" off1.openfoodfacts.org:/srv/obf/ /zfs-hdd/pve/subvol-111-disk-0/srv/obf-old/

mkdir /zfs-hdd/pve/subvol-112-disk-0/srv/opf-old/
rsync -x -a --info=progress2 --exclude "logs/" --exclude "html/images/products/" --exclude "html/data" --exclude "deleted.images" --exclude "tmp/" --exclude "new_images/" --exclude="build-cache" off1.openfoodfacts.org:/srv/opf/ /zfs-hdd/pve/subvol-112-disk-0/srv/opf-old/
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

I will generaly work to modify / commit to the repository using my user alex, while using off only to push.
So as alex on obf:
```
git config --global --add safe.directory /srv/obf
git config --global --add author.name "Alex Garel"
git config --global --add author.email "alex@openfoodfacts.org"
```

Do the same on opf.

### Finding git commit for obf

`ls -ltr lib/ProductOpener/ cgi/` seems to indicate to search commits around 2021-02-03

## Production switch

**FIXME**: don't forget to cross mount opf and obf volumes in opff


## Documentation


**FIXME**: report change on 110.conf for off images as dataset

**FIXME**: report zfs-nvme creation:
