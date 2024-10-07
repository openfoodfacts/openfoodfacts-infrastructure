# 2024-09-19 move docker volumes

Previously in an attempt not to have all docker volumes on the system disk,
I did mount some on /srv/off/docker_data, on docker-staging and docker-prod VM.

In between we have directly mounted the disk for docker volumes on /var/lib/docker/volumes
but we forgot to move those other volumes.

As it took space on system disk we got alerts about it !

So I had to move them.

Here is a quick dump of what I did, justs in case…

```bash
# shutdown and rm container (to be able to rm volumes)
sudo -u off docker compose down

# copy volumes data in a temporary place
time rsync -a --info=progress2 /srv/off/docker_data/po_search_esdata01 /var/lib/docker/volumes/po_search_esdata01.tmp
time rsync -a --info=progress2 /srv/off/docker_data/po_search_esdata02 /var/lib/docker/volumes/po_search_esdata02.tmp


# Edited Makefile, see https://github.com/openfoodfacts/search-a-licious/commit/51a2450ee84854686b593213bd74eae7794461a7

# removed volumes
docker volume rm po_search_esdata01
docker volume rm po_search_esdata02

# re-create volumes with modified Makefile
# important to do with user off
sudo -u off make create_external_volumes

# fix ownership, not sure if needed
chown off:root /var/lib/docker/volumes/po_search_esdata0{1,2}/_data

# move data to new volumes dirs
mv /var/lib/docker/volumes/po_search_esdata02.tmp/po_search_esdata02/* /var/lib/docker/volumes/po_search_esdata02/_data/
mv /var/lib/docker/volumes/po_search_esdata01.tmp/po_search_esdata01/* /var/lib/docker/volumes/po_search_esdata01/_data/

# restart services
sudo -u off docker compose up -d

# if it went well remove old data and temporary dirs
rm -rf /srv/off/docker_data/po_search_esdata01/
rm -rf /srv/off/docker_data/po_search_esdata02
rmdir /var/lib/docker/volumes/po_search_esdata02.tmp/po_search_esdata02
rmdir /var/lib/docker/volumes/po_search_esdata02.tmp
rmdir /var/lib/docker/volumes/po_search_esdata01.tmp/po_search_esdata01
rmdir /var/lib/docker/volumes/po_search_esdata01.tmp

# verify disk space is still ok
df -h / /var/lib/docker/volumes
```