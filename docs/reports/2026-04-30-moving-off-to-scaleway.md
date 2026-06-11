# Moving OFF to scaleway

After we moved [opff](./2026-03-12-moving-opff-to-scaleway.md), [obf and opf](./2026-03-27-moving-obf-opf-to-scaleway.md), [off-pro](./2026-04-01-moving-off-pro-to-scaleway.md),
it's time to move the last component to scaleway: the openfoodfacts container (aka off).

We not only have to move the off container, but also all the ZFS datasets that are common to off and the other instances.
So we will need to reconfigure and restart all VMs to point to the right ZFS datasets
(currently they are using NFS mounts).


## Preparing stunnel to off-query

I first had to add an ipv6 ip to my stunnel client.
I tried hard to use a ULA, having the proxmox host act as a NAT66,
but I failed…
So for the moment:
* I added a public ipv6 to the container
* although the iptables should stop non private connections,
  I preferred to only accept stunnel connections on 10.13.1.101
  (for all exposed stunnel entries)

On OSM45, I edited stunnel server configuration just to add a PSK in `/etc/stunnel/psk/off-query-psk.txt`.

I added this PSK to `scaleway-stunnel-client-secrets.yml` and run:
```bash
ansible-playbook sites/stunnel-client.yml -l scaleway-stunnel-client --tags stunnel
```
(as we are asked to switch branch, we use the continue `c` option).

I edited the stunnel config on scaleway-stunnel-client to add:
```ini
# off query at moji
[MojiOffQuery]
client = yes
# BEWARE: as we have a public ipv6, only accept on private ipv4
accept = 10.13.1.101:16001
connect = 2a06:c484:5::102:16001
PSKsecrets = /etc/stunnel/psk/moji-off-query-psk.txt

```

Checked with a `stunnel /etc/stunnel/off.conf`

And restarted: `systemctl restart stunnel@off`

Checked it's still ok `systemctl status stunnel@off`

Check if I can join off-query:
```bash
curl 10.13.1.101:16001/health
{"status":"ok","info":{"postgres":{"status":"up","info":{"last_scheduled_update":"2026-04-09T14:31:19Z"}},"mongodb":{"status":"up"},"redis":{"status":"up","info":{"last-generated-id":"1777932576222-0","last-processed-id":"1777932576222-0"}}}}
```
From off-pro container, it also works.

**FIXME** try to use a ULA ipv6 nated by the proxmox host (seems harder than it should be…)

## moving users and orgs to nvme

We will take the opportunity of moving to scaleway to move some datasets to nvme,
because we write to them quite a lot.
I will move orgs and users.
(note that `off/logs` is also a good candidate, but too heavy, right now, due to archive,
we should find a better approach on that one).

For this, I did a sync of the users and orgs datasets to the nvme disk (not directly to their final destination, to avoid sanoid creating conflicting snapshots)
```bash
syncoid --no-sync-snap zfs-hdd/off-backups/off2-zfs-hdd/off/users zfs-nvme/off-backups/off2-zfs-nvme/off/users
syncoid --no-sync-snap zfs-hdd/off-backups/off2-zfs-hdd/off/orgs zfs-nvme/off-backups/off2-zfs-nvme/off/orgs
```

## Preparing target off container

