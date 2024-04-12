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

Then I ensured off1 user exists on off1 with nologin as shell
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
I just checked they already have snapshots on off1, and are replicated on off2 and ovh3.

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

## Moving data

**TODO**

## Moving domain name

**TODO:**
* change DNS CNAME entry
* generate certificates with certbot and change config back to normal

