# 2024-09-02 OFF server double apache

## Goal

We experience latency problems on Open Food Facts because the Apache instance is busy processing long requests (facets / searches / etc.).

We can't prioritize requests based on URL in Apache2 (or dedicate workers).

We will setup a second Apache instance which will only serve certain requests:

* Product read (api or not)
* root page for every country
* product writes (api or not)

The rest of the requests will be handled by the other apache2 server.

## Reflection on how to setup the new apache2 instance

On debian, apache2 is managed by systemd. There is:
* a default `apache2.service` service definition, using /etc/apache2/ configuration directory
* and an `apache2@<instance>.service` definition which use /etc/apache2.%i/ configuration directory (where %i is the instance name)

Both use the apache2ctl script to start apache2.
So we can use APACHE_ARGUMENTS to add arguments to httpd daemon program,
and this can be used to add -D arguments to add variables.

Here we want to create a second apache2 instance where the only differences are:
* the port apache2 is listening on
* the log file names

For the log file names, we will modify startup_apache2.pl to use environment variable to get the log configuration file.

For ports, we need to modify ports.conf file to use a variable that we will give thanks to a -D option to apache2 with APACHE_ARGUMENTS variable.

To be more consistent, we will drop the `apache2.service` instance and use two new instances:
* apache2@standard.service - for product read, root pages and product writes
* apache2@priority.service - for the rest

## Doing it in Product-Opener

See https://github.com/openfoodfacts/openfoodfacts-server/pull/10766

## Installation / Migration

1. checkout the new release / code
1. change ports .conf link: `unlink /etc/apache2/ports.conf; ln -s /srv/opf/conf/apache-2.4/ports.conf /etc/apache2/`
2. symlink /srv/$SERVICE/conf/systemd/apache2@.service.d to /etc/systemd/system/
1. systemctl daemon-reload
2. symlink `ln -s /etc/apache2 /etc/apache2-priority; ln -s /etc/apache2 /etc/apache2-standard`
2. symlink `ln -s /var/log/apache2 /var/log/apache2-priority; ln -s /var/log/apache2 /var/log/apache2-standard`
2. enable the apache2@standard.service apache2@priority.service
2. start apache2@priority.service
2. and test it's working using `curl http://127.0.0.1:8002/display.pl -H "Host: world.openfoodfacts.org"`
  `curl http://127.0.0.1:8002/display.pl?api/v2/product/3017620422003/ -H "Host: world.openfoodfacts.org"`
2. check nginx configuration is ok (`nginx -t`) and restart the service
3. check both apache2 are working:
   * `curl http://127.0.0.1/ -H "Host: world.openfoodfacts.org"`
   * `curl http://127.0.0.1/discover -H "Host: world.openfoodfacts.org"`
2. stop apache2.service
2. start apach2@standard.service
3. test it's working using curl commands above and using your browser
1. deactivate  apache2.service
1. unlink the /etc/systemd/system/apache2.service
1. unlink /srv/$SERVER_NAME/log.conf

Celebrate !

## Test installation

### Creating a test container

I first try to test my process on opf, but did fail (maybe because of a specific hostname at that time).
So I decided to first try on a test instance, I will use opf to avoid using too much memory.

So I first created a new container opf-test as 130 looking like opf (see options below).

I removed the created volume and replaced by a clone of opf volume
at a specific snapshot.
```bash
zfs snapshot zfs-hdd/pve/subvol-117-disk-0@2025-08-01-for-opf-test-clone
zfs clone zfs-hdd/pve/subvol-117-disk-0@2025-08-01-for-opf-test-clone zfs-hdd/pve/subvol-130-disk-0-clone-from-117
zfs destroy zfs-hdd/pve/subvol-130-disk-0
zfs destroy -r zfs-hdd/pve/subvol-130-disk-0
```

I then edited lxc file to
- change the volume name
- add mount points
- add idmap rules
- drop capabilities
resulting in:
```
arch: amd64
cores: 4
features: nesting=1
hostname: opf-test
memory: 6000
net0: name=eth0,bridge=vmbr1,firewall=1,gw=10.0.0.2,hwaddr=D2:BC:21:00:36:00,ip=10.1.0.130/24,type=veth
ostype: debian
rootfs: zfs-hdd:subvol-130-disk-0-clone-from-117,mountoptions=noatime,size=30G
swap: 6000
unprivileged: 1
mp0: /zfs-hdd/opf,mp=/mnt/opf
mp1: /zfs-hdd/obf/products/,mp=/mnt/obf/products
mp10: /zfs-hdd/opf/products/,mp=/mnt/opf/products
mp11: /zfs-hdd/opf/images,mp=/mnt/opf/images
mp12: /zfs-hdd/off/orgs,mp=/mnt/opf/orgs
mp2: /zfs-hdd/off/users,mp=/mnt/opf/users
mp3: /zfs-hdd/obf/images,mp=/mnt/obf/images
mp4: /zfs-hdd/opf/html_data,mp=/mnt/opf/html_data
mp5: /zfs-hdd/opf/cache,mp=/mnt/opf/cache
mp6: /zfs-nvme/off/products,mp=/mnt/off/products
mp7: /zfs-hdd/off/images,mp=/mnt/off/images
mp8: /zfs-hdd/opff/products,mp=/mnt/opff/products
mp9: /zfs-hdd/opff/images,mp=/mnt/opff/images
lxc.cap.drop: "sys_rawio audit_read"
lxc.idmap: u 0 100000 999
lxc.idmap: g 0 100000 999
lxc.idmap: u 1000 1000 64536
lxc.idmap: g 1000 1000 64536
```

