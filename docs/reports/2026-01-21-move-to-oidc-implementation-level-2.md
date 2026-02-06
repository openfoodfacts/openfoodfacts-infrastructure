# 2026-01-21 Move Production Services to OIDC Implementation level 2

For each service:

* OBF
* OPFF
* OPF
* OFF-PRO
* OFF

Check that teh minion and redis_listener services were still running:

```
export SERVICE=$HOSTNAME
sudo systemctl -l status --no-pager minion@$SERVICE.service 
sudo systemctl -l status --no-pager redis_listener@$SERVICE.service 
```

Edit Config2.pm using `sudo -u off vi /srv/$SERVICE/lib/ProductOpener/Config2.pm` and set `$oidc_implementation_level = 2;`

Restart services with:

```
sudo systemctl stop apache2 && sudo systemctl start apache2
[[ "$SERVICE" = off ]] && sudo systemctl stop apache2@priority && sudo systemctl start apache2@priority
sudo systemctl restart cloud_vision_ocr@$SERVICE.service minion@$SERVICE.service redis_listener@$SERVICE.service
```

To test:
* Log in to each flavour
* Go to the account screen in Keycloak (https://auth.openfoodfacts.org/realms/openfoodfacts/account) and edit Name
* Refresh PO page to see if Name updates in the top right
* Sign out of flavour
* Change password on Keycloak account screen
* Sign in to flavour with old password (should fail)
* Sign in to flavour with new password

# Progress

* OBF: Done
* OPFF: Done
* OPF: Done
* OFF-PRO: Done
* OFF: Done

# Status 2026-01-21 12:26 UTC

OBF worked OK but OPFF wouldn't allow login at Level 2. Investigating...

Root URL was worng (was set to https://world.new.openpetfoodfacts.org). Fixed this to https://world.openpetfoodfacts.org but still not working...

It looks like opff is only at version v2.84.0 where obf is at v2.85.1

Attempted to upgrade but got this error on checkout:

```
error: The following untracked working tree files would be overwritten by checkout:
        conf/opf-minion_log.conf
        conf/opff-minion_log.conf
```
Removed the local copies as they were a temporary fix and completed upgrade but still not working.

Eventually found an error in the Keycloak client events:
```
January 21, 2026 at 3:59 PM	No user details	
LOGIN_ERROR	213.36.253.208
reason
Client requires user consent
auth_method
oauth_credentials
grant_type
password
client_auth_method
client-secret
error
consent_denied
```

Fixed the OPFF client in Keycloak.

