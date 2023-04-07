#! /bin/bash

# this script was used to progressively migrate the products folder to a zfs dataset
# see also migration-ean8.sh

SRC=/srv/off/products
DST=/rpool/off/products

# on stoppe à la moindre erreur
set -e

cd $SRC

for DIR in $(seq -w 000 499)
do
  echo "--- $DIR"
  # première synchro (lente) et deuxième synchro (rapide grace aux caches)
  rsync $SRC/$DIR $DST/ -a
  rsync $SRC/$DIR $DST/ -a

  # rename XXX > XXX.old + lien symbolique vers nouveau stockage
  mv $SRC/$DIR $SRC/$DIR.old && ln -s $DST/$DIR $DIR

  # synchro finale uniquement pour ce qui est plus récent
  time rsync $SRC/$DIR.old/ $DST/$DIR -av -u

  sleep 1
done
