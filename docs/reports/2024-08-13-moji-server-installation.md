# Moji server installation

We have a new server hosted by Moji, thanks to Open Street Maps.
The server is a Dell T630 with 2 1080Ti GPUs, 128GB of RAM, 56 cores, 1x 8TB NVMe, 8x 8TB HDD.

For more information, see https://wiki.openstreetmap.org/wiki/FR:Serveurs_OpenStreetMap_France/Moji.

Proxmox 8.2 was already installed by Christian on the server, so we just had to configure it.

## Proxmox configuration

Create a user:

`sudo pveum user add raphael@pve` 

Create the admin group:

`sudo pveum group add admin -comment "System Administrators"`

Add user to admin group:

`sudo pveum user modify  raphael@pve -groups admin`

Add Administrator role to admin group:

`sudo pveum acl modify / -group admin -role Administrator`

Change password:

`sudo pveum passwd raphael@pve`

## Create the docker-prod-2 VM

We choose a QEMU VM instead of CT as we’re running docker inside.

### Pre-installation

Download latest Debian install ISO:  `debian-12.6.0-amd64-netinst.iso` 

Move .iso file to `/var/lib/vz/template/iso` .

Create a dataset for Proxmox data:

`zfs create hdd-zfs/pve`

Adding a new ZFS pool as a storage for Proxmox:

`pvesm add zfspool hdd-zfs -pool hdd-zfs/pve -mountpoint /hdd-zfs/pve -sparse 0`

Same thing for NVMe disk:

`zfs create nvme-zfs/pve`

`pvesm add zfspool nvme-zfs -pool nvme-zfs/pve -mountpoint /nvme-zfs/pve -sparse 0 -content rootdir,images`

### Info

ID: 200
name: docker-prod-2 (as docker-prod is deployed in OVH cluster)

### Hardware

3 hard-drives were configured:

- `scsi0`: 140 GB from nvme-zfs for machine
- `scsi1`: 300 GB for docker volumes
- `scsi2`: 400 GB

RAM: 100GB (/124 GB)
Cores: 40 (/55), flag: +aes

### Post-installation

- English
- timezone: France (in others)
- locale: en_US.UTF8
- keymap: french

Network was manually configured:

- ip address: 10.3.0.200/8
- gateway: 10.0.0.45
- dns server: 9.9.9.9

Next:

- Created `off` user (and group).
- cloned https://github.com/openfoodfacts/openfoodfacts-infrastructure into `/opt/openfoodfacts-infrastructure`
- installed docker using `install_docker.sh` script
- added off and raphael to docker group

I mounted `/deb/sdb1` (`UUID=60fc037f-dc90-4b4e-a7df-ceabf7955a06`) on `/var/lib/docker/volumes` , by updating `/etc/fstab`.

## ipv6 configuration

I added an ipv6 interface to VM 200 (`docker-prod-2`) by adding to `/etc/network/interfaces`:

```
iface ens18 inet6 static
    address 2a06:c484:5::200
    netmask 48
    gateway 2a06:c484:5::
    dns-nameservers 2001:4860:4860::8888 2001:4860:4860::8844 
```

`2a06:c484:5::200` is the ipv6 address configured (Moji gives us range `2a06:c484:5::/48`).

After restarting networking on VM (`systemctl restart networking`), VM is reachable using ipv6 from outside:

```bash
>>> ping6 2a06:c484:5::200
PING 2a06:c484:5::200(2a06:c484:5::200) 56 data bytes
64 bytes from 2a06:c484:5::200: icmp_seq=1 ttl=57 time=11.9 ms
64 bytes from 2a06:c484:5::200: icmp_seq=2 ttl=57 time=11.1 ms
```

From there, we have 3 solutions:

1. make docker services directly joinable through ipv6
2. add a NAT rule using iptable to reroute ipv6 trafic to ipv4
3. set-up a nginx reverse-proxy in front of Robotoff, that will listen to the ipv6 server and redirects trafic on ipv4-only api container
4. Use stunnel to make Robotoff API accessible from outside

### Solution 1

