#!/bin/sh

nice -n 19 ionice -c 3 rsync -a -x -e "ssh -T -o Compression=no -x -i /home/off/.ssh/off2_rsync_id_rsa" off@10.0.0.1:/srv/ /srv/ --exclude '*.old' &
nice -n 19 ionice -c 3 rsync -a -x -e "ssh -T -o Compression=no -x -i /home/off/.ssh/off2_rsync_id_rsa" off@10.0.0.1:/srv2/ /srv2/ &
wait

# copy off photos to ovh3
for N in $(seq 0 9)
  do rsync /srv2/off/html/images/products/$N* ovh3.openfoodfacts.org:/rpool/off/images/products/ -a
done
