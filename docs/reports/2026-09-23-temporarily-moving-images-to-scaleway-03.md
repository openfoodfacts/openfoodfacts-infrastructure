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

I logged inside the CT to `mkdir /mnt/off-images`

and I did edit `/etc/pve/lxc/116.conf` on `scaleway-03` to add the:
```ini
mp0: /zfs-hdd/off-backups/scaleway-01-podata-hdd/images,mp=/mnt/off-images
```
then on the host: `pct stop 116 && pct start 116`

## Reverse proxy install

### Configurations

I created `confs/scaleway-images-tmp`  and added needed `nginx` and `fail2ban` file and folders.

### Running ansible for reverse proxy

After some modifications, I did run:

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

```
curl --connect-to images.openfoodfacts.org:443:127.0.0.1:443 \
  https://images.openfoodfacts.org/images/products/628/703/571/3790/1.400.jpg \
  -o /tmp/1.400.jpg
```

I can test the service, even before NATing,
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

