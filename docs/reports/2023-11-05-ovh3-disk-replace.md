# 2024-11-05 OVH3 Disk Replace

We add identified that we had a problem with sda on OVH3, with a read error on the disk,
making smartctl tests always fail at 90%.
More over there was a list of several badblocks on the disk.

## Asking OVH for replacement

I asked OVH to replace the disk, ticket CS10364862

```
Numéro de série du ou des disques défectueux :
5PHAYN4F

Si le ou les disques à remplacer ne sont pas détectés, renseignez ici les numéros de série des disques à conserver :
5PG578XF
8DJ8YH1H
5PHAYLUF
5PHAYBUF
8DH4VTRH
20233A448703

Pour les serveurs de type HG ou FS uniquement, si l’identification LED n’est pas disponible, merci de nous confirmer le changement de pièce en arrêtant votre serveur (coldswap) :
No

Possédez-vous une sauvegarde de vos données ?
Oui

Quel est l'état de vos volumes RAID ?
J'utilise ZFS, en raid-z logiciel, le disque fautif a été enlevé du pool, donc je n'ai plus de redondance.

Informations complémentaires :


Quel est le résultat des tests smartctl ?
Les tests finissent sur un read failure.

 smartctl -a /dev/sda

 ... SMARTCTL ouput ...
```

They did a first intervention without doing nothing…

I asked again for replacement:
```
Bonjour, il était prévu de changer le disque 5PHAYN4F sur notre serveur mais le disque n'a pas été changé !

Le rapport d'intervention dit:
[TICKET#10369493] Opération Changement composant terminée
...
L'intervention sur ns31251591.ip-51-210-32.eu est terminée.
...
Aucune intervention n'a été faite sur le serveur. 

Le numéro de série de disque est toujours le même, et c'est un disque avec un secteur défectueux en read (en plus de pas mal de badblocks) ce qui est rédhibitoire…

Merci de changer le disque comme prévu.
```

This time they replaced the disk but also detected that sdb has issues, but propose to backup data first.

I decided I will add the new disk to the pool and resilver, then ask for sdb replacement.

On ovh3
```bash
zpool replace rpool /dev/sda
```
and speed up the resilver
```bash
echo 15000 > /sys/module/zfs/parameters/zfs_resilver_min_time_ms
```

With `zpool status` I can follow progress
```bash
zpool status
  pool: rpool
 state: DEGRADED
status: One or more devices is currently being resilvered.  The pool will
	continue to function, possibly in a degraded state.
action: Wait for the resilver to complete.
  scan: resilver in progress since Tue Nov  5 11:44:24 2024
	5.37T scanned at 910M/s, 2.81T issued at 476M/s, 49.8T total
	480G resilvered, 5.65% done, 1 days 04:41:52 to go
config:

	NAME             STATE     READ WRITE CKSUM
	rpool            DEGRADED     0     0     0
	  raidz2-0       DEGRADED     0     0     0
	    replacing-0  DEGRADED     0     0     0
	      old        OFFLINE      0     0     0
	      sda        ONLINE       0     0     0  (resilvering)
	    sdb          ONLINE       0     0     0
	    sdc          ONLINE       0     0     0
	    sdd          ONLINE       0     0     0
	    sde          ONLINE       0     0     0
	    sdf          ONLINE       0     0     0

errors: No known data errors
```