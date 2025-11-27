# 2025-11-27 Moving keycloak to scaleway

Keycloak is currently on off1.

We want to move it to scaleway-01.

It is currently using docker compose, running on a CT on proxmox.

As they have been recent problem with this approach on Proxmox 9.1,
I prefer to go for a VM as recommended by Proxmox.
Also now that we have VirtioFS enabling direct write to ZFS Datasets,
one important drawback is removed.

## Adding a zpool for data on scaleway-01

The host system is currently on the nvme in the rpool zpool.

But we have plenty of space left on the disk. We will set it up in a zfs-nvme zpool.

### Creating partitions

I first use parted to create the partition on scaleway-01

```bash
parted /dev/nvme2n1
GNU Parted 3.6
Using /dev/nvme2n1
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) unit s                                                           
(parted) print                                                            
Model: TS4TMTE250S (nvme)
Disk /dev/nvme2n1: 7814037168s
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags: 

Number  Start     End         Size        File system  Name   Flags
 1      34s       2048s       2015s                    grub   bios_grub
 2      4096s     1953791s    1949696s    fat32        boot   boot, esp
 3      1953792s  537108479s  535154688s  zfs          rpool
(parted) mkpart primary zfs 535154689s 100%
Warning: You requested a partition from 535154689s to 7814037167s (sectors 535154689..7814037167).
The closest location we can manage is 537108480s to 7814037134s (sectors 537108480..7814037134).
Is this still acceptable to you?
Yes/No?
(parted) name 4 zfs-nvme
(parted) print
Model: TS4TMTE250S (nvme)
Disk /dev/nvme2n1: 7814037168s
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start       End          Size         File system  Name   Flags
 1      34s         2048s        2015s                     grub   bios_grub
 2      4096s       1953791s     1949696s     fat32        boot   boot, esp
 3      1953792s    537108479s   535154688s   zfs          rpool
 4      537108480s  7814037134s  7276928655s  zfs          zfs-nvme
```

I did the same for `/dev/nvme0n1` but I add to issue a
`mkpart primary zfs 536872960s 100%` to get an aligned partition.

After that lsblk gives:
```
...
nvme2n1     259:0    0    3,6T  0 disk 
├─nvme2n1p1 259:1    0 1007,5K  0 part 
├─nvme2n1p2 259:2    0    952M  0 part 
├─nvme2n1p3 259:3    0  255,2G  0 part 
└─nvme2n1p4 259:8    0    3,4T  0 part 
nvme0n1     259:4    0    3,5T  0 disk 
├─nvme0n1p1 259:5    0   1007K  0 part 
├─nvme0n1p2 259:6    0      1G  0 part 
├─nvme0n1p3 259:7    0    255G  0 part 
└─nvme0n1p4 259:9    0    3,2T  0 part 
```
There is a slight difference in size between nvme2n1p4 and nvme0n1p4
but zpool won't care (it will use size of smallest partition).

We will let the zpool be created by ansible.

### Creating zfs-nvme zpool

I first get the id of my partitions by using:
```bash
ls -l /dev/disk/by-id/ |grep nvme.n1p4 |grep nvme-eui
`lrwxrwxrwx 1 root root 15 27 nov.  17:11 nvme-eui.00000000000000007c35485224e769cf-part4 -> ../../nvme2n1p4
lrwxrwxrwx 1 root root 15 27 nov.  17:17 nvme-eui.000000000000000100a0752249f51d6e-part4 -> ../../nvme0n1p4
```

I added the ZPool and some zfs dataset that I wanted to create
to host_vars/scaleway-01/proxmox.yml using those ids

Now I run the playbook to instanciate this:
```bash
ansible-playbook sites/proxmox-node.yml --tags zfs -l scaleway-01
```
## Creating the VM for docker on scaleway-01

I will create a VM on scaleway-01 to use docker.

I will use ansible recipe for that.

I will create a VM 200 and name it scaleway-docker-prod

- I added the server to inventory, in scaleway_vms group
- I added the scaleway-docker-prod-secrets in it's host vars to define the become password

## Using stunnel to connect to Postgres on off2

FIXME