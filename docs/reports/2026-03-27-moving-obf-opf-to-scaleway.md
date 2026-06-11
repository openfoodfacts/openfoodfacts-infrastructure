# 2026-03-27 moving obf and opf to scaleway

We did [move Open Pet Food Facts (opff) to scaleway](./2026-03-12-moving-opff-to-scaleway.md)
the next that we will move are Open Beauty Facts (obf)
and Open Products Facts (opff).

We will do it directly without primary tests
as it is so close to OPF in term of migration.

We already have the NFS shares available for data shared with off.
We just have to create the containers and adjust file systems.

## Procedure for OBF migration

### Preparing container

First create the 113 container named obf using ansible (see [proxmox - How to create a new container with ansible](../proxmox.md#how-to-create-a-new-container-with-ansible))
following what was done for 115 (opff).

On scaleway-01:
1. shutdown the container: `pct shutdown 113`
3. edit the container configuration to add mountpoints:
   ```
    mp0: /zfs-hdd/podata/obf,mp=/mnt/obf
    mp1: /zfs-hdd/podata/obf/cache,mp=/mnt/obf/cache
    mp2: /zfs-hdd/podata/obf/html_data,mp=/mnt/obf/html_data
    mp3: /mnt/nfs/off/products,mp=/mnt/obf/products
    mp4: /mnt/nfs/off/images,mp=/mnt/obf/images
    mp5: /mnt/nfs/off/users,mp=/mnt/obf/users
    mp6: /mnt/nfs/off/orgs,mp=/mnt/obf/orgs
    ```
    also added:
    ```
    lxc.cap.drop: "sys_rawio audit_read"
    ```
2. remove the created disk: `zfs destroy zfs-hdd/pve/subvol-113-disk-0`


### Preparing Reverse Proxy

We have to setup the reverse proxy in `scaleway-proxy`

First we copy the certificates from off2-proxy to scaleway-proxy
(following https://charlesreid1.github.io/copying-letsencrypt-certs-between-machines.html)
On off2-proxy:
```bash
CONF=/etc/nginx/sites-enabled/openbeautyfacts.org
DOM=$(sed -nr  "s|.*letsencrypt/live/(.*)/privkey.*|\1|p" $CONF)
echo "COPYING CERTS FOR $DOM in $DOM.tar.gz"
sudo tar -cvzf $DOM.tar.gz \
    /etc/letsencrypt/archive/${DOM} \
    /etc/letsencrypt/renewal/${DOM}.conf \
    /etc/letsencrypt/live/${DOM}
sudo chown alex:alex $DOM.tar.gz
sudo chmod go-rw $DOM.tar.gz
```
I then copied it to scaleway-proxy (using scp).
And on scaleway-proxy[^ErrorTarLetsencrypt]:
```bash
cd /
tar xzf /home/alex/openbeautyfacts.org.tar.gz
# verify
ls -l /etc/letsencrypt/*/openbeautyfacts.org /etc/letsencrypt/renewal/openbeautyfacts.org.conf
```

On scaleway-proxy
I copied the configuration from off2 reverse proxy in scaleway-proxy conf dir (common config were already copied and linked while moving opff):
```bash
cd /opt/openfoodfacts-infrastructure/
cp confs/off2-reverse-proxy/nginx/sites-enabled/openbeautyfacts.org confs/scaleway-proxy/nginx/sites-enabled/
# link at system level
ln -s /opt/openfoodfacts-infrastructure/confs/scaleway-proxy/nginx/sites-enabled/openbeautyfacts.org /etc/nginx/sites-enabled/
```

I also edited openbeautyfacts.org conf
* `listen 443 ... http2` is now deprecated in favour of `http2 on;`
* comment `ssl_stapling` and `ssl_stapling_verify` directives (deprecated)
* to substitute any occurrence of `10.1.0.116` for `10.13.1.113`.

[^ErrorTarLetsencrypt]: When I did it, in fact I did use the -h flag
  which dereferences symlink, and certbot is not happy with it
  (`live` items must points to `archive` items).
  To fix that, I had to use this command:
  ```bash
  FOLDER=openbeautyfacts.org; \
  for f in /etc/letsencrypt/live/$FOLDER/*.*; \
  do \
    NAME=$(basename $f); \
    BARE_NAME=${NAME%.*}; \
    TARGET=$(ls -tr /etc/letsencrypt/archive/$FOLDER/${BARE_NAME}*|tail -n 1); \
    TARGET_FILE=$(basename $TARGET); \
    unlink $f; \
    ln -s ../../archive/$FOLDER/$TARGET_FILE $f; \
  done
  ls -l /etc/letsencrypt/live/$FOLDER
  ```
  then verify with `nginx -t`

### Preparing DNS

On OVH web console: modify TTL on openbeautyfacts.org and *.openbeautyfacts.org to 60s

On your desktop prepare the following lines to add to your `/etc/hosts` (comment them until migration):

```
151.115.132.10 world.openbeautyfacts.org fr.openbeautyfacts.org static.openbeautyfacts.org images.openbeautyfacts.org
```


### Migration

1. on scaleway-01 comment obf backups in /etc/sanoid/syncoid-args.conf

Now we hurry:

1. on off2, stop obf container `pct shutdown 116`
1. on off2, create a last snapshot:
  ```bash
  # mimic sanoid
  SNAP_NAME=autosnap_$(date --utc +"%Y-%m-%d_%H:%M:%S")_hourly
  for dataset in zfs-hdd/pve/subvol-116-disk-0 zfs-hdd/obf{,/cache,/html_data}; \
  do \
    zfs snapshot $dataset@$SNAP_NAME; \
    echo DONE: $dataset@$SNAP_NAME; \
  done
  ```
1. on `scalway-01`, make a last sync of datasets:
   ```bash
   syncoid --no-sync-snap --no-privilege-elevation scaleway01operator@off2.openfoodfacts.org:zfs-hdd/pve/subvol-116-disk-0 zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-116-disk-0
   syncoid --no-sync-snap --no-privilege-elevation --recursive scaleway01operator@off2.openfoodfacts.org:zfs-hdd/obf zfs-hdd/off-backups/off2-zfs-hdd/obf
   ```
   verify:
   ```bash
   zfs list -t snap zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-116-disk-0 |tail -n 1
   for dataset in obf{,/cache,/html_data}; \
   do \
     zfs list -t snap zfs-hdd/off-backups/off2-zfs-hdd/$dataset |tail -n 1; \
   done
   ```
1. move the backup zfs to their new location:
    ```bash
    zfs rename zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-116-disk-0 zfs-hdd/pve/subvol-113-disk-0
    zfs rename zfs-hdd/off-backups/off2-zfs-hdd/obf zfs-hdd/podata/obf
    ```
1. on scaleway-01, remove the obf/products,images datasets as they are useless
  and may conflict with the real mount we need in the container
  ```bash
  zfs destroy -r zfs-hdd/podata/obf/products
  zfs destroy -r zfs-hdd/podata/obf/images
  ```
1. modify the configuration `srv/obf/lib/ProductOpener/Config2.pm` in `/zfs-hdd/pve/subvol-113-disk-0/`:
   ```
   $mongodb_host = "10.13.1.200";
    ...
    $redis_url = '10.13.1.200:6379';
    ...
    %server_options = (

            cookie_domain => "openbeautyfacts.org",   # if not set, default to $server_domain
            minion_backend => {'Pg' => 'postgresql://off:********@10.13.1.200/minion'},
            minion_local_queue => "openbeautyfacts.org",
    ...
    $memd_servers = [ "10.13.1.102:11211" ];
    ```
1. modify links to folders:
    ```bash
    cd /zfs-hdd/pve/subvol-113-disk-0/
    unlink srv/obf/products
    ln -s /mnt/obf/products srv/obf/products
    unlink srv/obf/html/images/products
    ln -s /mnt/obf/images/products srv/obf/html/images/products
    # some strange old refs
    rm -rf srv/off/new_images/1730024919.opf:84165435.search.2.jpg
    # remove old refs
    for dirname in srv/{off,opf,opff}/{html/images/products,products}; \
    do \
    unlink $dirname; \
    done
    for dirname in mnt/{off,opf,opff}/{images,products,} srv/{off,opf,opff}/{html/{images,},}; \
    do \
    rmdir $dirname; \
    done
    ```
1. on scaleway-01, start the service `pct start 113`
1. on your computer, verify the service is working with a modified `/etc/hosts`
1. in OVH web console, change the `openbeautyfacts.org` `A` entry to point to `151.115.132.10`
1. on your computer remove you `/etc/hosts` specific configuration and test again
1. It's live !

After migration:
* on off2: rename subvol-116 to avoid confusion
  ```bash
  zfs rename zfs-hdd/pve/subvol-116-disk-0 zfs-hdd/backups/subvol-116-disk-0
  ```
* verify backups of the new datasets are done on scaleway-03:
  * `zfs list zfs-hdd/off-backups/scaleway-01-podata-hdd -r`
* rerun the ansible:
  * container creation on scaleway-01:
    `ansible-playbook sites/proxmox-node.yml --tags containers -l scaleway-01`
  * jobs/configure for obf:
    `ansible-playbook jobs/configure.yml -l obf` [^SSH_RESTART]
* remove the backup datasets at ovh3
* Verify podata is synced on ovh3
* put back the TTL for domain to a normal level

Later:
* on off2: remove the pct 116: `pct remove 116`



## Procedure for OPF migration

### Preparing container

First create the 114 container named opf using ansible (see [proxmox - How to create a new container with ansible](../proxmox.md#how-to-create-a-new-container-with-ansible))
following what was done for 115 (opff).

On scaleway-01:
1. shutdown the container: `pct shutdown 114`
3. edit the container configuration to add mountpoints:
   ```
    mp0: /zfs-hdd/podata/opf,mp=/mnt/opf
    mp1: /zfs-hdd/podata/opf/cache,mp=/mnt/opf/cache
    mp2: /zfs-hdd/podata/opf/html_data,mp=/mnt/opf/html_data
    mp3: /mnt/nfs/off/products,mp=/mnt/opf/products
    mp4: /mnt/nfs/off/images,mp=/mnt/opf/images
    mp5: /mnt/nfs/off/users,mp=/mnt/opf/users
    mp6: /mnt/nfs/off/orgs,mp=/mnt/opf/orgs
    ```
    also added:
    ```
    lxc.cap.drop: "sys_rawio audit_read"
    ```
2. remove the created disk: `zfs destroy zfs-hdd/pve/subvol-114-disk-0`


### Preparing Reverse Proxy

We have to setup the reverse proxy in `scaleway-proxy`

First we copy the certificates from off2-proxy to scaleway-proxy
(following https://charlesreid1.github.io/copying-letsencrypt-certs-between-machines.html)
On off2-proxy:
```bash
CONF=/etc/nginx/sites-enabled/openproductsfacts.org
DOM=$(sed -nr  "s|.*letsencrypt/live/(.*)/privkey.*|\1|p" $CONF)
echo "COPYING CERTS FOR $DOM in $DOM.tar.gz"
sudo tar -cvzf $DOM.tar.gz \
    /etc/letsencrypt/archive/${DOM} \
    /etc/letsencrypt/renewal/${DOM}.conf \
    /etc/letsencrypt/live/${DOM}
sudo chown alex:alex $DOM.tar.gz
sudo chmod go-rw $DOM.tar.gz
```
I then copied it to scaleway-proxy (using scp).
And on scaleway-proxy[^ErrorTarLetsencrypt]:
```bash
cd /
tar xzf /home/alex/openproductsfacts.org.tar.gz
# verify
ls -l /etc/letsencrypt/*/openproductsfacts.org /etc/letsencrypt/renewal/openproductsfacts.org.conf
```

On scaleway-proxy
I copied the configuration from off2 reverse proxy in scaleway-proxy conf dir (common config were already copied and linked while moving opff):
```bash
cd /opt/openfoodfacts-infrastructure/
cp confs/off2-reverse-proxy/nginx/sites-enabled/openproductsfacts.org confs/scaleway-proxy/nginx/sites-enabled/
# link at system level
ln -s /opt/openfoodfacts-infrastructure/confs/scaleway-proxy/nginx/sites-enabled/openproductsfacts.org /etc/nginx/sites-enabled/
```

I also edited openproductsfacts.org conf
* `listen 443 ... http2` is now deprecated in favour of `http2 on;`
* comment `ssl_stapling` and `ssl_stapling_verify` directives (deprecated)
* to substitute any occurrence of `10.1.0.117` for `10.13.1.114`.

[^ErrorTarLetsencrypt]: When I did it, in fact I did use the -h flag
  which dereferences symlink, and certbot is not happy with it
  (`live` items must points to `archive` items).
  To fix that, I had to use this command:
  ```bash
  FOLDER=openproductsfacts.org; \
  for f in /etc/letsencrypt/live/$FOLDER/*.*; \
  do \
    NAME=$(basename $f); \
    BARE_NAME=${NAME%.*}; \
    TARGET=$(ls -tr /etc/letsencrypt/archive/$FOLDER/${BARE_NAME}*|tail -n 1); \
    TARGET_FILE=$(basename $TARGET); \
    unlink $f; \
    ln -s ../../archive/$FOLDER/$TARGET_FILE $f; \
  done
  ls -l /etc/letsencrypt/live/$FOLDER
  ```
  then verify with `nginx -t`


### Preparing DNS

On OVH web console: modify TTL on openproductsfacts.org and *.openproductsfacts.org to 60s

On your desktop prepare the following lines to add to your `/etc/hosts` (comment them until migration):

```
151.115.132.10 world.openproductsfacts.org fr.openproductsfacts.org static.openproductsfacts.org images.openproductsfacts.org
```

### Migration

1. on scaleway-01 comment opf backups in /etc/sanoid/syncoid-args.conf

Now we hurry:

1. on off2, stop opf container `pct shutdown 117`
1. on off2, create a last snapshot:
  ```bash
  # mimic sanoid
  SNAP_NAME=autosnap_$(date --utc +"%Y-%m-%d_%H:%M:%S")_hourly
  for dataset in zfs-hdd/pve/subvol-117-disk-0 zfs-hdd/opf{,/cache,/html_data}; \
  do \
    zfs snapshot $dataset@$SNAP_NAME; \
    echo DONE: $dataset@$SNAP_NAME; \
  done
  ```
1. on `scalway-01`, make a last sync of datasets:
   ```bash
   syncoid --no-sync-snap --no-privilege-elevation scaleway01operator@off2.openfoodfacts.org:zfs-hdd/pve/subvol-117-disk-0 zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-117-disk-0
   syncoid --no-sync-snap --no-privilege-elevation --recursive scaleway01operator@off2.openfoodfacts.org:zfs-hdd/opf zfs-hdd/off-backups/off2-zfs-hdd/opf
   ```
   verify:
   ```bash
   zfs list -t snap zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-117-disk-0 |tail -n 1
   for dataset in opf{,/cache,/html_data}; \
   do \
     zfs list -t snap zfs-hdd/off-backups/off2-zfs-hdd/$dataset |tail -n 1; \
   done
1. move the backup zfs to their new location:
    ```bash
    zfs rename zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-117-disk-0 zfs-hdd/pve/subvol-114-disk-0
    zfs rename zfs-hdd/off-backups/off2-zfs-hdd/opf zfs-hdd/podata/opf
    ```
1. on scaleway-01, remove the opf/products,images datasets as they are useless
  and may conflict with the real mount we need in the container
  ```bash
  zfs destroy -r zfs-hdd/podata/opf/products
  zfs destroy -r zfs-hdd/podata/opf/images
  ```
1. modify the configuration `srv/opf/lib/ProductOpener/Config2.pm` in `/zfs-hdd/pve/subvol-114-disk-0/`:
   ```
   $mongodb_host = "10.13.1.200";
    ...
    $redis_url = '10.13.1.200:6379';
    ...
    %server_options = (

            cookie_domain => "openproductsfacts.org",   # if not set, default to $server_domain
            minion_backend => {'Pg' => 'postgresql://off:********@10.13.1.200/minion'},
            minion_local_queue => "openproductsfacts.org",
    ...
    $memd_servers = [ "10.13.1.102:11211" ];
    ```
1. modify links to folders:
    ```bash
    cd /zfs-hdd/pve/subvol-114-disk-0/
    unlink srv/opf/products
    ln -s /mnt/opf/products srv/opf/products
    unlink srv/opf/html/images/products
    ln -s /mnt/opf/images/products srv/opf/html/images/products
    # some strange old refs
    rm -rf srv/off/new_images
    rm -rf srv/obf/new_images
    rm -rf srv/opff/new_images
    # remove old refs
    for dirname in srv/{off,opff,obf}/{html/images/products,products}; \
    do \
    unlink $dirname; \
    done
    for dirname in mnt/{off,opff,obf}/{images,products,} srv/{off,opff,obf}/{html/{images,},}; \
    do \
    rmdir $dirname; \
    done
    ```
1. on scaleway-01, start the service `pct start 114`
1. on your computer, verify the service is working with a modified `/etc/hosts`
1. in OVH web console, change the `openproductsfacts.org` `A` entry to point to `151.115.132.10`
1. on your computer remove you `/etc/hosts` specific configuration and test again
1. It's live !

After migration:
* on off2: rename subvol-117 to avoid confusion
  ```bash
  zfs rename zfs-hdd/pve/subvol-117-disk-0 zfs-hdd/backups/subvol-117-disk-0
  ```
* verify backups of the new datasets are done on scaleway-03:
  * `zfs list zfs-hdd/off-backups/scaleway-01-podata-hdd -r`
* rerun the ansible:
  * container creation on scaleway-01:
    `ansible-playbook sites/proxmox-node.yml --tags containers -l scaleway-01`
  * jobs/configure for opf:
    `ansible-playbook jobs/configure.yml -l opf` [^SSH_RESTART]
* remove the backup datasets at ovh3
* Verify podata is synced on ovh3
* put back the TTL for domain to a normal level

Later:
* on off2: remove the pct 117: `pct remove 117`


[^SSH_RESTART]: Note that while running the configure job,
at some point it was not able to connect to the server…
I had to go on scaleway-01, use `pct enter <ct_id>`
and there do a `systemctl daemon-reload && systemctl restart ssh`