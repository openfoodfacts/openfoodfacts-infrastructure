#!/usr/bin/env bash

# SANOID_TARGETS is an env variable set by sanoid before calling this script

# This script removes eventual vzdump snapshots that where synchronized
# but shan't have been
# This is for backup of datasets only (not local one)
readarray -d "," DATASETS <<< $SANOID_TARGETS
for DATASET in "${DATASETS[@]}"
do
  # remove line returns
  DATASET=$(echo $DATASET|tr -d '\r\n')
  if [[ -n "$DATASET" ]] && ( zfs list "$DATASET@vzdump" )
  then
    zfs destroy "$DATASET@vzdump"
  fi
done
