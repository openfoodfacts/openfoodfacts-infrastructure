
### ZFS : the basics

24 feb 2022 - by Christian Quest


---

### Some story

* [**OpenZFS**](https://openzfs.github.io/openzfs-docs/#)

* written 20 years ago.

* by Sun Micro System.

* For some time, licensing problems, now solved.

* A lot of forks have joined again (OpenZFS) and more features are developped


---

### ZFS glossary

forget partitions / filesystem / lvm / md etc.

1. storage space (full disks, parititons, even files, S3 planned !)
2. vdev - virtual device (assemble different storage space together, defines redundancy)
3. pool - gather different virtual devices into a big unique space
4. datasets - they are like the filesystem (but they are not a filesystem 😉)

* ⚠️ there is no traditional notion of *partitions* in zfs

* see also: https://openzfs.github.io/openzfs-docs/man/7/zfsconcepts.7.html

---

### ZFS virtual device (vDev)

* vDev = set of storage spaces :

  * **Recommended:** use whole disks in vDev

  * But you can optionally add a partition (part of a disk).

  * You can even use a file (good for testing or dev, not for prod).

  * (in next ZFS version even S3 storage can be added)

* **Important**:
  * In one vdev there is only one redundancy configuration. (but in a pool you can put vdev with different redundancy)
  * In a vdev all disk must have same size.


---

### vDev manipulation

* Most of the time, you create the vdev by adding it to the pool.

* You can't extend a vDev by adding more disks (so far).

* But you can change the disks in the vdev one by one by bigger disks. The vdev is expanded when all disks have increased size.


* There are special vdevs:
  * read cache
  * write journaling

---

### ZFS : pools

* There can be several virtual devices in a pool.

* Eg:
  * a pool with a vdev with 5 disks in a RAIDZ1 vdev
  * and, later, a vdev with 5 more disks in a RAIDZ2 vdev

* You can remove some vdev from a pool (VDEV) but some cannot be removed - for example ZRAID vdevs.

  So think carefully before adding them.

---

### ZFS vdev redundancy

* Example:
  * 5 x 4TB disks: you have 20 TB of storage space
  * to get redundancy, mirrors, raid, you can rearrange them using virtual devices (vdev)

* That vdev I can ask the level of redundancy (number of disk that  can disapear without data lost)
  * RAIDZ1 - RAIDZ2 - RAIDZ3 (1, 2 or 3 disk redondancy)
  * mirror: all data written on all disks (max redundancy)
  * or no redundancy at all…

---

### Create a zpool and vdev inside it

* `zpool create mypool raidz1 sda sdb sdc sdd sde`

  Creates a pool named mypool with one vdev in RAIDZ1 with the 5 disk

* `zpool add mypool mirror sdf sdg`

  Adds a new vdev in mirror mode with two disks

---

### Spare disks

* You can add spare disks in your pool. That is a disk which is not in a vdev, but can be used as a replacement if a disk fails in any vdev (replacement will be automatic).

* Ex: 3 vdev ZRAID1, the remaining spare may go in any of the vdev

* Maybe a disk that was lost, may be in fact still resetable (after some tests), and can become the new spare.


---

### Datasets

* Each pool can have as many datasets as wanted

* Each dataset has it's own settings can be compressed, encrypted etc.

* You don't know how the datasets is laid out in the pool.

* Datasets have no defined size - they can grow (but you may place quotas)

* Datasets are created in the pool, not on a specific vdev

---


### Datasets (2)


* The command to manage datasets in `zfs`

* ZFS is a copy on write (COW) storage system. Data is always written to a new place, not where you read it previously.
Thanks to that we can create snapshots (freeze part  dataset at a point in time, while still writing to it).


---

### Dataset creation example

* `zfs create mypool/mydataset `

  Creates a dataset with default settings (taking whole pool size)

* `zfs set compress=on mypool/mydataset`

  Compression will be active for everything added after that

---

### Dataset size


* For dataset size:
  * either add a quota on total size
  * or add a quota

* `zfs set refquota=100G mypool/mydataset`

  Will limit  the quantity of data to 100G, but without taking into account snapshots.

---


### snapshots

* You can diff two snapshots. This enables very cheap backups.

* Really helpful on Open Food Facts for the products (/path/bar/code/version.sto) - it created millions of files, and it was hard to backup because rsync must look at every files (more than 2/3 hours). With ZFS we are down to below a minute. And we are able to backup every 1/2 hour.

* Also the snapshot is immediatly usable (no restore needed), it's already the dataset.

* When you use snapshots + diff, you can access any version of snapshot thanks to virtual folders.

* You can also remove some diffs.

* To sync ZFS you can snapshot at regular intervals.

---

### Clone

* You can create writable snapshots, known as clones. It's like a fork of the filesystem.

* For example you want to test a script, you can test it on a clone.

* If you remove the clone, your changes are lost, but you can also promot the clone to replace the main dataset.

* At Open Food Facts stagging areas use clone of backup datasets (and mount them through nfs).

---

### ZFS snapshot and sync

* `zfs send mypool/mydataset | zfs recv otherpool/otherdataset`

  Generates a stream of data. Then store it either on a file or on another dataset.

* `zfs snapshot mypool/mydataset@myshanpshotname`

  create a snapshot.

* `zfs send -I mypool/mydataset@oldsnap mypool/mydataset@newpool`

  creates an incremental snapshot (-i), (-I sends all snapshot inbetween the two)

* **Note:** On the receiving side, you can also maintain a receive token, to be able to resume send at a specific point if it breaks in the middle.

---

### Block storage datasets

* Datasets can be blocks. And you can format that block storage as ext4, etc. All read/write are done on the dataset, so you still get snapshots, compression, etc.

* There is shortcuts in ZFS for this option.

---

### Some features

* **encryption**

  Datasets can be encrypted. Thanks to that you can have encrypted snapshots and make the backup without deciphering data.

* **Compression**

  Dataset can use different compression algorithm LZ4, LZ0 and Zstandard.

* **NFS** is integrated to ZFS, which is very handy.


---

### Performance / Data safety tradeoff

* ZFS is not the champion of performance because it prefers data safety.

* All data have [checksums](https://openzfs.github.io/openzfs-docs/Basic%20Concepts/Checksums.html).

* real life example: checksum errors once happens because of a failing SSD Cache. When the SSD was removed it all went back to normal.

* `zscrub` verifies data integrity. If a checksum is wrong, the data is moved to another place (auto-repair).

* If a disk have bad sectors - an error is reported. Thanks to redundancy zfs will write again the data (to ensure redundancy). And zfs will manage "pending sectors" - sectors that cannot be read, that will come back (reallocated) after a new successful write.

---

### ZFS Read Cache

* cache is at pool level

* ZFS has a RAM cache and possibly a 2nd level with SSD, with cache vdev.

* cache balances Least Recently Used (LRU) and Most Recently Used (MRU), this avoid cache poisonning.
  (which happens with LRU cache when you read a big file (you loose all interesting cache))

---

### ZFS write with journaling

* At pool level.

* Organizing data on the disk may need to wait for big writes.

* ZFS has a write cache in RAM, but it's not safe. You can add a SSD to keep a journaling of last write, used only if we lose RAM content after a crash. (you need fast disk and disks that accepts a lot of rewrite - you just need a few gigabits)

---

### Deduplication (at pool level)

* You can deduplicate data in a pool.
* It uses a checksum to avoid
* It save spaces but needs RAM and slows down writing quite a lot.
* As a consequence, few people use it.

* It's real time dedup (no async dedup, yet).

---

### ZFS daemon

* [ZED](https://openzfs.github.io/openzfs-docs/man/8/zed.8.html) is the ZFS Event Daemon.

* If there are important errors, sends a mail to the administrator.

* Notifications from ZED are really important.

---

### SSD management

* SSD timming can be automatic, but you can launch it with `zpool trim`

---

### ZFS limits

Very hard to hit limits on number of directories and files.

Same for file size.


---

### Summary

* ZFS - very stable
* focused on data safety
  * with checksum
  * transparent sectors handling, etc.
  * recommended to use ECC memory?
* not the best for performance, but still good
* if you loose too much redundancy you loose the entire pool (as data is anywhere)
  * for very large space, multiple pools might be considered

* https://cq94.medium.com/zfs-vous-connaissez-vous-devriez-1d2611e7dad6

---

# Using ZFS on your own machine

* It make sense using ZFS to sync prod data on your
  * maybe using a partition or a large file

* Btrfs - might be a good option
  * more flexible on pool / vdev definitions
  * ⚠️ but beware stripping raid which is a bit buggy

* ZFS for root - only if you know it well

