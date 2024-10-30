# 2024-10-30 keycloak container install

We want to deploy keycloak and test it in production.

We would like to do it on a copy container of OPFF.
So we want to deploy it on a CT (yes we are trying again docker in CT)

I will thus closely follow [2024-04 install off-query on off1](./2024-04-12-install-off-query-off1.md)


## Adding overlay kernel module on off1

Was already [done for off-query](./2024-04-12-install-off-query-off1.md#adding-overlay-kernel-module-on-off1)

## Creating the container

Created a container following usual steps on [creating a container](../proxmox.md#how-to-create-a-new-container)

I used:
* number 104
* debian 11 image
* hostname "keycloak"
* template debian 11
* storage:
  * root disk of 40Gb with noatime
  * mp0 of 50G on SSD mounted on /var/lib/docker/volumes with noatime
* 6GB RAM - 0 swap
* 4 vCPU

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
pct set 104 -feature nesting=1,keyctl=1
```
and reboot:
```bash
pct stop 104
pct start 104
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

On my computer, a private key:
```bash
ssh-keygen -t ed25519 -C "off@off-keycloak-org" -f off-keycloak-org-ssh-key
```
And put the key content in our keepassX file as an attachment while removing the file from the hard drive.

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

## Create an account for John

I created a new account for John on the container following [proxmox - how to create a user in a Container or VM](../proxmox.md#how-to-create-a-user-in-a-container-or-vm)

## Prepare keycloak install

In github settings / environment I created my temporary environment `off-auth-org` and added the SSH_PRIVATE_KEY.

I let John manage the rest.

## Setup reverse proxy

**TODO**

## setup ZFS sync

Because my volumes are regular PVE volumes, I had nothing to do.
I just checked they already have snapshots on off1, and are replicated on off2 and ovh3.

```bash
# off1
zfs list -t snap zfs-hdd/pve/subvol-104-disk-0
zfs list -t snap zfs-nvme/pve/subvol-104-disk-0
```

```bash
# off2
zfs list -t snap zfs-hdd/off-backups/off1-pve/subvol-104-disk-0
zfs list -t snap zfs-hdd/off-backups/off1-pve-nvme/subvol-104-disk-0
```

```bash
# ovh3
zfs list -t snap rpool/off-backups/off1-pve/subvol-104-disk-0
zfs list -t snap rpool/off-backups/off1-pve-nvme/subvol-104-disk-0
```
