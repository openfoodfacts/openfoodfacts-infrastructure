# 2026-09-23 temporarily moving images to scaleway-03

We have very big latency problem on ks1 serving images.openfoodfacts.org.

Moreover, ks1 images is not up-to-date anymore since end of july,
due to a bad manipulation that removed snapshots that syncoid was relying upon.
As the disk space is not enough on ks1, we can't start a new zfs sync along the current one,
so we are doomed to switch to another server.
(Also we knew ks1 to be under-sized anyway).

We want to move images.openfoodfacts.org to scaleway-05 (previously off2, moved to scaleway),
but we first need to set it up to be in the cluster, and upgrade its proxmox version.

## Creating the CT

I created a container for the images reverse-proxy, following [Proxmox / how to create a new container with ansible](../explanation/proxmox.md#how-to-create-a-new-container-with-ansible)

### mounting images

We need to mount images in the container,

I logged inside the CT to `mkdir /mnt/off/images`

Note that I must have a folder named `images`
because the url of images starts with `images/products/...`

and I did edit `/etc/pve/lxc/116.conf` on `scaleway-03` to add the:
```ini
mp0: /zfs-hdd/off-backups/scaleway-01-podata-hdd/images,mp=/mnt/off/images
```
then on the host: `pct stop 116 && pct start 116`

## Reverse proxy install

### Configurations

I created `confs/scaleway-images-tmp`  and added needed `nginx` and `fail2ban` file and folders.

I added a public ipv6 to the container, for ipv4 we will need NATing through the revers proxy.

Consequently, in the CT variables, I also put `iptables_public_ports: [22, 80, 443]`

### Running ansible for reverse proxy


After some modifications of ansible to verify fail2ban rules, I did run:

```
ansible-playbook sites/reverse-proxy.yml -l scaleway-images-tmp
```

I stumbled on a problem during nginx installation.
The post-install script was failing on a chown command.
Looking at the script it was a `chown nginx:adm /var/log/nginx/access.log`.
In fact this was the `chown nginx` which was not working.
In some way the chown to id 999 was not possible.
It was due to an error in container idmapping.
We wrote a mapping with:
```ini
lxc.idmap: u 0 100000 999
lxc.idmap: g 0 100000 999
lxc.idmap: u 1000 1000 64536
lxc.idmap: g 1000 1000 64536
```
but the first two line, don't cover id 999,
so it should be:
```ini
lxc.idmap: u 0 100000 1000
lxc.idmap: g 0 100000 1000
lxc.idmap: u 1000 1000 64536
lxc.idmap: g 1000 1000 64536
```
I fixed that in `/etc/pve/lxc/116.conf` (and in the ansible variables).

### Testing it

I can test on the CT 116 itself:

```bash
curl --connect-to images.openfoodfacts.org:443:10.13.1.116:443 \
  https://images.openfoodfacts.org/images/products/628/703/571/3790/1.400.jpg \
  -o /tmp/1.400.jpg

# verify
md5sum /tmp/1.400.jpg /mnt/off/images/products/628/703/571/3790/1.400.jpg
```

```bash
curl --connect-to images.openfoodfacts.org:443:[2001:bc8:c025:11:116::]:443 \
  https://images.openfoodfacts.org/images/products/628/703/571/3790/1.400.jpg \
  -o /tmp/1.400.jpg

# verify
md5sum /tmp/1.400.jpg /mnt/off/images/products/628/703/571/3790/1.400.jpg
```


I can test the ip4 service on my machine, even before NATing,
by:
* changing my `/etc/hosts` to add:
  ```
  127.0.0.1 images.openfoodfacts.org
  ```
* setting up a stunnel:
  ```bash
  # sudo + SSH_AUTH_SOCK preserve
  sudo SSH_AUTH_SOCK=${SSH_AUTH_SOCK} ssh -J alex@scaleway-03.infra.openfoodfacts.org -L 443:127.0.0.1:443 alex@10.13.1.116
  ```
and querying https://images.openfoodfacts.org/images/products/628/703/571/3790/1.400.jpg

I can also test ip6 access:
* changing my `/etc/hosts` to add:
  ```
  2001:bc8:c025:11:116:: images.openfoodfacts.org
  ```
and using
`curl -6 https://images.openfoodfacts.org/images/products/628/703/571/3790/1.400.jpg`


## Setting up the NAT

To setup the NAT, I just added the corresponding values for
`iptables__enable_ip_forward_v4` and `iptables_extra_rules_nat_v4`
in `ansible/host_vars/scaleway-03/iptables.yml`

```
iptables__enable_ip_forward_v4: true

iptables_extra_rules_nat_v4:
  "001 - Forward http request to scaleway-images-tmp": >-
    -A PREROUTING -p tcp -d 151.115.132.13 --dport 80 -j DNAT --to-destination 10.13.1.116:80
  "002 - Forward https request to scaleway-images-tmp": >-
    -A PREROUTING -p tcp -d 151.115.132.13 --dport 443 -j DNAT --to-destination 10.13.1.116:443
```

And then
```bash
ansible-playbook jobs/configure.yml -l scaleway-03 --tags iptables
```

### Testing it

This is as simple adding a line in `/etc/hosts` with:
```
151.115.132.13 images.openfoodfacts.org
```

Or, as contributed by Freso, if you use [Unbound](https://www.nlnetlabs.nl/projects/unbound/about/), you can use this config:
```
local-zone: "images.openfoodfacts.org" redirect
local-data: "images.openfoodfacts.org A 151.115.132.13"
```
or, as contributed by Nitro, with chromium (or brave):
```
brave-browser --host-resolver-rules="MAP images.openfoodfacts.org 151.115.132.13"
```
and then accessing images.

Or with curl:
```bash
curl --connect-to images.openfoodfacts.org:443:151.115.132.13:443 \
  https://images.openfoodfacts.org/images/products/628/703/571/3790/1.400.jpg \
  -o /tmp/1.400.jpg
# and maybe, on linux:
xdg-open /tmp/1.400.jpg
```

## Adding ip to product opener configuration

I had to update the rule that redirect images url to images server,
so that it does an exception for our new server
(otherwise we can't fetch new images from the source server).

see https://github.com/openfoodfacts/openfoodfacts-server/pull/14697

## Changing DNS

Finally I changed the DNS zone using OVH console,
to have `images.openfoodfacts.org` be a `CNAME` to `scaleway-03.infra.openfoodfacts.org`

I can monitor the impact of the change looking at:
https://www.computel.fr/munin/openfoodfacts/sc3.openfoodfacts/index.html