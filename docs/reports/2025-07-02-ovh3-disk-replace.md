# 2025-07-02 OVH3 Disk Replace

## Symptoms

During the resilver was finished after [last disk replacement, few days ago](./2025-06-27-ovh3-disk-replace.md),

ZFS reported errors with /dev/sdb on the rpool ZFS pool.

```
The number of I/O errors associated with a ZFS device exceeded
acceptable levels. ZFS has marked the device as faulted.

 impact: Fault tolerance of the pool may be compromised.
    eid: 12619
  class: statechange
  state: FAULTED
   host: ovh3
   time: 2025-06-28 13:26:17+0000
  vpath: /dev/sdb1
  vphys: pci-0000:00:1f.2-ata-2
  vguid: 0xEF1AC8F34C562144
  devid: ata-HGST_HUH721212ALE601_5PG578XF-part1
   pool: 0x0600B76D0B2E72DB
```

I can see it with zpool status
```
zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices are faulted in response to persistent errors.
	Sufficient replicas exist for the pool to continue functioning in a
	degraded state.
action: Replace the faulted device, or use 'zpool clear' to mark the device
	repaired.
  scan: resilvered 8.56T in 4 days 16:34:51 with 0 errors on Wed Jul  2 06:45:23 2025
config:

	NAME        STATE     READ WRITE CKSUM
	rpool       DEGRADED     0     0     0
	  raidz2-0  DEGRADED     0     0     0
	    sda     ONLINE       0     0     0
	    sdb     FAULTED     31     0     0  too many errors
	    sdc     ONLINE       0     0     0
	    sdd     ONLINE       0     0     0
	    sde     ONLINE       0     0     0
	    sdf     ONLINE       0     0     0

errors: No known data errors
```

## Asking disk replacement

At 17:13, I asked OVH for disk replacement using their support.

To get the serial number:
`smartctl -i /dev/sdb | grep "Serial Number"`


```
CS11289820

Numéro de série du ou des disques défectueux :
5PG578XF

Si le ou les disques à remplacer ne sont pas détectés, renseignez ici les numéros de série des disques à conserver :
5PHH715D
8DJ8YH1H
5PHAYLUF
8CKERNSE
8DH4VTRH

Pour les serveurs de type HG ou FS uniquement, si l’identification LED n’est pas disponible, merci de nous confirmer le changement de pièce en arrêtant votre serveur (coldswap) :
No

Possédez-vous une sauvegarde de vos données ?
yes

Quel est l'état de vos volumes RAID ?
We don't have material RAID
We use ZFS raidz2-0.

Informations complémentaires :
We want to replace sdb device asap.

Quel est le résultat des tests smartctl ?
zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices are faulted in response to persistent errors.
 Sufficient replicas exist for the pool to continue functioning in a
 degraded state.
action: Replace the faulted device, or use 'zpool clear' to mark the device
 repaired.
  scan: resilvered 8.56T in 4 days 16:34:51 with 0 errors on Wed Jul  2 06:45:23 2025
config:

 NAME        STATE     READ WRITE CKSUM
 rpool       DEGRADED     0     0     0
   raidz2-0  DEGRADED     0     0     0
     sda     ONLINE       0     0     0
     sdb     FAULTED     31     0     0  too many errors
     sdc     ONLINE       0     0     0
     sdd     ONLINE       0     0     0
     sde     ONLINE       0     0     0
     sdf     ONLINE       0     0     0

errors: No known data errors
```

The OVH services automatically created a concurrent ticket (CS11289821) at 17:20
and at 22:26 (5 hours later) the disk was replaced.

## Resilvering

The morning after I logged on ovh3 and replace the old disk with the new one:

```bash
zpool replace rpool /dev/sdb
```
(note: I add to type it twice because I was getting a
`cannot open '/dev/sdb1': Device or resource busy`,
there might be some race condition with the partition creation).

I speed up the resilver at max, since it's vital
```bash
# default is 3000
echo 15000 > /sys/module/zfs/parameters/zfs_resilver_min_time_ms
```

zpool estimates me it gonna take 12 hours, but I expect it to take 4 days,
as for last resilver.
```
zpool status
...
action: Wait for the resilver to complete.
  scan: resilver in progress since Thu Jul  3 08:22:23 2025
	536G scanned at 4.92G/s, 129G issued at 1.18G/s, 52.5T total
	3.41G resilvered, 0.24% done, 12:38:31 to go
...
```
-->