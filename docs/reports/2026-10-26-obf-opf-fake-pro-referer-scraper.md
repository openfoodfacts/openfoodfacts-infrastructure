# OBF / OPF facets flooded by a scraper using fake "pro" referrers

**Date**: 2026-10-26

**Authors**: @stephanegigandet

**Status**: Mitigation drafted, to be deployed

**Summary**: A distributed scraper flooded Product Opener facet pages on Open Beauty Facts
(and Open Products Facts) with requests carrying fake `*.pro.openbeautyfacts.org` /
`*.pro.openproductsfacts.org` referrers, saturating Apache and causing timeouts.

**Impact**: obf (and to a lesser extent opf) slow or timing out for users from around
03:00 on 2026-10-26 (start time from Munin).

**Root Causes**: Facet pages (`/cgi/display.pl?/facets...`) are expensive to compute.
At ~300 req/s, the 40 Apache mod_perl workers of the obf container saturate.
The existing per-IP `limit_req` (zone `obf` / `opf`) does not help: it is in dry-run mode,
and in any case each IP only makes a few requests.

## Evidence

Observed on obf (container 113, `10.13.1.113`):

- ~17,800 requests in one minute (~300 req/s).
- 18,740 of the last 20,000 requests were to `/cgi/display.pl?/facets...`.
- Thousands of distinct IPs, each with only a few requests.
- 5 rotating Chrome/Edge user agents, with near-identical request counts.
- Referrers (last 20,000 requests): `https://world-be.pro.openbeautyfacts.org` (6,894),
  plus world-fi / world-es / world-fr / ca-fr variants.

On opf the same morning: referrer `https://world-ca.pro.openproductsfacts.org`.

The pro platform only exists for Open Food Facts (`pro.openfoodfacts.org`).
There is no `*.pro.openbeautyfacts.org` nor `*.pro.openproductsfacts.org`,
so these referrers are fake and safe to reject.

## Mitigation

On scaleway-proxy:

- `confs/scaleway-proxy/nginx/conf.d/fake_pro_referer.conf` sets `$fake_pro_referer` to 1
  when the `Referer` host is `pro.open(beauty|products|petfood)facts.org` or a subdomain of it.
  `*.pro.openfoodfacts.org` is **not** matched.
- `sites-enabled/openbeautyfacts.org`, `openproductsfacts.org` and `openpetfoodfacts.org`
  `return 403` at the server level when `$fake_pro_referer` is set
  (same as the `$deny_user_agents` rule in `openfoodfacts.org`).
  opff gets the rule for consistency, even though it was not targeted.

The 403s will appear in `/var/log/nginx/<site>.access-errors.log` (4xx/5xx statuses are logged there).

This is easy for the scraper to evade (change or drop the referrer), but it is cheap
and stops the current wave.

### Deploy

scaleway-proxy is in the ansible `reverse_proxy_hosts` group, but that role only installs nginx
and the `zz-sites-enabled.conf` include. Site configs and `conf.d` files are symlinked
by hand from `/opt/openfoodfacts-infrastructure` (see the opff / obf / opf migration reports).
So the new `conf.d` file has to be linked manually:

```bash
cd /opt/openfoodfacts-infrastructure
git pull
ln -s /opt/openfoodfacts-infrastructure/confs/scaleway-proxy/nginx/conf.d/fake_pro_referer.conf /etc/nginx/conf.d/
nginx -t && systemctl reload nginx
```

### Check

```bash
# expect 403
curl -sI -H 'Referer: https://world-be.pro.openbeautyfacts.org/' https://world.openbeautyfacts.org/
# expect 200
curl -sI https://world.openbeautyfacts.org/
# expect 200 (legitimate OFF pro platform must not be affected)
curl -sI -H 'Referer: https://world.pro.openfoodfacts.org/' https://world.openbeautyfacts.org/
```

Then check that the request rate drops in the access log of the obf container (113)
and in Munin. Also check that 403s show up in `/var/log/nginx/openbeautyfacts.org.access-errors.log`
on scaleway-proxy.

## Possible next steps

- Add a global (all-IP) `limit_req` on facets for obf / opf / opff, like the
  `off-global` zone used for openfoodfacts.org, so that the next wave, which
  may use different referrers, cannot saturate Apache. This is a separate decision and is not part of this change.
- Turn off `limit_req_dry_run` on the per-IP `obf` / `opf` / `opff` zones
  (this would not have helped here, because each IP made only a few requests).
