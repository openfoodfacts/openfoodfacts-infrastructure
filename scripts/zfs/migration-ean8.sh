#! /bin/bash

# this script was used to progressively migrate the products folder to a zfs dataset
# see also migration.sh

SRC=/srv/off/products
DST=/rpool/off/products

# on stoppe à la moindre erreur
set -e

cd $SRC

for DIR in $(find $SRC/ -maxdepth 1 -type d -not -name '*.old' | grep -v '/$' | sed 's!^.*/!!')
do
  echo "--- $DIR"
  # premièsynchro (lente) et deuxieme synchro (rapide grace aux caches)
  mkdir -p $SRC/$DIR
  rsync $SRC/$DIR $DST/ -a
  rsync $SRC/$DIR $DST/ -a

  # rename XXX > XXX.old + lien symbolique vers nouveau stockage
  mv $SRC/$DIR $SRC/$DIR.old && ln -s $DST/$DIR $DIR

  # synchro finale uniquement pour ce qui est plus récent
  time rsync $SRC/$DIR.old/ $DST/$DIR -av -u
done
