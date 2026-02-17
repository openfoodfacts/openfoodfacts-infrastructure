# 2026-02-17 monitoring 01, Elasticsearch disk full

## Symptoms

After a deployment on monitoring-01,
we got an alert that kibana was down.

Looking at it on monitoring-01, I saw in its log that it's unable to start
due to a migration that can't happen because disk is full.

Looking at ES log, I see that the index is readonly because disk usage
is above the threshold.

Indeed the disk is at 96% capacity !

```
zfs list data-zfs -r
  NAME                                                    USED  AVAIL  REFER  MOUNTPOINT
  data-zfs                                                190G  2.79G    96K  /data-zfs
  data-zfs/docker-volumes                                 190G  2.79G   128K  /data-zfs/docker-volumes
  data-zfs/docker-volumes/monitoring_alertmanager-data     96K  2.79G    96K  /data-zfs  docker-volumes/monitoring_alertmanager-data
  data-zfs/docker-volumes/monitoring_elasticsearch-data   164G  2.79G   164G  /data-zfs  docker-volumes/monitoring_elasticsearch-data
  data-zfs/docker-volumes/monitoring_grafana-data        46.5M  2.79G  17.8M  /data-zfs  docker-volumes/monitoring_grafana-data
  data-zfs/docker-volumes/monitoring_influxdb-data       1.73G  2.79G   110M  /data-zfs  docker-volumes/monitoring_influxdb-data
  data-zfs/docker-volumes/monitoring_prometheus-data     24.1G  2.79G  2.13G  /data-zfs/docker-volumes/monitoring_prometheus-data
df -h /data-zfs/docker-volumes/monitoring_elasticsearch-data
  Filesystem                                             Size  Used Avail Use% Mounted on
  data-zfs/docker-volumes/monitoring_elasticsearch-data  167G  164G  2.8G  99% /data-zfs  docker-volumes/monitoring_elasticsearch-data
```

## Resolution

My plan is to:
* list indexes that I can remove (old logs)
* ~~remove the watermark temporarily~~
* remove indexes
* ~~set back the watermark~~

I will then consider if:
* some logging is too high
* ILM should be adjusted to trash log earlier
* seek why we did not get an alert on the disk

