#! /bin/bash

/usr/bin/mongo off /srv/off/scripts/refresh_products_tags.js  >> /var/log/mongodb/refresh_products_tags.log
/usr/bin/mongo obf /srv/off/scripts/refresh_products_tags.js  >> /var/log/mongodb/refresh_products_tags.log
/usr/bin/mongo opf /srv/off/scripts/refresh_products_tags.js  >> /var/log/mongodb/refresh_products_tags.log
/usr/bin/mongo opff /srv/off/scripts/refresh_products_tags.js  >> /var/log/mongodb/refresh_products_tags.log


