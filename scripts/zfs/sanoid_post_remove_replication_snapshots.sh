#!/usr/bin/env bash

# SANOID_TARGETS is an env variable set by sanoid before calling this script

# This script removes eventual replication snapshot that have been synced
# but shan't have been
#
# Use this only if the server is not a replication target !
if [[ "$SANOID_SCRIPT" = "prune" ]]
then
  DATASETS=( $SANOID_TARGET )
else
  readarray -d "," DATASETS <<< $SANOID_TARGETS
fi

for DATASET in "${DATASETS[@]}"
do
  # remove line returns
  DATASET=$(echo $DATASET|tr -d '\r\n')
  zfs list -t snap $DATASET -o name -H | grep "@__replicate_"| xargs -r -n 1  zfs destroy 
done
