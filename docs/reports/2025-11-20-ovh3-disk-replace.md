# 2025-11-20 ovh3 disk replace

We had once again a failure on OVH3, resulting as the disk being put offline.

We got an email:
```
ZFS device fault for pool 0x0600B76D0B2E72DB on ovh3

The number of I/O errors associated with a ZFS device exceeded
acceptable levels. ZFS has marked the device as faulted.

 impact: Fault tolerance of the pool may be compromised.
    eid: 2804785
  class: statechange
  state: FAULTED
   host: ovh3
   time: 2025-11-17 03:01:30+0000
  vpath: /dev/sdf1
  vphys: pci-0000:00:1f.2-ata-6
  vguid: 0xCC41DA46A0AC20A4
  devid: ata-HGST_HUH721212ALE601_5PG0KKAF-part1
   pool: 0x0600B76D0B2E72DB
```

As always, I asked for a replacement to OVH3 support, on our mecenat account.
on 19.11.2025 16:49:27

Here is the content of the ticket.

```
CS12863462

Numéro de série du ou des disques défectueux :
5PG0KKAF

Si le ou les disques à remplacer ne sont pas détectés, renseignez ici les numéros de série des disques à conserver :
5PHH715D
8DKZYH9H
8DJ8YH1H
5PHAYLUF
8CKERNSE

Pour les serveurs de type HG ou FS uniquement, si l’identification LED n’est pas disponible, merci de nous confirmer le changement de pièce en arrêtant votre serveur (coldswap) :
Yes

Possédez-vous une sauvegarde de vos données ?
Yes

Quel est l'état de vos volumes RAID ?
We don't have material RAID

# zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices are faulted in response to persistent errors.
 Sufficient replicas exist for the pool to continue functioning in a
 degraded state.
action: Replace the faulted device, or use 'zpool clear' to mark the device
 repaired.
  scan: scrub repaired 0B in 5 days 09:36:29 with 0 errors on Fri Nov 14 10:00:30 2025
config:

 NAME        STATE     READ WRITE CKSUM
 rpool       DEGRADED     0     0     0
   raidz2-0  DEGRADED     0     0     0
     sda     ONLINE       0     0     0
     sdb     ONLINE       0     0     0
     sdc     ONLINE       0     0     0
     sdd     ONLINE       0     0     0
     sde     ONLINE       0     0     0
     sdf     FAULTED      0    21     0  too many errors

errors: No known data errors

Informations complémentaires :
We want to replace the device asap.

Quel est le résultat des tests smartctl ?
# smartctl -l error /dev/sdf
smartctl 7.2 2020-12-30 r5155 [x86_64-linux-5.4.203-1-pve] (local build)
Copyright (C) 2002-20, Bruce Allen, Christian Franke, www.smartmontools.org

=== START OF READ SMART DATA SECTION ===
SMART Error Log Version: 1
ATA Error Count: 1
 CR = Command Register [HEX]
 FR = Features Register [HEX]
 SC = Sector Count Register [HEX]
 SN = Sector Number Register [HEX]
 CL = Cylinder Low Register [HEX]
 CH = Cylinder High Register [HEX]
 DH = Device/Head Register [HEX]
 DC = Device Command Register [HEX]
 ER = Error register [HEX]
 ST = Status register [HEX]
Powered_Up_Time is measured from power on, and printed as
DDd+hh:mm:SS.sss where DD=days, hh=hours, mm=minutes,
SS=sec, and sss=millisec. It "wraps" after 49.710 days.

Error 1 occurred at disk power-on lifetime: 45587 hours (1899 days + 11 hours)
  When the command that caused the error occurred, the device was active or idle.

  After command completion occurred, registers were:
  ER ST SC SN CL CH DH
  -- -- -- -- -- -- --
  84 43 00 00 00 00 00  Error: ICRC, ABRT at LBA = 0x00000000 = 0

  Commands leading to the command that caused the error were:
  CR FR SC SN CL CH DH DC   Powered_Up_Time  Command/Feature_Name
  -- -- -- -- -- -- -- --  ----------------  --------------------
  61 68 b0 e0 90 9a 40 08  33d+19:08:36.193  WRITE FPDMA QUEUED
  61 80 d0 80 a2 93 40 08  33d+19:08:36.192  WRITE FPDMA QUEUED
  61 40 48 f0 a0 93 40 08  33d+19:08:36.192  WRITE FPDMA QUEUED
  61 40 68 50 9f 93 40 08  33d+19:08:36.191  WRITE FPDMA QUEUED
  61 40 80 10 9f 93 40 08  33d+19:08:36.191  WRITE FPDMA QUEUED
```

We got the disk replaced after less than an hour !

So the morning after I did replace the disk and give resilvering a high priority:

```
zpool replace rpool /dev/sdf
echo 15000 > /sys/module/zfs/parameters/zfs_resilver_min_time_ms
```

As of friday at 11:11, the `zpool status` report was:

```bash
  scan: resilver in progress since Thu Nov 20 08:44:25 2025
	12.2T scanned at 139M/s, 12.0T issued at 137M/s, 56.3T total
	1.78T resilvered, 21.30% done, 3 days 22:02:50 to go
```
