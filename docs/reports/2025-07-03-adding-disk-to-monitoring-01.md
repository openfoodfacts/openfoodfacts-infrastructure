# 2025-07-03 Adding a disk to monitoring 01

Yesterday the monitoring services on monitoring-01 refused to start
because there was not enough space on the disk
(Elasticsearch has a fool proof mechanism to avoid running out of disk space,
which might be catastrophic for its data).

Also the current disk is an ext4 disk which will not ease the backup of data.
We want to switch to ZFS datasets for docker volumes.

We have a disk with ZFS but it's holding the backups of Elasticsearch,
and it's a standard persistent disk, which is not performant enough.

## Estimating the cost

I want to estimate what it will cost, and for that I want to know current cost of the primary disk.
* gone to billing reports in the google cloud console
* you have to choose the group by service view, and to filter on balanced PD capacity in paris and (or storage PD capacity in Paris to view the ZFS backup disk)
  so it's about 16€ / month for 170 Go, it will be around 20€ / month for 200 Go, still ok

Also I don't need to directly take a big disk as we can extend it later,
and with ZFS it's quite easy to extend the pool to the new disk size ([`zfs online -e`](https://openzfs.github.io/openzfs-docs/man/master/8/zpool-online.8.html))

## Adding a disk on Google Cloud Console

So I decided to add a new disk to the instance,
an equilibrated persistent disk with 200 GB.

Here is what I did (interface was in french so those may not be the exact terms):
* Go on off monitoring Instance (robotoff project)
* click modify
* more disk - add a disk
* add disk form:
  * name: monitoring-01-docker-volumes
  * where: unique zone
  * source: empty disk
  * type: persistent equilibrated
  * size: 200 G
  * Save
* Beware to also save the machine settings at the end

After that I can login to monitoring-01 and `lsblk` shows a new /dev/sdc disk.

## Creating the ZFS pool

It is done with ansible.

I just had to modify `ansible/host_vars/monitoring-01/zfs.yml`,
(`monitoring__zfs_pools` and `monitoring__zfs_filesystems`),
and run
```bash
ansible-playbook sites/monitoring.openfoodfacts.org.yml  -l monitoring-01
```

## Moving docker volumes


Stopped and destroyed the monitoring services:
```bash
cd /home/off/monitoring/
sudo -u off docker compose down
cd /home/off/filebeat/
sudo -u off docker compose down
```
temporarily move old volume data to new directories

```bash
mkdir /opt/docker-volumes-backup
# beware not to take /var/lib/docker/volumes/monitoring_elasticsearch-backup
for vol in monitoring_{alertmanager,elasticsearch,grafana,influxdb,prometheus}-data; do echo $vol; mv /var/lib/docker/volumes/$vol/_data /opt/docker-volumes-backup/$vol && mkdir /var/lib/docker/volumes/$vol/_data; done
# verify
ls /opt/docker-volumes-backup
du -sh /var/lib/docker/volumes/monitoring_*
# should be 8k / folder, more or less
```

Remove the volumes:
```bash
for vol in monitoring_{alertmanager,elasticsearch,grafana,influxdb,prometheus}-data; do echo $vol; docker volume rm $vol; done
```

I then modified monitoring Makefile create_external_volumes to use the new disks.
See https://github.com/openfoodfacts/openfoodfacts-monitoring/pull/123

Recreate them with the Make command of the project:
```bash
sudo -u off make create_external_volumes
# verify
docker volume list|grep monitoring
```

Copy the backup data (Note: we don't need a _data folder anymore, and also note there is no trailing / to rsync source, to copy the folder, not the content):
```bash
for vol in monitoring_{alertmanager,elasticsearch,grafana,influxdb,prometheus}-data; do echo $vol; rsync -a --info=progress2 /opt/docker-volumes-backup/$vol /data-zfs/docker-volumes/$vol/_data; done
```

Verify that data is ok by running a docker container:

```bash
cd /home/off/monitoring/

sudo -u off docker compose run --rm --entrypoint sh  prometheus
ls /prometheus -l
exit
sudo -u off docker compose run --rm elasticsearch bash

Then I restarted the services:
```bash
cd /home/off/monitoring/
sudo -u off docker compose up -d
cd /home/off/filebeat/
sudo -u off docker compose up -d
```

carefully look at if services are running ok [^not_the_case_for_me]

Also connect to Kibana to verify we have
[old logs](https://kibana.openfoodfacts.org/app/logs/stream?flyoutOptions=%28flyoutId%3A%21n%2CflyoutVisibility%3Ahidden%2CsurroundingLogsId%3A%21n%29&logPosition=%28end%3Anow%252Fy%2Cposition%3A%28tiebreaker%3A88566%2Ctime%3A1751356441851%29%2Cstart%3Anow%252Fy%2CstreamLive%3A%21f%29).
Connect to grafana and prometheus to verify we still have previous metrics
(eg with a a [graph](https://prometheus.openfoodfacts.org/graph?g0.expr=apache_cpuload&g0.tab=0&g0.stacked=0&g0.show_exemplars=0&g0.range_input=2w)).

[^not_the_case_for_me]: it was not the case for me, and I had to fix several time !
  Mainly because the way I created external volumes was wrong.

## Cleaning

Removing the old docker volumes on primary disk:

```bash
rm -rf /opt//docker-volumes-backup
```

## Next steps

We must setup replication of docker volumes to other servers to backup data.

We could eventually try to shrink the primary disk size (to say 40GB),
but it is a quite complicated operation,
it might not be worth it.