#!/usr/bin/env bash

# SANOID_TARGETS is an env variable set by sanoid before calling this script

# This script removes eventual syncoid snapshot for other servers that have been synced
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
  # we remove all snapshot but the last two (because the last one is our own sync snapshot)
  zfs list -t snap $DATASET -o name -H | grep '@syncoid_'|head -n -2|xargs -r -n 1 zfs destroy
done
