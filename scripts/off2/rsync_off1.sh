#!/bin/sh

# run this script as root on off2 side to avoid permission changes problems

# sync of /srv
nice -n 19 ionice -c 3 \
  rsync -a -x -e "ssh -T -o Compression=no -x -i \
  --exclude="lost+found" \
  /home/off/.ssh/off2_rsync_id_rsa" off@10.0.0.1:/srv/ /srv/ --exclude '*.old' &
# sync of /srv2
for dir_name in off off-pro
do
  nice -n 19 ionice -c 3 \
    rsync -a -x -e "ssh -T -o Compression=no -x -i \
    /home/off/.ssh/off2_rsync_id_rsa" off@10.0.0.1:/srv2/$dir_name /srv2/$dir_name &
done

wait

# copy off photos to ovh3
# Currently this is done manually through sync2ovh3.sh
