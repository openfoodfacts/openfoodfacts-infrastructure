# 2024-01-24 Move old Product Opener folders to backup

We are near saturation of disk space of off and other containers with Product Opener.

Before augmenting the quotas, we decided to move the old off1 installs folders
which were rsynced during migrations (and were handy to have there during migrations)
to the backup folder.

On off2 as root (better do it in a screen also to avoid interruption):

```bash
mkdir /zfs-hdd/backups/off1-2023/srv
# limit bw to 1M to avoid charging server too much
args="-a --remove-source-files --info=progress2 --bwlimit=1m"
dest=/zfs-hdd/backups/off1-2023/srv

orig=/zfs-hdd/pve/subvol-113-disk-0/srv/off-old
rsync $args $orig $dest &&  find $orig -type d -empty -delete
for orig in  /zfs-hdd/pve/subvol-114-disk-0/srv/off-pro-old /zfs-hdd/pve/subvol-112-disk-0/srv/opf-old /zfs-hdd/pve/subvol-111-disk-0/srv/obf-old /zfs-hdd/pve/subvol-110-disk-0/srv/opff-old; \
do \
    echo $orig; \
    rsync $args $orig $dest &&  find $orig -type d -empty -delete; \
done \
```