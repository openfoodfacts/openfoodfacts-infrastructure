# 2026-03-12 moving opff to scaleway

We are migrating all our instance from off1/off2 to scaleway new servers.

We already moved [mongodb](./2026-01-15-moving-mongodb-to-scaleway.md), [redis (and postgres backups)](./2026-02-26-moving-redis-to-scaleway.md) and installed a [new memcached instance](https://github.com/openfoodfacts/openfoodfacts-infrastructure/pull/610/changes) on scaleway-02

We now want to move the first opff instance there.


## Plan

We first need to add NFS shares on files that are common to the different instances:
- `zfs-hdd/off/products`
- `zfs-hdd/off/images`
- `zfs-hdd/off/users`
- `zfs-hdd/off/orgs` (it's not sure it's still needed, but let's not add a risk to the migration)

Note that previously we used to also cross mount products and images folders but we don't need them anymore, since database is centralized.

There are ZFS volumes that we don't need anymore since the merge of database,
it's a good occasion to get rid of them:
* `opff/products`
* `opff/images`

There are volumes where, during tests, we will use a clone of a backup of the volume,
and then, as we migrate, we will rename the backup instead to become the volume.
This is, all what is under zfs-hdd/opff currently:
- `/zfs-hdd/opff`
- `/zfs-hdd/opff/html_data`
- `/zfs-hdd/opff/cache`
and of course the container system disk: zfs-hdd/pve/subvol-118-disk-0

## NFS shares on off2

We will add NFS shares on off2, but only allowing scaleway ips to connect to them.

As there is user information that is circulating,
we will use stunnel to encrypt NFS communication.

On off2, I just add the nfs share property, enabling access from stunnel server
(on reverse proxy):
```bash
for dataset in zfs-hdd/off/{images,users,orgs} zfs-nvme/off/products
do
  echo $dataset
  zfs set sharenfs="rw=@10.1.0.101,no_root_squash" $dataset
done

zfs share -a
# verification
cat /etc/exports.d/zfs.exports
```

Restart NFS server using: `systemctl restart nfs-server.service`

I can now test from off2 reverse proxy.
First I add to change the network configuration on off2 reverse proxy
which was wrongly using `10.1.0.101/24` instead of `10.1.0.101/8` for it's internal ip
(leading to not being able to reach off2 through `10.0.0.2`).
```bash
nc -vz 10.0.0.2 2049
10.0.0.2: inverse host lookup failed: Unknown host
(UNKNOWN) [10.0.0.2] 2049 (nfs) open

apt install nfs-common
# -e shows all exports
showmount -e 10.0.0.2
...
/zfs-hdd/off/images 10.1.0.101(sec=sys,rw,no_subtree_check,mountpoint,no_root_squash)
/zfs-hdd/off/orgs 10.1.0.101(sec=sys,rw,no_subtree_check,mountpoint,no_root_squash)
/zfs-hdd/off/users 10.1.0.101(sec=sys,rw,no_subtree_check,mountpoint,no_root_squash)
...
/zfs-nvme/off/products 10.1.0.101(sec=sys,rw,no_subtree_check,mountpoint,no_root_squash)
...
```


### Stunnel setup

Now we will configure an access to the on off2 server, and on scaleway-stunnel.

I edited `scaleway-stunnel-client-secrets.yml` to add the secret psk,
run `ansible-playbook sites/stunnel-client.yml --tags stunnel -l scaleway-stunnel-client`
to create the secret file. On off2 reverse proxy, I did it manually.

I then edit the configuration of `/etc/stunnel/off.conf` on off2 reverse proxy
and on `scaleway-stunnel-client` to add the server and client part.

On off2 reverse proxy I also had to edit `/etc/nftables.conf.d/001-off2-reverse-proxy.conf`
to add the new port to `STUNNEL_PORTS`

I then test on the `scaleway-stunnel-client` directly:
```bash
nc -vz 10.13.1.101 2049
scaleway-stunnel-client.infra.openfoodfacts.org [10.13.1.101] 2049 (nfs) open

apt  install nfs-common
# -e shows all exports
showmount -e 10.13.1.101
```
It's not working, but it might be because LXC container can't use NFS directly.

So I tried from off2:
```bash
nc -vz 10.13.1.101 2049
  10.13.1.101: inverse host lookup failed: Unknown host
  (UNKNOWN) [10.13.1.101] 2049 (nfs) open

apt install nfs-common
...
showmount -e 10.13.1.101
  clnt_create: RPC: Program not registered

# trying a mount
mount -t nfs -o "nfsvers=4.2,proto=tcp,port=2049" 10.13.1.101:/zfs-hdd/off/orgs /mnt/test/
  mount.nfs: Operation not permitted for 10.13.1.101:/zfs-hdd/off/orgs on /mnt/test
```

### Going Without stunnel

As this will only be a temporary mount point, and servers are in the same datacenter,
we decided it's acceptable to go for a direct mount.

On off2, I changed the `sharenfs` option for the datasets:
```bash
for dataset in zfs-hdd/off/{images,users,orgs} zfs-nvme/off/products
do
  echo $dataset
  zfs set sharenfs="rw=@151.115.132.10/31,rw=@151.115.132.12/31,rw=@10.1.0.101,no_root_squash" $dataset
done

zfs share -a
# verification
cat /etc/exports.d/zfs.exports
```

And let firewall pass:
```bash
root@off2:~# iptables -A INPUT -p tcp -m tcp -s 151.115.132.10/31 --dport 2049 -j ACCEPT
root@off2:~# iptables -A INPUT -p tcp -m tcp -s 151.115.132.12/31 --dport 2049 -j ACCEPT
```
I also edited `/etc/iptables/rules.v4` to add the rules.

Now on scaleway-01
```bash
apt install nfs-common
nc -vz 213.36.253.208 2049
  off2.free.org [213.36.253.208] 2049 (nfs) open

showmount -e 213.36.253.208
  clnt_create: RPC: Timed out

mkdir /mnt/test
mount -t nfs -o "nfsvers=4.2,proto=tcp,port=2049" 213.36.253.208:/zfs-hdd/off/orgs /mnt/test/

ls -l /mnt/test/off-test.sto
-rw-r--r-- 1 config-op config-op 840 16 mars  03:20 /mnt/test/off-test.sto
umount /mnt/test/
```
So this is working :tada:

So I added the NFS mounts to fstab:
```bash
mkdir -p /mnt/nfs/off/{orgs,images,users,products}


cp /etc/fstab /opt/openfoodfacts-infrastructure/confs/scaleway-01/
rm /etc/fstab; ln -s /opt/openfoodfacts-infrastructure/confs/scaleway-01/fstab /etc/fstab
```
Edited fstab to add entries ([see commit 4ac8a7a33e](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commits/4ac8a7a33e4a183a2ebfdd36d3b83cbb7a7aea41)) .
Then:
```bash
systemctl daemon-reload
mount -a
```


## Setting up a test opff instance

We will do a test with opff instance,
where we will
* mount NFS mountpoints (so it will be on the live production data)
* clone the other volumes we need using the backups and mount them in the VM

We will change the configuration of openfoodfacts-server to point to the right IPs
for redis / memcached / postgres / mongodb.

Then we will need to setup NGINX reverse proxy to serve it on a specific domain.

We will keep the instance private because modifying some data but not others might leads to inconsistencies.

### Creating the container

To create the container I used ansible, promox-node site.
But I didn't use the configure job, as I will replace the root dir
with the one from off2.
See [proxmox - How to create a new container with ansible](../proxmox.md#how-to-create-a-new-container-with-ansible)

We create the container with a disk, but this disk will be throne away to replace with opff current disk (or a clone, while testing).

Note: We take the opportunity to also re-order container number.
So we will have:
- off - 111 (was 113)
- off-pro - 112 (was 114)
- obf - 113 (was 116)
- opf - 114 (was 117)
- opff - 115 (was 118)

### Creating CT and cloning the volumes

Here are the volumes we will need to clone (after reading `/etc/pve/lxc/118.conf` on off2, but removing datasets that are not used anymore)
- the root dir: `zfs-hdd/pve/subvol-118-disk-0`
- `zfs-hdd/opff`
- `zfs-hdd/opff/html_data`
- `zfs-hdd/opff/cache`


I now clone the original disk in place of the disk, and created the other clones:
```bash
# get last daily snapshot
declare -A snapshot
for dataset in zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-118-disk-0 zfs-hdd/off-backups/off2-zfs-hdd/opff{,/cache,/html_data}; \
do \
  snapshot[$dataset]=$(zfs list -t snap $dataset -o name|grep "_daily"|tail -n 1); \
done

pct shutdown 115
zfs destroy -r zfs-hdd/pve/subvol-115-disk-0

zfs clone ${snapshot["zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-118-disk-0"]} zfs-hdd/pve/subvol-115-disk-0

zfs create zfs-hdd/podata

for dataset in opff{,/cache,/html_data}; \
do \
  zfs clone ${snapshot["zfs-hdd/off-backups/off2-zfs-hdd/$dataset"]} zfs-hdd/podata/$dataset;
done
```

### Adding the mountpoints

Before we must add the mountpoints to the container.
I did it by editing `/etc/pve/lxc/115.conf` to add:
```
mp0: /zfs-hdd/podata/opff,mp=/mnt/opff
mp1: /zfs-hdd/podata/opff/cache,mp=/mnt/opff/cache
mp2: /zfs-hdd/podata/opff/html_data,mp=/mnt/opff/html_data
mp3: /mnt/nfs/off/products,mp=/mnt/opff/products
mp4: /mnt/nfs/off/images,mp=/mnt/opff/images
mp5: /mnt/nfs/off/users,mp=/mnt/opff/users
mp6: /mnt/nfs/off/orgs,mp=/mnt/opff/orgs
```

While `images` and `products` were not mounted under `/mnt/off` on off2,
we decided to mount them under `/mnt/opff` in the new container,
to be more coherent with what we did on `users` and `orgs`.

### User mapping

We need specific user mapping in the container, to keep ids above 1000 the same.

I edited the container creation role to support it.

It modified `/etc/pve/lxc/115.conf` to add:

```
lxc.idmap: u 0 100000 999
lxc.idmap: g 0 100000 999
lxc.idmap: u 1000 1000 64536
lxc.idmap: g 1000 1000 64536
lxc.cap.drop: "sys_rawio audit_read"
```
and added `root:1000:64536` to `/etc/subuid` and `/etc/subgid`

But for that to work I need to enable root to map such subid.

I modified the containers role to support for it.

## Setting up the reverse proxy

We have to setup the reverse proxy in `scaleway-proxy`

First we copy the certificates from off2-proxy to scaleway-proxy
(following https://charlesreid1.github.io/copying-letsencrypt-certs-between-machines.html)
On off2-proxy:
```bash
CONF=/etc/nginx/sites-enabled/openpetfoodfacts.org
DOM=$(sed -nr  "s|.*letsencrypt/live/(.*)/privkey.*|\1|p" $CONF)
echo "COPYING CERTS FOR $DOM in $DOM.tar.gz"
sudo tar -chvzf $DOM.tar.gz \
    /etc/letsencrypt/archive/${DOM} \
    /etc/letsencrypt/renewal/${DOM}.conf \
    /etc/letsencrypt/live/${DOM}
chmod go-rw $DOM.tar.gz
```
I then copied it to scaleway-proxy (using scp).
And on scaleway:
```bash
cd /
tar xzf /home/alex/
# verify
ls -l /etc/letsencrypt/*/openpetfoodfacts.org /etc/letsencrypt/renewal/openpetfoodfacts.org.conf
```

On scaleway-proxy
I copied the configuration from off2 reverse proxy in scaleway-proxy conf dir:
```bash
cd /opt/openfoodfacts-infrastructure/
# verify we have the log format conf
ls -l confs/scaleway-proxy/nginx/conf.d/log_format.conf
ls -l /etc/nginx/conf.d/log_format.conf
# copy needed configs
cp confs/off2-reverse-proxy/nginx/sites-enabled/openpetfoodfacts.org confs/scaleway-proxy/nginx/sites-enabled/
# link at system level
ln -s /opt/openfoodfacts-infrastructure/confs/scaleway-proxy/nginx/sites-enabled/openpetfoodfacts.org /etc/nginx/sites-enabled/
```
I also add to add some specific configs,
```bash
ln -s /opt/openfoodfacts-infrastructure/confs/scaleway-proxy/nginx/nginx.conf /etc/nginx/
ln -s /opt/openfoodfacts-infrastructure/confs/scaleway-proxy/nginx/conf.d/proxy_cache.conf /etc/nginx/conf.d/
```

I also edited openfoodfacts.org conf because
`listen 443 ... http2` is now deprecated in favour of `http2 on;`
And to substitute any occurrence of `10.1.0.118` for `10.13.1.115`.

## Testing

### Starting opff for testing

After discussion on the impact of the test instance of prod.

The new opff container on scaleway has separate volume for all but for users / orgs / products /images, where it uses the NFS mounts of production. It will also use same Mongo / Postgres and Redis as production.
Starting this instance in // with production, is safe because:
* products changes will impact the mongo of prod, so might not be a problem
* redis listener does not process global events, it might eventually conflict with opff --> shut down redis listener (but it's not a problem)
* daily feeds generally will create file on a separate filesystem, it adds a small loads 
* Also we will:
  * stop OCR service to avoid submitting images twice
  * stop the minion to avoid stilling production tasks

To stop the OCR and minion service, I will disable them,
an easy way to do that is to unlink them in `/etc/systemd/system/multi-user.target.wants`,
I can do this before starting the container, from `scaleway-01` host:

```bash
unlink /zfs-hdd/pve/subvol-115-disk-0/etc/systemd/system/multi-user.target.wants/cloud_vision_ocr@opff.service
unlink /zfs-hdd/pve/subvol-115-disk-0/etc/systemd/system/multi-user.target.wants/minion@opff.service
```

Note: As we are working on a clone of the system disk, no need to remove that afterwards,
at migration time, we will use the new opff snapshot.

We are ready to start the container: `pct start 115`

Note: in reality I had to run `pct start 115 --debug` to debug my errors before being ables to start it.

Then I `pct enter 115` to see if services are ok with `systemctl status apache2.service nginx.service redis_listener@opff.service`.

### Changing opff configuration

For opff to work in new environment we have to change its configuration,
in `srv/opff/lib/ProductOpener/Config2.pm` (in `/zfs-hdd/pve/subvol-115-disk-0/`)
we have to change services ips:
* 10.13.1.200 for mongodb / redis / postgresql
* 10.13.1.102 for memcached
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

I also changed `products` and `images` location as we moved them to `/mnt/opff`
(found using `find . -type l -print0|xargs -0 ls -l |grep -i mnt/off`)
```bash
cd /zfs-hdd/pve/subvol-115-disk-0/
unlink srv/opff/products
ln -s /mnt/opff/products srv/opff/products
unlink srv/opff/html/images/products
ln -s /mnt/opff/images/products srv/opff/html/images/products
# some strange old refs
unlink srv/obf/log.conf
unlink srv/obf/minion_log.conf
unlink srv/opf/new_images/1730024919.opf:84165435.search.2.jpg
rmdir srv/opf/new_images/
# remove old refs
for dirname in srv/{off,opf,obf}/{html/images/products,products}; \
do \
  unlink $dirname; \
done
rmdir mnt/off/users
rmdir mnt/off/orgs
for dirname in mnt/{off,opf,obf}/{images,products,} srv/{off,opf,obf}/{html/{images,},}; \
do \
  rmdir $dirname; \
done
```

### Testing the opff clone instance

I edited my `/etc/hosts` to add:
```
151.115.132.10 world.openpetfoodfacts.org fr.openpetfoodfacts.org static.openpetfoodfacts.org images.openpetfoodfacts.org
```
I will test sync between data using uk.openpetfoodfacts.org

I edited my user:
* if I change the country it does not change on the other part
* if I change the "team" field it changes succesfully
* editing a product worked
  * I can see changes on the current instance


TODO: gen feeds daily.

## migrating

### Steps to execute

1. [DONE] in OVH, change TTL of opff names to a lower TTL
1. [DONE] on scaleway-01 comment opff backups in /etc/sanoid/syncoid-args.conf
1. [DONE] on scaleway-01, stop the opff container: `pct shutdown 115`
1. [DONE] on scaleway-01, remove the clones:
   ```bash
   zfs destroy -r zfs-hdd/pve/subvol-115-disk-0
   zfs destroy -r zfs-hdd/podata/opff
   ```

Now we hurry:

1. [DONE] on off2, stop opff container `pct shutdown 118`
1. [DONE] on off2, create a last snapshot:
  ```bash
  # mimic sanoid
  SNAP_NAME=autosnap_$(date --utc +"%Y-%m-%d_%H:%M:%S")_hourly
  for dataset in zfs-hdd/pve/subvol-118-disk-0 zfs-hdd/opff{,/cache,/html_data}; \
  do \
    zfs snapshot $dataset@$SNAP_NAME; \
    echo DONE: $dataset@$SNAP_NAME; \
  done
  ```
1. [DONE] on scalway-01, make a last sync of datasets:
   ```bash
   syncoid --no-sync-snap --no-privilege-elevation scaleway01operator@off2.openfoodfacts.org:zfs-hdd/pve/subvol-118-disk-0 zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-118-disk-0
   syncoid --no-sync-snap --no-privilege-elevation --recursive scaleway01operator@off2.openfoodfacts.org:zfs-hdd/opff zfs-hdd/off-backups/off2-zfs-hdd/opff
   ```
   verify:
   ```bash
   zfs list -t snap zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-118-disk-0 |tail -n 1
   for dataset in opff{,/cache,/html_data}; \
   do \
     zfs list -t snap zfs-hdd/off-backups/off2-zfs-hdd/$dataset |tail -n 1; \
   done
1. [DONE] move the backup zfs to their new location:
    ```bash
    zfs rename zfs-hdd/off-backups/off2-zfs-hdd/pve/subvol-118-disk-0 zfs-hdd/pve/subvol-115-disk-0
    zfs rename zfs-hdd/off-backups/off2-zfs-hdd/opff zfs-hdd/podata/opff
    ```
1. [DONE] on scaleway-01, remove the opff/products,images datasets as they are useless
  and may conflict with the real mount we need in the container
  ```bash
  zfs destroy -r zfs-hdd/podata/opff/products
  zfs destroy -r zfs-hdd/podata/opff/images
  ```
1. [DONE] modify the configuration, as done above, [see Changing OPFF configuration](#changing-opff-configuration)
1. [DONE] on scaleway-01, start the service `pct start 115`
1. [DONE] on your computer, verify the service is working with a modified /etc/hosts
1. [DONE]in OVH, change the `openpetfoodfacts.org` `A` entry to point to `151.115.132.10`
1. [DONE] on your computer remove you /etc/hosts specific configuration and test again
1. [DONE] It's live !

After migration:
* [DONE] rename subvol-118 to avoid confusino
  ```bash
  zfs rename zfs-hdd/pve/subvol-118-disk-0 zfs-hdd/backups/subvol-118-disk-0
  ```
* [DONE] verify backups of the new datasets are done
  * remove the conflicting `zfs-hdd/off-backups/scaleway-01-pve/subvol-115-disk-0`
    backup, as we re-created it:
    `zfs destroy zfs-hdd/off-backups/scaleway-01-pve/subvol-115-disk-0`
    wait for next syncoid, and verify it's recreated:
    `zfs list zfs-hdd/off-backups/scaleway-01-pve/subvol-115-disk-0`
  * modify scaleway-03 config to save scaleway-01's `zfs-hdd/podata`
  * then after some time, verify it's working: `zfs list zfs-hdd/off-backups/scaleway-01-podata-hdd -r`
* [DONE] run the ansible:
  * container creation on scaleway-01:
    `ansible-playbook sites/proxmox-node.yml --tags containers -l scaleway-01`
  * jobs/configure for opff:
    `ansible-playbook jobs/configure.yml -l opff`
* [DONE] remove the backup datasets at ovh3
* [DONE]add backups of opff data from scaleway-01 on ovh3
* [DONE] put back the TTL for domain to a normal level

Later:
* on off2: remove the pct 118: `pct remove 118`

Note: while destroying `rpool/opff/products` on OVH3, I had:
```
cannot destroy snapshot rpool/opff/products@autosnap_2024-10-26_00:04:32_daily: dataset is busy
...
```
on different dataset, this because there were "holds" see https://openzfs.github.io/openzfs-docs/man/v2.0/8/zfs-hold.8.html. Those datasets had a hold with tag backup.
I just removed them all, with 
```bash
for SNAP in $(zfs list -t snap rpool/opff/products -o name|grep -v NAME); do zfs release backup $SNAP; done
```

## Annex

### opff configuration on off2:
```bash
cat /etc/pve/lxc/118.conf
  arch: amd64
  cores: 4
  features: nesting=1
  hostname: opff
  memory: 12288
  mp0: /zfs-hdd/opff,mp=/mnt/opff,replicate=0
  mp1: /zfs-hdd/obf/products/,mp=/mnt/obf/products
  mp10: /zfs-hdd/opf/products/,mp=/mnt/opf/products
  mp11: /zfs-hdd/opf/images,mp=/mnt/opf/images
  mp12: /zfs-hdd/off/orgs,mp=/mnt/opff/orgs
  mp2: /zfs-hdd/off/users,mp=/mnt/opff/users
  mp3: /zfs-hdd/obf/images,mp=/mnt/obf/images
  mp4: /zfs-hdd/opff/html_data,mp=/mnt/opff/html_data
  mp5: /zfs-hdd/opff/cache,mp=/mnt/opff/cache
  mp6: /zfs-nvme/off/products,mp=/mnt/off/products
  mp7: /zfs-hdd/off/images,mp=/mnt/off/images
  mp8: /zfs-hdd/opff/products,mp=/mnt/opff/products
  mp9: /zfs-hdd/opff/images,mp=/mnt/opff/images
  net0: name=eth0,bridge=vmbr1,firewall=1,gw=10.0.0.2,hwaddr=1A:01:25:5B:5F:7C,ip=10.1.0.118/  24,type=veth
  onboot: 1
  ostype: debian
  protection: 1
  rootfs: zfs-hdd:subvol-118-disk-0,size=30G
  swap: 0
  unprivileged: 1
  lxc.idmap: u 0 100000 999
  lxc.idmap: g 0 100000 999
  lxc.idmap: u 1000 1000 64536
  lxc.idmap: g 1000 1000 64536
  lxc.cap.drop: "sys_rawio audit_read"
```


We don't need a lot of the mount points, and will evict them.
We just create the container, 