First create the 111 container named off using ansible (see [proxmox - How to create a new container with ansible](../proxmox.md#how-to-create-a-new-container-with-ansible))
following what was done for 115 (opff).

On scaleway-01:
1. shutdown the container: `pct shutdown 111`
2. edit the container configuration to add mountpoints: **FIXME**
   ```
    mp0: /zfs-hdd/podata/off,mp=/mnt/off
    mp1: /zfs-hdd/podata/off/cache,mp=/mnt/off/cache
    mp2: /zfs-hdd/podata/off/html_data,mp=/mnt/off/html_data
    mp3: /zfs-hdd/podata/off/logs,mp=/mnt/off/logs
    mp4: /zfs-nvme/podata/products,mp=/mnt/off/products
    mp5: /zfs-hdd/podata/images,mp=/mnt/off/images
    mp6: /zfs-nvme/podata/users,mp=/mnt/off/users
    mp7: /zfs-nvme/podata/orgs,mp=/mnt/off/orgs
    mp8: /zfs-hdd/podata/pro_export_files,mp=/mnt/off-pro/cache/export_files
    mp9: /zfs-hdd/podata/off-pro/images,mp=/mnt/off-pro/images
    ```
    also added:
    ```
    lxc.cap.drop: "sys_rawio audit_read"
    ```
3. remove the created disk: `zfs destroy zfs-hdd/pve/subvol-111-disk-0`

Do not start the container yet!

## Preparing Reverse Proxy

We have to setup the reverse proxy in `scaleway-proxy`

First we copy the certificates from off2-proxy to scaleway-proxy
(following https://charlesreid1.github.io/copying-letsencrypt-certs-between-machines.html)
On off2-proxy:
```bash
CONF=/etc/nginx/sites-enabled/openfoodfacts.org
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
And on scaleway-proxy:
```bash
sudo -i
DOM=openfoodfacts.org
cd /
tar xzf /home/alex/$DOM.tar.gz
# verify
ls -l /etc/letsencrypt/*/$DOM /etc/letsencrypt/renewal/$DOM.conf
```

I also had to do it for secondary websites: `howmuchsugar.in` and `madenear.me`

On scaleway-proxy:
I copied the configuration from off2 reverse proxy in scaleway-proxy conf dir (common config were already copied and linked while moving opff):
```bash
cd /opt/openfoodfacts-infrastructure/
cp -r confs/off2-reverse-proxy/nginx/snippets confs/scaleway-proxy/nginx/
ln -s /opt/openfoodfacts-infrastructure/confs/scaleway-proxy/nginx/snippets/backend-proxy.conf /etc/nginx/snippets
for hostname in openfoodfacts.org howmuchsugar.in madenear.me; do \
  cp confs/off2-reverse-proxy/nginx/sites-enabled/$hostname confs/scaleway-proxy/nginx/sites-enabled/; \
  ln -s /opt/openfoodfacts-infrastructure/confs/scaleway-proxy/nginx/sites-enabled/$hostname /etc/nginx/sites-enabled/; \
done
```

I also edited openfoodfacts.org conf
* `listen 443 ... http2` is now deprecated in favour of `http2 on;`
* comment `ssl_stapling` and `ssl_stapling_verify` directives (deprecated)
* to replace any occurrence of `10.1.0.113` with `10.13.1.111`.

Also I prepared the maintenance page to use the "planned maintenance" page,
that is in `/opt/openfoodfacts-infrastructure/html`:
```bash
unlink 502.html
ln -s 502-planned.html 502.html
```


## Preparing DNS

On OVH web console: modify TTL on openfoodfacts.org and *.openfoodfacts.org to 60s

On your desktop prepare the following lines to add to your `/etc/hosts` (comment them until migration):

```
151.115.132.10 world.openfoodfacts.org fr.openfoodfacts.org static.openfoodfacts.org images.openfoodfacts.org
```

You might use this configuration to do a quick test that your reverse proxy is setup correctly (but you will get a gateway timeout of course, as 111 is shutdown)

(Note: didn't test madenear.me, howmuchsugar.in and so on, because downtime is far less important on those websites).


## Preparing KS1

KS1 will have to sync images from scaleway,
for this we need to have an operator on scaleway-01 for it.

I just followed [our sanoid doc on creating operator on PROD_SERVER](../sanoid.md#creating-operator-on-prod_server)


## Migration



1. on off2-reverse-proxy, put the "planned maintenance page on":
   ```bash
   cd /opt/openfoodfacts-infrastructure/html
   unlink 502.html
   ln -s 502-planned.html 502.html
   ```
1. login to ks1 and comment the syncoid line for images (until end of migration)
1. on scaleway-01 comment off backups in /etc/sanoid/syncoid-args.conf (line for zfs-hdd and for nvme)

Now we hurry:

1. on off2, create a before last snapshot:
  ```bash
  # mimic sanoid
  SNAP_NAME=autosnap_$(date --utc +"%Y-%m-%d_%H:%M:%S")_hourly
  for dataset in zfs-hdd/pve/subvol-113-disk-0 zfs-hdd/off{,/cache,/html_data,/logs,/images,/orgs,/users,/pro_export_files} zfs-nvme/off{,/products}; \
  do \
    zfs snapshot $dataset@$SNAP_NAME; \
    echo DONE: $dataset@$SNAP_NAME; \
  done
  ```
1. on `scaleway-01` do a sync before shutting down off:
   ```bash
   syncoid --no-sync-snap --no-privilege-elevation scaleway01operator@off2.openfoodfacts.org:zfs-hdd/pve/subvol-113-disk-0 zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-113-disk-0
   syncoid --no-sync-snap --no-privilege-elevation --recursive scaleway01operator@off2.openfoodfacts.org:zfs-hdd/off zfs-hdd/off-backups/off2-zfs-hdd/off
   syncoid --no-sync-snap --no-privilege-elevation --recursive scaleway01operator@off2.openfoodfacts.org:zfs-nvme/off zfs-nvme/off-backups/off2-zfs-nvme/off
   # sync our users and orgs new location
   syncoid --no-sync-snap zfs-hdd/off-backups/off2-zfs-hdd/off/users zfs-nvme/off-backups/off2-zfs-nvme/off/users
   syncoid --no-sync-snap zfs-hdd/off-backups/off2-zfs-hdd/off/orgs zfs-nvme/off-backups/off2-zfs-nvme/off/orgs
   ```

1. on off2, stop off container `pct shutdown 113` and verify with `pct list`
1. on scaleway-01 stop all containers accessing off data
   `echo 11{2,3,4,5}|xargs -P 4 -n 1 pct shutdown --forceStop=1`
   verify with `pct list`
1. on off2, create a last snapshot:
  ```bash
  # mimic sanoid
  SNAP_NAME=autosnap_$(date --utc +"%Y-%m-%d_%H:%M:%S")_hourly
  for dataset in zfs-hdd/pve/subvol-113-disk-0 zfs-hdd/off{,/cache,/html_data,/logs,/images,/orgs,/users,/pro_export_files} zfs-nvme/off{,/products}; \
  do \
    zfs snapshot $dataset@$SNAP_NAME; \
    echo DONE: $dataset@$SNAP_NAME; \
  done
  ```
1. on `scaleway-01`, make a last sync of datasets:
   ```bash
   syncoid --no-sync-snap --no-privilege-elevation scaleway01operator@off2.openfoodfacts.org:zfs-hdd/pve/subvol-113-disk-0 zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-113-disk-0
   syncoid --no-sync-snap --no-privilege-elevation --recursive scaleway01operator@off2.openfoodfacts.org:zfs-hdd/off zfs-hdd/off-backups/off2-zfs-hdd/off
   syncoid --no-sync-snap --no-privilege-elevation --recursive scaleway01operator@off2.openfoodfacts.org:zfs-nvme/off zfs-nvme/off-backups/off2-zfs-nvme/off
   # sync our users and orgs new location
   syncoid --no-sync-snap zfs-hdd/off-backups/off2-zfs-hdd/off/users zfs-nvme/off-backups/off2-zfs-nvme/off/users
   syncoid --no-sync-snap zfs-hdd/off-backups/off2-zfs-hdd/off/orgs zfs-nvme/off-backups/off2-zfs-nvme/off/orgs
   ```
   verify:
   ```bash
   zfs list -t snap -o name zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-113-disk-0 |tail -n 1
   for dataset in zfs-hdd/off-backups/off2-zfs-hdd/off{,/cache,/html_data,/logs,/images,/pro_export_files} zfs-nvme/off-backups/off2-zfs-nvme/off{,/users,/orgs,/products}; \
   do \
       zfs list -t snap -o name $dataset |tail -n 1; \
   done
   ```
1. move the backup zfs to their new location:
    ```bash
    zfs rename zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-113-disk-0 zfs-hdd/pve/subvol-111-disk-0
    zfs rename zfs-hdd/off-backups/off2-zfs-hdd/off zfs-hdd/podata/off
    # products, users, orgs on nvme are common
    zfs rename zfs-nvme/off-backups/off2-zfs-nvme/off/products zfs-nvme/podata/products
    zfs rename zfs-nvme/off-backups/off2-zfs-nvme/off/users zfs-nvme/podata/users
    zfs rename zfs-nvme/off-backups/off2-zfs-nvme/off/orgs zfs-nvme/podata/orgs
    # we don’t need hdd users and orgs anymore
    zfs destroy -r zfs-hdd/podata/off/users
    zfs destroy -r zfs-hdd/podata/off/orgs
    #  images, and pro_export_files are common, move them up
    zfs rename zfs-hdd/podata/off/images zfs-hdd/podata/images
    zfs rename zfs-hdd/podata/off/pro_export_files zfs-hdd/podata/pro_export_files
    ```
1. modify the configuration `srv/off/lib/ProductOpener/Config2.pm` in `/zfs-hdd/pve/subvol-111-disk-0/`:
   ```
    $mongodb_host = "10.13.1.200";
    ...
    $memd_servers = [ "10.13.1.102:11211" ];
    ...
    $redis_url = '10.13.1.200:6379';
    ...
    $query_url = "http://10.13.1.101:16001";
    ...
    %server_options = (

            cookie_domain => "openfoodfacts.org",   # if not set, default to $server_domain
            minion_backend => {'Pg' => 'postgresql://off:********@10.13.1.200/minion'},
            minion_local_queue => "openfoodfacts.org",
    ```
1. modify links to folders:
    ```bash
    cd /zfs-hdd/pve/subvol-111-disk-0/
    # some old refs
    rm -rf srv/obf/new_images
    rm -rf srv/opf/new_images
    rm -rf srv/opff/new_images
    # remove old refs
    for dirname in srv/{obf,opf,opff}/{html/images/products,products}; \
    do \
    unlink $dirname; \
    done
    for dirname in mnt/{obf,opf,opff}/{images,products,} srv/{obf,opf,opff}/{html/{images,},}; \
    do \
    rmdir $dirname; \
    done
    ```
1. on scaleway-01, start the service `pct start 111`
1. on your computer, verify the service is working with a modified `/etc/hosts`
1. in OVH web console, change the `openfoodfacts.org` `A` entry to point to `151.115.132.10`
1. on your computer remove your `/etc/hosts` specific configuration and test again
1. unmount all nfs to be sure we are not writing to them again:
   ```bash
   umount /mnt/nfs/off/orgs /mnt/nfs/off/images /mnt/nfs/off/users /mnt/nfs/off/products /mnt/nfs/off/pro_export_files /mnt/nfs/off/data
   for dirname in /mnt/nfs/off/orgs /mnt/nfs/off/images /mnt/nfs/off/users /mnt/nfs/off/products /mnt/nfs/off/pro_export_files /mnt/nfs/off/data /mnt/nfs/off/off /mnt/nfs/off /mnt/nfs; do rmdir $dirname; done
   ```
1. We now continue for the other containers, for each container (113 to 115, aka obf,opf,opff):
   1. `declare -x ct=<id>`
   1. change the mountpoints for the container:
      ```bash
      vim /etc/pve/lxc/$ct.lxc
      …
      %s!/mnt/nfs/off!/zfs-hdd/podata!
      %s!/zfs-hdd/podata/products!/zfs-nvme/podata/products
      %s!/zfs-hdd/podata/users!/zfs-nvme/podata/users
      %s!/zfs-hdd/podata/orgs!/zfs-nvme/podata/orgs
      ```
   1. verify your modification and save
   1. restart the container: `pct start $ct`
1. We now change off-pro (112):
   1. change the mountpoints for the container:
      ```bash
      vim /etc/pve/lxc/112.lxc
      …
      %s!/mnt/nfs/off!/zfs-hdd/podata!
      %s!/zfs-hdd/podata/products!/zfs-nvme/podata/products
      %s!/zfs-hdd/podata/users!/zfs-nvme/podata/users
      %s!/zfs-hdd/podata/orgs!/zfs-nvme/podata/orgs
      %s!/zfs-hdd/podata/data!/zfs-nvme/podata/off/data
      ```
   1. verify your modification and save
   1. restart the container: `pct start 112`
1. It's live !
1. login to ks1 and change the sync for images to sync from scaleway
1. deal with howmuchsugar.in and madenear.me
   * change DNS for:
     * howmuchsugar.in, ~~howmuchsugar.info~~, ~~combiendesucres.fr~~
     * madenear.me, madenear.me.uk, cestemballepresdechezvous.fr, ~~cestemballepresdechezvous.info~~
   * check it works


## After migration

* [DONE] on off2: rename subvol-113 to avoid confusion
  ```bash
  zfs rename zfs-hdd/pve/subvol-113-disk-0 zfs-hdd/backups/subvol-113-disk-0
  ```
* [TODO] verify backups of the new datasets are done on scaleway-03:
  * `zfs list zfs-hdd/off-backups/scaleway-01-podata-hdd -r`
  * `zfs list zfs-hdd/off-backups/scaleway-01-podata-nvme -r`
  * (you may need to manually sync big datasets like images !)
* rerun the ansible:
  * container creation on scaleway-01:
    `ansible-playbook sites/proxmox-node.yml --tags containers -l scaleway-01 -e proxmox_containers__limit_to_containers=111`
  * jobs/configure for off:
    `ansible-playbook jobs/configure.yml -l off` [^SSH_RESTART]
* change the backup datasets at ovh3:
  * we don't want to sync images from scratch it's too heavy… see OVH3 backups update below
* Verify podata is synced on ovh3
* put back the TTL for domain to a normal level

* check any traffic still coming to off2 reverse proxy
* [DONE] change fallback server for images.openfoodfacts.org ([commit 724f156e](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/724f156e4e71954bb567a3a49770c252c0cd7ff3))

* [DONE] move query.openfoodfacts.org to scaleway reverse proxy
  (following same procedure as in [Preparing reverse Proxy](#preparing-reverse-proxy)

* [DONE] install fail2ban jails we had on off2 proxy on scaleway-proxy:
  * see commits
    [b6f4d634](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/b6f4d634c3cdfa0d7462521a6fb7ea89608f195c)
    and [a35797db](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/a35797db8a689b50ec0c20284863086329542c37)
  * I also transfered the manual banned ips, by listing them on off2 proxy
    and adding them back on the other side (using the `fail2ban-client … banip` command)

* [DONE] change sync_images to AWS parameters ([see commit 9bd66e6](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/9bd66e6347be39b36f4019a61420f37939df130a))
* [TODO] change monitoring to scrape on scaleway
  But we want to do it using the exporters pattern,
  so we need a new ansible role for that.

Post fixes:
* query.openfoodfacts.org was not responding, it was a DNS problem because proxy2.openfoodfacts.org
  was not defined any more, while query was a CNAME to it…
  So I redefined proxy2 as an A entry pointing to off2 reverse proxy IP
* https://robotoff.openfoodfacts.org/api/v1/health
* I had to whitelist scaleway servers [in PMG](../mail.md#adding-a-new-server) because emails were not arriving (I previously think it was not mandatory, because I though the iptables redirect rule was masking the real ip)
* we had to whitelist the scaleway-01 ip on brevo,
  as openfoodfacts use the API key to subscribe users to the mailing list.
* the certbot certificates renewal did not get well, see belw

Later:
* [DONE] shutdown stunnel services that are not needed anymore
  * shutdown container 105 on off1
  * remove config to old services on scaleway-stunnel-client
* on off2: remove the pct 113: `pct remove 113`
* could we move off logs to nvme on scaleway ?
  * for that we need to remove a lot of current logs that are not useful
    (maybe rewrite logrotate config)
* use ULA for container ipv6, nated by the proxmox host (investigate how on a test container)
* [TODO] decide whether we move the experimental opensuplementsfacts to scaleway…
  (note that its database is not merged with off)

## OVH3 backup updates

We need to have backups on OVH3. But resyncing images would take too long (and disk space may not even be there).

So here is the procedure:

* stop off staging instances (off-net) on ovh1 docker-staging VM,
  and add a NO_DEPLOY file to avoid deployments
* in `/etc/sanoid/syncoid-args.conf`,
  * comment lines that sync old off2 data
  * also comment lines that syncs podata from scaleway-01
* remove the clones on ovh3:
  ```bash
  # better restart the service
  systemctl restart nfs-server.service
  for dataset in  rpool/staging-clones/{off-images,off-products,orgs,users};do echo $dataset; zfs   destroy -r $dataset; done
  ```
  to be able to remove the images clones, I had to restart nfs server.
* move old dataset taken from off2 to the new locations
  ```bash
  # move root
  zfs rename rpool/off rpool/off-backups/podata/off
  # move common dataset up
  zfs rename rpool/off-backups/podata{/off,}/users
  zfs rename rpool/off-backups/podata{/off,}/orgs
  zfs rename rpool/off-backups/podata{/off,}/products
  zfs rename rpool/off-backups/podata{/off,}/images
  zfs rename rpool/off-backups/podata{/off,}/pro_export_files
  ```
* come back to a pre migration snapshot:
  ```bash
  for dataset in rpool/off-backups/podata/{off{,/cache,/html_data,/logs},users,orgs,products,images,pro_export_files}; \
  do \
    SNAP=$(zfs list -H -o name -t snap $dataset|grep "@autosnap_2026-05-05.*_daily"); \
    echo $SNAP; \
    time zfs rollback -r $SNAP; \
  done
  ```
  (note: this took a lot of time)
* verify structure is coherent with the one of scaleway-01, using `zfs list -o name .../podata`
* rerun syncoid for podata:
  ```bash
  syncoid --no-sync-snap --no-privilege-elevation --recursive ovh3operator@scaleway-01.infra.openfoodfacts.org:zfs-hdd/podata rpool/off-backups/podata
  ```
* uncomment the line for podata sync in `/etc/sanoid/syncoid-args.conf`
* rerun the clone script:
  `/opt/openfoodfacts-infrastructure/scripts/ovh3/maj-clones-nfs-VM-dockers.sh`
  (note: I had to kill the sync-s3-images script to be able to move images dataset,
  see [d52f6099](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/d52f60999fb88755bc79c48370c436ab39071e81)
  and [7785b412](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/7785b412d6cee66b7034e5448eaadf4d509a4033))
* I also removed the old data that are not useful anymore (as they are in nvme):
  ```bash
  for dataset in products orgs users; \
  do \
    zfs destroy -r rpool/off-backups/podata/$dataset; \
  done
  ```

  ### fix on certificates

  Certificates renewal did not work after install.
  I saw this on 26/05.
  This was due to several reason:

  1. some live directory where not using simlink…
     this is because PR corresponding to [commit `62b39187`](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/62b391872ef16f7ff2d25db0576b6c64f972fa3e)
     was not yet merged, and so I used wrong tar options (`-h`, which should not have been used)
  2. [`ovh-dns` certbot plugin]() was not installed on `scaleway-proxy`,
     so I added the installation in the ansible role.
     I also had to add the credential files (with ansible).
  3. the let'sencrypt account name had to be changed in every renewal files,
     to use the one found in `/etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org/directory/`,
     so in my case I use:
     ```bash
     sed  -e "s/account \?=.*$/account = a0d2da217c3d569b7964d2f500ba96ca/" -i /etc/letsencrypt/renewal/*.conf
     ```
