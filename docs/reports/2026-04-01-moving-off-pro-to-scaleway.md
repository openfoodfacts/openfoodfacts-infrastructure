# 2026-04-01 Moving OFF-pro to scaleway

After moving [opff](./2026-03-12-moving-opff-to-scaleway.md),
[obf and opf to scaleway](./2026-03-27-moving-obf-opf-to-scaleway.md)
we have to also move the pro platform to scaleway (Open Food Facts public platform will be the last).

The difference between obf and the pro-platform is:
* the access to the sftp files,
* the export exchange folder (`export_files`) in the off-pro `cache` folder,
  so we will have to put this folder in a separate dataset,
  leave it on off2 for now and share it with NFS
* the `products` and `images` folders are specific,
  but we need access to off products folder (because of `internal_code.json`)
* the `data` folder shared with `off` (but it seems not useful…, we will play safe though)

A small difference is also that it has a specific mount for logs (as off).

## Moving SFTP service

Currently the sftp service is provided by off2 proxy.
We now have to provide it from a service based on scaleway.
The reverse proxy is still the right choice.
It will be on the same host as the producer platform,
so we will use a direct mount of the shared dataset as we did before
(otherwise we would need a NFS mount on the host).

The sftp service install on off2 was documented in
[2023-06-07 OFF and OFF-pro reinstall on off2, Adding sftp to reverse proxy](./2023-07-off2-off-reinstall.md#adding-sftp-to-reverse-proxy)

We will do almost the same transformations to the reverse-proxy:

1. Using ansible change the id mapping of the container
   (because we didn't set it before, but as we share sftp folder with off-pro which as this mapping)
   1. add the mapping to the container definition in `ansible/host_vars/scaleway-01/proxmox.yml`
   1. run the playbook `ansible-playbook sites/proxmox-node.yml --tags containers --extra-vars "proxmox_containers__limit_to_containers=100" -l scaleway-01`
      this fails at some point but it's normal
   1. manually adjust ownership where needed (essentially /home/*) on scaleway-01:
      ```bash
      cd /zfs-hdd/pve/subvol-100-disk-0
      # note we list user from the container, so it's etc/ not /etc
      # we also need to remove add a ./ for home folder
      for USERID_HOMEDIR in $(cat etc/passwd|grep /home|cut -d ":" -f 3,6);do USERID=${USERID_HOMEDIR%:*};HOMEDIR=${USERID_HOMEDIR#*:};sudo echo chown $USERID:$USERID -R .$HOMEDIR; chown $USERID:$USERID -R .$HOMEDIR; done
      ```
    1. test you can log into the container, and permissions are ok on the home folder.
       Otherwise use `pct enter 100` from `scaleway-01` to see what's happening
    1. rerun the playbook command above, this should pass now
1. Mount the sftp volume in the container (we will first test with a clone of backups data on scaleway-01)
   1. clone the volume to the target place, we also clone off-pro as it is above in hierarchy:
       ```bash
       # take daily snap to avoid blocking an hourly one
     TARGET_SNAP=$(zfs list -o name -t snap zfs-hdd/off-backups/off2-zfs-hdd/off-pro|grep _daily|tail -n 1)
     echo $TARGET_SNAP
     zfs clone $TARGET_SNAP zfs-hdd/podata/off-pro
     TARGET_SNAP=$(zfs list -o name -t snap zfs-hdd/off-backups/off2-zfs-hdd/off-pro/sftp|grep _daily|tail -n 1)
     echo $TARGET_SNAP
     zfs clone $TARGET_SNAP zfs-hdd/podata/off-pro/sftp
       ```
   1. add the mount point in the container
       ```bash
       vim /etc/pve/lxc/100.conf
       ...
       mp0:/zfs-hdd/podata/off-pro/sftp,mp=/mnt/off-pro/sftp
       ...
       ```
   1. restart the container `pct shutdown 100 && pct start 100`
   1. verify everything is still working
   1. verify the folder is mounted in the container with right access, so in `scaleway-proxy`:
       ```bash
       sudo ls /mnt/off-pro/sftp -l
       ```
       Now we may have a problem with users as we may need some id changes
1. Copy sshd_config file used at off2 (in this repo) and link it (or wait for sftp role to do it)
1. Port users:
   1. Get all users that use sftp on off2 proxy:
      ```bash
      exp=$(grep /mnt/off-pro/sftp/ /etc/passwd|cut -d ":" -f 1|sort|tr  '\n' '|')
      exp="("$exp"nonexistinguser)"
      sudo grep -P "$exp" /etc/shadow
      ```
   1. add them to the `ansible/host_vars/scaleway-proxy/sftp-secrets.yml` file
   1. run the playbook sftp actions
      ```bash
      ansible-playbook sites/reverse-proxy.yml -l scaleway-proxy --tags sftp
      ```
1. testing:
   1. I added a offtest user to test (and rerun the reverse-proxy playbook)
   1. I then use `ssh offtest@151.115.132.10` to validate the host key
   1. I use `lftp sftp://151.115.132.10 --user offtest` to test it was working
      1. don't forget to run at least `ls` to get authenticated (auth is deferred)
      1. to test, I did run:
         ```
         cd data
         put README.md
         ls
         get README.md -o /tmp/testREADME.md
         rm README.md
         ```
   1. I also tested authenticating with a key using ``lftp sftp://sftoff --user offtest`
      after defining `sftpoff` in my .ssh/config, with the right `IdentityFile` directive,
      and leaving the password prompt empty (which makes lftp use the keyfile)

## Sharing off/data and off-pro/cache through NFS

the off/data, is not a dataset per se, but a folder in off.
This means we will have to share `off` dataset through ZFS.

We do this on off2:
```bash
zfs set sharenfs="rw=@151.115.132.10/31,rw=@151.115.132.12/31,rw=@10.1.0.101,no_root_squash" zfs-hdd/off
```

We add it on scaleway-01:
```bash
mkdir /mnt/nfs/off/data
vim /etc/fstab
...
213.36.253.208:/zfs-hdd/off/data /mnt/nfs/off/data nfs nfsvers=4.2,proto=tcp,port=2049 0 0
...
systemctl daemon-reload
mount /mnt/nfs/off/data
# verify
ls /mnt/nfs/off/data
```

### Export files folder

For export files folder, this is unfortunate that it is not a dataset per se.
In the future it might even be needed to share it on opf / opff etc. (not sure though).

So we will make it its own dataset and keep it on off2.

It's normally a temporary folder, so no need to keep the data around.

We will migrate it to its own dataset on off2:

1. Create the new dataset. On purpose, I'll do it outside of off-pro dataset,
   as this one will move on scaleway-01.
   I'll do it under `off` dataset, but later we will move it in `podata`.
   So on off2:
   ```bash
   zfs create zfs-hdd/off/pro_export_files
   ```
2. edit `/etc/pve/lxc/11{3,4}.conf`,
   to add the mountpoint: `mp16: /zfs-hdd/off/pro_export_files,mp=/mnt/off-pro/cache/export_files`
   (it's `mp11` in `114.conf`)
3. rsync data, on off2:
   ```bash
   time rsync --info=progress2 -a /zfs-hdd/off-pro/cache/export_files/ /zfs-hdd/off/pro_export_files/
   ...
   real	8m53,743s
   ```
4. restart the containers:
   ```bash
   pct shutdown 114 && pct start 114
   pct shutdown 113 && pct start 113
   ```

### Creating zfs-nvme/podata folder

off-pro `products` data is on the nvme disk.
As it is the first dataset on nvme we migrate to scaleway-01,
we need to create the parent dataset.
```bash
zfs create zfs-nvme/podata
```

### Preparing Reverse Proxy

We have to setup the reverse proxy in `scaleway-proxy`

First we copy the certificates from off2-proxy to scaleway-proxy
(following https://charlesreid1.github.io/copying-letsencrypt-certs-between-machines.html)
On off2-proxy:
```bash
CONF=/etc/nginx/sites-enabled/pro.openfoodfacts.org
DOM=$(sed -nr  "s|.*letsencrypt/live/(.*)/privkey.*|\1|p" $CONF)
echo "COPYING CERTS FOR $DOM in $DOM.tar.gz"
sudo tar -chvzf $DOM.tar.gz \
    /etc/letsencrypt/archive/${DOM} \
    /etc/letsencrypt/renewal/${DOM}.conf \
    /etc/letsencrypt/live/${DOM}
sudo chown alex:alex $DOM.tar.gz
sudo chmod go-rw $DOM.tar.gz
```
I then copied it to scaleway-proxy (using scp).
And on scaleway-proxy:
```bash
cd /
tar xzf /home/alex/pro.openfoodfacts.org.tar.gz
# verify
ls -l /etc/letsencrypt/*/pro.openfoodfacts.org /etc/letsencrypt/renewal/pro.openfoodfacts.org.conf
```

On scaleway-proxy
I copied the configuration from off2 reverse proxy in scaleway-proxy conf dir (common config were already copied and linked while moving opff):
```bash
cd /opt/openfoodfacts-infrastructure/
cp confs/off2-reverse-proxy/nginx/sites-enabled/pro.openfoodfacts.org confs/scaleway-proxy/nginx/sites-enabled/
# link at system level
ln -s /opt/openfoodfacts-infrastructure/confs/scaleway-proxy/nginx/sites-enabled/pro.openfoodfacts.org /etc/nginx/sites-enabled/
```

I also edited pro.openfoodfacts.org conf
* `listen 443 ... http2` is now deprecated in favour of `http2 on;`
* comment `ssl_stapling` and `ssl_stapling_verify` directives (deprecated)
* to substitute any occurrence of `10.1.0.114` for `10.13.1.112`.



## Procedure for OFF-Pro migration

### Preparing container

First create the 112 container named off-pro using ansible (see [proxmox - How to create a new container with ansible](../proxmox.md#how-to-create-a-new-container-with-ansible))
following what was done for 115 (opff).

On scaleway-01:
1. shutdown the container: `pct shutdown 112`
3. edit the container configuration to add mountpoints:
   ```
   mp0: /zfs-hdd/podata/off-pro,mp=/mnt/off-pro
   mp1: /zfs-hdd/podata/off-pro/cache,mp=/mnt/off-pro/cache
   mp2: /zfs-hdd/podata/off-pro/html_data,mp=/mnt/off-pro/html_data
   mp3: /zfs-nvme/podata/off-pro/products,mp=/mnt/off-pro/products
   mp4: /zfs-hdd/podata/off-pro/images,mp=/mnt/off-pro/images
   mp5: /zfs-hdd/podata/off-pro/sftp,mp=/mnt/off-pro/sftp
   mp6: /zfs-hdd/podata/off-pro/logs,mp=/mnt/off-pro/logs
   mp7: /mnt/nfs/off/users,mp=/mnt/off-pro/users
   mp8: /mnt/nfs/off/orgs,mp=/mnt/off-pro/orgs
   mp9: /mnt/nfs/off/products,mp=/mnt/off/products
   mp10: /mnt/nfs/off/data,mp=/mnt/off-pro/data
    ```
    also added:
    ```
    lxc.cap.drop: "sys_rawio audit_read"
    ```
2. remove the created disk: `zfs destroy zfs-hdd/pve/subvol-112-disk-0`

### Preparing Migration

On OVH web console: modify TTL on pro.openfoodfacts.org and *.pro.openfoodfacts.org to 60s

On your desktop prepare the following lines to add to your `/etc/hosts` (comment them until migration):

```
151.115.132.10 world.pro.openfoodfacts.org fr.pro.openfoodfacts.org static.pro.openfoodfacts.org images.pro.openfoodfacts.org
```

### Migration

1. on scaleway-01 comment off-pro backups in /etc/sanoid/syncoid-args.conf

Now we hurry:

1. on off2, stop off-pro container `pct shutdown 114`
1. on off2, create a last snapshot:
  ```bash
  # mimic sanoid
  SNAP_NAME=autosnap_$(date --utc +"%Y-%m-%d_%H:%M:%S")_hourly
  for dataset in zfs-hdd/pve/subvol-114-disk-0 zfs-hdd/off-pro{,/cache,/html_data,/images,/sftp,/logs} zfs-nvme/off-pro{,/products}; \
  do \
    zfs snapshot $dataset@$SNAP_NAME; \
    echo DONE: $dataset@$SNAP_NAME; \
  done
  ```
1. on `scalway-01`, make a last sync of datasets:
   ```bash
   syncoid --no-sync-snap --no-privilege-elevation scaleway01operator@off2.openfoodfacts.org:zfs-hdd/pve/subvol-114-disk-0 zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-114-disk-0
   syncoid --no-sync-snap --no-privilege-elevation --recursive scaleway01operator@off2.openfoodfacts.org:zfs-hdd/off-pro zfs-hdd/off-backups/off2-zfs-hdd/off-pro
   syncoid --no-sync-snap --no-privilege-elevation --recursive scaleway01operator@off2.openfoodfacts.org:zfs-nvme/off-pro zfs-nvme/off-backups/off2-zfs-nvme/off-pro
   ```
   verify:
   ```bash
   zfs list -t snap zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-114-disk-0 |tail -n 1
   for dataset in off-pro{,/cache,/html_data,/images,/sftp,/logs}; \
   do \
     zfs list -t snap zfs-hdd/off-backups/off2-zfs-hdd/$dataset |tail -n 1; \
   done
   for dataset in off-pro{,/products}; \
   do \
     zfs list -t snap zfs-nvme/off-backups/off2-zfs-nvme/$dataset |tail -n 1; \
   done
   ```

1. move the backup zfs to their new location:
    ```bash
    zfs rename zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-114-disk-0 zfs-hdd/pve/subvol-112-disk-0
    zfs rename zfs-nvme/off-backups/off2-zfs-nvme/off-pro zfs-nvme/podata/off-pro
    ```
1. to move main data, we need to first remove the clones we created to test sftp setup,
   **warning** we have to restart the reverse proxy:
   ```bash
   pct shutdown 100
   zfs destroy -r zfs-hdd/podata/off-pro/sftp
   zfs destroy -r zfs-hdd/podata/off-pro
   zfs rename zfs-hdd/off-backups/off2-zfs-hdd/off-pro zfs-hdd/podata/off-pro
   pct start 100
   ```
1. modify the configuration `srv/off-pro/lib/ProductOpener/Config2.pm` in `/zfs-hdd/pve/subvol-112-disk-0/`:
   ```
   $mongodb_host = "10.13.1.200";
    ...
    # $redis_url = '10.13.1.200:6379';
    ...
    %server_options = (

            minion_backend => {'Pg' => 'postgresql://off:********@10.13.1.200/minion'},
            minion_local_queue => "pro.openfoodfacts.org",
    ...
    $memd_servers = [ "10.13.1.102:11211" ];
    ```
1. Contrary to opff / obf /obf migrations there is no link to modify
1. on scaleway-01, start the service `pct start 112`
1. on your computer, verify the service is working with a modified `/etc/hosts`
1. in OVH web console
   1. change the `pro.openfoodfacts.org` `A` entry to point to `151.115.132.10`
   1. change `sftp.openfoodfacts.org` to `CNAME` `scaleway-proxy`
1. on your computer remove you `/etc/hosts` specific configuration and test again
1. It's live !

After migration:
* on off2: rename subvol-114 to avoid confusino
  ```bash
  zfs rename zfs-hdd/pve/subvol-114-disk-0 zfs-hdd/backups/subvol-114-disk-0
  ```
* add new backups of scaleway-01 nvme podata on scaleway-03
* verify backups of the new datasets are done on scaleway-03:
  * `zfs list zfs-hdd/off-backups/scaleway-01-podata-hdd -r`
  * `zfs list zfs-hdd/off-backups/scaleway-01-podata-nvme -r`
* rerun the ansible:
  * container creation on scaleway-01:
    `ansible-playbook sites/proxmox-node.yml --tags containers -l scaleway-01 -e proxmox_containers__limit_to_containers=112`
  * jobs/configure for off-pro:
    `ansible-playbook jobs/configure.yml -l off-pro`
  * sftp/setup for scaleway-reverse-proxy:
    `ansible-playbook sites/reverse-proxy.yml -l scaleway-proxy --tags sftp`

* remove the backup datasets at ovh3
* Verify podata is synced on ovh3
* put back the TTL for domain to a normal level
* remove the site on off2 proxy (to avoid certbot errors in the future)

Later:
* on off2: remove the pct 114: `pct remove 114`

## Email producers about sftp ip change

While we changed the `sftp.openfoodfacts.org` address,
some producers might have firewall or so using ip address,
so we must advertise the change.

To get the current producers, with last date of file transfert,
on `scaleway-proxy`, i used:
```bash
cd /mnt/off-pro/sftp
for x in */data; do last_file=$(ls $x -tr|tail -n 1); mod_year=$(stat -c "%y" "$x/$last_file" | cut -d " " -f 1); user=${x%/data}; echo $mod_year $user; done|sort
```
and use a file to parse and sort it.
