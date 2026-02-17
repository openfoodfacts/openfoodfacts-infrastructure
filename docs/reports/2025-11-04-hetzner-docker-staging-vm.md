# 2025-11-06 Hetzner Docker Staging VM

We want to install Search-a-licious staging on Hetzner:
* moving it from OVH
* on a VM with docker staging deployments
* using a ZFS Dataset through virtiofs for important docker volumes


## Creating the VM for staging docker

I tried to have the VM created with ansible, but as it happens to be too much work,
I switch to doing it manually.

I first take the occasion [to upgrade to Proxmox 9](2025-10-22-hetzner-proxmox-8-to-9.md)

### Creating a template VM for debian 13

I already have a template VM, but I want to do a new one,
to have latest debian version.

So I'm doing again what I did in [2025-08-07 testing virtiofs](2025-08-07-testing-virtiofs.md)

```bash
cd /home/alex
# navigate from https://cloud.debian.org/images/cloud to retrieve the name
wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
apt install -y libguestfs-tools dhcpcd-base
virt-customize -a debian-13-generic-amd64.qcow2 --update
virt-customize -a debian-13-generic-amd64.qcow2 --install qemu-guest-agent
# NOTE: I needed to add dhcpcd-base package on the host (see above),
# otherwise this install was failing with "Temporary failure resolving 'deb.debian.org'"
# see https://forum.proxmox.com/threads/virt-customize-install-broken.130473/post-797805
qm create 998 --name debian12-cloudinit --net0 virtio,bridge=vmbr1 --scsihw virtio-scsi-single

# add the disk, using rpool-pve
qm set 998 --scsi0 rpool-pve:0,iothread=1,backup=off,format=qcow2,import-from=/home/alex/debian-13-generic-amd64.qcow2
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

### Creating the VM

I use the Template VM to create my VM:

- Target node: hetzner-02
- VM ID: 201
- Name: hetzner-02-docker-staging
- Mode: full-clone
- Target storage: rpool-pve

I tweak configuration to:
- start at boot
- enable protection
- change cloudinit to:
  - user: config-op
  - password: *****
  - ssh public keys: I took the content of /root/.ssh/authorized_keys on hetzner-02
  - IPConfig: IP: 10.12.1.201/16 and Gateway: 10.12.0.1

In ansible/ folder I:
- add the VM to the inventory.
  ```
  hetzner-02-docker-staging ansible_ssh_host=10.12.1.201 proxmox_node="hetzner-02"
  ```
- create `host_vars/hetzner-02-docker-staging/hetzner-02-docker-staging-secrets.yml`
  and add the `ansible_become_password` inside (using the same password as in cloudinit)

I will run the jobs/configure recipe after having configure virtio-fs.

### Configuring virtio-fs

In ansible:
- in `ansible/host_vars/hetzner-02/proxmox.yml`,
  I added the ZFS configuration for our virtiofs volumes:
  ```yaml
  proxmox_node__zfs_filesystems:
    ...
    # we will put all virtiofs volumes for QEMU vms under this
    - name: rpool/virtiofs
        properties:
        # this is mandatory for virtiofs to work well in linux
        acltype: posixacl
    - name: rpool/virtiofs/qm-201
    - name: rpool/virtiofs/qm-201/docker-volumes
    # datasets for serach-a-licious ES data
    - name: rpool/virtiofs/qm-201/docker-volumes/po_search_esdata01
    - name: rpool/virtiofs/qm-201/docker-volumes/po_search_esdata02
  ```
- in `ansible/group_vars/pvehetzner/proxmox.yml`,
  I added the virtiofs mappings
  ```yaml
  # directory mappings
  virtiofs__dir_mappings:
  - id: qm-201-virtiofs-docker-volumes
      map:
      - node: hetzner-02
          path: /rpool/virtiofs/qm-201/docker-volumes
      description: "virtiofs dataset for qm-201 docker volumes"
  ```

I then run the playbook for proxmox cluster but only zfs and virtiofs tag:
```bash
ansible-playbook sites/proxmox-node.yml -l hetzner-02 --tags zfs,virtiofs
```
(Note: I had to fix some bug,
for example I discovered the [weirdness of tags + role include](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_tags.html#tag-inheritance-for-includes-blocks-and-the-apply-keyword) and moved to import !)

### Adding virtiofs volume to our VM

I edited manually the VM to add the VIRTIOFS device:
- in hardware, add virtiofs
- directory id: qm-201-virtiofs-docker-volumes
- enable posix acl
- do not enable direct IO (would slow it down)

The corresponding string is: `qm-201-virtiofs-docker-volumes,expose-acl=1`

### Configuring the VM

Now I can start the VM.

I can run ansible playbooks:
```bash
ansible-playbook jobs/configure.yml -l hetzner-02-docker-staging
ansible-playbook sites/docker_vm.yml -l hetzner-02-docker-staging
```

**Note:** running the second playbook I had an issue because the "/" partition was saturated.
To fix that, I only had to stop the VM, then, on the host, run: `qm resize 201 scsi0 +7G`
(scis0 corresponding to the primary disk in proxmox config, and I decided to add 7GB).
When I restarted the VM, the partition was already extended.
