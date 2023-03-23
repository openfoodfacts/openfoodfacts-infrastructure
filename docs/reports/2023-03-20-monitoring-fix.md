## Setup policy

* upgrade filebeat:
  * see [f0799c2bc475b5c26ba5b0af8c444b4a71bbd6db](https://github.com/openfoodfacts/openfoodfacts-monitoring/commit/f0799c2bc475b5c26ba5b0af8c444b4a71bbd6db)

* changed filebeat configuration:

  * see [17eb23e47863140a2958d68f31c8c1107fc8f1bb](https://github.com/openfoodfacts/openfoodfacts-monitoring/commit/17eb23e47863140a2958d68f31c8c1107fc8f1bb)

* in Kibana:
  * changed template configuration:
    * index pattern:
    * settings:
      * lifecycle policy
      * compression
  * changed life cycle policy:
    * only hot / delete phase, because we don't have multiple nodes however

## Cleaning

* in Kibana: removed a lot of indexes and data streams
* 

## Extending disk space

In proxmox:
* snapshot the VM 203
* hardware -> select disk -> resize disk -> disk increment: 80Go (to reach 120 Go)

In ssh:

parted
GNU Parted 3.4
Using /dev/sda
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) p                                                                
Model: QEMU QEMU HARDDISK (scsi)
Disk /dev/sda: 129GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags: 

Number  Start   End     Size    Type      File system     Flags
 1      1049kB  41,3GB  41,3GB  primary   ext4            boot
 2      41,3GB  42,9GB  1649MB  extended                  lba
 5      41,3GB  42,9GB  1648MB  logical   linux-swap(v1)

(parted) q


swapoff -a


```
parted /dev/sda
# change unit to sectors
(parted) u
Unit?  [compact]? s
# remove swap partitions
(parted) rm 5
(parted) rm 2
# print to check
# resize partition 1, leaving space for swap, ending just before a multiple of 2048
(parted) resizepart 1
Warning: Partition /dev/sda1 is being used. Are you sure you want to continue?
Yes/No? y
End? 249706495s
# print
umber  Start  End         Size        Type     File system  Flags
 1      2048s       249706495s  249704448s  primary  ext4            boot
# recreate swap (Start is end of part 1 + 1)
(parted) mkpart
Partition type?  primary/extended? primary
File system type?  [ext2]? linux-swap
Start? 249706496s
End? -1s
(parted) p
Number  Start       End         Size        Type     File system     Flags
 1      2048s       249706495s  249704448s  primary  ext4            boot
 2      249706496s  251658239s  1951744s    primary  linux-swap(v1)  lba
(parted) quit
```

We recreated swap, now we have to format it:
```
mkswap /dev/sda2
```

show new uids:
```
blkid /dev/sda{1,2}
/dev/sda1: UUID="9f60eb6f-5c31-42d1-8012-cddeccd5c7d1" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="1a8a9d5e-01"
/dev/sda2: UUID="e555d486-31bc-4333-9e62-d292f7e7e36e" TYPE="swap" PARTUUID="1a8a9d5e-02"
```


Change /etc/fstab accordingly (`sda1` UUID did not change, only swap changed):

```
# / was on /dev/sda1 during installation
UUID=9f60eb6f-5c31-42d1-8012-cddeccd5c7d1 /               ext4    errors=remount-ro 0       1
# swap was on /dev/sda2 during installation
UUID=e555d486-31bc-4333-9e62-d292f7e7e36e none            swap    sw              0       0
```

Now we resized the partition, but we have to resize the filesystem. Let's resize sda1:
```
resize2fs /dev/sda1
```

Reactivate swap:
```
swapon -a
```

Let's see our changes:

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       118G   28G   85G  25% /
```