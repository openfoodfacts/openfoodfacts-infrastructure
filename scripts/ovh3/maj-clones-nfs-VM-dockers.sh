#!/usr/bin/env bash

# Script de remise à jour des clones (R/W) des données off (users/orgs/images/products)

SNAP=$(date +%Y%m%d%H%M%S)

CLONES_DATASET=rpool/staging-clones

# stop docker for openfoodfacts-net (staging)
# ssh not working yet, but I don't know why :'(
echo ssh 10.1.0.200 sudo -u off bash -c "cd /home/off/off-net;docker-compose stop"
read -p "waiting for you to do it"

# Data synced with sanoid / syncoid
for DATA in orgs users images products
do
	echo regenerating clone for $DATA
	LAST=$(zfs list -t snap rpool/off/$DATA -o name | grep '_daily$' | tail -n 1)
	CLONE_NAME=$DATA
	if (echo images products | grep -w $DATA)
	then
		CLONE_NAME=off-$CLONE_NAME
	fi
	zfs destroy $CLONES_DATASET/$DATA
	zfs clone $LAST $CLONES_DATASET/$DATA
done

# reboot de la VM "dockers" pour remonter les volumes NFS
# ssh 10.1.0.200 reboot

# restart docker for openfoodfacts-net (staging)
# ssh not working yet, but I don't know why :'(
echo ssh 10.1.0.200 sudo -u off bash -c "cd /home/off/off-net;docker-compose start"
read -p "waiting for you to do it"
