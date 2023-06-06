# 2022-11 moving monitoring to its own machine

When we deployed monitoring it was deployed on staging as it was the only available QEMU VM at that time.
But it's a bad idea to keep it like it. We decided we should move it on OVH1 in it's own VM.

## Preparing

### Disk space

I look how much data is taken by monitoring on current staging VM:

```bash
$ du -sh /home/off/monitoring
$ du -sh /var/lib/docker/volumes/{influxdb-data,grafana-data,elasticsearch-data,prometheus-data,alertmanager-data}
418M	/var/lib/docker/volumes/influxdb-data
23M	/var/lib/docker/volumes/grafana-data
9.8G	/var/lib/docker/volumes/elasticsearch-data
1.7G	/var/lib/docker/volumes/prometheus-data
8.0K	/var/lib/docker/volumes/alertmanager-data
```

And separately ES backup which should be on a shared filesystem
```bash
$ du -sh /var/lib/docker/volumes/monitoring_elasticsearch-backup/
28G	/var/lib/docker/volumes/monitoring_elasticsearch-backup/
```

### Memory usage


Getting docker stats, limiting to used memory:
```bash
docker stats --no-stream --format "{{ json . }}"|jq  -s  'map(select(.Name|startswith("monitoring_"))) | map({"Name": .Name, "MemUsage": .MemUsage|split("/")|.[0]})'
```

