# 2025-11-27 Moving keycloak to scaleway

Keycloak is currently on off1.

We want to move it to scaleway-01.

It is currently using docker compose, running on a CT on proxmox.

As they have been recent problem with this approach on Proxmox 9.1,
I prefer to go for a VM as recommended by Proxmox.
Also now that we have VirtioFS enabling direct write to ZFS Datasets,
one important drawback is removed.

## Creating a template VM on scaleway-02

We need a template VM to create our VM.

Following what we did on hetzner.

```bash
cd /home/alex
# navigate from https://cloud.debian.org/images/cloud to retrieve the name
wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
apt install -y libguestfs-tools dhcpcd-base
virt-customize -a debian-13-generic-amd64.qcow2 --update
virt-customize -a debian-13-generic-amd64.qcow2 --install qemu-guest-agent

# create the VM
qm create 998 --name debian12-cloudinit --net0 virtio,bridge=vmbr10 --scsihw virtio-scsi-single

# add the disk, using zfs-hdd/pve
qm set 998 --scsi0 zfs-hdd-pve:0,iothread=1,backup=off,format=qcow2,import-from=/home/alex/debian-13-generic-amd64.qcow2
# set boot
qm set 998 --boot order=scsi0
# set some physical values
qm set 998 --cpu host --cores 2 --memory 4096
# add cloudinit
qm set  998 --ide2 local:cloudinit
# set qemu agent
qm set 998 --agent enabled=1
# make it a template
qm template 998
```

## Creating the VM for docker on scaleway-02


### Creating the VM

I use the Template VM to create my VM:

- Target node: scaleway-02
- VM ID: 200
- Name: scaleway-docker-prod
- Mode: full-clone
- Target storage: zfs-hdd-pve

I tweak configuration to:
- start at boot
- enable protection
- change cloudinit to:
  - user: config-op
  - password: *****
  - ssh public keys: I took part of the content of /root/.ssh/authorized_keys on scaleway-02
  - IPConfig: IP: 10.13.1.200/16 and Gateway: 10.13.0.2

In ansible/ folder I:
- add the VM to the inventory.
  ```
  scaleway-docker-prod proxmox_vm_id=200 proxmox_node="scaleway-02"
  ```
  and add it to the `scaleway_vms` group
- create `host_vars/scaleway-docker-prod/scaleway-docker-prod-secrets.yml`
  and add the `ansible_become_password` inside (using the same password as in cloudinit)

I will run the jobs/configure recipe after having configure virtio-fs.

### Configuring virtio-fs

I configure virtio-fs using ansible.

