# 2025-08-19 OVH3 Disk Replace

This time sdf was failing (serial id: 8DH4VTRH) was replaced.

To start with it's all the same as [2025-06-27 OVH3 Disk Replace](./2025-06-27-ovh3-disk-replace.md)

But then there was a problem !

## Problem with replaced disk

### Symptoms

After we do the `zpool replace` to integrate the new disk,
resilver restarted.

After one day, I observed that it was running at a far lower pace than expected.
It had only resilvered about 500M in 24h, out of 52T,
which would mean months before full resilver.

On munin I can see an impressive latency for sdf, around 140ms (instead of 4/8ms for other disks)

I asked myself if it was an artefact and decided to observe some day after.
Meanwhile I launched a smartctl long test to see.
```bash
smartctl -t long /dev/sdf
```

On friday I look at it again.
Resilver was still unbearably slow:
```
  scan: resilver in progress since Tue Aug 19 12:29:32 2025
	2.17T scanned at 8.63M/s, 2.03T issued at 8.06M/s, 53.2T total
	277G resilvered, 3.81% done, no estimated completion time
```
and smartctl test result is clear:
```
smartctl -a /dev/sdf
=== START OF READ SMART DATA SECTION ===
SMART overall-health self-assessment test result: FAILED!
Drive failure expected in less than 24 hours. SAVE ALL DATA.
See vendor-specific Attribute list for failed Attributes.
```

### remediation

Before asking ovh3 another disk replacement,
I decided to put sdf offline,
so that resilver is stopped,
and all ZFS syncs can happen.

```bash
$ zpool offline rpool /dev/sdf
$ zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices is currently being resilvered.  The pool will
	continue to function, possibly in a degraded state.
action: Wait for the resilver to complete.
  scan: resilver in progress since Tue Aug 19 12:29:32 2025
	2.17T scanned at 8.59M/s, 2.04T issued at 8.09M/s, 53.2T total
	280G resilvered, 3.84% done, no estimated completion time
config:

	NAME                        STATE     READ WRITE CKSUM
	rpool                       DEGRADED     0     0     0
	  raidz2-0                  DEGRADED     0     0     0
	    sda                     ONLINE       0     0     0
	    sdb                     ONLINE       0     0     0
	    sdc                     ONLINE       0     0     0
	    sdd                     ONLINE       0     0     0
	    sde                     ONLINE       0     0     0
	    replacing-5             UNAVAIL      0     0     0  insufficient replicas
	      12927432126504181617  UNAVAIL      0     0     0  was /dev/sdf1/old
	      sdf                   OFFLINE      0     0     0  (resilvering)

errors: No known data errors
```

I did also lower the resilver latency
```bash
echo 1 > /sys/module/zfs/parameters/zfs_resilver_min_time_ms
```

I then decided to let some time (at least 1 day) for zfs syncs to happen.

### New disk change

After the usual ticket exchanges, we got the disk changed.

Although note that this time they had rebooted the server in "rescue mode"
and I did have to go to the OVH management console to put it back to normal boot,
and restart the server from there.

### Trying (and failing) to stop previous resilver

After the boot, the disk is there but the state is that the disk is still resilvering on the old disk !

```bash
# zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices is currently being resilvered.  The pool will
	continue to function, possibly in a degraded state.
action: Wait for the resilver to complete.
  scan: resilver in progress since Tue Aug 19 12:29:32 2025
	20.6T scanned at 236M/s, 20.4T issued at 145M/s, 53.2T total
	280G resilvered, 38.32% done, 2 days 17:57:14 to go
config:

	NAME                        STATE     READ WRITE CKSUM
	rpool                       DEGRADED     0     0     0
	  raidz2-0                  DEGRADED     0     0     0
	    sda                     ONLINE       0     0     0
	    sdb                     ONLINE       0     0     0
	    sdc                     ONLINE       0     0     0
	    sdd                     ONLINE       0     0     0
	    sde                     ONLINE       0     0     0
	    replacing-5             UNAVAIL      0     0     0  insufficient replicas
	      12927432126504181617  UNAVAIL      0     0     0  was /dev/sdf1/old
	      sdf                   OFFLINE      0     0     0
```

I launched a
```bash
zpool replace rpool /dev/sdf
```

I got:
```bash
# zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices is currently being resilvered.  The pool will
	continue to function, possibly in a degraded state.
action: Wait for the resilver to complete.
  scan: resilver in progress since Tue Aug 19 12:29:32 2025
	20.6T scanned at 232M/s, 20.4T issued at 142M/s, 53.2T total
	280G resilvered, 38.33% done, 2 days 19:24:49 to go
config:

	NAME                        STATE     READ WRITE CKSUM
	rpool                       DEGRADED     0     0     0
	  raidz2-0                  DEGRADED     0     0     0
	    sda                     ONLINE       0     0     0
	    sdb                     ONLINE       0     0     0
	    sdc                     ONLINE       0     0     0
	    sdd                     ONLINE       0     0     0
	    sde                     ONLINE       0     0     0
	    replacing-5             DEGRADED     0     0     0
	      12927432126504181617  UNAVAIL      0     0     0  was /dev/sdf1/old
	      old                   OFFLINE      0     0     0
	      sdf                   ONLINE       0     0     0  (awaiting resilver)

errors: No known data errors
```

