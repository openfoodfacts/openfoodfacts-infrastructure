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
ansible-playbook sites/docker_vm.yml -l hetzner-docker-prod
```

## Adding stunnel client on hetzner

We need to connect to remote postgres servers and we will do so through stunnel.

So we need a stunnel client endpoint on hetzner.

For that, I will use ansible:

1. added hetzner-stunnel-client to inventory
2. created `host_vars/hetzner-stunnel-client/hetzner-stunnel-client-secrets.yml` with
   - `ansible_become_password`
   - `ansible_user_password_salt`
   - `stunnel__psk_secrets`
3. edited `proxmox_containers__containers` variable in `ansible/host_vars/hetzner-02/proxmox.yml`
   to add container definition
3. I then launched:
   ```bash
   ansible-playbook sites/proxmox-node.yml -l hetzner-02 --tags containers
   ansible-playbook jobs/configure.yml -l hetzner-stunnel-client
   ```
3. I added the secret psk on stunnel server on OVH (for postgres-query-net),
   and on osm45/moji (for postgres-query-org)
   and I modified the configuration on both to expose postgres on each stunnel-server.
   I also had to add the port in the iptables rules (/etc/iptables/rules.v4 and v6).
   see commit [9a70c296e0e05d7d0639e81f6b0ab42eb3b505d5](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/9a70c296e0e05d7d0639e81f6b0ab42eb3b505d5) and [b6c687d923bfd4d72fc0927003d4fb4a875aaa51](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/b6c687d923bfd4d72fc0927003d4fb4a875aaa51)
4. I added a config file for the new stunnel client in `confs/hetzner-stunnel-client/`:
    - in `stunnel/off.conf`
    - in `stunnel/systemd/system/stunnel@.service.d` (that symlinks `../../../common/systemd/system/stunnel@.service.d`)
    and pushed it
4. I added `hetzner-stunnel-client` to `stunnel_client_hosts` in inventory
4. I then launched:
   ```bash
   ansible-playbook sites/stunnel-client.yml -l hetzner-stunnel-client
   ```
4. As I forgot to open iptables open ports,
   I add to definde `iptables_public_ports` in `host_vars/hetzner-stunnel-client/base.yml`
  and then relaunch:
  ```bash
  ansible-playbook jobs/configure.yml -l hetzner-stunnel-client --tags firewall
  ansible-playbook sites/stunnel-client.yml -l hetzner-stunnel-client --tags stunnel
  ```
  (Also I had to fix masquerading rule in ipv6 in iptables roles
  because it was missing the right masquerading rule)

I can test it on hetzner-docker-prod by using:
```bash
alex@hetzner-docker-prod:~$ nc -vz 10.12.1.112 16002
Connection to 10.12.1.112 16002 port [tcp/*] succeeded!
alex@hetzner-docker-prod:~$ nc -vz 10.12.1.112 16022
Connection to 10.12.1.112 16022 port [tcp/*] succeeded!

alex@hetzner-docker-prod:~$ docker run -ti --rm --entrypoint sh pgautoupgrade/pgautoupgrade:16-alpine
/var/lib/postgresql # pg_isready -h 10.12.1.112 -p 16022
10.12.1.112:16022 - accepting connections
/var/lib/postgresql # pg_isready -h 10.12.1.112 -p 16002
10.12.1.112:16002 - accepting connections
/var/lib/postgresql # exit
```

## Deploying postgres on hetzner-docker-prod

The [PR #225 in openfoodfacts-query](https://github.com/openfoodfacts/openfoodfacts-query/pull/225)
contains the modifications to configuration of postgres and CI workflow
to deploy postgres replica on hetzner-docker-prod.

On caveat is that because of virtiofs mount and the folder for my docker volume being a dataset inside it,
docker compose refuse to create the volume. So I had to declare it external and create it (I added a Make target for that).

I first forced my deployment action to run for replica and staging (.net) on my branch.
I systematically cancelled .net deployment until I got replica to the point of starting the docker compose
and having it failed because database does not exists.

When this was ok, I run it also on .net branch (I wanted to test with .net before .org).

I also added a command to create the replication user in makefile and deployment.

## Importing data from net (test)

I then run the command to use a backup from the primary for the replica


```bash
docker compose run --rm --entrypoint bash query_postgres 

# /usr/local/bin/pg_basebackup --host 10.12.1.112 --port 16022 --username replication --password --pgdata /var/lib/postgresql/data --progress --wal-method=stream --write-recovery-conf --create-slot --slot hetzner_replica -v
pg_basebackup: error: connection to server at "10.12.1.112", port 16022 failed: FATAL:  no pg_hba.conf entry for replication connection from host "10.1.0.101", user "replicator", no encryption
Password: 
pg_basebackup: initiating base backup, waiting for checkpoint to complete
pg_basebackup: checkpoint completed
pg_basebackup: write-ahead log start point: 45E/B4000028 on timeline 1
pg_basebackup: starting background WAL receiver
pg_basebackup: created replication slot "hetzner_replica"
112581901/112581901 kB (100%), 1/1 tablespace                                         
pg_basebackup: write-ahead log end point: 45E/B4000138
pg_basebackup: waiting for background process to finish streaming ...
pg_basebackup: syncing data to disk ...
pg_basebackup: renaming backup_manifest.tmp to backup_manifest
pg_basebackup: base backup completed
# exit
```

Now we can try to start it: `docker compose up -d`

It didn't start, but simply because I forgot to upgrade memory and cpus on the VM.

Also it's at this point that I realized we need `hot_standby=on` to be able to run queries !

Note: if you want to restart replication from scratch, or if you stop it,
you need to remove the slot from primary postgres with `select pg_drop_replication_slot('hetzner_replica');`

## Testing

To test it's working, I logged in on the replica database with superset user to see it's
all working fine.

I also verified that the tables keeps being up to date
after I did some changes on staging (and thus created some events).

As some deployment of main branch also happened on staging at some point,
thus removing my replication parameters, and stall replication.
This was a good occasion to test resilience, that, when I restored the parameters,
it worked again, getting back to last state smoothly.


## Importing data from org

Before the release,
I had to change the `POSTGRES_REPLICATION_PASSWORD` in github settings
for `replica-off-org` environment
to be aligned with the one in `off-query-replica-org` environment.

To restart from a fresh instance:

I did a `docker compose down` and `docker volume rm off-query-replica_dbdata` (which finish with an error but that's not a big deal) then `make create_external_volumes`

Then I get the prod backup:

```bash
docker compose run --rm --entrypoint bash query_postgres 

# /usr/local/bin/pg_basebackup --host 10.12.1.112 --port 16002 --username replication --password --pgdata /var/lib/postgresql/data --progress --wal-method=stream --write-recovery-conf --create-slot --slot hetzner_replica -v
```
