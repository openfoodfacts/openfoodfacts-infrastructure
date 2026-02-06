# 2025-11-27 creating scaleway zfs-nvme

On scaleway servers, we setup the zfs pools `rpool` and `zfs-hdd`.
But we still have a lot of space on nvme, that we will use for data.
So we have to create `zfs-nvme` pool on each server.

## Adding a zpool for data on scaleway-01

The host system is currently on the nvme in the `rpool` zfs pool.

But we have plenty of space left on the disk. We will set it up in a `zfs-nvme` zfs pool.

### Creating partitions on scaleway-01

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

### Creating zfs-nvme zpool on scaleway-01

I first get the id of my partitions by using:
```bash
ls -l /dev/disk/by-id/ |grep nvme.n1p4 |grep nvme-eui
`lrwxrwxrwx 1 root root 15 27 nov.  17:11 nvme-eui.00000000000000007c35485224e769cf-part4 -> ../../nvme2n1p4
lrwxrwxrwx 1 root root 15 27 nov.  17:17 nvme-eui.000000000000000100a0752249f51d6e-part4 -> ../../nvme0n1p4
```

I added the ZPool and some zfs dataset that I wanted to create
to `host_vars/scaleway-01/proxmox.yml` using those ids

Now I run the playbook to instanciate this:
```bash
ansible-playbook sites/proxmox-node.yml --tags zfs -l scaleway-01
```

I bumped into a problem while running this because zfs-dkms would not install…

Part of the log:

```
...
Error! Module version 2.3.4-1~bpo13+1 for spl.ko
is not newer than what is already found in kernel 6.14.11-4-pve (2.3.4-pve1).
You may override by specifying --force.
...
Errors were encountered while processing:
 zfs-dkms
 proxmox-kernel-6.17.2-2-pve-signed
 proxmox-kernel-6.17
 proxmox-default-kernel
 proxmox-ve
```

`uname -a` tells be we are using kernel 6.15.11-4-pve.

I tried to reboot to get the new kernel but it goes wrong and I lost the server… (and IPMI access was not yet setup!)

**So I decided to switch for an install scaleway-02!**

### Finishing (later on) on scaleway-01
I returned to this task when scaleway-01 was back online (see report about disk problem on 2025-12-09).


I Create the zpool manually:
```bash
zpool create zfs-nvme -f -o ashift=12 mirror nvme-eui.00000000000000007c35485224e769cf-part4 nvme-eui.000000000000000100a0752249f51d6e-part4
```
And then run locally ansible:
```bash
ansible-playbook sites/proxmox-node.yml --tags zfs -l scaleway-01
```

## Adding a zpool for data on scaleway-02

The host system is currently on the nvme in the `rpool` zpool.

But we have plenty of space left on the disk. We will set it up in a `zfs-nvme` zpool.

### Upgrading the server

Because of my previous problem on scaleway-01,
I decided to first do a full dist-upgrade before
doing anything else.
I simply did the 
```bash
sudo apt update
sudo apt dist-upgrade
```
it went well!

### Creating partitions on scaleway-02

I first use parted to create the partition on scaleway-02

```bash
parted /dev/nvme1n1
GNU Parted 3.6
Using /dev/nvme1n1
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) unit s                                                           
(parted) print                                                            
Model: TS4TMTE250S (nvme)
Disk /dev/nvme1n1: 7814037168s
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags: 

Number  Start     End          Size         File system  Name  Flags
 1      34s       2047s        2014s                           bios_grub
 2      2048s     2099199s     2097152s     fat32              boot, esp
 3      2099200s  1073741824s  1071642625s  zfs
(parted) mkpart primary zfs 1071642626s 100%                              
Warning: You requested a partition from 1071642626s to 7814037167s (sectors
1071642626..7814037167).
The closest location we can manage is 1073741825s to 7814037134s (sectors 1073741825..7814037134).
Is this still acceptable to you?
Yes/No? y                                                                 
Warning: The resulting partition is not properly aligned for best performance: 1073741825s % 2048s
!= 0s
Ignore/Cancel? C
(parted) mkpart primary zfs 1073743872s 7814035456s
(parted) name 4 zfs-nvme
(parted) print
Model: TS4TMTE250S (nvme)
Disk /dev/nvme1n1: 7814037168s
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start        End          Size         File system  Name      Flags
 1      34s          2047s        2014s                               bios_grub
 2      2048s        2099199s     2097152s     fat32                  boot, esp
 3      2099200s     1073741824s  1071642625s  zfs
 4      1073743872s  7814035456s  6740291585s  zfs          zfs-nvme
