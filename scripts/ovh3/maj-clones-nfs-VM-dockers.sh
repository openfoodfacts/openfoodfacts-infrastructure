#!/usr/bin/env bash

# Script de remise à jour des clones (R/W) des données off (users/orgs/images/products)

CLONES_DATASET=rpool/staging-clones
SOURCE_DATASET_HDD=rpool/off-backups/podata
SOURCE_DATASET_NVME=rpool/off-backups/podata-nvme

# stop docker for openfoodfacts-net (staging)
# ssh not working yet, but I don't know why :'(
echo ssh 10.1.0.200 sudo -u off bash -c "cd /home/off/off-net;docker-compose stop"
read -p "waiting for you to do it"

# restart nfs because otherwise it might disable unmount
echo restarting nfs-server
systemctl restart nfs-server.service
# Data synced with sanoid / syncoid
for DATA in orgs users images products
do
	if (echo products orgs users | grep -w $DATA)
	then
		SOURCE_DATASET=$SOURCE_DATASET_NVME
	else
		SOURCE_DATASET=$SOURCE_DATASET_HDD
	fi
	echo regenerating clone for $SOURCE_DATASET/$DATA
	LAST=$(zfs list -t snap $SOURCE_DATASET/$DATA -o name | grep '_daily$' | tail -n 1)
	CLONE_NAME=$DATA
	if (echo images products | grep -w $DATA)
	then
		CLONE_NAME=off-$CLONE_NAME
	fi
	zfs destroy $CLONES_DATASET/$CLONE_NAME
	zfs clone $LAST $CLONES_DATASET/$CLONE_NAME
done

# reboot de la VM "dockers" pour remonter les volumes NFS
# ssh 10.1.0.200 reboot

# restart docker for openfoodfacts-net (staging)
# ssh not working yet, but I don't know why :'(
echo ssh 10.1.0.200 sudo -u off bash -c "cd /home/off/off-net;docker-compose start"
read -p "waiting for you to do it"