To ease the work, as kibana is not accessible,
I will use [elasticvue app in standalone mode](https://elasticvue.com/installation/)

### Listing and removing indexes

Elasticvue offers me a view with all indexes.
I can see that some indices are very big:
in particular: `logs-current-logs-2025.09.01-000308` is 18G and it's really old.

I am able to remove it (no need to change threshold)

It seems ILM is not working correctly as there are a lot of old indexes.
I will remove them.
I use the filter to get all indexes of 2024, and use bulk action to remove them.

It has an immediate effect on disk use:
```
data-zfs/docker-volumes/monitoring_elasticsearch-data  128G  125G  2.8G  98% /data-zfs/docker-volumes/monitoring_elasticsearch-data
```

I do the same for indexes before 2025-10, which are even more and huge.

After that we are back to a very reasonable amount of data:
```
data-zfs/docker-volumes/monitoring_elasticsearch-data  2.8G   51M  2.8G   2% /data-zfs/docker-volumes/monitoring_elasticsearch-data
```

Kibana is finally back !

## Looking at indices content

I connect to kibana.openfoodfacts.org

In Management > Stack Management > Index Management

I see that finally I only have one log index remaining! It is `logs-current`.

It is not under ILM …

Using analytics > visualize library:
* I create a datatable
* Index pattern: logs-*
* I had a split row bucket on terms on com_docker_compose_project_working_dir by count, showing 50 items
* I also had to take care of the time window on top right corner and set last 3 years

I see:
```
/home/off/monitoring    54,179
/home/off/off-search-org    25,799
/home/off/open-prices-org   22,166
/home/off/filebeat  18,558
/home/off/robotoff-net  16,598
/home/off/off-search-net    15,547
/home/off/nutripatrol-org   13,217
/home/off/argilla-org   12,305
/home/off/metrics-net/docker/metrics    10,651
/home/off/open-prices-net   10,276
```
From that I can see that moji is not sending logs,
we will have to look into this…
(hetzner and scaleway also but this is expected).

## Setting Index Lifecycle Policy

As we saw that logs-current is not under ILM,
we want to add it.

Normally filebeat should have done that itself,
but it's not the case.

The `configs/filebeat/config.yml` tells us the ILM config name is logs.

In Management > Stack Management > Index Lifecycle Policies,

I can see the policy `logs` exists
and its content is conform to `configs/filebeat/ilm-config.json`.

Before I can setup the policy, there is a problem to fix:
`logs-current` is an indice when it should be an alias to an indice.
Also in ES we can't rename an index.

So first I do the following:
* put logs current in read only mode (there is an action on index in  elasticvue interface)
* clone it in `logs-2025.03.15-000001` (there is an action in elasticvue)
* remove `logs-current`
* ~~add alias `logs-current` to created log~~

Last step does not work because filebeat immediately recreate the index…

To disable this here is what I did:
* I generated a password hash using: `openssl passwd -5 -stdin`
* I edited `/opt/reverse_proxy/nginx/passwords/elasticsearch.openfoodfacts.org`
  * commented current off password
  * added my new one
* change password in elasticvue
Then I:
* clone `logs-current` in `logs-2026.02.17-000001` (there is an action in elasticvue)
* remove `logs-current`
* add alias `logs-current` to `logs-2026.02.17-000001`
Finally I edit again `/opt/reverse_proxy/nginx/passwords/elasticsearch.openfoodfacts.org`
to put back the old password, and put it back also in elasticvue.


No I must apply the log policy my logs indices.
For this, in kibana, I go in Management > Stack Management > Index Management,
* I search `logs-` and select `logs-2026.02.17-000001`
* I use the action "add lifecycle policy"
* I select the `logs` lifecycle policy, with logs-current rolling alias and apply

## About alert on disk threshold

It would have been important to have an alert as the disk gets full.

### Diagnosis

In the configs/prometheus/alerts.yml, we have a `VMOutOfDiskSpace` alert,
but it's looking at a specific device `/dev/sda1` and mountpoint `/`
which only work for a very specific setting !

So we need to change this.

Testing in prometheus, the request `node_filesystem_avail_bytes{device!="tmpfs"}`
only gives me two entries, which are from OVH.
Why don't we have the one from `monitoring-01` ?

### Fixing node metrics on monitoring-01

on monitoring itself, if I do a:
```bash
curl localhost:8281/metrics|grep filesystem_avail
```
I can see the zfs volumes, but it seems not to be harvested.

But if I go in `/home/off/monitoring`, and use
```bash
sudo -u off docker compose exec --user root prometheus sh
wget -O - host.docker.internal:8281/metrics 
  Connecting to host.docker.internal:8281 (172.17.0.1:8281)
  wget: can't connect to remote host (172.17.0.1): Connection timed out
ping 172.17.0.1
PING 172.17.0.1 (172.17.0.1): 56 data bytes
64 bytes from 172.17.0.1: seq=0 ttl=64 time=0.201 ms
```
So we got a connection problem, this is strange because the port seems exposed
```bash
docker ps|grep node
53ebef18c7a6   prom/node-exporter:v1.2.2                                   "/bin/node_exporter …"   7 months ago   Up 7 months             0.0.0.0:8281->9100/tcp, [::]:8281->9100/tcp                                    filebeat-node_exporter-1
```
It might be a firewall problem ?
We have the accept in INPUT for PrivateNet4,
but the PrivateNet4 set only has 10.0.0.0/8.

This is blocking requests.

I modified the `off_private_networks_v4` in `group_vars/all/common.yml`
and run:
```bash
ansible-playbook jobs/configure.yml -l monitoring-01 --tags firewall
```

back to my `prometheus` container on `monitoring-01`,
I now have `wget -O - host.docker.internal:8281/metrics` working correctly !

The change is contributed in https://github.com/openfoodfacts/openfoodfacts-infrastructure/pull/595

The strange thing is that I see no alerts in prometheus logs
about `host.docker.internal` not working…

### Fixing the alert

Now I want my alert to be more general.

Playing around in prometheus graph interface,
I came with this expression:

```promql
node_filesystem_avail_bytes{device!="tmpfs",device!="ramfs"} / on (app,device,env,service,fstype,mountpoint) node_filesystem_size_bytes{device!="tmpfs",device!="ramfs"}
```

The first term selects `node_filesystem_avail_bytes` that are not tmpfs or ramfs,
We then do a division by metrics `node_filesystem_size_bytes`
having the same `app,device,env,service,fstype,mountpoint` labels as the first one.

But finally it seems the on is not mandatory, by default it will match all labels,
so this simpler expression works:
```promql
(node_filesystem_avail_bytes{device!="tmpfs",device!="ramfs"} / node_filesystem_size_bytes)
```

This is contributed in https://github.com/openfoodfacts/openfoodfacts-monitoring/pull/129