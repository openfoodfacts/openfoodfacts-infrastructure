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

Following [what we did on hetzner](./2025-11-04-search-a-licious-staging-hetzner.md)

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



## Setting up stunnel to connect to Postgres on off2

We will need to connect to postgres currently on off2 in a secure way.

To make things easy we will use stunnel.

[TODO]
I had to first create a container for stunnel,
I did it by using 