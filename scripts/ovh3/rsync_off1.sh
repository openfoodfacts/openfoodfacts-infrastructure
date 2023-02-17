#!/bin/sh

# run this script as root on off2 side to avoid permission changes problems

backup_dir=/rpool/backups/off1

# sync of /srv
nice -n 19 ionice -c 3 \
  rsync -a -x -e "ssh -T -x" \
  --exclude="lost+found" --exclude '*.old' \
  off@off1.openfoodfacts.org:/srv/ $backup_dir/srv/  &
# sync of /srv2
for dir_name in off off-pro
do
  nice -n 19 ionice -c 3 \
    rsync -a -x -e "ssh -T -x" \
    off@off1.openfoodfacts.org:/srv2/$dir_name $backup_dir/srv2/$dir_name --exclude=html/images/prod
ucts/ --exclude=orgs/ --exclude=users/ &
done



wait
# sync users and orgs
for dir_name in orgs users
do
  nice -n 19 ionice -c 3 \
    rsync -a -x -e "ssh -T -x" \
    off@off1.openfoodfacts.org:/srv/off/$dir_name /rpool/off/$dir_name &
done
wait

# copy off photos to ovh3
# Currently this is done manually through sync2ovh3.sh

