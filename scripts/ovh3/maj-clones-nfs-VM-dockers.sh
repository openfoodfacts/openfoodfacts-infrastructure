cat maj-clones-nfs-VM-dockers.sh
#! /bin/bash

# Script de remise à jour des clones (R/W) des données off (users/orgs/images/products)

SNAP=$(date +%Y%m%d%H%M%S)

for DATA in orgs users images
do
	zfs destroy rpool/off/clones/$DATA
	zfs snapshot rpool/off/$DATA@$SNAP
	zfs clone rpool/off/$DATA@$SNAP rpool/off/clones/$DATA
done

# dernier snapshot quotidien pour "products" qui est en sync ZFS
LAST=$(zfs list -t snap rpool/off/products -o name | grep '0000$' | tail -n 1)
zfs destroy rpool/off/clones/products
zfs clone $LAST rpool/off/clones/products

# reboot de la VM "dockers" pour remonter les volumes NFS
ssh 10.1.0.200 reboot

