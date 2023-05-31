#! /bin/bash

# this script was used to progressively migrate the images folder to a zfs dataset

SRC=/srv2/off/html/images/products
DST=/mnt/off2/off-images/products
# don't use rsync over NFS, but over SSH
SYNC_DST=10.0.0.2:/zfs-hdd/off/images/products

# we stop as soon as we encounter an error
set -e

function sync_folder {
  DIR=$1
  echo "--- $DIR"
  echo $(date --iso-8601=s)
  # first sync (slow) then second one (fast thanks to caches)
  time rsync $SRC/$DIR $SYNC_DST/ -a --delete
  time rsync $SRC/$DIR $SYNC_DST/ -a

  # rename XXX > XXX.old + symlink to the new storage
  mv $SRC/$DIR $SRC/$DIR.old && \
    ln -s $DST/$DIR $SRC/$DIR

  # final sync in update mode to cover what may have be written during second rsync
  time rsync $SRC/$DIR.old/ $SYNC_DST/$DIR -av -u
}

cd $SRC

# ean13
for DIR in $(seq -w 000 999)
do
  sync_folder $DIR
done
# the rest
# folders (not symlinks) that are not .old, not current dir (grep) and removing path at begining (using sed)
for DIR in $(find $SRC/ -maxdepth 1 -type d -not -name '*.old' | grep -v '/$' | sed 's!^.*/!!')
do
  sync_folder $DIR
done