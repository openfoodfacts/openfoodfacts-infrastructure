# Redirect openproductfacts.org to openproductsfacts.org

Deployment for [issue #493](https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/493).
The root redirects to the plural root, and single-label subdomains such as
`world.openproductfacts.org` redirect to their plural equivalents. Paths and
query strings are preserved. The wildcard certificate covers single-label
subdomains only.

## Issue the certificate on scaleway-proxy

The `reverse_proxy_nginx` Ansible role installs Certbot and its OVH DNS plugin.
Provision OVH credentials authorized for the **singular** `openproductfacts.org`
zone in `/root/.ovhapi/openproductfacts.org` (root-owned, mode `0600`), following
the [DNS challenge documentation](../explanation/nginx-reverse-proxy.md).
Do not commit credentials. Credentials for the plural zone may not authorize
changes to the singular zone.

Before enabling the nginx file, run:

```sh
sudo certbot certonly --dns-ovh \
  --dns-ovh-credentials /root/.ovhapi/openproductfacts.org \
  --cert-name openproductfacts.org \
  -d openproductfacts.org -d '*.openproductfacts.org' \
  --deploy-hook 'systemctl reload nginx'
```

DNS validation allows issuance before changing the root A record. Certbot stores
the renewal settings; verify renewal with:

```sh
sudo certbot renew --cert-name openproductfacts.org --dry-run
```

## Enable the redirects

```sh
sudo ln -s /opt/openfoodfacts-infrastructure/confs/scaleway-proxy/nginx/sites-enabled/openproductfacts.org /etc/nginx/sites-enabled/openproductfacts.org
sudo nginx -t && sudo systemctl reload nginx
```

Before switching DNS, check both protocols against Scaleway:

```sh
curl -I --resolve openproductfacts.org:80:151.115.132.10 'http://openproductfacts.org/test?check=1'
curl -I --resolve openproductfacts.org:443:151.115.132.10 'https://openproductfacts.org/test?check=1'
curl -I --resolve world.openproductfacts.org:443:151.115.132.10 'https://world.openproductfacts.org/test?check=1'
```

Expect `301` with `Location: https://openproductsfacts.org/test?check=1` for
the root, and `https://world.openproductsfacts.org/test?check=1` for `world`.
HTTPS must pass certificate verification.

## Update DNS

In OVH, change the `openproductfacts.org` root A record from `213.36.253.214`
to `151.115.132.10`. Keep the wildcard CNAME to `openproductsfacts.org`.
After the previous TTL expires, repeat the checks without `--resolve`.
