# 2024-01-19 Certbot failure on off2 reverse proxy

## Alert

We got an alert email from letsencrypt on certificate expiration

```
Let's Encrypt certificate expiration notice for domain "*.openbeautyfacts.org" (and 3 more)
```



## Analysis

Looking at /var/log/letsencrypt/letsencrypt.log, we see that the renewal failed,
but it's not clear why it is failing, as writing entries to OVH DNS seems to work.

I can't use renew command to try a dry run, as it runs on all domains… 
and you can't use `-d` option with `renew` command

I try a dry run using certonly command and the right parameters:

```bash
certbot certonly --dry-run  --test-cert -d openbeautyfacts.org -d "*.openbeautyfacts.org" --dns-ovh --dns-ovh-credentials /root/.ovhapi/openbeautyfacts.org
```

It's failing:
```
Challenge failed for domain openbeautyfacts.org
Challenge failed for domain openbeautyfacts.org
dns-01 challenge for openbeautyfacts.org
dns-01 challenge for openbeautyfacts.org
Cleaning up challenges
Some challenges have failed.
```

## Resolution

Going to OVH DNS Zones interface, I see that there are a lot of stalled _acme-challenge records.

I removed them (I advise using the *edit zone as text* option because the interface is buggy, not refrecting just removed entries).

I can test it's not there using:
```bash
dig TXT _acme-challenge.openbeautyfacts.org @ns103.ovh.net +short
```

(`@ns103.ovh.net` is the authority name server, I get it with `dig NS openbeautyfacts.org  +short`)

I'm able to test again:
```bash
certbot certonly --dry-run  --test-cert -d openbeautyfacts.org -d "*.openbeautyfacts.org" --dns-ovh --dns-ovh-credentials /root/.ovhapi/openbeautyfacts.org
```

This time it passes.

I did the same work of cleaning  for openproductsfacts.org, openpetfoodfacts.org and openfoodfacts.org domains.

Then I ran:

```bash
certbot renew
```
And all works fine.

## Post operations

### Adding an alert on certbot failure

I added an email alert on certbot.service failure.

See [commit b89ed9d30a](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/b89ed9d30a6259020e7005552194720165368166)

```bash
ln -s /opt/openfoodfacts-infrastructure/confs/off2-reverse-proxy/systemd/system/certbot.service.d /etc/systemd/system/
sytemctl daemon-reload
```

### Cleaning other DNS Zones

While at it, I also cleaned openfoodfacts.net.