At the moment, keycloak does not have any docker volume (it's only using the distant postgres).

Nonetheless, I will add docker volumes virtiofs
mapping on zfs-hdd for now.

I edited `proxmox_node__zfs_filesystems` in `host_vars/scaleway-02/proxmox.yml` to add `zfs-hdd/virtiofs/qm-200/docker-volumes` and its parents, adding posix acl type to `zfs-hdd/virtiofs`.

And edited `virtiofs__dir_mappings` in `group_vars/pvescaleway/proxmox.yml` to add the virtiofs mapping.

I can then run:

```bash
ansible-playbook sites/proxmox-node.yml -l scaleway-02 --tags zfs,virtiofs
```

### Adding virtiofs volume to our VM

I edited manually the VM to add the VIRTIOFS device:
- in hardware, add virtiofs
- directory id: qm-200-virtiofs-docker-volumes
- enable posix acl
- do not enable direct IO (would slow it down)

The corresponding string is: `qm-200-virtiofs-docker-volumes,expose-acl=1`

### Resizing partition

I need to resize the VM disk which is small from 3G to 24G
(to account for the space of docker images).

On the host:`qm resize 200 scsi0 +21G`

On the VM:
```bash
parted /dev/sda
  Warning: Not all of the space available to /dev/sda appears to be used, you can fix the GPT to use
  all of the space (an extra 44040192 blocks) or continue with the current setting? 
  Fix/Ignore? fix
  (parted) p
  Model: QEMU QEMU HARDDISK (scsi)
  Disk /dev/sda: 50331648s
  Sector size (logical/physical): 512B/512B
  Partition Table: gpt
  Disk Flags:
  Number  Start    End       Size      File system  Name  Flags
  14      2048s    8191s     6144s                        bios_grub
  15      8192s    262143s   253952s   fat16              boot, esp
  1      262144s  6289407s  6027264s  ext4
  (parted) resizepart 1 50329601s
  Warning: Partition /dev/sda1 is being used. Are you sure you want to continue?
  Yes/No? y
  (parted) quit
resize2fs /dev/sda1
  resize2fs 1.47.2 (1-Jan-2025)
  Filesystem at /dev/sda1 is mounted on /; on-line resizing required
  old_desc_blocks = 1, new_desc_blocks = 3
  The filesystem on /dev/sda1 is now 6258432 (4k) blocks long.
df -h /
  Filesystem      Size  Used Avail Use% Mounted on
  /dev/sda1        24G  2.5G   20G  12% /
```

**Note** that, because of the start of the partition `6289407 mod 2048 == 1`,
we had to take `50331648s - 2047` for the end, so that partition length is aligned. [^alignment]

[^alignment]: https://pieterbakker.com/optimal-disk-alignment-with-parted/ is a good resource to understand alignment.

## Setting up stunnel to connect to Postgres on off2

We will need to connect to postgres currently on off2 in a secure way.

To make things easy we will use stunnel.

### Configuring stunnel server side on off2 proxy

I changed config of off2 proxy to add an entry for postgres:
```ini
[OffPostgres]
client = no
accept = 5432
connect = 10.1.0.120:5432
ciphers = PSK
PSKsecrets = /etc/stunnel/psk/postgres-psk.txt
```
in `postgres-psk.txt` I added a key (generated with `pwgen 32`) with user scaleway-02.

Tested the config with `stunnel /etc/stunnel/off.conf`.

Restarted the service: `systemctl restart stunnel@off.service && systemctl status stunnel@off.service`

Test it's ok: `nc -v 127.0.0.1 5432`

Edited `/etc/nftables.conf.d/001-off2-reverse-proxy.conf` to add port 5432 to `STUNNEL_PORTS`,
and to add scaleway address ranges `151.115.132.0/27` to `OFF_SERVERS`.
Then I `sudo systemctl reload nftable`.

I can now test nc access from scaleway-02:
```bash
nc -vz 213.36.253.214 5432
off2-2.free.org [213.36.253.214] 5432 (postgresql) open
```

### Configuring stunnel client side on scaleway-02

We have to create a container running stunnel in client mode.

So first we create the CT, for this I edited the scaleway-02 host_vars proxmox.yml
to add an entry to `proxmox_containers__containers`,
add my container in inventory as well as its secret [as stated in Proxmox / How to cerate a new container with ansible](../proxmox.md#how-to-create-a-new-container-with-ansible).
and then run:
```bash
ansible-playbook sites/proxmox-node.yml -l scaleway-02 --tags containers
```

and then:

```bash
ansible-playbook jobs/configure.yml -l scaleway-stunnel-client
```

Note: we don't have to add ports of stunnel in iptables config
because, by default, internal address are whitelisted
and our stunnel client is to be accessed only from the private network.

Now we use the stunnel-client playbook.

I launched:
```bash
ansible-playbook sites/stunnel-client.yml -l scaleway-stunnel-client
```
(In reality there were debugging things, as the playbook was new and stunnel role was reworked).

I realized afterward that we also need Redis connection.
This one was already available on off1 side, so I just had to add it on my stunnel client configuration.

### Testing it

We can test our stunnel is working
From our scaleway-stunnel-client, first, we can test:
```bash
nc -vz 10.13.1.101 5432
Connection to 10.13.1.101 5432 port [tcp/postgresql] succeeded!
```
From our scaleway-docker-prod VM:
```bash
nc -vz 10.13.1.101 5432
Connection to 10.13.1.101 5432 port [tcp/postgresql] succeeded!
```

## Installing docker on scaleway-prod-docker

We:
* add scaleway-docker-prod to docker_vm_hosts group
* define `docker__volumes_virtiofs` and `continuous_deployment__ssh_public_keys` variables in `host_vars/scaleway-docker-prod/docker.yml` (I get the public key from current deployment on off1/104)
and use the docker_vm playbook.

## Deploying keycloak

This is done on openfoodfacts-auth with a specific PR and a rule in the workflow.

See https://github.com/openfoodfacts/openfoodfacts-auth/pull/294

## Reverse proxy configuration

I added a configuration to the reverse proxy,
with a temporary auth-new.openfoodfacts.org name.

* added `auth-new.openfoodfacts.org` in OVH DNS as a CNAME to `scaleway-proxy.openfoodfacts.org`.
* created a config on off1 reverse proxy, taking inspiration from the one existing for the old keycloak

As I wanted to test it on auth.openfoodfacts.org (because keycloak won't accept another domain, as it is configured for this domain), I needed to copy the certificates on the reverse proxy:
* on off2 proxy:
  ```bash
  tar cvzf /root/auth-certs.tgz /etc/letsencrypt/live/auth.openfoodfacts.org/ /etc/letsencrypt/archive/auth.openfoodfacts.org /etc/letsencrypt/renewal/auth.openfoodfacts.org.conf
  chmod go-rw /root/auth-certs.tgz
  chown alex:alex /root/auth-certs.tgz
  mv /root/auth-certs.tgz /home/alex/
  ```
* I transfered it to (using `ssh -A proxy-off2`) `scp -J 151.115.132.12 auth-certs.tgz 10.13.1.100:`
* I extract on the reverse proxy: `cd / ; tar xzf /home/alex/auth-certs.tgz`
* test and restart nginx: `nginx -t && systemctl restart nginx`
* remove the archives in /home/alex on both servers

Now I can test by editing my `/etc/hosts` with:
```
151.115.132.10 auth.openfoodfacts.org
```
