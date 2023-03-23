#! /bin/bash

rsync /srv/off/orgs/ ovh3.openfoodfacts.org:/rpool/off/orgs/ -av --progress
rsync /srv/off/users/ ovh3.openfoodfacts.org:/rpool/off/users/ -av --progress

# dossiers images NNN/NNN/...
for N in $(ls -1 /srv2/off/html/images/products/ | egrep '^[0-9][0-9][0-9]$'); do echo "$(date -Iseconds) $N"; rsync /srv2/off/html/images/products/$N ovh3.openfoodfacts.org:/rpool/off/images/products/ -a; done

# autres images
for N in $(ls -1 /srv2/off/html/images/products/ | egrep '^[0-9][0-9][0-9]$' -v | egrep '^[0-9]*$'); do echo "$(date -Iseconds) $N"; rsync /srv2/off/html/images/products/$N ovh3.openfoodfacts.org:/rpool/off/images/products/ -a; done