```

I did the same for `/dev/nvme0n1` but I add to issue a
`mkpart primary zfs 1073743872s 100%` to get an aligned partition.

After that lsblk gives:
```
...
nvme1n1     259:0    0  3,6T  0 disk 
├─nvme1n1p1 259:1    0 1007K  0 part 
├─nvme1n1p2 259:2    0    1G  0 part 
├─nvme1n1p3 259:3    0  511G  0 part 
└─nvme1n1p4 259:8    0  3,1T  0 part 
nvme0n1     259:4    0  3,5T  0 disk 
├─nvme0n1p1 259:5    0 1007K  0 part 
├─nvme0n1p2 259:6    0    1G  0 part 
├─nvme0n1p3 259:7    0  511G  0 part 
└─nvme0n1p4 259:9    0    3T  0 part
```
There is a slight difference in size between nvme2n1p4 and nvme0n1p4
but zpool won't care (it will use size of smallest partition).


### Creating zfs-nvme zpool on scaleway-02

I decided I would not create zpool using ansible,
because of previous problems on scaleway-01.

The problem might have come because the zfs-dkm install 
triggered the upgrade of this single package without
upgrading other packages, thus creating an inconsistency.

Christian sees it as very risky to use ansible on a proxmox host.
We need to think about this.

I first get the id of my partitions by using:
```bash
ls -l /dev/disk/by-id/ |grep nvme.n1p4 |grep nvme-eui
lrwxrwxrwx 1 root root 15  2 déc.  12:39 nvme-eui.00000000000000007c35485224e769fa-part4 -> ../../nvme1n1p4
lrwxrwxrwx 1 root root 15  2 déc.  12:45 nvme-eui.000000000000000100a07525513740ea-part4 -> ../../nvme0n1p4
```

Create the zpool:
```bash
zpool create zfs-nvme -f -o ashift=12 mirror nvme-eui.00000000000000007c35485224e769fa-part4 nvme-eui.000000000000000100a07525513740ea-part4
```

I had to add the `-f` flag because my disk don't have the same size,
and zfs warn about this:
```
se '-f' to override the following errors:
mirror contains devices of different sizes
```

I added the ZPool and some zfs dataset that I wanted to create
to host_vars/scaleway-02/proxmox.yml using those ids

Now I run the playbook to instanciate this:
```bash
ansible-playbook sites/proxmox-node.yml --tags zfs -l scaleway-02
```

## Creating zfs-nvme on scaleway-03

While at it,

I follow exactly the same procedure as on scaleway-02

* dist upgrade first
* parted, with final partitions as follow:
  ```bash
  parted /dev/nvme0n1 unit s print
  Model: Micron_7400_MTFDKBG3T8TDZ (nvme)
  Disk /dev/nvme0n1: 7501476528s
  Sector size (logical/physical): 512B/4096B
  Partition Table: gpt
  Disk Flags: 

  Number  Start       End          Size         File system  Name      Flags
  1      34s         2047s        2014s                               bios_grub
  2      2048s       2099199s     2097152s     fat32                  boot, esp
  3      2099200s    536870912s   534771713s   zfs
  4      536872960s  7501475839s  6964602880s               zfs-nvme
  parted /dev/nvme1n1 unit s print
  Model: TS4TMTE250S (nvme)
  Disk /dev/nvme1n1: 7814037168s
  Sector size (logical/physical): 512B/512B
  Partition Table: gpt
  Disk Flags: 

  Number  Start       End          Size         File system  Name      Flags
  1      34s         2047s        2014s                     grub      bios_grub
  2      2048s       2099199s     2097152s     fat32        boot      boot, esp
  3      2099200s    536870912s   534771713s   zfs          rpool
  4      536872960s  7814035455s  7277162496s               zfs-nvme
  ```
* ```bash
  zpool create zfs-nvme -f -o ashift=12 mirror nvme-eui.00000000000000007c35485224e769e6-part4 nvme-eui.000000000000000100a0752249f51e2a-part4
  ```

## Adding it to ZFS storages

I edited `host_vars/scaleway-02/proxmox.yml`
to add `zfs-nvme/pve` to `proxmox_node__zfs_filesystems`.

I did the same for `scaleway-01` and `scaleway-03` (but can't apply it to scaleway-01) as it's currently down.

As storage are the same on all nodes,
I moved `proxmox_node__pve_storages` to `group_vars/pvescaleway/proxmox.yml`,
and added the `zfs-nvme-pve` storage.

Before running ansible, I dist-upgrade the hosts, to avoid the problem I had with `scaleway-01`.

I run:
```bash
ansible-playbook sites/proxmox-node.yml --tags zfs,storage -l scaleway-02,scaleway-03 -e _init_node=scaleway-02
```
(and later on `scaleway-01` when it was up again)