I spent some time trying solution (1), [by enabling ipv6 on docker](https://docs.docker.com/config/daemon/ipv6/), with this `/etc/docker/daemon.json` :

```bash
{
  "metrics-addr" : "127.0.0.1:9323",
  "experimental" : true,
  "storage-driver": "overlay2",
  "ipv6": true,
  "userland-proxy": false,
  "fixed-cidr-v6": "2a06:c484:5::200/48"
}
```

Docker then assigns a random ipv6 address from the range, I didn’t manage to make a docker service running locally accessible from outside. Not that it does not mean it's not possible, but that I’m really new at ipv6 networking.

### Solution 4

As we may get an ipv4 later (Stephane is asking for one), i decided to try directly solution 4, as it’s easy to set-up, and has the advantage of encrypting connection between ovh1 (where the reverse proxy is in CT 101) and docker-prod-2 (VM 200 on Moji).

With solution (3) (nginx), the trafic is not encrypted, so stunnel is a better choice here.

After talking with Alex, we decided to use stunnel between the reverse proxy on OVH and robotoff on Moji.

- Request to Robotoff API: client – http/ipv4 → reverse proxy - ipv4 -> stunnel client on ovh - ipv6 -> stunnel server on moji - ipv4 -> robotoff on Moji (private)
- Add a container for stunnel client
  - should work in IPv4: it will be accessible only from other VM on Moji server, using local ipv4
- Add a container for stunnel server
  - must have a public IPv6 address. Reverse proxy on OVH1 (VM 101) will reach the stunnel server using the ipv6 address.
- robotoff nginx proxy config should forward to stunnel client on the right pid

## stunnel-client CT configuration

### Create the container

This container will be used for Robotoff service to reach MongoDB and Redis hosted on ovh2 server.

We don’t need a VM, a container is enough. I created CT 101 with the following parameters:

- 1 CPU
- 512 MB of RAM (no swap)
- 8 GB of disk
- network:
  - ipv4: 10.3.0.101/8
  - no ipv6, as we will use internal ipv4
  - gateway: 10.0.0.45 (host)
- dns: I added `1.1.1.1` (cloudflare) as DNS

### Install stunnel

The installation process follows [https://openfoodfacts.github.io/openfoodfacts-infrastructure/reports/2024-01-04-setting-up-stunnel/](https://openfoodfacts.github.io/openfoodfacts-infrastructure/reports/2024-01-04-setting-up-stunnel/).

- Install with `apt install stunnel4`

- Update `/etc/stunnel/off.conf` with the content in `openfoodfacts-infrastructure` repo, in `confs/moji-stunnel-client/stunnel/off.conf`

  - Override the systemd config of `stunnel@.service` with `systemctl edit stunnel@.service`:

  ```bash
  [Service]
  # we need to enable putting pit file in runtime directory, with right permissions
  # while still starting as root (needed by stunnel)
  Group=stunnel4
  RuntimeDirectory=stunnel-%i
  RuntimeDirectoryMode=0775
  ```

- Mask default stunnel4 config: `sudo systemctl mask stunnel4.service`

- start service: `systemctl start stunnel@off.service`

- enable service (to be launched as startup): `systemctl enable stunnel@off.service`

## stunnel-server CT configuration

### Create the container

This container will be used to allow external services to reach Robotoff API, through ipv6.

I created CT 102 with the following parameters:

- 1 CPU
- 512 MB of RAM (no swap)
- 8 GB of disk
- network:
  - ipv4: 10.3.0.103/8, gateway: 10.0.0.45 (host)
  - ipv6: 2a06:c484:5::103/48, gateway: 2a06:c484:5::

### Install stunnel

Exactly the same procedure as for stunnel-client, but use ``confs/moji-stunnel-server/stunnel/off.conf` as configuration file.

## Install Robotoff services

- Clone robotoff repository in `robotoff-org`
- Install git LFS
- Create external networks, create external volumes
- Download ML models with `make dl-models`
- Configure .env file

## OVH1 configuration

### Added ipv6 to OVH1 Proxy CT (101)

In proxmox network interface, I added an ipv6 to CT 101, so that the reverse proxy can reach `docker-prod-2` in ipv6:

- ipv6/CIDR: 2001:41d0:0203:948c::101/8 (fixed IP)
- gateway: 2001:41d0:0203:94ff:00ff:00ff:00ff:00ff (as declared in OVH mecenat dashboard)

### Update proxy stunnel configuration

We need to access InfluxDB from `docker-prod-2`, so we use the stunnel deployed in proxy (CT 101. We also need to configure OVH1 reverse proxy →Robotoff API connection to stunnel.
We add the following configuration block to the stunnel configuration on CT 101 (reverse proxy):

```bash
# enabling connections to InfluxDB from outside
[InfluxDB]
client = no
accept = 0.0.0.0:8087
connect = 10.1.0.201:8087
ciphers = PSK
# this file and directory are private
PSKsecrets = /etc/stunnel/psk/influxdb-psk.txt

# OVH1 reverse proxy is the only one that has IPv6, so we use this stunnel
# instead of the one of stunnel-client
[Robotoff]
client = yes
accept = 127.0.0.1:16000
# Connect to stunnel-client of Moji server
connect = 2a06:c484:5::102:16000
ciphers = PSK
PSKsecrets = /etc/stunnel/psk/robotoff-psk.txt
```

We enable the service with `systemctl enable stunnel@off.service` and restart it with `systemctl restart stunnel@off.service`.

## Robotoff migration

To migrate Robotoff to the new server, I did the following:

- Stop Robotoff services on OVH2
- Migrate data from old server (OVH2) to new one (Moji): elasticsearch, redis, postgresql
- Start services on Moji machine
- Update the `proxy_pass` in nginx configuration (`robotoff.conf`) to point to the stunnel server (`127.0.0.1:16000`) running on CT 101

The migration went smoothly, and Robotoff is now running on the new server.

## Tasks remaining

What remains to be done:

- configure GPU (GPU configuration documentation: [https://pve.proxmox.com/wiki/NVIDIA_vGPU_on_Proxmox_VE](https://pve.proxmox.com/wiki/NVIDIA_vGPU_on_Proxmox_VE)). Indeed, we're not using the GPUs yet.
- Configure backups (set-up sanoid)