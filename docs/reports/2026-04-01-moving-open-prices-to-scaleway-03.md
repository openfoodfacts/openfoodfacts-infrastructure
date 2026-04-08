# 2026-04-01 Moving Open Prices to scaleway-03

As we're running out of disk space again on ovh, and as Open Prices images now takes ~650 GB of disk space, it's a good time to move them to scaleway-03, where we have plenty of disk space.

## Creating ZFS datasets and docker-prod VM

The process is the same as for (docker-prod VM install on scaleway-02)[./2025-11-27-moving-keycloak-to-scaleway.md].

The ID of the VM will be 201.

### Creating ZFS datasets

As for docker-prod on scaleway-02, we decided that by default, all docker volumes will be on a ZFS dataset in the zfs-hdd pool: we use HDD by default, as our storage capacity is limited on nVMe (only 3 TB).

If we need more disk performance, we create a specific ZFS dataset on the nVMe pool, and we mount it in the VM using VirtioFS. That's what we did for OFF MongoDB and Redis, and that's what we will do for Open Prices PostgreSQL DB.

ZFS dataset creation and virtiofs configuration is done by Ansible.

First, we update `proxmox.yml` to configure the datasets:

```yaml
_proxmox_node__zfs_filesystems_specific:
  - name: zfs-hdd/virtiofs
    properties:
      # this is mandatory for virtiofs to work well in linux
      acltype: posixacl
  - name: zfs-hdd/virtiofs/qm-201
  - name: zfs-hdd/virtiofs/qm-201/docker-volumes
  - name: zfs-nvme/virtiofs
    properties:
      # this is mandatory for virtiofs to work well in linux
      acltype: posixacl
  # data volumes
  - name: zfs-nvme/virtiofs/qm-201-open_prices_postgres-data
    properties:
      # we need to mount it in the right place for docker in the VM
      mountpoint: /zfs-hdd/virtiofs/qm-201/docker-volumes/open_prices_postgres-data
```

We also add the `proxmox_node__pve_storages` that was present in scaleway-01 and scaleway-02, but not in `scaleway-03` yet:

```yaml
proxmox_node__pve_storages:
  - name: zfs-hdd-pve
    type: zfspool
    pool: zfs-hdd/pve
    content: rootdir,images
    mountpoint: /zfs-hdd/pve
    sparse: 0
    # shared: 0 # for some reason, this flag did make the setup crash
  - name: local
    type: dir
    path: /var/lib/vz
    content: vztmpl,snippets,iso
    shared: 0
  # removing installed storage
  - name: zfs-hdd
    type: zfspool
    pool: zfs-hdd
    state: absent
```

We edit `virtiofs__dir_mappings` in `group_vars/pvescaleway/proxmox.yml` to add the virtiofs mapping.

```yaml
  - id: qm-201-virtiofs-docker-volumes
    map:
      - node: scaleway-03
        path: /zfs-hdd/virtiofs/qm-201/docker-volumes
    description: "virtiofs dataset for qm-201 docker volumes"
```

Then we run:

```bash
ansible-playbook sites/proxmox-node.yml -l scaleway-03 --tags zfs,virtiofs
```

ZFS datasets and virtiofs are now configured on scaleway-03.

## Creating the VM

We now create a VM template. Following what was done on scaleway-02:

```bash
```bash
cd /home/raphael0202
# navigate from https://cloud.debian.org/images/cloud to retrieve the name
wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
apt install -y libguestfs-tools dhcpcd-base
virt-customize -a debian-13-generic-amd64.qcow2 --update
virt-customize -a debian-13-generic-amd64.qcow2 --install qemu-guest-agent

# create the VM
qm create 999 --name debian13-cloudinit --net0 virtio,bridge=vmbr10 --scsihw virtio-scsi-single

