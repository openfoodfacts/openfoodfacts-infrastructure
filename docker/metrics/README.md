# Setup

Below, the steps necessary to set up the metric stack (Grafana + InfluxDB) are described.

First, launch deployment using Github Action.

## InfluxDB

Create `robotoff` and `grafana` users in InfluxDB belonging to the `off` organization:

```
docker exec -it metrics_influx_db_1 influx user create -n {USERNAME} -o off
```

Create an authentication token for both users (`robotoff` and `grafana`):

```
influx auth create             \
--org off                      \
--user ${USERNAME}             \
--read-authorizations          \
--read-buckets                 \
--write-buckets                \
--read-users
```

This token should provided to Robotoff in `INFLUXDB_AUTH_TOKEN` envvar, and during Grafana configuration.

## Grafana

Connect locally on the Grafana instance (for example using SSH port forwarding: `ssh -L 3001:localhost:3001 {SERVER_HOST}`), and change admin password.
