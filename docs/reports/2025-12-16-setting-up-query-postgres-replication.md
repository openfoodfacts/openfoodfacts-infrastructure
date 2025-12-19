# 2025-12-16 Setting up query postgres replication

We have setup SuperSet to enable anyone to build dashboard or get inside from our data.

One interesting data source is postgreSQL form openfoodfacts query
because it offers structured data.

But we don't want to put more pressure on the production database,
which is already under high load.
Thus we want to setup a replica, so that data is always fresh,
but it does not impact much the production database.

We will deploy the postgres using docker compose on the hetzner server.

## Creating hetzner-docker-prod

### Creating Virtiofs resource

Using ansible,
I edited `ansible/group_vars/pvehetzner/proxmox.yml`
to add the desired mapping to `virtiofs__dir_mappings`:
```yaml
  - id: qm-202-virtiofs-docker-volumes
    map:
      - node: hetzner-03
        path: /rpool/virtiofs/qm-202/docker-volumes
    description: "virtiofs dataset for qm-202 docker volumes"
```
I also edited `ansible/host_vars/hetzner-03/proxmox.yml` to add the datasets
in `proxmox_node__zfs_filesystems`:
```yaml
  - name: rpool/virtiofs
    properties:
      # this is mandatory for virtiofs to work well in linux
      acltype: posixacl
  - name: rpool/virtiofs/qm-202
  - name: rpool/virtiofs/qm-202/docker-volumes
  # data of off-query postgres replication
  - name: rpool/virtiofs/qm-202/docker-volumes/off-query-replica_dbdata
```

and then:
```bash
ansible-playbook sites/proxmox-node.yml -l hetzner-03 --tags zfs,virtiofs
```

I also had to modify `/etc/sanoid/sanoid.conf` on the `hetzner-03` server,
as it was the first virtiofs service, to add:
```ini
[rpool/virtiofs]
  use_template=data_sys
  recursive=yes
```

### Creating the VM

I started by a dist-upgrade on hetzner-03.

I used the template VM debian 13 (already created to create the docker staging VM).

- Target node: hetzner-02
- VM ID: 202
- Name: hetzner-docker-prod
- Mode: full-clone
- Target storage: rpool-pve

I then migrate the new VM to hetzner-03.

~~But first I have to copy /var/lib/vz/images/202/vm-202-cloudinit.qcow2 to hetzner-03.
On hetzner-03 as root~~ (see below this was not really needed):
```bash
mkdir /var/lib/vz/images/202
scp hetzner-02:/var/lib/vz/images/202/vm-202-cloudinit.qcow2 /var/lib/vz/images/202/
```

Then I want to do the migration but I got the error:
```bash
local:202/vm-202-cloudinit.qcow2: content type 'images' is not available on storage 'local' (500)
```

This is strange but this is because during my clone,
it did not convert the couldinit volume to a proper storage on rpool/pve.
That is *Cloud init drive* was `local:202/vm-202-cloudinit.qcow2`,
instead of `rpool-pve:202/vm-202-cloudinit.qcow2`.
I don't know why this happened.

So I removed the VM and on hetzner-03, `rm /var/lib/vz/images/202/vm-202-cloudinit.qcow2`.
Then I recreated it in exactly the same way as before.
This time *Cloud init drive* is the correct value.

Now I'm able to migrate it !

### Configuring disk and VirtioFS

The template has a minimal disk space (VM is still not started, but it could be).
To augment it we:
* go in proxmox manager
* click on VM 202
* click in hardware
* choose the scsi0 disk
* in top bar, click on *disk action*, resize
* we add 7 GB to be at 10 GB (needed because we will download docker images there)

I also add Virtiofs disk:
* go in proxmox manager
* click on VM 202
* click in hardware
* in top bar, click *Add*, *Virtiofs*
* choose the `qm-202-virtiofs-docker-volumes` volume and validate


### Setting options

Tweak VM 202 configuration to:
- start at boot
- enable protection
- change cloudinit to:
  - user: config-op
  - password: *****
  - ssh public keys: I added my public key from github
  - IPConfig: IP: 10.12.1.202/16 and Gateway: 10.12.0.3
  - click on "regenerat image"

### Starting the VM

It's time to start the VM !

I started it.

I verified it was reachable with a ssh connection:
```bash
ssh config-op@10.12.1.202 -J hetzner-03
```
(hetzner-03 is a configured Host in my local ssh config)

### Setting it up

I then add it to the ansible inventory:
```ini
[hetzner_vms]
...
hetzner-docker-prod proxmox_vm_id=202 proxmox_node="hetzner-03"
...
[docker_vm_hosts]
...
hetzner-docker-prod
```
And created the `host_vars/hetzner-docker-prod/hetzner-docker-prod-secrets.yml` file
and added the `ansible_become_password` variable with the password of `config-op`
chose before.

I then run:
```bash
ansible-playbook jobs/configure.yml -l hetzner-docker-prod
```

### Setting up docker

I created a ssh private key for off user, that I will put in
`SSH_PRIVATE_KEY` in `off-query-replica-org` environment
in the openfoodfacts-query repository.

I also put it in the KeepassXC of passwords.

```
ssh-keygen -t ed25519 -C "off-query-replica-org@hetzner-docker-prod" -f off-query-replica-key
```

I then added the `host_vars/hetzner-docker-prod/proxmox.yml`,
with `docker__volumes_virtiofs` variable,
and a `continuous_deployment__ssh_public_keys`
corresponding to the public created before.

Then I run:
```bash
ansible-playbook sites/proxmox-node.yml -l hetzner-docker-prod
```