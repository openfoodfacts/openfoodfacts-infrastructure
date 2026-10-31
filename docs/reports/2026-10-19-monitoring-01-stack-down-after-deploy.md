# 2026-10-19 monitoring-01 stack down after concurrent deployments

## Symptoms

https://grafana.openfoodfacts.org/ returned `502 Bad Gateway`.

Looking further, the whole monitoring stack on monitoring-01 was down
(grafana, prometheus, alertmanager, elasticsearch, kibana, influxdb, exporters).
`https://prometheus.openfoodfacts.org/-/healthy` was also 502;
other sites only answered 401 because the reverse proxy basic auth
replies before reaching the backend.

It had been down since **2026-10-02 10:17 (Paris time)**, so 17 days, without any alert
(alertmanager was down too).

## Cause

A push on `main` of [openfoodfacts-monitoring](https://github.com/openfoodfacts/openfoodfacts-monitoring)
on 2026-10-02 triggered two workflows at the same time, both acting on monitoring-01:

1. [Docker Compose Deployment CI](https://github.com/openfoodfacts/openfoodfacts-monitoring/actions/runs/36983083474)
   runs `make up`: at 08:16:38 UTC it stopped and removed all monitoring containers
   (and the `monitoring_monitoring` network), then started pulling images.
2. [Filebeat Deployment CI](https://github.com/openfoodfacts/openfoodfacts-monitoring/actions/runs/36983083691)
   ran `make prune` (`docker system prune -af`) at 08:16:47.
   As no monitoring container existed anymore,
   it deleted the images that were not being re-pulled (eg. `prom/alertmanager:v0.23.0`).
3. At 08:17:06 compose tried to create the containers and failed with:
   ```
   Error response from daemon: No such image: prom/alertmanager:v0.23.0
   ```
   No container was recreated.

On the host, docker logs showed DNS lookups for `grafana` / `elasticsearch` failing
(the reverse proxy could not resolve the missing containers).

## Resolution

* Re-ran the failed Docker Compose Deployment CI run: it pulled the images and started all services.
* Then re-ran the Filebeat Deployment CI run (sequentially, to avoid the same race).
  It succeeded on all hosts but hetzner-02 docker prod VM (10.12.1.202),
  which failed with an unrelated ssh authentication error
  (`unable to authenticate, attempted methods [none publickey]`).
* Checked: grafana `/api/health` returns 200, prometheus `/-/healthy` returns 200,
  all monitoring processes are running on monitoring-01.

## Next steps

* Prevent concurrent deployments on the same host in openfoodfacts-monitoring
  (eg. a shared GitHub Actions `concurrency` group for both workflows),
  or avoid `docker system prune -a` while another deployment may be running.
* Add an external check of the monitoring stack itself
  (eg. uptime check on prometheus `/-/healthy` from outside monitoring-01),
  since alertmanager cannot alert about its own outage.
* Fix the ssh key for the Filebeat deployment on hetzner-02 docker prod VM
  (`SSH_PRIVATE_KEY_HETZNER_DOCKER_PROD` secret or `authorized_keys` on the VM).
