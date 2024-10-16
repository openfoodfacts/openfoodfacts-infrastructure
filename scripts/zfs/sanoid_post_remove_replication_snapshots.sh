#!/usr/bin/env bash

# SANOID_TARGETS is an env variable set by sanoid before calling this script

# This script removes eventual replication snapshot that have been synced
# but shan't have been
#
# Use this only if the server is not a replication target !
readarray -d "," DATASETS <<< $SANOID_TARGETS
for DATASET in "${DATASETS[@]}"
do
  # remove line returns
  DATASET=$(echo $DATASET|tr -d '\r\n')
  if [[ -n "$DATASET" ]] && ( zfs list -t snap $DATASET | grep "__replicate_" )
  then
    for REPLICATION_SNAPSHOT in $( zfs list -t snap $DATASET -o name | grep "@__replicate_" )
    do
      zfs destroy $REPLICATION_SNAPSHOT
    done
  fi
done