# add the disk, using zfs-hdd/pve
qm set 999 --scsi0 zfs-hdd-pve:0,iothread=1,backup=off,format=qcow2,import-from=/home/raphael0202/debian-13-generic-amd64.qcow2
# set boot
qm set 999 --boot order=scsi0
# set some physical values
qm set 999 --cpu host --cores 2 --memory 4096
# add cloudinit
qm set  999 --ide2 local:cloudinit
# set qemu agent
qm set 999 --agent enabled=1
# make it a template
qm template 999
```

Using Proxmox UI, I use the Template VM to create my VM. Right click on the 999 template, and click "Clone". I fill the form with:

- Target node: scaleway-03
- VM ID: 201
- Name: scaleway-docker-prod-2
- Mode: full-clone
- Target storage: zfs-hdd-pve

I tweak the configuration to:

- start at boot
- enable protection
- 70 cores, 128 GB of RAM (same as scaleway-docker-prod on scaleway-02)
- change cloudinit to:
  - user: config-op
  - password: *****
  - ssh public keys: I took part of the content of /root/.ssh/authorized_keys on scaleway-03
  - IPConfig: IP: 10.13.1.201/16 and Gateway: 10.13.0.3


In ansible/ folder I:

- add the VM to the inventory.
  ```
  scaleway-docker-prod-2 proxmox_vm_id=201 proxmox_node="scaleway-03"
  ```
  and add it to the `scaleway_vms` group
- create `host_vars/scaleway-docker-prod-2/scaleway-docker-prod-2-secrets.yml`
  and add the `ansible_become_password` inside (using the same password as in cloudinit)
- define `docker__volumes_virtiofs` and `continuous_deployment__ssh_public_keys` variables in `host_vars/scaleway-docker-prod/docker.yml` (I copied the SSH public keys from scaleway-docker-prod on scaleway-02)
- add scaleway-docker-prod-2 to docker_vm_hosts group


## Adding virtiofs volume to our VM

On Proxmox UI, in the VM hardware section of scaleway-docker-prod-2, I edited manually the VM to add the VIRTIOFS device:

- in hardware, add virtiofs
- directory id: qm-201-virtiofs-docker-volumes
- enable posix acl (in Advanced options)
- do not enable direct IO (would slow it down)

The corresponding string is: `qm-201-virtiofs-docker-volumes,expose-acl=1`


## Resizing partition

We then resize the VM disk from 3G to 24G
(to account for the space of docker images).

We use gparted to do this:

```bash
config-op@scaleway-docker-prod-2:~$ sudo parted /dev/sda
GNU Parted 3.6
Using /dev/sda
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) unit s                                                           
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
Yes/No? Yes                                                               
(parted) align-check optimal 1                                            
1 aligned
(parted) quit
```

**Note** that, because of the start of the partition `6289407 mod 2048 == 1`,
we had to take `50331648s - 2047` for the end, so that partition length is aligned. [^alignment]

[^alignment]: https://pieterbakker.com/optimal-disk-alignment-with-parted/ is a good resource to understand alignment.

Then we resize the filesystem:

```bash
config-op@scaleway-docker-prod-2:~$ sudo resize2fs /dev/sda1
resize2fs 1.47.2 (1-Jan-2025)
Filesystem at /dev/sda1 is mounted on /; on-line resizing required
old_desc_blocks = 1, new_desc_blocks = 3
The filesystem on /dev/sda1 is now 6258432 (4k) blocks long.
```

We check the new size:

```bash
config-op@scaleway-docker-prod-2:~$ df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        24G  943M   22G   5% /
```

## Installing docker on scaleway-docker-prod-2

First, we configure the server:

```bash
ansible-playbook jobs/configure.yml -l scaleway-docker-prod-2
```

Then, we run the `docker_vm` playbook:

```bash
ansible-playbook sites/docker_vm.yml -l scaleway-docker-prod-2
```

## Configuring stunnel to connect to Triton

I updated the stunnel configuration to access Triton (deployed on gpu-01) from scaleway-docker-prod-2:

```
# Triton deployed on gpu-01
# Open Prices deployed on scaleway server need to access
# Triton
[Triton-HTTP]
client = yes
accept = 10.13.1.101:5505
connect = 34.140.15.35:5506
ciphers = PSK
PSKsecrets = /etc/stunnel/psk/triton-psk.txt

[Triton-gRPC]
client = yes
accept = 10.13.1.101:5504
connect = 34.140.15.35:5507
ciphers = PSK
PSKsecrets = /etc/stunnel/psk/triton-psk.txt
```

I also configured ansible to copy the PSK secret file on scaleway-docker-prod-2, and run the stunnel-client playbook:

```bash
ansible-playbook sites/stunnel-client.yml --tags stunnel -l scaleway-stunnel-client
```

From scaleway-docker-prod-2, I tested the connection to Triton:

```bash
curl -XPOST http://10.13.1.101:5505/v2/repository/index

[{"name":"category-classifier-keras-image-embeddings-3.0","version":"1","state":"READY"},{"name":"clip","version":"1","state":"READY"},{"name":"front_image_classification","version":"1","state":"READY"},{"name":"ingredient-ner","version":"1","state":"READY"},{"name":"nutriscore","version":"1","state":"READY"},{"name":"nutrition_extractor","version":"2","state":"READY"},{"name":"nutrition_table","version":"1","state":"READY"},{"name":"price_proof_classification","version":"1","state":"READY"},{"name":"price_tag_classification","version":"1","state":"READY"},{"name":"price_tag_detection","version":"1","state":"READY"},{"name":"universal_logo_detector_yolo","version":"1","state":"READY"}]
```

## Move Certbot certificates to scaleway-proxy

We copy the certificates from ovh1-proxy to scaleway-proxy (following https://charlesreid1.github.io/copying-letsencrypt-certs-between-machines.html)

On ovh1-proxy:
```bash
CONF=/etc/nginx/conf.d/prices.openfoodfacts.org
DOM=$(sed -nr  "s|.*letsencrypt/live/(.*)/privkey.*|\1|p" $CONF)
echo "COPYING CERTS FOR $DOM in $DOM.tar.gz"
sudo tar -chvzf $DOM.tar.gz \
    /etc/letsencrypt/archive/${DOM} \
    /etc/letsencrypt/renewal/${DOM}.conf \
    /etc/letsencrypt/live/${DOM}
