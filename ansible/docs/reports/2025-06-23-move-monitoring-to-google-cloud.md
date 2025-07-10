# Move monitoring to Google Cloud

We are moving monitoring server to Google Cloud.

The current monitoring server is on ovh1 server which is really saturated in term of disk space.
Also it's a good idea to have monitoring outside of data centers where we have monitored services.

We have some free credits there (thank you Google).

So we decided to move monitoring to Google Cloud.

## Setting up server and preparing the switch

Thomas had prepared the new server using ansible,
and we also made changes to the monitoring repository,
deploying it to the new server
(but not deploying the filebeat which goes on monitored servers,
and for that we add special rules to the container-deploy).

* [PR #474 to install the server](https://github.com/openfoodfacts/openfoodfacts-infrastructure/pull/474)
* [PR #119 to modify monitoring](https://github.com/openfoodfacts/openfoodfacts-monitoring/pull/119)

At the end we had a working monitoring server,
but without historical data and without the DNS pointing to it.

### A bit before the switch

Edit DNS and make TTL smaller for:
* monitoring
* grafana
* prometheus
* kibana
* alertmanager
* elasticsearch


## Migrating

We needed to switch from the current monitoring server (ovh1/qm203)
to the new one (monitoring-01).

Our migration plan was as follow:
* stop services on monitoring-01
* rsync docker volumes from ovh1/qm203 to monitoring-01
* stop all services on ovh1/qm203
* rsync again docker volumes to monitoring-01 (should use cache and be fast)
* start services on monitoring-01
* update DNS
* test it's working
* deploy filebeat config on targets

After some time:

* remove qm203 from ovh1 (keep the volume backup on ovh3 for some time)

### Rsyncing docker volumes

We need to rsync data in one go, without loosing permissions and so on.
But we don't have root ssh access.
So we need to use sudo on destination host, and to use root with access to ssh keys on source.

Here is how we did it:

* On monitoring-01,
  we temporarily edited /etc/sudoers to use NOPASSWD directive:
  ```conf
  %sudo   ALL=(ALL) NOPASSWD:ALL
  ```
* We use the `ssh -A` (forwarding ssh agent), to connect to ovh1/qm203,
  and `sudo -E` to become root (keep environment containing the ssh agent socket),
  and we use `--rsync-path="sudo rsync"` with rsync,
  to be able to be root on target side.
  ```bash
  ssh -A offmonit
  sudo -E bash
  cd /var/lib/docker/volumes/
  for vol in monitoring_*; do echo $vol; time rsync --delete --info=progress2 -a --rsync-path="sudo rsync" $vol alex@34.1.5.157:/var/lib/docker/volumes/; done
  ```

  Note: the --delete is very important, because some software (like elasticsearch),
  might not work if we provide inconsistent data.

  As the last line executed we shoot down the rsync of elasticsearch backups
  as on ovh1/qm203, it is a NFS mount form ovh3, hence it's slow.
  More over, we can sync it directly from ovh3 using zfs send/receive.

Note: `file has vanished on monitoring_elasticsearch-data` is expected while we are syncing and ES is live.
(because ES do a lot of file removal / creation to handle its index).

The biggest volumes to backup ar elasticsearch and prometheus data,
the sync take more thant 30 min in total.

We then stop services on ovh1/qm203.

rsync after stopping services was really fast.

We then started the services on monitoring-01.

### DNS changes

We changed the DNS for:
* monitoring
* grafana
* prometheus
* kibana
* alertmanager
* elasticsearch

to CNAME to monitoring-01.openfoodfacts.org

### Testing

We tested and all was ok.

## Filebeat deployment

Now that monitoring is up, we need to deploy the filebeat config on all monitored servers,
so that they talk to the new monitoring server.

PR to deploy filebeat config: https://github.com/openfoodfacts/openfoodfacts-monitoring/pull/121

After deploying, we looked at logs in kibana, and did not see new logs.

We had some hard time understanding why we didn't get the logs at first.

To test the filebeat config, we need to run it in a container,
here is how we did it:
```bash
sudo -u off
cd /home/off/filebeat
docker compose exec filebeat bash
filebeat test config
Config OK
filebeat test output
```

## Next step to do

* filebeat on osm45 and on docker + container ?
* [FIXED] authentification for prometheus probes
* [FIXED] instance_name is wrong on prometheus (review proxy config)
* [DONE] verify it all works
* [DONE] create backups volume
* [DONE] move docker volumes to a zfs filesystem
* [DOING] backup zfs data to others servers
* [FIXED] look at failing targets https://prometheus.openfoodfacts.org/targets
