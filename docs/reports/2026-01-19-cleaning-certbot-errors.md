# 2026-01-19 Cleaning certbot errors on ovh1 reverse proxy

## Problem

We got alerts in the morning because folksonomy API service is down.
Indeed the service has a certificate problem.

On the reverse proxy,
`journalctl -xe -u certbot`
shows us errors.

For alertmanager and other monitoring services, this is because they have been moved to monitoring-01.
```
janv. 19 03:11:03 proxy certbot[11030]: Attempting to renew cert (alertmanager.openfoodfacts.org) fr
janv. 19 03:11:12 proxy certbot[11030]: Attempting to renew cert (annotate.openfoodfacts.net) from /
janv. 19 03:11:21 proxy certbot[11030]: Attempting to renew cert (annotate.openfoodfacts.org) from /
janv. 19 03:11:32 proxy certbot[11030]: Attempting to renew cert (api.folksonomy.openfoodfacts.org-0
janv. 19 03:11:42 proxy certbot[11030]: Attempting to renew cert (api.folksonomy.openfoodfacts.org) 
janv. 19 03:11:51 proxy certbot[11030]: Attempting to renew cert (auth.openfoodfacts.net) from /etc/
janv. 19 03:12:01 proxy certbot[11030]: Attempting to renew cert (contents.openfoodfacts.org) from /
janv. 19 03:12:10 proxy certbot[11030]: Attempting to renew cert (elasticsearch.openfoodfacts.org) f
janv. 19 03:12:20 proxy certbot[11030]: Attempting to renew cert (facets-kp.openfoodfacts.net) from 
janv. 19 03:12:29 proxy certbot[11030]: Attempting to renew cert (facets-kp.openfoodfacts.org) from 
janv. 19 03:12:38 proxy certbot[11030]: Attempting to renew cert (grafana.openfoodfacts.org) from /e
janv. 19 03:12:48 proxy certbot[11030]: Attempting to renew cert (kibana.openfoodfacts.org) from /et
janv. 19 03:12:58 proxy certbot[11030]: Attempting to renew cert (link.openfoodfacts.org) from /etc/
janv. 19 03:13:10 proxy certbot[11030]: Attempting to renew cert (metabase.openfoodfacts.org) from /
```

There are 404 and 401 problems.

See [Certbot debugging tips](../nginx-reverse-proxy.md#certbot-debugging-tips)

## Removing old monitoring services

Some of the services listed above are part of monitoring and when moved to monitoring-01:
- alertmanager.openfoodfacts.org
- elasticsearch.openfoodfacts.org
- grafana.openfoodfacts.org
- kibana.openfoodfacts.org
- monitoring.openfoodfacts.org
- prometheus.openfoodfacts.org

So I had to:
- unlink each file in `/etc/nginx/conf.d`
- remove the corresponding files in the git repository (for clarity)
- remove certificates:
  - `certbot certificates` to list them, then
  - `certbot delete --cert-name <cert-name>` to remove them
    (generally cert-name is the domain name)

## Removing old certificates

I to remove some certificates that were not used anymore:
- query.openfoodfacts.org
- price.openfoodfacts.org (instead of prices)
- off-wiki.rn7.net
- openfoodfacts.info

# Fixing the rest

After removing the monitoring sites,
`certbot renew --test-cert --dry-run`
seems to show that it will be ok now even for folksonomy.
So I run the `certbot renew` command and it fixed folksonomy engine certificate problem.

## On off2 reverse proxy

I inspected off2 reverse proxy and found auth.openfoodfacts.org
which was moved to scaleway,
so I removed the confs and the certificates.