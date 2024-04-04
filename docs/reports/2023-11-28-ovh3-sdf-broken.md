# Post-mortem 2023-11-28 Disk sdf errors on OVH3


## Event

When we bring the images nginx server back on ovh3, we had several time nginx completely blocked.
All NGINX processes are indefinitely waiting to read.
The only way to restart it was to do a hard reboot. Read on zfs seems to completely fail until reboot.
It happens several time in a few weeks, and even a few minutes after reboot.

We already had a disk replaced 4 months before, see [Post-mortem 2023-07-16 Disk sdc errors on OVH3](./2023-07-16-ovh3-sdc-broken.md)

## Analysis

Reading syslog on ovh3:
```
Nov 25 22:24:55 ovh3 smartd[2244]: Device: /dev/sde [SAT], SMART Usage Attribute: 194 Temperature_Celsius changed from 176 to 181
Nov 25 22:24:55 ovh3 smartd[2244]: Device: /dev/sdf [SAT], 8 Currently unreadable (pending) sectors
Nov 25 22:24:55 ovh3 smartd[2244]: Device: /dev/sdf [SAT], 2 Offline uncorrectable sectors
Nov 25 22:24:55 ovh3 smartd[2244]: Device: /dev/sde [SAT], SMART Usage Attribute: 194 Temperature_Celsius changed from 176 to 181
Nov 25 22:24:55 ovh3 smartd[2244]: Device: /dev/sdf [SAT], 8 Currently unreadable (pending) sectors
Nov 25 22:24:55 ovh3 smartd[2244]: Device: /dev/sdf [SAT], 2 Offline uncorrectable sectors
```

A smartctl long test on /etc/sdf systematically fails.

Looks like the disks on this server are 6 identical HGST HUH721212ALE601 (/dev/sda to /dev/sdf).
The official datasheet is not very informative: https://documents.westerndigital.com/content/dam/doc-library/en_us/assets/public/western-di[…]star-dc-hc500-series/data-sheet-ultrastar-dc-hc520.pdf

Our analysis was that we had a block (or more blocks) which failed to be read on /dev/sdf and this is what is completely blocking the server from times to times (Especially if we put "images" host on it). As we are not really able to locate this block and smarctl longtest fails before ending, 
@vince  proposed that we remove the drive from zpool and attempt a low level format in the hope it will identify bad blocks and mark them, also we can do a complete check of the disk, so that eventually, if needed, we can ask OVH to replace it.

C. Quest noted: No doubt sdf should be replaced as there is currently 72 pending sector to reallocate. As the pool is radidZ2, we have another disk providing redundancy.

## Repairing

### Asking replacement

We changed images.openfoodfacts.org DNS to point back to off2.

We put sdf in offline state and asked OVH to replace the disk on nov 29 at 9:50.
In between Christian launched a scrub on the pool.

The same day, before 12:40, the disk was replaced and we have a new disk /dev/sdf.

But at the same moment OVH told us sdb was having issues so they wanted to change it.
We didn't want to do it immediately, even with current redundancy it would be at risk.
Though we have enough redundancy so we can put sdb offline.

### Putting server offline (recovery boot mode)

So We rebooted in fail safe mode, the server was offline for some time.
This means:
* elasticsearch was offline (needs the backup directory which is a NFS mount)
* staging Open Food Facts (.net) won't work (it use NFS mount of products and images ZFS datasets)
and of course replications and backups of ovh1 and ovh2 were not happening.

I had to `zpool import -f rpool` (because the fail safe system is not the regular one).

Put sdb offline:
`zpool offline rpool /dev/sdb`

Resilver is launched: `zpool replace rpool /dev/sdf`


```
zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices is currently being resilvered.  The pool will
	continue to function, possibly in a degraded state.
action: Wait for the resilver to complete.
  scan: resilver in progress since Wed Nov 29 11:53:46 2023
	14.2T scanned out of 37.5T at 775M/s, 8h45m to go
	2.24T resilvered, 37.87% done
config:

	NAME             STATE     READ WRITE CKSUM
	rpool            DEGRADED     0     0     0
	  raidz2-0       DEGRADED     0     0     0
	    sda          ONLINE       0     0     0
	    sdb          OFFLINE      0     0     0
	    sdc          ONLINE       0     0     0
	    sdd          ONLINE       0     0     0
	    sde          ONLINE       0     0     0
	    replacing-5  DEGRADED     0     0     0
	      old        OFFLINE      0     0     0
	      sdf        ONLINE       0     0     0
	logs
	  nvme0n1p4      ONLINE       0     0     0
	cache
	  nvme0n1p5      ONLINE       0     0     0

errors: No known data errors
```

Some backups were not yet on the free side, I rysnc them (rpool/backups/robotoff and storage/)


## Resilver speed

On 30 nov I see that the resilver is very slow. 
We have:

```
	15.7T scanned out of 37.5T at 88.0M/s, 72h0m to go
	2.59T resilvered, 41.91% done
```
it seems to go very slowly (from 41,77% to 41,91 in 6 hours !).

`zpool iostat -vl 5` shows that it's working.

Thanks to Christian we boost the zfs resilver priority (the server is in rescue mode, it's the only priority !)
```bash
echo 8000 > /sys/module/zfs/parameters/zfs_resilver_min_time_ms
# later
echo 15000 > /sys/module/zfs/parameters/zfs_resilver_min_time_ms
```

I/O bumps from 25M/s to 200M/s

see https://devopstales.github.io/linux/speed_up_zfs/

The 1/12 at 16 we ar at 73,10%

The 2/12 at 12 we are at 94,41%

Finally the same day around 23:
```bash
  scan: resilvered 6.38T in 72h58m with 0 errors on Sat Dec  2 12:52:16 2023
```

### Replace sdb

We were thus able to ask for OVH intervention to replace sdb

The morning after, I was able to reboot server normally and launch the resilver:
`zpool replace rpool /dev/sdb`

I also relaunched staging and robotoff.

On 7/12 resilver was done: 
```
scan: resilvered 6.76T in 3 days 17:09:17 with 0 errors on Thu Dec  7 01:03:16 2023
```