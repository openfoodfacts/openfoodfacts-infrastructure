# Post-mortem 2023-07-16 Disk sdc errors on OVH3


## What happened

On 16 july 2023 we received a mail from OVH to tell us :

- ping was lost on ovh3 at 19:31
- an intervention took place, that ended at 19:44

Content of [the intervention](https://help.ovhcloud.com/csm?id=csm_ticket&table=sn_customerservice_case&sys_id=8c68f40a884c7550476bac9f915e86b0):
> Serveur 'freezé' sur "Kernel panic - not syncing". Pas de réponse clavier.
>
> Actions :
> Nous avons effectué un redémarrage.
> Test hardware en échec :
> Le disque SN :5PHAUL7F est défectueux.
> RAM : OK.
> Cooling : OK.
> Redémarrage du serveur.
>
> Le serveur est démarré sur disque et est sur l'écran de connexion. Ping OK et les services sont ouverts.
>
> Recommandations :
> Merci de bien vouloir procéder à une sauvegarde de vos données et de contacter le support afin de remplacer le > disque défectueux.
>
> Additional details :
> SMART_ATA_ERROR : SMART ATA errors found on disk 5PHAUL7F (Total : 2)

So they tell us they will replace the disk when we are ready (backups done).

Note: to find the ticket back: 
* gone to https://help.ovhcloud.com/csm/fr-home?id=csm_index
* signed in
* followed entry "tickets" under search bar
* "notification services" in tickets

## What we did

On 2023-07-17.

I did a backup of /etc on ovh3 and copied it to off2.

I tell OVH I was ready for the intervention through OVH console:
* added all requested informations
  * I  got disk serial number with `udevadm info --query=all --name=/dev/sdc | grep ID_SERIAL`
  * for RAID status I put the result of `sudo zpool status`
  * added reference of incident and PDF of it
* ticket [CS8088256](https://help.ovhcloud.com/csm?id=csm_ticket&table=sn_customerservice_case&sys_id=4bfe4512a4c4bd102d4cf25a537d0e87) was created

I proposed to make the change the same day between 15:00 and 17:00 UTC.

I later got confirmation for that schedule from OVH team.

At 14:30 UTC, I changed CNAME entry for images.openfoodfacts.org to point to off1.


At 17:03 (15:03 UTC) I received a mail telling the operation will take place after 15min

At 17:23 I received a mail telling me the server was rebooted in rescue mode

I ssh the server but realized rescue mode was not useful to me.

So I go in OVH console, change boot type to disk,  and ask for cold reboot.

Now I ssh ovh3, and started a root session.

zpool status is as expected
```bash
# zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices could not be used because the label is missing or
	invalid.  Sufficient replicas exist for the pool to continue
	functioning in a degraded state.
action: Replace the device using 'zpool replace'.
   see: https://openzfs.github.io/openzfs-docs/msg/ZFS-8000-4J
  scan: scrub in progress since Sun Jul 16 23:21:45 2023
	6.99T scanned at 1.20G/s, 6.68T issued at 0B/s, 32.1T total
	0B repaired, 20.80% done, no estimated completion time
config:

	NAME                      STATE     READ WRITE CKSUM
	rpool                     DEGRADED     0     0     0
	  raidz2-0                DEGRADED     0     0     0
	    sda                   ONLINE       0     0     0
	    sdb                   ONLINE       0     0     0
	    17844476680277185950  UNAVAIL      0     0     0  was /dev/sdc1
	    sdd                   ONLINE       0     0     0
	    sde                   ONLINE       0     0     0
	    sdf                   ONLINE       0     0     0
	logs	
	  nvme0n1p4               ONLINE       0     0     0
	cache
	  nvme0n1p5               ONLINE       0     0     0

errors: No known data errors
```

And new sdc is here.

```bash
lsblk
…
sdb           8:16   0  10,9T  0 disk 
├─sdb1        8:17   0  10,9T  0 part 
└─sdb9        8:25   0     8M  0 part 
sdc           8:32   0  10,9T  0 disk 
sdd           8:48   0  10,9T  0 disk 
├─sdd1        8:49   0  10,9T  0 part 
└─sdd9        8:57   0     8M  0 part 
…
```

Added a gpt label to sdc (not sure if useful)

```bash
parted /dev/sdc
(parted) mklabel
New disk label type? gpt  
```

Then followed https://askubuntu.com/questions/172577/replacing-a-disk-in-zpool

```bash
zpool offline rpool 17844476680277185950
zpool replace rpool /dev/sdc
```

```bash
# zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices is currently being resilvered.  The pool will
	continue to function, possibly in a degraded state.
action: Wait for the resilver to complete.
  scan: resilver in progress since Mon Jul 17 16:27:48 2023
	599G scanned at 3.54G/s, 1.80G issued at 10.9M/s, 32.1T total
	0B resilvered, 0.01% done, 35 days 15:39:43 to go
config:

	NAME                        STATE     READ WRITE CKSUM
	rpool                       DEGRADED     0     0     0
	  raidz2-0                  DEGRADED     0     0     0
	    sda                     ONLINE       0     0     0
	    sdb                     ONLINE       0     0     0
	    replacing-2             DEGRADED     0     0     0
	      17844476680277185950  OFFLINE      0     0     0  was /dev/sdc1/old
	      sdc                   ONLINE       0     0     0
	    sdd                     ONLINE       0     0     0
	    sde                     ONLINE       0     0     0
	    sdf                     ONLINE       0     0     0
	logs	
	  nvme0n1p4                 ONLINE       0     0     0
	cache
	  nvme0n1p5                 ONLINE       0     0     0

errors: No known data errors

```

Later, at 18:51 it's more optimistic:
```bash
zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices is currently being resilvered.  The pool will
	continue to function, possibly in a degraded state.
action: Wait for the resilver to complete.
  scan: resilver in progress since Mon Jul 17 16:27:48 2023
	1.78T scanned at 1.30G/s, 315G issued at 231M/s, 32.1T total
	50.2G resilvered, 0.96% done, 1 days 16:09:43 to go

```
