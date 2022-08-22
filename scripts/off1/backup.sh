#!/bin/sh

rm -rf /srv2/backup.2
mv /srv2/backup.1 /srv2/backup.2
mv /srv2/backup /srv2/backup.1
mkdir /srv2/backup

cd /srv

tar cfz /srv2/backup/off.tar.gz off/cgi off/lib off/po off/scripts off/taxonomies off/users


cd /

tar cfz /srv2/backup/system.tar.gz bin etc lib lib64 usr sbin var