So I tried to remove 12927432126504181617 volume.
```bash
zpool detach rpool 12927432126504181617
```

But resilver seems to continue…
```bash
zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices is currently being resilvered.  The pool will
	continue to function, possibly in a degraded state.
action: Wait for the resilver to complete.
  scan: resilver in progress since Tue Aug 19 12:29:32 2025
	20.6T scanned at 211M/s, 20.4T issued at 130M/s, 53.2T total
	283G resilvered, 38.36% done, 3 days 01:29:09 to go
config:

	NAME             STATE     READ WRITE CKSUM
	rpool            DEGRADED     0     0     0
	  raidz2-0       DEGRADED     0     0     0
	    sda          ONLINE       0     0     0
	    sdb          ONLINE       0     0     0
	    sdc          ONLINE       0     0     0
	    sdd          ONLINE       0     0     0
	    sde          ONLINE       0     0     0
	    replacing-5  DEGRADED     0     0     0
	      old        OFFLINE      0     0     0
	      sdf        ONLINE       0     0     0  (resilvering)

errors: No known data errors
```

So I tried a:

```bash
zpool detach rpool sdf
```

But it does not stop resilver…
```
zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices is currently being resilvered.  The pool will
	continue to function, possibly in a degraded state.
action: Wait for the resilver to complete.
  scan: resilver in progress since Tue Aug 19 12:29:32 2025
	20.6T scanned at 203M/s, 20.4T issued at 130M/s, 53.2T total
	285G resilvered, 38.38% done, 3 days 01:35:30 to go
config:

	NAME        STATE     READ WRITE CKSUM
	rpool       DEGRADED     0     0     0
	  raidz2-0  DEGRADED     0     0     0
	    sda     ONLINE       0     0     0
	    sdb     ONLINE       0     0     0
	    sdc     ONLINE       0     0     0
	    sdd     ONLINE       0     0     0
	    sde     ONLINE       0     0     0
	    sdf     OFFLINE      0     0     0

errors: No known data errors
```

So finally I did a
```bash
zpool replace rpool sdf
```
And it's always the same:
```bash
  pool: rpool
 state: DEGRADED
status: One or more devices is currently being resilvered.  The pool will
	continue to function, possibly in a degraded state.
action: Wait for the resilver to complete.
  scan: resilver in progress since Tue Aug 19 12:29:32 2025
	20.8T scanned at 84.9M/s, 20.7T issued at 67.1M/s, 53.2T total
	337G resilvered, 38.82% done, 5 days 21:14:03 to go
config:

	NAME             STATE     READ WRITE CKSUM
	rpool            DEGRADED     0     0     0
	  raidz2-0       DEGRADED     0     0     0
	    sda          ONLINE       0     0     0
	    sdb          ONLINE       0     0     0
	    sdc          ONLINE       0     0     0
	    sdd          ONLINE       0     0     0
	    sde          ONLINE       0     0     0
	    replacing-5  DEGRADED     0     0     0
	      old        OFFLINE      0     0     0
	      sdf        ONLINE       0     0     0  (resilvering)

errors: No known data errors
```

It's a bit weird, but it seems there is really no way to halt a resilver.

```bash
zpool scrub -s rpool
cannot cancel scrubbing rpool: currently resilvering
```

**Conclusion**: we are forced to wait for the end of the resilver and launch a new scrub after that…

### Second resilver

At the end of the current resilver,
ZFS started by itself a new resilver (I tried to start a scrub but the new resilver did start immediately).

```
# zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices is currently being resilvered.  The pool will
        continue to function, possibly in a degraded state.
action: Wait for the resilver to complete.
  scan: resilver in progress since Fri Aug 29 00:09:16 2025
        1.90T scanned at 70.9M/s, 1.90T issued at 70.6M/s, 53.8T total
        262G resilvered, 3.52% done, 8 days 22:02:30 to go
config: 

        NAME             STATE     READ WRITE CKSUM
        rpool            DEGRADED     0     0     0
          raidz2-0       DEGRADED     0     0     0
            sda          ONLINE       0     0     0
            sdb          ONLINE       0     0     0
            sdc          ONLINE       0     0     0
            sdd          ONLINE       0     0     0
            sde          ONLINE       0     0     0
            replacing-5  DEGRADED     0     0     0
              old        OFFLINE      0     0     0
              sdf        ONLINE       0     0     0  (resilvering)

errors: No known data errors

