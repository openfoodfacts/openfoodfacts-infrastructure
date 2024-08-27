#!/usr/bin/env bash

# This script removes eventual vzdump snapshots that where synchronized
# but shan't have been
# This is for backup of datasets only (not local one)
readarray -d "," DATASETS <<< $SANOID_TARGETS
for DATASET in "${DATASETS[@]}"
do
  if ( zfs list "$DATASET"@vzdump )
  then
    zfs destroy "$DATASET"@vzdump
  fi
done
