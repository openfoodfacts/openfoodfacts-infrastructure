#!/usr/bin/env bash

# SANOID_TARGETS is an env variable set by sanoid before calling this script

# This script removes eventual vzdump snapshots that where synchronized
# but shan't have been
# This is for backup of datasets only (not local one)
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
  zfs list -t snap $DATASET -o name -H | grep '@vzdump$'|xargs -r -n 1 zfs destroy
done
