# 2024-04 install off-query on off1

I want to install in a unpriviledge LXC container and will follow https://du.nkel.dev/blog/2021-03-25_proxmox_docker/

## Adding overlay kernel module on off1

* check modules overlay (not aufs as it is deprecated)

```bash
grep -r "overlay" /etc/modules-load.d/
lsmod|grep "overlay"
```
both return nothing, so we add to load it.
```bash
$ modprobe overlay
$ lsmod|grep overlay
overlay               147456  0
$ vim /etc/modules-load.d/modules.conf
...
overlay
...
```

## Creating the container

Created a container following usual steps on [creating a container](../proxmox.md#how-to-create-a-new-container)

I used:
* number 115
* hostname "off-query"
* template debian 11
* storage: root disk of 40Gb and a mp0 of 200G mounted on /var/lib/docker/volumes
* 32GB RAM
* 12 vCPU

I did the post install and create user off with adduser.

## Preparing for docker in container


In the container, I removed the systemd-networkd service: `systemctl stop systemd-networkd && systemctl disable systemd-networkd`

as proxmox [documentation on Linux Containers config](https://pve.proxmox.com/wiki/Linux_Container) mentions about `keyctl` activation:

>  keyctl=<boolean> (default = 0)
>
> For unprivileged containers only: Allow the use of the keyctl() system call. This is required to use docker inside a container. By default unprivileged
> containers will see this system call as non-existent. This is mostly a workaround for systemd-networkd, as it will treat it as a fatal error 
> when some keyctl() operations are denied by the kernel due to lacking permissions. Essentially, you can choose between running systemd-networkd or docker.

I then added the `keyctl=1` options (not able to do it in web admin, in Options > Features, so I did it with the CLI):
```bash
pct set 115 -feature nesting=1,keyctl=1
```
and reboot:
```bash
pct stop 115
pct start 115
```

## Installing docker

In the container:
1. Installed docker.io ([official doc](https://docs.docker.com/engine/install/debian/#install-using-the-repository))
   ```bash
   apt install ca-certificates curl
   install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
   chmod a+r /etc/apt/keyrings/docker.asc
   echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   # verify
   cat /etc/apt/sources.list.d/docker.list
   apt update
   apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   docker run hello-world
   ```

2. install make : `apt install make` (needed for deployments)

3. added user off to docker group:
   ```bash
   adduser off docker
   ```

## Prepare for off SSH connections

Created a private key: `ssh-keygen -t ed25519 -C "off@off-query-org" -f off-query-org-ssh-key`
And put the key content in our keepassX file as an attachment while removing the file from my hard drive.

Then I ensured off user exists on off1 with nologin as shell
```bash
$ cat /etc/passwd |grep off
off:x:1000:1000:OFF user,,,:/home/off:/usr/sbin/nologin
...
```

On off1 and in the container I added the public key in authorized_keys for user off.
```bash
mkdir /home/off/.ssh
vim /home/off/.ssh/authorized_keys # and paste the public key there
chown -R off:off  /home/off/.ssh
chmod go-rwx -R /home/off/.ssh
```

## Install off-query

In github settings / environment I created my temporary environment `off-query-new-org` and added the SSH_PRIVATE_KEY secret
as well as a random POSTGRES_PASSWORD.

I then cloned the repo.
I made a [new branch deploy-new-ct](https://github.com/openfoodfacts/openfoodfacts-query/pull/40) and modify the container-deploy workflow,
with a new (temporary) "off-query-new-org" environment and right settings for new container.

I then just push my branch to trigger the action.

After some iterations, it's deploying.

## Setup reverse proxy

I setup the reverse proxy on off2 to [configure a new service](../nginx-reverse-proxy.md#configuring-a-new-service)
copying the file we have on ovh1 reverse proxy, but adding a -tmp to certificates names, and copying corresponding certs from ovh1 reverse proxy and add them with "-tmp" suffix, and changing proxying ip !

I can test it from the reverse proxy with: `curl 10.1.0.115:5511/health`.

I can test it from my machine using my `/etc/hosts` with `213.36.253.214  query.openfoodfacts.org`, and then https://

## setup ZFS sync

Because my volumes are regular PVE volumes, I had nothing to do.
I just checked they already have snapshots on off1, and are replicated on off2 and ovh3.

```bash
# off1
zfs list -t snap zfs-hdd/pve/subvol-115-disk-{0,1}
...
zfs-hdd/pve/subvol-115-disk-0@autosnap_2024-04-12_16:00:11_hourly    186K      -     1.33G  -
...
zfs-hdd/pve/subvol-115-disk-1@autosnap_2024-04-12_16:00:12_hourly   1.23M      -     27.3M  -
```

```bash
# off2
zfs list -t snap zfs-hdd/off-backups/off1-pve/subvol-115-disk-{0,1}
```

```bash
# ovh3
zfs list -t snap rpool/off-backups/off1-pve/subvol-115-disk-{0,1}
```

## Testing it's working


In the container itself:
```bash
curl http://10.1.0.115:5511/health
# {"status":"ok","info":{"postgres":{"status":"up"},"mongodb":{"status":"up"}},"error":{},"details":{"postgres":{"status":"up"},"mongodb":{"status":"up"}}}
```

In the reverse proxy container:
```bash
curl http://10.1.0.115:5511/health
# {"status":"ok","info":{"postgres":{"status":"up"},"mongodb":{"status":"up"}},"error":{},"details":{"postgres":{"status":"up"},"mongodb":{"status":"up"}}}
```

From my computer:
```bash
$ curl https://proxy2.openfoodfacts.org/health -H "Host: query.openfoodfacts.org"
{"status":"ok","info":{"postgres":{"status":"up"},"mongodb":{"status":"up"}},"error":{},"details":{"postgres":{"status":"up"},"mongodb":{"status":"up"}}}
}}}
```

## Moving data

There was nothing to do !
Upon start, our new instance did see it have an empty data and started getting data from MongoDB,
and then plugged to the redis stream.

After two day it's ok.

## Moving domain name

On off container, `QUERY_URL` is defined in `Config2.pm` using the domain name.

So to test it's ok, I first edit `/etc/hosts` on off container !
```conf
# TESTING off-query new instance
213.36.253.214 query.openfoodfacts.org
```
And goes to https://world.openfoodfacts.org/allergens

It works.

I then go to OVH console to change query CNAME from `proxy1.openfoodfacts.org` to `proxy2.openfoodfacts.org`.

After verifying name propagated to configured DNS on off `dig query.openfoodfacts.org @213.36.253.10`
I removed my line in `/etc/hosts`


### Regenerating certificate with certbot

On free reverse proxy:
```bash
certbot certonly -d "query.openfoodfacts.org"  --nginx
```
Does not work and ends with `live directory exists for query.openfoodfacts.org`.

So I did:
```bash
mv /etc/letsencrypt/live/query.openfoodfacts.org{,-old} 
# edit nginx conf to use this directory
vim /etc/nginx/sites-enabled/query.openfoodfacts.org
...
    ssl_certificate /etc/letsencrypt/live/query.openfoodfacts.org-old/fullchain-tmp.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/query.openfoodfacts.org-old/privkey-tmp.pem; # managed by Certbot
...
# restart nginx
nginx -t
systemctl reload nginx
```

Now I can run:
```bash
certbot certonly -d "query.openfoodfacts.org"  --nginx
```

Finally I manually changed `/etc/nginx/sites-enabled/query.openfoodfacts.org` to point to new certifcates:

```conf
    ssl_certificate /etc/letsencrypt/live/query.openfoodfacts.org-0001/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/query.openfoodfacts.org-0001/privkey.pem; # managed by Certbot
```

```bash
nginx -t
systemctl reload nginx
```

## IMPORTANT POST Install fix

Open Food Facts Produc Opener instance was using off-query public address to access the service.
But due to a limitation on routing in proxmox,
[we can't access services hosted on same proxmox cluster using the off2 reverse proxy](../nginx-reverse-proxy.md#never-call-an-internal-service-using-reverse-proxy).

So in fact Product Opener was expecting a response that did not came, until timeout.
This had the bad side effect of monopolizing workers…

The fix was to change in Config2.pm,
`$query_url="https://query.openfoodfacts.org";`
to `$query_url = "http://10.1.0.115:5511";`


## Removing old install

After moving, I did a `docker compose down` on the container VM where the old install was.

After some time, seeing all was ok in production, I just did a `docker compose down -v`.

I then renamed the folder, (to avoid confusions).

I also restored values of envs in my PR, and merged it.

I removed the temporary env in github configuration and changes secrets for off-query-org.

