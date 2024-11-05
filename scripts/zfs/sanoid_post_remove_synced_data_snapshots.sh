#!/usr/bin/env bash
SCRIPT_PATH=$(dirname $0)

>&2 echo "removing synced snapshots for $SANOID_TARGETS $SANOID_TARGET"
$SCRIPT_PATH/sanoid_post_remove_vzdump.sh
$SCRIPT_PATH/sanoid_post_remove_syncoid_snapshots.sh
