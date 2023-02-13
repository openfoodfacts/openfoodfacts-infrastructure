#!/bin/sh

# run this script as root

nice -n 19 ionice -c 3 \
  rsync -a -x -e "ssh -T -o Compression=no -x -i \
  --exclude="lost+found" \
  /home/off/.ssh/off2_rsync_id_rsa" off@10.0.0.1:/srv/ /srv/ --exclude '*.old' &
nice -n 19 ionice -c 3 \
  rsync -a -x -e "ssh -T -o Compression=no -x -i \
  /home/off/.ssh/off2_rsync_id_rsa" off@10.0.0.1:/srv2/ /srv2/ &
wait

# copy off photos to ovh3
# Currently is done manually through

# we prefer to split work
# use list files and let xargs divide work
#ls /srv2/off/html/images/products/ | \
#xargs -IDIRECTORIES \
#  rsync -a -x -e "ssh -T -x -i /home/off/.ssh/off2_rsync_id_rsa" DIRECTORIES raphael0202@ovh3.openfoodfacts.org:/rpool/off/images/products/


find . ! \( -user "$u" -perm -u=r -o \
          ! -user "$u" \( -group $g \) -perm -g=r -o \
          ! -user "$u" ! \( -group $g \) -perm -o=r \)