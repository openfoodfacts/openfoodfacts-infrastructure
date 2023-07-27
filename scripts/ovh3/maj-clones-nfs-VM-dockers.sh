#! /bin/bash

# Script de remise à jour des clones (R/W) des données off (users/orgs/images/products)

# stop staging environment as it uses clones
ssh off@10.1.0.200 -J root@10.0.0.1 'cd /home/off/off-net/ && docker-compose stop'

# restart nfs because sometimes it otherwise creates problems
systemctl restart nfs-server.service

# update clones
for DATA in orgs users images
do
	# we use last daily snapshot
	SNAP=$(zfs list -t snap -o name -s creation rpool/off/$DATA |grep 'autosnap_.*_daily'|tail -n 1)
	zfs destroy rpool/off/clones/$DATA
	zfs clone $SNAP rpool/off/clones/$DATA
done

# dernier snapshot quotidien pour "products" qui est en sync ZFS
LAST=$(zfs list -t snap rpool/off/products -o name | grep '0000$' | tail -n 1)
zfs destroy rpool/off/clones/products
zfs clone $LAST rpool/off/clones/products

# restart staging environment
ssh off@10.1.0.200 -J root@10.0.0.1 'cd /home/off/off-net/ && docker-compose up -d'
