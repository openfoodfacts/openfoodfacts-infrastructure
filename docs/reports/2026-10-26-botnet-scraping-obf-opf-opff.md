# High load on scaleway-01: distributed botnet scraping obf / opf / opff

**Date**: 2026-10-26

**Authors**: @stephanegigandet

**Status**: Mitigated

**Summary**: scaleway-01 reached a load average above 60. A distributed botnet,
using a fixed set of outdated Chrome/Edge User-Agents and a different IP for
almost every request, was scraping Open Beauty Facts, Open Products Facts and
Open Pet Food Facts, and to a lesser extent Open Food Facts.

**Impact**: slow responses on all product opener instances hosted on scaleway-01
(off, obf, opf, opff), and high CPU on the reverse proxy (CT 100).

**Root Causes**: per-IP rate limits can't stop a scraper that sends ~1 request
per IP. On top of that, the obf / opf / opff rate limits on the proxy are in
`limit_req_dry_run` mode, so they don't block anything.

## Investigation

`load average: 63.12, 49.89, 37.78` on scaleway-01.

The load average inside LXC containers is the host's, so to see CPU per
container use cgroups on the host:

```bash
systemd-cgtop -1 -n 3 -d 2 --order=cpu lxc
```

CT 111 (off) ~400% CPU, CT 100 (proxy) ~300%, CT 113 (obf) ~230%,
CT 114 (opf) up to 265%, CT 115 (opff) 50-90%. Disk I/O was negligible.

```bash
ps -eo pid,pcpu,etime,cgroup:40,args --sort=-pcpu | head -30
```

The top processes were all apache2 / mod_perl children of obf, opf and opff,
all 0 to 4 seconds old. With `MaxConnectionsPerChild` at 100, that means a
very high request rate.

The proxy only logs errors for these sites. The nginx inside each container
logs every request with the client IP (from `X-Forwarded-For`) as the first
field:

```bash
for ct in 111 113 114 115; do echo "== CT $ct UAs"; pct exec $ct -- bash -c 'tail -n 50000 /var/log/nginx/proxy-productopener-access.log | awk -F\" "{print \$6}" | sort | uniq -c | sort -rn | head -10'; done
```

On obf, opf and opff, 8 User-Agents accounted for ~5,300 requests each,
~85% of the last 50,000 requests:

```
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/14[2-5].0.0.0 Safari/537.36
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/14[45].0.0.0 Safari/537.36 Edg/14[45].0.0.0
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/14[2-5].0.0.0 Safari/537.36
```

These Chrome versions are ~10 releases behind what real visitors send
(Chrome 153-156). The top IP had only ~400 requests, and many came from
cloud ranges (e.g. 47.79.200.0-47.79.207.255, Alibaba Cloud).

On off, the same User-Agents made 1,348 of the last 50,000 requests,
from 1,301 distinct IPs, all GET requests (mostly `/cgi`, `/product`,
`/api` and facets): the same botnet.

## Resolution

In `confs/scaleway-proxy/nginx/sites-enabled/`:

* added a regex matching exactly those User-Agents to the `$deny_user_agents`
  map in `openfoodfacts.org` (which returns 403)
* added the `$deny_user_agents` check to `openbeautyfacts.org`,
  `openproductsfacts.org` and `openpetfoodfacts.org`, which didn't have it.
  As a side effect, the existing bot list (Ahrefs, GPTBot, etc.) is now
  also blocked on those sites.

Then on the proxy (CT 100):

```bash
nginx -t && systemctl reload nginx
```

To check that it works, look for 403s:

```bash
tail -n 5000 /var/log/nginx/openbeautyfacts.org.access-errors.log | awk '{print $9}' | sort | uniq -c
```

## Action Items

* Look into turning off `limit_req_dry_run` for obf / opf / opff.
* If the botnet switches to other User-Agents, run the same per-User-Agent
  counts again and update the regex.
* Other candidates for `$deny_user_agents` seen on off: `Lightpanda`
  (headless browser, ~1,500 requests), and requests coming through
  Cloudflare (`2a06:98c0:3600::103`, ~1,300 requests).
