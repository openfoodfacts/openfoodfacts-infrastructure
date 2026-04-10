# 2026-04-01 Moving OFF-pro to scaleway

After moving [opff](./2026-03-12-moving-opff-to-scaleway.md),
[obf and opf to scaleway](./2026-03-27-moving-obf-opf-to-scaleway.md)
we have to also move the pro platform to scaleway (Open Food Facts public platform will be the last).

The difference between obf and the pro-platform is:
* the access to the sftp files,
* the export exchange folder (`export_files`) in the off-pro `cache` folder
* the `products` folder is specific, but we need access to off products folder (because of `internal_code.json`)
* the `data` folder shared with `off` (but it seems not useful…, we will play safe sough)

A small difference is also that it has a specific mount for logs (as off).

## Moving SFTP service

Currently the sftp service is provided by ovh proxy.
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
1. Copy sshd_config file used at off2 (in this repo) and link it
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



## Sharing off/data through NFS

the off/data, is not a dataset per se, but a folder in off.
This means we will have to share `off` dataset through ZFS.

We do this on off2:
```bash
zfs set sharenfs="rw=@151.115.132.10/31,rw=@151.115.132.12/31,rw=@10.1.0.101,no_root_squash" zfs-hdd/off
```

We add it on scaleway-01:
```bash
mkdir /mnt/nfs/off/off
vim /etc/fstab
...
213.36.253.208:/zfs-hdd/off /mnt/nfs/off/off nfs nfsvers=4.2,proto=tcp,port=2049 0 0
...
systemctl daemon-reload
mount /mnt/nfs/off/off
# verify
ls /mnt/nfs/off/off/data
```


## Procedure for OFF-Pro migration

### Preparing container

