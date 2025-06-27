# 2025-06-27 OVH3 Disk Replace

## Symptoms

ZFS reported errors with /dev/sde on the rpool ZFS pool.

```
The number of I/O errors associated with a ZFS device exceeded
acceptable levels. ZFS has marked the device as faulted.

 impact: Fault tolerance of the pool may be compromised.
    eid: 4000890
  class: statechange
  state: FAULTED
   host: ovh3
   time: 2025-05-31 13:16:36+0000
  vpath: /dev/sde1
  vphys: pci-0000:00:1f.2-ata-5
  vguid: 0xBE814F46F0DCFA0A
  devid: ata-HGST_HUH721212ALE601_5PHAYBUF-part1
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
  scan: resilvered 38.5G in 03:21:49 with 0 errors on Fri Jun  6 09:12:33 2025
config:

	NAME        STATE     READ WRITE CKSUM
	rpool       DEGRADED     0     0     0
	  raidz2-0  DEGRADED     0     0     0
	    sda     ONLINE       0     0     0
	    sdb     ONLINE       0     0     0
	    sdc     ONLINE       0     0     0
	    sdd     ONLINE       0     0     0
	    sde     FAULTED    457     0     0  too many errors
	    sdf     ONLINE       0     0     0
```

## Asking disk replacement

At 11:48, I asked OVH for disk replacement using their support.

To get the serial number:
`smartctl -i /dev/sde | grep "Serial Number"`


```
Numéro de série du ou des disques défectueux :
5PHAYBUF

Si le ou les disques à remplacer ne sont pas détectés, renseignez ici les numéros de série des disques à conserver :
5PHH715D
5PG578XF
8DJ8YH1H
5PHAYLUF
8DH4VTRH

Pour les serveurs de type HG ou FS uniquement, si l’identification LED n’est pas disponible, merci de nous confirmer le changement de pièce en arrêtant votre serveur (coldswap) :
No

Possédez-vous une sauvegarde de vos données ?
yes

Quel est l'état de vos volumes RAID ?
We don't have material RAID

We use ZFS raidz2-0.

zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices are faulted in response to persistent errors.
 Sufficient replicas exist for the pool to continue functioning in a
 degraded state.
action: Replace the faulted device, or use 'zpool clear' to mark the device
 repaired.
  scan: resilvered 38.5G in 03:21:49 with 0 errors on Fri Jun  6 09:12:33 2025
config:

 NAME        STATE     READ WRITE CKSUM
 rpool       DEGRADED     0     0     0
   raidz2-0  DEGRADED     0     0     0
     sda     ONLINE       0     0     0
     sdb     ONLINE       0     0     0
     sdc     ONLINE       0     0     0
     sdd     ONLINE       0     0     0
     sde     FAULTED    457     0     0  too many errors
     sdf     ONLINE       0     0     0

errors: No known data errors

Informations complémentaires :
We want to replace sde device asap.
```

The OVH services responded immediately and at 15:22 (3,5 hours later) the disk was replaced

## Resilvering

Then I logged on ovh3 and replace the old disk with the new one:

```bash
zpool replace rpool /dev/sde
```

I speed up the resilver at max, since it's vital
```bash
echo 15000 > /sys/module/zfs/parameters/zfs_resilver_min_time_ms
```

zpool estimates me it gonna take 1day and 6 hours.
```
zpool status
  ...
  scan: resilver in progress since Fri Jun 27 14:10:32 2025
	1.64T scanned at 1.16G/s, 690G issued at 490M/s, 52.2T total
	109G resilvered, 1.29% done, 1 days 06:36:49 to go
```
