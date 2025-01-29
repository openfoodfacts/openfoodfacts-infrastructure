# 2024-03-04 Moving opf, obf and opff logs

## Context

I just had a disk space problem on OPF because the gen_feeds script was logging directly in syslog, and it was logging a lot. This made 5G file is /var/log which lead to the disk being filled.
At this occasion I also remarked and fixed that we wanted to keep nginx logs for long (and not apache logs).

On off I put logs in a separate dataset, and it's a good practice to have logs in a different place.

On opf, obf and opff I decided to at least put logs in a data volume, at /mnt/<service_name>/logs. We can move it to a specific dataset later on if we want, but right not it seems to be sufficient to separate it from the system disk.

## Procedure

```bash
cd /var/log
# start rsyncing
mkdir  /mnt/$HOSTNAME/logs
rsync -a --info=progress2 nginx /mnt/$HOSTNAME/logs && rsync -a --info=progress2 $HOSTNAME /mnt/$HOSTNAME/logs
# verify
ls -l /mnt/$HOSTNAME/logs
# stop timer for regular service
systemctl stop gen_feeds@$HOSTNAME.timer gen_feeds_daily@$HOSTNAME.timer
# verify service are stopped (or wait until it's true)
systemctl status gen_feeds@$HOSTNAME.service gen_feeds_daily@$HOSTNAME.service
... Active: inactive (dead) ...
# stop services (no minion or ocr atm here)
systemctl stop gen_feeds@$HOSTNAME.timer gen_feeds_daily@$HOSTNAME.timer apache2 nginx
# rsync again
rsync -a --info=progress2 nginx /mnt/$HOSTNAME/logs && rsync -a --info=progress2 $HOSTNAME /mnt/$HOSTNAME/logs
# move folders and symlink
mv nginx{,.old}
mv $HOSTNAME{,.old}
ln -s /mnt/$HOSTNAME/logs/nginx .
ln -s /mnt/$HOSTNAME/logs/$HOSTNAME .
# restart services
systemctl start gen_feeds@$HOSTNAME.timer gen_feeds_daily@$HOSTNAME.timer apache2 nginx
```

**NOTE:** on opf I used mv instead of rsync and it take far too much time (with rsync you can do it in two steps) !