First create the 113 container named off-pro using ansible (see [proxmox - How to create a new container with ansible](../proxmox.md#how-to-create-a-new-container-with-ansible))
following what was done for 115 (opff).

On scaleway-01:
1. shutdown the container: `pct shutdown 113`
3. edit the container configuration to add mountpoints:
   ```
    mp0: /zfs-hdd/podata/off-pro,mp=/mnt/off-pro
    mp1: /zfs-hdd/podata/off-pro/cache,mp=/mnt/off-pro/cache
    mp2: /zfs-hdd/podata/off-pro/html_data,mp=/mnt/off-pro/html_data
    mp3: /mnt/nfs/off/products,mp=/mnt/off-pro/products
    mp4: /mnt/nfs/off/images,mp=/mnt/off-pro/images
    mp5: /mnt/nfs/off/users,mp=/mnt/off-pro/users
    mp6: /mnt/nfs/off/orgs,mp=/mnt/off-pro/orgs
    ```
    also added:
    ```
    lxc.cap.drop: "sys_rawio audit_read"
    ```
2. remove the created disk: `zfs destroy zfs-hdd/pve/subvol-113-disk-0`

### Preparing Migration

On OVH web console: modify TTL on pro.openfoodfacts.org and *.pro.openfoodfacts.org to 60s

On your desktop prepare the following lines to add to your `/etc/hosts` (comment them until migration):

```
151.115.132.10 world.pro.openfoodfacts.org fr.pro.openfoodfacts.org static.pro.openfoodfacts.org images.pro.openfoodfacts.org
```

### Migration

1. on scaleway-01 comment off-pro backups in /etc/sanoid/syncoid-args.conf

Now we hurry:

1. on off2, stop off-pro container `pct shutdown 116`
1. on off2, create a last snapshot:
  ```bash
  # mimic sanoid
  SNAP_NAME=autosnap_$(date --utc +"%Y-%m-%d_%H:%M:%S")_hourly
  for dataset in zfs-hdd/pve/subvol-116-disk-0 zfs-hdd/off-pro{,/cache,/html_data}; \
  do \
    zfs snapshot $dataset@$SNAP_NAME; \
    echo DONE: $dataset@$SNAP_NAME; \
  done
  ```
1. on `scalway-01`, make a last sync of datasets:
   ```bash
   syncoid --no-sync-snap --no-privilege-elevation scaleway01operator@off2.openfoodfacts.org:zfs-hdd/pve/subvol-116-disk-0 zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-116-disk-0
   syncoid --no-sync-snap --no-privilege-elevation --recursive scaleway01operator@off2.openfoodfacts.org:zfs-hdd/off-pro zfs-hdd/off-backups/off2-zfs-hdd/off-pro
   ```
   verify:
   ```bash
   zfs list -t snap zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-116-disk-0 |tail -n 1
   for dataset in off-pro{,/cache,/html_data}; \
   do \
     zfs list -t snap zfs-hdd/off-backups/off2-zfs-hdd/$dataset |tail -n 1; \
   done
1. move the backup zfs to their new location:
    ```bash
    zfs rename zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-116-disk-0 zfs-hdd/pve/subvol-113-disk-0
    zfs rename zfs-hdd/off-backups/off2-zfs-hdd/off-pro zfs-hdd/podata/off-pro
    ```
1. on scaleway-01, remove the off-pro/products,images datasets as they are useless
  and may conflict with the real mount we need in the container
  ```bash
  zfs destroy -r zfs-hdd/podata/off-pro/products
  zfs destroy -r zfs-hdd/podata/off-pro/images
  ```
1. modify the configuration `srv/off-pro/lib/ProductOpener/Config2.pm` in /`zfs-hdd/pve/subvol-113-disk-0/`:
   ```
   $mongodb_host = "10.13.1.200";
    ...
    $redis_url = '10.13.1.200:6379';
    ...
    %server_options = (

            cookie_domain => "openpetfoodfacts.org",   # if not set, default to $server_domain
            minion_backend => {'Pg' => 'postgresql://off:********@10.13.1.200/minion'},
            minion_local_queue => "openpetfoodfacts.org",
    ...
    $memd_servers = [ "10.13.1.102:11211" ];
    ```
1. modify links to folders:
    ```bash
    cd /zfs-hdd/pve/subvol-113-disk-0/
    unlink srv/off-pro/products
    ln -s /mnt/off-pro/products srv/off-pro/products
    unlink srv/off-pro/html/images/products
    ln -s /mnt/off-pro/images/products srv/off-pro/html/images/products
    # some strange old refs
    rm -rf srv/off/new_images/1730024919.opf:84165435.search.2.jpg
    # remove old refs
    for dirname in srv/{off,opf,off-pro}/{html/images/products,products}; \
    do \
    unlink $dirname; \
    done
    for dirname in mnt/{off,opf,off-pro}/{images,products,} srv/{off,opf,off-pro}/{html/{images,},}; \
    do \
    rmdir $dirname; \
    done
    ```
1. on scaleway-01, start the service `pct start 113`
1. on your computer, verify the service is working with a modified `/etc/hosts`
1. in OVH web console, change the `pro.openfoodfacts.org` `A` entry to point to `151.115.132.10`
1. on your computer remove you `/etc/hosts` specific configuration and test again
1. It's live !

After migration:
* on off2: rename subvol-116 to avoid confusino
  ```bash
  zfs rename zfs-hdd/pve/subvol-116-disk-0 zfs-hdd/backups/subvol-116-disk-0
  ```
* verify backups of the new datasets are done on scaleway-03:
  * `zfs list zfs-hdd/off-backups/scaleway-01-podata-hdd -r`
* rerun the ansible:
  * container creation on scaleway-01:
    `ansible-playbook sites/proxmox-node.yml --tags containers -l scaleway-01`
  * jobs/configure for off-pro:
    `ansible-playbook jobs/configure.yml -l off-pro`
* remove the backup datasets at ovh3
* Verify podata is synced on ovh3
* put back the TTL for domain to a normal level

Later:
* on off2: remove the pct 116: `pct remove 116`

