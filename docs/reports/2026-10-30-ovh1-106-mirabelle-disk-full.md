# 2026-10-30 OVH1 106 (mirabelle) disk full

## Symptoms

Munin `df` plugin on ovh1 was in critical state:
`/rpool/subvol-106-disk-0` (mirabelle, `mirabelle.openfoodfacts.org`) was at 99.8%.

The graph showed a daily pattern: usage was around 80-86% and jumped to ~99%
every morning during the products daily update, then went back down.
The baseline was also slowly growing (~72% in July, 86% end of October).

```
root@ovh1:~# zfs list -o name,used,refquota,avail rpool/subvol-106-disk-0
NAME                      USED  REFQUOTA  AVAIL
rpool/subvol-106-disk-0  72.0G       48G  62.9M
```

The pool itself was fine (`rpool` 920G, 326G free).

Note: the ~24G difference between USED and REFQUOTA are snapshots (sanoid),
they do not count in the refquota.

## Analysis

`du` inside the container (sizes on disk, ZFS compression makes apparent sizes much bigger):

```
8.3G    /var/log
7.7G    /home/off/mirabelle.bak
31G     /home/off/off-infrastructure/scripts/mirabelle
```

Three causes:

1. **Logs were never rotated.** `logrotate.service` had been failing every night
   since the container was upgraded (around 2025-11-26) with:
   ```
   logrotate.service: Failed at step NAMESPACE ... Permission denied
   (code=exited, status=226/NAMESPACE)
   ```
   This is the systemd sandboxing of recent Debian services not working
   in an LXC container without nesting on our (old) proxmox host.
   Apparent sizes: `syslog` 69G, `daemon.log` 68G,
   `nginx/mirabelle.log` 15G, `nginx/mirabelle_errors.log` 6.7G.

2. **Every datasette request was logged twice**:
   uvicorn writes its access log on stdout, which goes to journald, then rsyslog
   writes it in both `syslog` and `daemon.log`.
   Nginx already logs the same requests in `mirabelle.log`.

3. **Old files**: old CSV exports
   (`archives/en.openfoodfacts.org.products.2025-06-17.csv.bak`,
   `en.openfoodfacts.org.products.csv.bak2`, `merged.csv`).

Also, during `products_daily_update.sh`, the disk holds at the same time
`products.db`, `previous.db`, `products_new.db` + its journal,
and the CSV + its `.bak`: this explains the daily peak.

The nginx errors log was mostly `upstream timed out` and
`768 worker_connections are not enough`: datasette is overloaded,
apparently by a crawler paginating through `/off-stats/data_quality_stats`
and fetching all `.copyable` export formats.

## Actions

On ovh1, as root:

* removed old CSV files:
  ```bash
  pct exec 106 -- rm /home/off/off-infrastructure/scripts/mirabelle/archives/en.openfoodfacts.org.products.2025-06-17.csv.bak /home/off/off-infrastructure/scripts/mirabelle/en.openfoodfacts.org.products.csv.bak2 /home/off/off-infrastructure/scripts/mirabelle/merged.csv
  ```
* emptied the big logs (still open, so `truncate` instead of `rm`):
  ```bash
  pct exec 106 -- truncate -s 0 /var/log/syslog /var/log/daemon.log /var/log/user.log /var/log/messages /var/log/nginx/mirabelle.log /var/log/nginx/mirabelle_errors.log
  ```
  Usage went from 91% to 74%, while the daily update was running.

On 2026-11-02:

* disabled datasette access log, with a drop-in
  (also added to `scripts/mirabelle/datasette.service`):
  ```bash
  pct exec 106 -- sh -c 'mkdir -p /etc/systemd/system/datasette.service.d && printf "[Service]\nStandardOutput=null\n" > /etc/systemd/system/datasette.service.d/no-access-log.conf && systemctl daemon-reload'
  ```
* enabled nesting on the container so that logrotate works again
  (after checking no daily update was running, i.e. no `products_new.db`):
  ```bash
  pct set 106 --features nesting=1 && pct reboot 106
  ```
* forced a first rotation and checked:
  ```bash
  pct exec 106 -- logrotate -f /etc/logrotate.conf
  ```
  logrotate now succeeds, logs are rotated,
  and datasette only logs its startup messages.

No resize of the container was needed: after the cleanup,
usage is ~60-66% and the daily peak stays under 80%.

## Follow-ups

* `/home/off/mirabelle.bak` (7.7G, a copy from December 2025) could be removed,
  to be checked with Charles.
  --> removed by Alex
* `products_daily_update.sh` could store yesterday's CSV line count in a small file
  and remove the CSV files once the import succeeded, to lower the daily peak.
* add rate limiting (or anubis) for mirabelle on the ovh1 reverse proxy
  to cope with crawlers.
* other containers on ovh1 running recent Debian may have the same
* other containers on ovh1 running recent Debian may have the same
  logrotate (`226/NAMESPACE`) problem.
  