I can then start the container.

### tweaking configuration

I will tweak the env directory because hostname mistmatch.
```bash
sudo mkdir /srv/opf-test
sudo chown off /srv/opf-test
sudo -u off bash
mkdir /srv/opf-test/env
ln -s /srv/opf/env/env.opf /srv/opf-test/env/env.opf-test
ln -s /srv/opf/env/env.opf.priority /srv/opf-test/env/env.opf-test.priority
ln -s /srv/opf/env/env.opf.standard /srv/opf-test/env/env.opf-test.standard
ls /srv/opf-test/env
exit
```

I then deploy my new version of product opener.
(following deploy procedure above),
but just after updating product opener, I did the following:
1. create /srv/opf/env/env.opf.priority with right content
2. create /srv/opf/opf-priority-log.conf with right content
3. edited the nginx module to have same setting as for off
   `conf/nginx/sites-available/opf`
   ```diff
15a16,27
> map $uri $apache_port {
>       default 8001;
> 
>       # home pages
>       "~*^/$" 8002;
>       # product read / write
>       "~*^/(mountaj|m\xc9\x99hsul|\xd0\xbf\xd1\x80\xd0\xbe\xd0\xb4\xd1\x83\xd0\xba\xd1\x82|gynnyrc
h|produkt|product|product|product|produkto|producto|toode|produkto|produit|produto|term\xc3\xa9k|pro
duk|\xe8\xa3\xbd\xe5\x93\x81|afaris|\xd3\xa9\xd0\xbd\xd1\x96\xd0\xbc|\xec\x83\x9d\xec\x84\xb1\xeb\xa
c\xbc|berhem|\xe0\xa4\x89\xe0\xa4\xa4\xe0\xa5\x8d\xe0\xa4\xaa\xe0\xa4\xbe\xe0\xa4\xa6\xe0\xa4\xa8|pr
oduk|produkt|\xe0\xa4\x89\xe0\xa4\xa4\xe0\xa5\x8d\xe0\xa4\xaa\xe0\xa4\xbe\xe0\xa4\xa6\xe0\xa4\xa8|pr
oduct|product|product|produkt|produkt|produit|produto|produto|produto|\xd0\xbf\xd1\x80\xd0\xbe\xd0\x
b4\xd1\x83\xd0\xba\xd1\x82|product|proizvod|produkto|\xc3\xbcr\xc3\xbcn|\xd0\xbf\xd1\x80\xd0\xbe\xd0
\xb4\xd1\x83\xd0\xba\xd1\x82|\xe4\xba\xa7\xe5\x93\x81|\xe7\x94\xa2\xe5\x93\x81|\xe7\x94\xa2\xe5\x93\
x81)/.*" 8002;
>       "~*^/cgi/product.pl/.*" 8002;
>       # product API read / write
>       "~*^/api/v./product/.*" 8002;
> }
> 
128c140
<       proxy_pass http://127.0.0.1:8001/cgi/display.pl?;
---
>       proxy_pass http://127.0.0.1:$apache_port/cgi/display.pl?;
139c151
<       proxy_pass http://127.0.0.1:8001;
---
>       proxy_pass http://127.0.0.1:$apache_port;
   ```

Also to test, I did the following:
* test apache priority:  
  `curl "http://127.0.0.1:8002/cgi/display.pl" -H "Host: world.openproductsfacts.org"`  
  `curl "http://127.0.0.1:8002/cgi/display.pl?api/v2/product/4018833954960" -H "Host: world.openproductsfacts.org"`
* test apache standard:
  `curl "http://127.0.0.1:8002/cgi/display.pl?/categories" -H "Host: world.openproductsfacts.org"`  

* test nginx:
  `curl "http://127.0.0.1/" -H "Host: world.openproductsfacts.org"`  
  `curl "http://127.0.0.1/api/v2/product/4018833954960" -H "Host: world.openproductsfacts.org"`  
  `curl "http://127.0.0.1/categories" -H "Host: world.openproductsfacts.org"`  


## Testing

To test I did simply use the request above and see which apache2 is logging.
as they log in different files.


**FIXME:** modify doc explaining off installation


