# 2024-04-26 New install of OBF on OFF2 with new generic code

## Introduction

OBF, OPF and OPFF currently use very old code (more than 2 years old). An effort is underway to make the current "main" code of Product Opener (currently used for OFF) able to power OBF, OPF and OPFF, so that we can have unified code and features on all platforms.

To test the new code, we will create a new container obf-new (116) that will run in parallel to the current container for obf (116).
Both containers will use the same data (.sto files and MongoDB database and collection).

Once we are satisfied with the new code, we can transform obf-new in the new production container for OBF, and retire the old container.

Update 2024/08/27: I also install containers opf-new (117) and opff-new (118) in the exact same way.

## Install logs

The obf-new install is done by Stéphane, following closely what Alex did and documented for [opff reinstall on off2](./2023-03-14-off2-opff-reinstall.md).

Refer to it if you need more explanation on a step.

## Creating Containers

I created a CT for obf-new followings [How to create a new Container](../proxmox.md#how-to-create-a-new-container) it went all smooth.
I choosed a 30Gb disk, 0B swap, 4 Cores and 6 Gb memory.
Network: vmbr1, ipv4: 10.1.0.116/24, gateway: 10.0.0.2

I also [configure postfix](../mail.md#postfix-configuration) and tested it.

Also run /opt/openfoodfacts-infrastructure/scripts/proxmox-management/ct_postinstall on off2 host.

**Important:** do not create any user until you changed id maping in lxc conf (see [Mounting volumes](#mounting-volumes)). And also think about creating off user before any other user to avoid having to change users uids, off must have uid 1000.

## Creating en_US.UTF-8 UTF-8 locale

Perl was complaining about the locale:

perl: warning: Setting locale failed.
perl: warning: Please check that your locale settings:
        LANGUAGE = (unset),
        LC_ALL = (unset),
        LANG = "en_US.UTF-8"
    are supported and installed on your system.
perl: warning: Falling back to the standard locale ("C").

Edited /etc/locale.gen to uncomment the line en_US.UTF-8 UTF-8
sudo locale-gen


## Mounting volumes

In production we have off, obf, opf and opff in off2, so we cross mount their products and images volumes.

### Changing lxc confs

On off2, we edit /etc/pve/lxc/116.conf.
We want the same mounts as the current obf container (111), so we copy the mp*: lines from /etc/pve/lxc/111.conf
and we also add the lxc.idmap: lines:

We also need the *orgs* directory, so we add a new line:
```conf
mp12: /zfs-hdd/off/orgs,mp=/mnt/obf/orgs
```

Resulting in:

```conf
mp0: /zfs-hdd/obf,mp=/mnt/obf
mp1: /zfs-hdd/obf/products/,mp=/mnt/obf/products
mp10: /zfs-hdd/opf/products/,mp=/mnt/opf/products
mp11: /zfs-hdd/opf/images,mp=/mnt/opf/images
mp12: /zfs-hdd/off/orgs,mp=/mnt/obf/orgs
mp2: /zfs-hdd/off/users,mp=/mnt/obf/users
mp3: /zfs-hdd/obf/images,mp=/mnt/obf/images
mp4: /zfs-hdd/obf/html_data,mp=/mnt/obf/html_data
mp5: /zfs-hdd/obf/cache,mp=/mnt/obf/cache
mp6: /zfs-nvme/off/products,mp=/mnt/off/products
mp7: /zfs-hdd/off/images,mp=/mnt/off/images
mp8: /zfs-hdd/opff/products,mp=/mnt/opff/products
mp9: /zfs-hdd/opff/images,mp=/mnt/opff/images
…
lxc.idmap: u 0 100000 999
lxc.idmap: g 0 100000 999
lxc.idmap: u 1000 1000 64536
lxc.idmap: g 1000 1000 64536
```

Also adding lines to start the container on boot and to make it protected (can also be done in proxmox web interface):

```
onboot: 1
protection: 1
```

Reboot and enter the container:

```bash
pct reboot 116
pct enter 116
```

### Create off user in the container

On obf-new:

The first user created should be the *off* user with id 1000:

```bash
adduser --uid 1000 off
```

I also create a user *stephane*:

```bash
adduser stephane
```

### Install sudo, add your user to sudo group

```bash
apt-get update
apt-get install sudo
usermod -aG sudo stephane
```

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


### Installing packages

On obf-new:

Packages taken from Dockerfile:


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
   cmake \
   pkg-config \
   libapache2-mod-perl2-dev \
   libavif-dev \
   libde265-dev \
   libheif-dev \
   libjpeg-dev \
   libpng-dev \
   libwebp-dev \
   libx265-dev

```


## Getting the code

### Copying production code

We copy the current obf code from container 111, while avoiding data. I put code in `/srv/obf-old/` so that I can easily compare to git code later on.

On off2 as root:
```bash
mkdir /zfs-hdd/pve/subvol-116-disk-0/srv/obf-old/
rsync -x -a --info=progress2 --exclude "logs/" --exclude "html/images/products/" --exclude "html/data" --exclude "deleted.images" --exclude "tmp/" --exclude "new_images/" --exclude="build-cache" /zfs-hdd/pve/subvol-111-disk-0/srv/obf/ /zfs-hdd/pve/subvol-116-disk-0/srv/obf-old/
# there are some permissions problems
sudo chown 1000:1000 -R /zfs-hdd/pve/subvol-116-disk-0/srv/obf-old/

```
### Cloning off-server repository

On obf-new:

First I create a key for off to access off-server repo:
```bash
sudo -u off ssh-keygen -f /home/off/.ssh/github_off-server -t ed25519 -C "off+off-server@obf-new.openfoodfacts.org"
sudo -u off vim /home/off/.ssh/config
…
# deploy key for openfoodfacts-server
Host github.com-off-server
        Hostname github.com
        IdentityFile=/home/off/.ssh/github_off-server
…
sudo cat /home/off/.ssh/github_off-server.pub
```
Go to github add the obf pub key for off to [productopener repository](https://github.com/openfoodfacts/openfoodfacts-server/settings/keys) with write access:

Then clone repository, on obf-new:

```bash
sudo apt-get install git
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

I will generaly work to modify / commit to the repository using my user stephane, while using off only to push.
So as stephane on obf:
```
git config --global --add safe.directory /srv/obf
git config --global --add author.name "Stéphane Gigandet"
git config --global --add author.email "stephane@openfoodfacts.org"
git config --global --add user.name "Stéphane Gigandet"
git config --global --add user.email "stephane@openfoodfacts.org"
```

Add your user to the off group so that it can used the shared git repository:
```bash
usermod -a -G off stephane
```


### Finding git commit for obf

On the off-new container, we will deploy the current main branch.


## Installing

We have git cloned our repository in `/srv/obf`.


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

opf:
```bash
for site in o{f,b,pf}f;do \
  mkdir -p /srv/$site/html/images/ && \
  chown -R off:off -R /srv/$site/ && \

  ln -s /mnt/$site/products /srv/$site/products; ln -s /mnt/$site/images/products /srv/$site/html/images/products; \
done
ls -l /srv/o{f,b,pf}f/ /srv/$site/html/images
```

opff:
```bash
for site in o{f,p,b}f;do \
  mkdir -p /srv/$site/html/images/ && \
  chown -R off:off -R /srv/$site/ && \

  ln -s /mnt/$site/products /srv/$site/products; ln -s /mnt/$site/images/products /srv/$site/html/images/products; \
done
ls -l /srv/o{f,p,b}f/ /srv/$site/html/images
```

### linking data

Unless stated otherwise operation are done with user off.

Create links for users, orgs and products

```bash
# set the instance as obf
SERVICE=obf
ln -s /mnt/$SERVICE/products /srv/$SERVICE/products
ln -s /mnt/$SERVICE/users /srv/$SERVICE/users
ln -s /mnt/$SERVICE/orgs /srv/$SERVICE/orgs
# verify
ls -l /srv/$SERVICE/products /srv/$SERVICE/users /srv/$SERVICE/orgs /srv/$SERVICE/data
```

Create links for data folders:

```bash
# set the instance as obf
SERVICE=obf
# html data
ln -s /mnt/$SERVICE/html_data /srv/$SERVICE/html/data
ln -s /mnt/$SERVICE/html_data/exports /srv/$SERVICE/html/exports
ln -s /mnt/$SERVICE/html_data/dump /srv/$SERVICE/html/dump
ln -s /mnt/$SERVICE/html_data/files /srv/$SERVICE/html/files
# product images
ln -s /mnt/$SERVICE/images/products  /srv/$SERVICE/html/images/products
# verify
ls -ld /srv/$SERVICE/html/images/products /srv/$SERVICE/html/{data,exports,dump,files}
```

Note:
The directories */mnt/obf/html_data/{export,dump,files}* do not currently exist in the old production.

some direct links:
```bash
# set the instance as obf
SERVICE=obf

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

Note: some directories do not currently exist in the old production.

we also need a link to `internal_code.sto`:
```bash
# set the instance as obf
SERVICE=obf
ln -s /mnt/off/products/internal_code.sto /srv/$SERVICE/products/
```

TODO: current old production already has a internal_code.sto, used for products created without a barcode.
It is likely that we created products with the same barcode on off, obf, opf and opff. We will need to change the barcode
of those products in order to have distinct barcodes for all products, and then we should use the same sequence number.

Create and link cache folders:

```bash
# set the instance as obf
SERVICE=obf
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

We also want to move html/data/data-field.txt outside the data volume and link it, as user off.
```bash
# set the instance as obf
SERVICE=obf
cd /srv/$SERVICE
mv html/data/data-fields.txt html/data-fields.txt
ln -s ../data-fields.txt html/data/data-fields.txt
```

### linking logs

We want logs to go in /var/logs and really in /mnt/obf/logs .

/mnt/obf/logs already contains logs from the current production container (111),
so we will use directories obf-new, apache-new and nginx-new to differentiate them.

```bash
# set the instance as obf
SERVICE=obf

# be sure to avoid having apache2 or nginx writing

sudo systemctl stop apache2 nginx
sudo -u off rm -rf /srv/$SERVICE/logs/

sudo mkdir /mnt/$SERVICE/logs/$SERVICE-new
sudo ln -s /mnt/$SERVICE/logs/$SERVICE-new /var/log/$SERVICE
sudo chown off:off -R /var/log/$SERVICE
sudo -u off ln -s /mnt/$SERVICE/logs/$SERVICE-new /srv/$SERVICE/logs

# also move nginx and apache logs
sudo mv /var/log/nginx /mnt/$SERVICE/logs/nginx-new
sudo mv /var/log/apache2 /mnt/$SERVICE/logs/apache2-new
sudo ln -s /mnt/$SERVICE/logs/nginx-new /var/log/nginx
sudo ln -s /mnt/$SERVICE/logs/apache2-new /var/log/apache2

sudo -u off ln -s ../apache2 /var/log/$SERVICE
sudo -u off ln -s ../nginx /var/log/$SERVICE

# verify
ls -l /srv/$SERVICE/logs /srv/$SERVICE/logs/ /var/log/{$SERVICE,nginx,apache2}
```

Create obf-log.conf and symlink it:


```bash
# set the instance as obf
SERVICE=obf

rm /srv/$SERVICE/log.conf
ln -s /srv/$SERVICE/conf/$SERVICE-log.conf /srv/$SERVICE/log.conf
rm /srv/$SERVICE/minion_log.conf
ln -s srv/$SERVICE/conf/$SERVICE-minion_log.conf /srv/$SERVICE/minion_log.conf
# verify
ls -l /srv/$SERVICE/{,minion_}log.conf 
```

### copy and verify config links

Config files:

I copy the off Config2.pm file to obf

```bash
root@off2:/home/stephane# cp -a /zfs-hdd/pve/subvol-113-disk-0/srv/off/lib/ProductOpener/Config2.pm /zfs-hdd/pve/subvol-116-disk-0/srv/obf/lib/ProductOpener/

```

Then edit the file.

Note: Config.pm now loads Config_{off,obf,opf,opff}.pm based on the value of the PRODUCT_OPENER_FLAVOR_SHORT environment variable.

### Verify broken links

`sudo find /srv/$SERVICE-old -xtype l | xargs ls -l`

It shows broken links for dists and lang files that will be added below.

### Adding dists

Create folders for dist:
```bash
# set the instance as obf
declare -x SERVICE=obf

sudo -E mkdir /srv/$SERVICE-dist
sudo -E chown off:off -R /srv/$SERVICE-dist
```

and unpack last dist release there (as user off):

```bash
wget https://github.com/openfoodfacts/openfoodfacts-server/releases/download/v2.42.0/frontend-dist.tgz -O /tmp/frontend-dist.tgz
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
ls -l  /srv/$SERVICE/dist /srv/$SERVICE/html/{images/icons,images/attributes,css,js}/dist
```



### Adding openfoodfacts-web

#### Cloning repo

Note that I add to make two deploys keys as explained in [github documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#using-multiple-repositories-on-one-server) and use a specific ssh_config hostname for openfoodfacts-web:

Create new key, as off:
```bash
# set the instance as obf
declare -x SERVICE=obf

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

We clearly want obf lang folder to come from off-web:

```bash
ln -s /srv/openfoodfacts-web/lang /srv/$SERVICE/

# verify
ls -ld /srv/$SERVICE/lang
```

Note: the current obf production has specific contact.html press.html and terms-of-use.html
linked to /srv/obf/lang/

TODO: We don't create links to those, and we will need to have another solution if we want flavor specific texts.


### Installing CPAN modules

#### Install zxing-cpp from source until 2.1 or higher is available in Debian: 
https://github.com/openfoodfacts/openfoodfacts-server/pull/8911/files#r1322987464

```bash
  set -x && \
    cd /tmp && \
    wget https://github.com/zxing-cpp/zxing-cpp/archive/refs/tags/v2.1.0.tar.gz && \
    tar xfz v2.1.0.tar.gz && \
    cmake -S zxing-cpp-2.1.0 -B zxing-cpp.release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_WRITERS=OFF -DBUILD_READERS=ON -DBUILD_EXAMPLES=OFF && \
    cmake --build zxing-cpp.release -j8 && \
    cmake --install zxing-cpp.release && \
    cd / && \
    rm -rf /tmp/v2.1.0.tar.gz /tmp/zxing-cpp*
```

#### Install CPAN modules

First add `Apache2::Connection::XForwardedFor` and `Apache::Bootstrap` to cpanfile

```bash
cd /srv/obf
sudo apt install libapache2-mod-perl2-dev
sudo cpanm --notest --quiet --skip-satisfied --installdeps .
```

cpan gives an error:

```
! Configure failed for Imager-File-PNG-0.99. See /root/.cpanm/work/1716285902.64340/build.log for details.
! Configure failed for Imager-zxing-1.001. See /root/.cpanm/work/1716285902.64340/build.log for details.
! Configure failed for Imager-File-HEIF-0.005. See /root/.cpanm/work/1716285902.64340/build.log for details.
! Configure failed for Imager-File-WEBP-0.005. See /root/.cpanm/work/1716285902.64340/build.log for details.
! Configure failed for Imager-File-AVIF-0.002. See /root/.cpanm/work/1716285902.64340/build.log for details.
! Configure failed for Imager-File-JPEG-0.97. See /root/.cpanm/work/1716285902.64340/build.log for details.
! Installing the dependencies failed: Module 'Imager::File::AVIF' is not installed, Module 'Imager::File::JPEG' is not installed, Module 'Imager::File::PNG' is not installed, Module 'Imager::zxing' is not installed, Module 'Imager::File::WEBP' is not installed, Module 'Imager::File::HEIF' is not installed
! Bailing out the installation for ..

```

JPEG: building independently
JPEG: main: includes not found - libraries not found
JPEG: Checking if the compiler can find them on its own
OS unsupported: JPEG libraries or headers not found
JPEG: Test code failed: Can't link/include 'jpeglib.h', 'jpeg'

Just missing some of the new libraries added recently to Dockerfile, installing them.



## Setting up services

### nginx for OBF (inside container)

Installed nginx `sudo apt install nginx`.

Removed default site `sudo unlink /etc/nginx/sites-enabled/default`

We are going to mimick the setup that we have in the off container.

Then made symlinks:
* For obf:
  ```bash
  sudo ln -s /srv/$SERVICE/conf/nginx/sites-available/$SERVICE /etc/nginx/sites-enabled/$SERVICE
  sudo ln -s /srv/$SERVICE/conf/nginx/snippets/expires-no-json-xml.conf /etc/nginx/snippets/
  sudo ln -s /srv/$SERVICE/conf/nginx/snippets/expiry-headers.include /etc/nginx/snippets/
  sudo ln -s /srv/$SERVICE/conf/nginx/snippets/off.cors-headers.include /etc/nginx/snippets/
  sudo rm -rf /etc/nginx/conf.d
  sudo ln -s /srv/$SERVICE/conf/nginx/conf.d /etc/nginx/
  sudo rm /etc/nginx/mime.types
  sudo ln -s /srv/$SERVICE/conf/nginx/mime.types /etc/nginx/
  ```


I then copied the off config file to obf, as lots of things have changed:

```bash
sudo cp /srv/$SERVICE/conf/nginx/sites-available/off /srv/$SERVICE/conf/nginx/sites-available/$SERVICE
```

And edited the file to change openfoodfacts.org to openbeautyfacts.org, the name of the log files etc. The result is in git.

I create an empty /srv/obf/conf/nginx/snippets/obf.domain-redirects.include + obf.locations-redirects.include , they might be used if we want to create subdomains shortcuts or redirects on OBF as we have on OFF.

```bash
sudo ln -s /srv/$SERVICE/conf/nginx/snippets/$SERVICE.domain-redirects.include /etc/nginx/snippets/
sudo ln -s /srv/$SERVICE/conf/nginx/snippets/$SERVICE.locations-redirects.include /etc/nginx/snippets/
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

QUESTION: we currently use different ports for Apache for each instance. But as we are on different containers, we could just use a single port like 8000, unless it causes issues for development or if we want to deploy multiple instances in the same container.
I will keep a different port for now.

On obf:
* Add configuration for obf in sites enabled
  ```bash
  sudo ln -s /srv/$SERVICE/conf/apache-2.4/sites-available/$SERVICE.conf /etc/apache2/sites-enabled/
  ```
* link `mpm_prefork.conf` to a file in git, identical as the one in production
  ```bash
  sudo rm /etc/apache2/mods-available/mpm_prefork.conf
  sudo ln -s /srv/$SERVICE/conf/apache-2.4/$SERVICE-mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf
  ```
* use customized ports.conf for obf (8002)
  ```bash
  sudo rm /etc/apache2/ports.conf
  sudo ln -s /srv/$SERVICE/conf/apache-2.4/$SERVICE-ports.conf /etc/apache2/ports.conf
  ```
* modperl environment variables
  ```bash
  ln -s /srv/$SERVICE/conf/apache-2.4/modperl.conf /etc/apache2/conf-enabled/
  ```

test it in container:
```bash
sudo apache2ctl configtest
```

We can restart apache2 then nginx:
```bash
sudo systemctl restart apache2
sudo systemctl restart nginx
```

#### Problem when restarting apache2 on obf

##### apache2.service: Failed to load environment files: No such file

This is because I named the host obf-new, and we use the host name in the environment file:
/etc/systemd/system/apache2.service.d/override.conf

[Service]
# Apache needs some environment variables like PRODUCT_OPENER_FLAVOR_SHORT
# %l is the short host name (e.g. off, obf, off-pro)
EnvironmentFile=/srv/%l/env/env.%l

Hack to fix it:

```bash
cd /srv/
mkdir obf-new
mkdir obf-new/env/
ln -s /srv/obf/env/env.obf /srv/obf-new/env/env.obf-new
```

##### Taxonomies

In `/var/log/apache2/error.log`
```
Could not load taxonomy: /srv/obf/taxonomies/inci_functions.result.sto
```
To build taxonomies:
```bash
export PERL5LIB=/srv/obf/lib
cd /srv/obf
source env/setenv.sh obf
./scripts/taxonomies/build_tags_taxonomy.pl 

```

##### Create missing directories

FATAL: Some important directories are missing: /srv/obf/deleted_private_products:/srv/obf/html/files/debug:/srv/obf/export_files:/srv/obf/orgs:/srv/obf/html/files:/srv/obf/deleted_products:/srv/obf/import_files:/srv/obf/html/exports:/srv/obf/translate:/srv/obf/deleted_products_images:/srv/obf/reverted_products:/srv/obf/html/dump at /srv/obf/lib/startup_apache2.pl line 159.\nCompilation failed in require at (eval 2) line 1.\n

```bash
# set the instance as obf
SERVICE=obf
mkdir /mnt/$SERVICE/cache
mkdir /mnt/$SERVICE/cache/build-cache
mkdir /mnt/$SERVICE/cache/build-cache/taxonomies
mkdir /mnt/$SERVICE/debug
mkdir /mnt/$SERVICE/deleted_private_products
mkdir /mnt/$SERVICE/deleted_products
mkdir /mnt/$SERVICE/deleted_products_images
mkdir /mnt/$SERVICE/imports
mkdir /mnt/$SERVICE/import_files
mkdir /mnt/$SERVICE/reverted_products
mkdir /mnt/$SERVICE/translate
mkdir /mnt/$SERVICE/exports
mkdir /mnt/$SERVICE/html_data/dump
mkdir /mnt/$SERVICE/html_data/exports
mkdir /mnt/$SERVICE/html_data/files
mkdir /mnt/$SERVICE/html_data/files/debug
mkdir /mnt/$SERVICE/cache/export_files
```


### creating systemd units for timers jobs

We install mailx

```bash
sudo apt install mailutils
```

and link them at system level
```bash
declare -x SERVICE=obf
sudo ln -s /srv/$SERVICE/conf/systemd/nginx.service.d /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/apache2.service.d /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/gen_feeds\@.timer /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/gen_feeds\@.service /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/gen_feeds_daily\@.service /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/gen_feeds_daily\@.timer /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/email-failures\@.service /etc/systemd/system
# account for new services
sudo systemctl daemon-reload
```

Test failure notification is working:

```bash
sudo systemctl start email-failures@gen_feeds__$SERVICE.service
```

Test systemctl gen_feeds services are working:

```bash
sudo systemctl start gen_feeds_daily@$SERVICE.service
sudo systemctl start gen_feeds@$SERVICE.service
```

Activate systemd units:

```bash
sudo systemctl enable gen_feeds@$SERVICE.timer
sudo systemctl enable gen_feeds_daily@$SERVICE.timer
sudo systemctl daemon-reload
``


### log rotate perl logs

```bash
declare -x PROJ_NAME=obf
```


We get `conf/logrotate/apache` from opff and install it:

```bash
cd /srv/$SERVICE
sudo -u off git checkout origin/opff-main -- conf/logrotate/apache2
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
curl localhost:$PORT_NUM/cgi/display.pl --header "Host: fr.$DOMAIN_NAME_EXT"
```

Nginx call
```bash
curl localhost --header "Host: fr.$DOMAIN_NAME_EXT"
```

### Using Matomo instead of google analytics

TODO: Copy configuration from OPFF and adapted with site id after creation of sites in Matomo.

## Reverse proxy configuration on container 101

### certbot wildcard certificates using OVH DNS

Note: we are using openbeautyfacts.com temporarily for obf-new

We already installed `python3-certbot-dns-ovh` so we just need to add credentials.

```bash
$ declare -x DOMAIN_NAME_EXT=openbeautyfacts.com
```

opf:

```bash
$ declare -x DOMAIN_NAME_EXT=new.openproductsfacts.org
```

For the new.open(beauty|petfood|productsfacts.org) certificates, we can use the OVH credentials than the domain:

```bash
$ ln -s /root/.ovhapi/openproductsfacts.org /root/.ovhapi/new.openproductsfacts.org
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
$ vim /root/.ovhapi/$DOMAIN_NAME_EXT
...
$ cat /root/.ovhapi/$DOMAIN_NAME_EXT
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
$ certbot certonly --test-cert --dns-ovh --dns-ovh-credentials /root/.ovhapi/$DOMAIN_NAME_EXT -d $DOMAIN_NAME_EXT -d "*.$DOMAIN_NAME_EXT"
...
...
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/xxxxx.org/fullchain.pem
```
and then without `--test-cert`
```bash
$ certbot certonly --dns-ovh --dns-ovh-credentials /root/.ovhapi/$DOMAIN_NAME_EXT -d $DOMAIN_NAME_EXT -d "*.$DOMAIN_NAME_EXT"
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
sudo ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/nginx/openbeautyfacts.com /etc/nginx/sites-enabled/
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


## Switching old and new containers

2024/09/09: we now have test containers for the new code running on:

https://world.new.openbeautyfacts.org
https://world.new.openpetfoodfacts.org
https://world.new.openproductsfacts.org

We want to now switch the containers, so that the new code is on the main URL,
and the old code on old.*.org:

https://world.old.openbeautyfacts.org
https://world.old.openpetfoodfacts.org
https://world.old.openproductsfacts.org

On the off2 reverse proxy:

root@proxy:/opt/openfoodfacts-infrastructure/confs/proxy-off/nginx# mv openproductsfacts.org old.openproductsfacts.org
root@proxy:/opt/openfoodfacts-infrastructure/confs/proxy-off/nginx# cp new.openproductsfacts.org openproductsfacts.org

Edit old.openproductsfacts.org and openproductsfacts.org
to change the log files paths + the SSL certificates paths
also put basic_auth on old.openproductsfacts.org

Get SSL certificate for old.openproductsfacts.org:


Try to get a wildcard using certbot, we will choose to obtain certificates using a DNS TXT record, and use tech -at- off.org for notifications. We first try with `--test-cert`
```bash
$ ln -s /root/.ovhapi/openproductsfacts.org /root/.ovhapi/new.openproductsfacts.org
$ export DOMAIN_NAME_EXT=old.openproductsfacts.org
$ certbot certonly --test-cert --dns-ovh --dns-ovh-credentials /root/.ovhapi/$DOMAIN_NAME_EXT -d $DOMAIN_NAME_EXT -d "*.$DOMAIN_NAME_EXT"
...
...
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/xxxxx.org/fullchain.pem
```
and then without `--test-cert`
```bash
$ certbot certonly --dns-ovh --dns-ovh-credentials /root/.ovhapi/$DOMAIN_NAME_EXT -d $DOMAIN_NAME_EXT -d "*.$DOMAIN_NAME_EXT"
...
...
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/xxxxx.org/fullchain.pem
...
```
### Apache configuration

Changed domains on opf and opf-new to be old.openproductsfacts.org and openproductsfacts.org

Need to run build_lang.pl again, as the file it generates as the domain name in it
(could be changed as not useful anymore)

Restart Apache.


## Later configuration

### 2024-11-06 Setup cloud vision on OBF, OPF, OPFF containers

as root in the obf, opf, opff containers:

```bash
export SERVICE=obf
cd /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/cloud_vision_ocr@.service cloud_vision_ocr@$SERVICE.service
sudo systemctl daemon-reload
sudo systemctl start cloud_vision_ocr@$SERVICE
sudo systemctl status cloud_vision_ocr@$SERVICE
```