sudo chmod go-rw $DOM.tar.gz
```

I then copied it to scaleway-proxy (using scp).
On scaleway-proxy:

```bash
cd /
tar xzf /home/raphael0202/prices.openfoodfacts.org.tar.gz
# verify
ls -l /etc/letsencrypt/*/prices.openfoodfacts.org /etc/letsencrypt/renewal/prices.openfoodfacts.org.conf
```

I also copied the Open Prices nginx configuration from ovh1-proxy to scaleway-proxy, updating the proxy_pass to point to scaleway-docker-prod-2 internal IP address.

## Copying data from ovh to scaleway

I configured SSH access from scaleway-docker-prod-2 to docker-prod (OVH), to be able to rsync data from OVH (as root) to scaleway-docker-prod-2.

I tarred the `www` directory from ovh, and scp and untarred it in `/home/open-prices-org/www` on scaleway-docker-prod-2.

The PostgreSQL DB content and the images will both be synchronized using rsync:

```bash
rsync -a --delete --info=progress2  docker-prod:/var/lib/docker/volumes/open_prices_postgres-data/_data/ /var/lib/docker/volumes/open_prices_postgres-data/_data

rsync -a --delete --info=progress2  docker-prod:/var/lib/docker/volumes/open_prices_images/_data/ /var/lib/docker/volumes/open_prices_images/_data
```

## Migration

1. We make sure that all Open Prices containers are stopped on scaleway-docker-prod-2.
2. We stop the Open Prices containers on docker-prod (OVH): `make down` in the `open-prices` repo.
3. We run both rsync commands to synchronize the PostgreSQL DB and the images.
4. We start the Open Prices containers on scaleway-docker-prod-2: `make up` in the `open-prices` repo.
5. We update the DNS record of prices.openfoodfacts.org to: `CNAME scaleway-proxy.openfoodfacts.org.`


## Troubleshooting

During the migration, an issue was encountered: a HTTP 500 was returned when uploading a new proof.

After investigation, the issue came from the fact the user ID associated with the `off` user was 1001 and not 1000. The `open_prices-api-1` container expects the image volume to be owned by the `off` user (UID 1000), but UID 1000 was associated with user `config-op` on scaleway-docker-prod-2.

As a quick fix, I changed the UID of `config-op` to 1009, and the group ID of `config-op` to 1009 as well (to avoid a conflict with the `off` user that has GID 1000):

```
sudo groupmod -u 1009 config-op
sudo usermod -u 1009 config-op
```

I then changed the ownership of the files in the image volume:

```bash
chown -R 1000:1000 /var/lib/docker/volumes/open_prices_images/_data
```

It solved the permission issue, even though user ID `1000` is not associated with any user on scaleway-docker-prod-2. I wanted to change the UID of `off` to 1000, but it was not possible as some systemd services were running with the `off` user.


## Post-install

I then run rsync to synchronize the images that were deleted from the OVH server but kept on scaleway-03. After configuring SSH, I run:

```bash
rsync -a --info=progress2 scaleway-03:/zfs-hdd/open-prices-images/ /var/lib/docker/volumes/open_prices_images/_data
```

Note that we didn't add the `--delete` flag, to avoid deleting the images that were transfered from OVH to scaleway-docker-prod.

On **docker-prod**, I deleted the now legacy volume to save disk space:

```bash
docker volume rm open_prices_images
```

We created a ssh key for deployment following
the [continuous_deployment role documentation](../ansible/roles/continuous_deployment.md),
and adding the new variable to
[open-prices](https://github.com/openfoodfacts/open-prices)
and [open-prices-frontend](https://github.com/openfoodfacts/open-prices-frontend).

The deployment actions also had to be modified to use `scaleway-03.infra.openfoodfacts.org` as reverse proxy,
as well as changing the host ip:
* for open-prices,
  [commit e5f40015929e](https://github.com/openfoodfacts/open-prices/commit/e5f40015929e461a3c324524ed4f590be17f334b)
  and [fix PR #1267](https://github.com/openfoodfacts/open-prices/pull/1267)
* for open-prices-frontend: [PR #2117](https://github.com/openfoodfacts/open-prices-frontend/pull/2117)