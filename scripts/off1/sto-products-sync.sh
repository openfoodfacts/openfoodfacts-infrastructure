#!/usr/bin/env bash
#set -e
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

TIMESTAMP=$(date +%Y%m%d-%H%M)

REMOTE="10.0.0.2 ovh3.openfoodfacts.org" # IP destination

# 2023-06-05 alex - removed opff
# DATASETS='rpool/off/products rpool/obf/products rpool/opf/products rpool/opff/products rpool/off-pro/products'
DATASETS='rpool/off/products rpool/obf/products rpool/opf/products rpool/off-pro/products'

for DATASET in $DATASETS
do
  # nouveau snapshot
  zfs snapshot $DATASET@$TIMESTAMP

  for DEST in $REMOTE
  do

    # REPLICATION
    TARGET=$DATASET
    if [ "$DEST" == "10.0.0.2" ]
    then
       # use HDD for now
       # TARGET=$(echo $TARGET | sed 's+rpool/+zfs-nvme/+')
       TARGET=$(echo $TARGET | sed 's+rpool/+zfs-hdd/+')
    fi

    # liste des snapshots destination
    ssh $DEST "zfs list -t snap -o name $TARGET" | grep "$TARGET@" | sed "s+$TARGET@++" | sed 's+zfs-nvme+rpool+' > /tmp/sync-remote
    # liste des snapshot locaux
    zfs list -t snap -o name 2>/dev/nul | grep "$DATASET@" | sed "s+$DATASET@++" > /tmp/sync-local
    # dernier snapshot local
    LAST_SNAP=$(tail -n 1 /tmp/sync-local)

    # dernier snapshot commun
    PREV_SNAP=$(awk 'NR==FNR{seen[$0]=1; next} seen[$0]' /tmp/sync-remote /tmp/sync-local | tail -n 1)
    if [ "$PREV_SNAP=" != "" ]
    then
      PREV_SNAP=" -i $DATASET@$PREV_SNAP "
    fi

    #rm /tmp/sync-remote /tmp/sync-local

    echo "$(date -Iseconds) : begin $PREV_SNAP $DATASET@$LAST_SNAP > $DEST $TARGET"
    # envoi du diff entre les snapshots vers DEST
    zfs send $PREV_SNAP $DATASET@$LAST_SNAP | ssh $DEST zfs recv $TARGET -F
    echo "$(date -Iseconds) : end $PREV_SNAP $DATASET@$LAST_SNAP > $DEST $TARGET"
  done

  # RETENTION

  # suppression des snapshots de l'avant veille sauf le premier
  OLD=$(zfs list -t snap -o name | grep "$DATASET@$(date -d '2 days ago' +%Y%m%d)" | tail -n +2)
  for OLD_SNAP in $OLD
  do
    zfs destroy $OLD_SNAP
  done

  # suppression des snapshots de mois -2 sauf le premier
  OLD=$(zfs list -t snap -o name | grep "$DATASET@$(date -d '2 month ago' +%Y%m)" | tail -n +2)
  for OLD_SNAP in $OLD
  do
    zfs destroy $OLD_SNAP
  done

  # suppression des snapshots mensuels de plus de 6 mois
  OLD=$(zfs list -t snap -o name | grep "$DATASET@.*01-0000" | head -n -6)
  for OLD_SNAP in $OLD
  do
    zfs destroy $OLD_SNAP
  done
done