We got: `2.317GiB + 4.389GiB + 313.3MiB + 719.1MiB + 221.1MiB + ...`
And considering I want to give more memory to ES (4G instead of 1G),
12G should be enough to begin with (and it's easy to scale-up)

### CPU usage
```bash
docker stats --no-stream --format "{{ json . }}"|jq  -s  'map(select(.Name|startswith("monitoring_"))) | map({"Name", "CPUPerc"})'
```
total is about 21% (but ES is quite idle), on a 9 core machines. So 4 cores should be really fine (there again, easy to scale down).

### Create ticket

I thus create [a ticket for the VM](https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/159)


## Creating a VM

We prefer not to reuse an ip that:
* from 100 to 200 for lxc containers
* from 200 and up for QEMU


Right click on ovh1 "create VM" or use the button up right (create VM).
I used "advanced".

General:
* node: ovh1
* VM ID: 203 (first available in 200+)
* name: monitoring
* start at boot: yes

OS:
* use CD/DVD image file:
  * Storage: backup
  * ISO image: debian 11.10

System: all left to default

Disk
* Bus / device: SCISI 0
* Storage: zfs
* Disk Size: 32 G
* advanced let as is

CPU:
* Sockets: 1
* Cores: 4
* Types: host (to be able to use SIMD opts)

Memory
* Memory: 12288 MB

Network:
* Bridge: vmbr0 (default)
* Vlan tag: No vlan (default)
* Model: virtio (default)

We confirm, asking it starts immediately.

In a console on ovh1 we can see it:

```bash
qm list
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID       
       202 discourse            running    4096              32.00 4936      
       203 monitoring           running    12288             32.00 46654     
```

## Installing the system

useful resource: https://www.snel.com/support/debian-vm-in-proxmox-and-networking-setup/

Opened the NoVNC console of my newly created VM.

We are on Debian installation.

* Graphical install
* English
* timezone: France (in others)
* locale: en_US.UTF8
* keymap: french

… install runs … and stops on network
* configure network manually
* ip address: 10.1.0.203/24
* gateway: 10.1.0.1 (it will then be set by PVE)
* nameserver: 213.186.33.99 (it will then be set by PVE)

I took values by looking at existing machines with (ip address list, ip route list and cat /etc/resolv.conf)

… it checks network…

* hostname: monitoring
* domain name: openfoodfacts.org (I think we need it for mail)
* root password:used `pgen 20` and stored in github off-passwords project keepassx
* create user: alex / alex
* personal password

… configuration continue…

* partition: use entire disk
* all file in one partition
* write changes
* confirm partition change

… install continues…

* no extra media scan
* package manager sources -> france -> ftp.fr.debian.org
* no proxy 

… install continues and it fails (my network is not fine it seems) …

I go back up to the steps menu and execute a shell to set the route config:

```bash
$ ip route list
default via 10.1.0.1 dev ens18
10.1.0.0/24 dev ens18 scope link src 10.1.0.203
$ ip route del default via 10.1.0.1 dev ens18
$ ip route add default via 10.0.0.1 dev ens18 proto kernel onlink 

$ ping ftp.fr.debian.org
…
$ exit
```
… restart from step configure the package manager …

… this time it works, software is installed …

* popularity contest: no
* software to install: ssh server + standard system utilities

… install continues …

* grub as primary: yes
* grub on: /dev/sda

… install continues …

* continue

… system reboots and is ready.

> **NOTE**: on the network side, the wiki page did in fact explains how to do, but I was not aware of its existence
>
>> Tips for Debian install:
>> * IP: 10.1.0.201/8 for the installation and then switch to /24 when install is done
>> * Gateway IP: 10.0.0.1/8 for the installation and then switch to 10.0.0.1/24 when install is done

## Accessing for the first time

When I try to ping from ovh1, 10.1.0.203 is not reachable.

I open a console in proxmox to install qemu-guest-agent but it was already there.

I saw in options that qemu agent was not enabled, so I enabled it.

My machine is still unreachable, so I look at 10.1.0.200 and adapted the /etc/network/interfaces. I used a console to update it, in fact I only changed the gateway from 10.1.0.1 to 10.0.0.1.
Then `systemctl restart networking.service` and `ifdown ens18; ifup ens18`

I then reboot the VM to be sure.

created a config in my machine .ssh/config:

```ssh_config
Host offmonit
    Hostname 10.1.0.203
    ProxyJump ovh1.openfoodfacts.org
    IdentityFile /home/alex/.ssh/alex_github
```

But first I have to manually copy my key there:

```bash
ssh ovh1.openfoodfacts.org
$ ssh 10.1.0.203 -o PubkeyAuthentication=no
...
mkdir .ssh
nano .ssh/authorized_keys
# ...copy pubkey and save ...
chmod go-rwx -R .ssh/
```

After that I can easily connect.

I use `su -` to become root, and then add my user to sudoers group: `adduser alex sudo`.

I also edited the `/etc/sudoers` to set remove password check:
`%sudo   ALL=(ALL:ALL) NOPASSWD:ALL`

(and remember you have to logout/in for group to be taken into account)

## Setting up docker and docker-compose

> **✎ NOTE**: I finally saw after install that indeed [we have a docker installation script](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/scripts/install_docker.sh). 
> I should have used it !

Docker install, following https://docs.docker.com/engine/install/debian/
```bash
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo docker run hello-world
```

Docker-compose install, following https://docs.docker.com/compose/install/other/
```bash
$ sudo curl -SL https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
$ chmod a+x /usr/local/bin/docker-compose
```

We also check git is already installed

```bash
$ git --version
git version 2.30.2
```

And build-essential to have make
and some tools like jq and rsync
```bash
$ sudo apt install build-essential jq rsync
```



## Creating off user

This is the user that will be used by github actions.

On the monitoring VM, I use a random password, I also create authorized keys using the publickey for off:
```bash
$ sudo adduser off
$ sudo mkdir /home/off/.ssh
$ sudo vim /home/off/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBCfxLQoDV2n+FgI4DiHhFSKzHx4RS3ynrSsAN14kt+
 off-net@ovh1

$ sudo chown off:off -R /home/off/
$ sudo chmod go-rwx -R /home/off/.ssh
```

We need off user to be able to operate docker, add it to docker group:

```bash
$ sudo adduser off docker
```

## Setting up zfs share for ES backups

### Create share on ovh3

We want ES backups to be on the ovh3 backups server to avoid taking place on SSD. So we want to create a fs in /rpool/backup/monitoring-volumes and share it via nfs.

```bash
sudo zfs create /rpool/backups/monitoring-volumes
```

NFS sharing is automatically inherited from backups:

```bash
sudo zfs get all rpool/backups/monitoring-volumes
NAME                                 PROPERTY              VALUE                                 SOURCE
...
rpool/backups/monitoring-volumes  sharenfs              rw=@10.0.0.0/28,no_root_squash        inherited from rpool/backups
```

We can even see it in NFS conf:
```bash
$ sudo grep monitoring-es-backup /etc/exports.d/zfs.exports
/rpool/backups/monitoring-volumes 10.0.0.0/28(sec=sys,rw,no_subtree_check,mountpoint,no_root_squash)
```

### Mount it in monitoring VM

On monitoring VM:
```bash
$ sudo apt install nfs-common
$ sudo mkdir /mnt/monitoring-volumes
$ sudo vim /etc/fstab
...
# NFS share on ovh3
10.0.0.3:/rpool/backups/monitoring-volumes     /mnt/monitoring-volumes   nfs     rw      0 0
```

Try it:
```bash
sudo mount /mnt/monitoring-volumes
ls /mnt/monitoring-volumes
```

## Deploying

See https://github.com/openfoodfacts/openfoodfacts-monitoring/pull/58

I didn't have to edit secrets as they are all global.

Of course I add different crashes, but rectified the doc above all along the way…

### Migrating data and starting

#### Rsync setup

To keep my ssh agent around I use `ssh -A` and `sudo -E`
```bash
ssh -A offpre
sudo -E bash
```

To get the directory corresponding to a volume:

```bash
$ docker volume inspect elasticsearch-data|jq ".[]|[.Mountpoint,.Options.device]"

[
"/var/lib/docker/volumes/elasticsearch-data/_data"
]
```

Remember when using rsync that source ending slash is very important…

#### Elasticsearch + kibana

I started a rsync of volumes from 200 to 203:

```bash
rsync -a --delete --info=progress2 --rsync-path="sudo rsync" /var/lib/docker/volumes/elasticsearch-data/_data alex@10.1.0.203:/var/lib/docker/volumes/monitoring_elasticsearch-data/_data
```

We have warnings but it's ok.

Same for backups:
```bash
rsync -a --delete --info=progress2 --rsync-path="sudo rsync" /var/lib/docker/volumes/monitoring_elasticsearch-backup/_data/ alex@10.1.0.203:/mnt/monitoring-volumes/monitoring_elasticsearch-backup/
```

I stopped ES and kibana and ES exporter on old prod (200) and on new VM (203).

Re-runned above rsync commands.

Started ES and kibana on new VM.

I then changed the proxy to the new address kibana on 101:
in `kibana.openfoodfacts.org.conf`, 10.1.0.200 becomes 10.1.0.203

I also manually changed prometheus config on old VM to stare at 203 instead of 200 for elasticsearch (I could'nt deploy there any more), editing `configs/prometheus/config.yml` and using `docker-composes restart prometheus`

#### Influxdb, Prometheus, alert-manager and grafana

I started with a rsync of volumes from 200 to 203, for volumes:
* grafana-data --> monitoring_grafana-data
* prometheus-data --> monitoring_prometheus-data
* influxdb-data --> monitoring_influxdb-data
* alertmanager-data --> monitoring_alertmanager-data

```bash
for vname in {grafana,prometheus,influxdb,alertmanager}-dat
a;do echo "$vname --------------"; rsync -a --delete --info=progress2 --rsync-path="sudo rsync" /var/lib/docker/volumes/$vname/_data/ alex@10.1.0.203:/var/lib/docker/volumes/monitoring_$vname/_data/;done
```

It's very fast !

Then I stopped old monitoring:
```bash
sudo -u off docker-compose stop
```

Redo the above sync [^double_rsync].

And started services on 203.

I then changed config on reverse proxy for:
* alertmanager.openfoodfacts.org.conf
* grafana.openfoodfacts.org.conf
* monitoring.openfoodfacts.org.conf
* prometheus.openfoodfacts.org.conf

[^double_rsync]: The idea here is to minimize down time. So:  
1- you first rsync with new service down and old service up (you know it might not give a coherent state, but it's just to do most of the work);  
2- then you stop the old service, do a rsync (which will be fast because most work is already done);  
3- then you start new service.  
I did this, of course, because at first I though it might takes long.


### Breaking old deployment

To avoid an accidental restart of old stack on 200 VM, but still keep it around, I edited manually the docker-compose.yml with a bad syntax, and change ownership to root, so a deployment would break !

## Post migration

## Elasticsearch life cycle and snapshot policies

The day after migration, checking kibana, I realized index lifecycle management wasn't correctly setup, also the backup policy was not there.

First I had to manually add the backup repository in kibana (choosing a repo of type shared file system, naming it backups, at location `/opt/elasticsearch/backups`)

I decided to restore the `.kibana` index from last snapshot. I just followed the procedure to only restore it (not other indexes), but choosing to restore system settings.

After that I got index lifecycle policy correct for logs (with a hot / warm / cold etc. phases).