#!/bin/sh
  
# renew certbot SSL wildcard certificates

# add this to root cron
# you will need a .ovhapi directory with a file for each domain, with
# dns_ovh_endpoint = ovh-eu
# dns_ovh_application_key = ****
# dns_ovh_application_secret = ****
# dns_ovh_consumer_key = ****



sudo certbot certonly --dns-ovh --dns-ovh-credentials /root/.ovhapi/openfoodfacts.net -d openfoodfac
ts.net -d *.openfoodfacts.net --non-interactive --agree-tos --email stephane@openfoodfacts.org

sudo certbot certonly --dns-ovh --dns-ovh-credentials /root/.ovhapi/openfoodfacts.info -d openfoodfa
cts.info -d *.openfoodfacts.info --non-interactive --agree-tos --email stephane@openfoodfacts.org

