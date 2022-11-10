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

```
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