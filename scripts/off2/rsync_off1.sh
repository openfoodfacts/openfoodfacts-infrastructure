#!/bin/sh

nice -n 19 ionice -c 3 rsync -a -x -e "ssh -T -o Compression=no -x -i /home/off/.ssh/off2_rsync_id_rsa" off@10.0.0.1:/srv/ /srv/ --exclude '*.old' &
nice -n 19 ionice -c 3 rsync -a -x -e "ssh -T -o Compression=no -x -i /home/off/.ssh/off2_rsync_id_rsa" off@10.0.0.1:/srv2/ /srv2/ &
wait

# copy off photos to ovh3

# we prefer to split work
# use list files and let xargs divide work
ls /srv2/off/html/images/products/ | \
xargs -IDIRECTORIES \
  rsync -a -x -e "ssh -T -x -i /home/off/.ssh/off2_rsync_id_rsa" DIRECTORIES raphael0202@ovh3.openfoodfacts.org:/rpool/off/images/products/
