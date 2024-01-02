# 2024-01-02 monitoring disk space - filebeat

## problem

We had an alert because free disk space on monitoring docker VM (203) was below 20%.

After a quick look at docker volumes size, I saw that Elasticsearch was taking most of the space.

Using Kibana, stack management, index management, I saw that the logs data stream was huge.
It was expected since we have an index lifecycle management problem. See https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/199

## Resolution

### short term

I abruptely removed all data stream (we don't use log so much, so it was an expeditive way).

But as filebeat was still running, a logs-current was created, and we would run in the same problem again.

### long term

I logged to docker production VM (200), staging VM (201) and monitoring (203) and stopped filebeat docker on all those VMs.

Then I removed logs-current index.

As a tentative to repair ILM, I modified the filebeat/config.yml on monitoring to add add `setup.ilm.overwrite: true` directive

But before I backup my policy by saving it as a new policy.

I added KIBANA_URI to docker-compose.node.yml because it was missing (see [openfoodfacts-monitoring commit 7131f0c5](https://github.com/openfoodfacts/openfoodfacts-monitoring/commit/7131f0c5a076d4e35bfd1c6a9f9da5c6bd070185)).

Then in off monitoring VM, `/home/off/filebeat`, I run:
```bash
docker-compose run --rm filebeat bash
$ filebeat setup --index-management
$ filebeat setup --dashboards # does not work complains about kibana version
```
I don't care for now that dashboards did not work. The important is ILM setup.

I then removed the `setup.ilm overwrite: true` directive

I restarted all the filebeat in all VM.

I can see the `logs-current-logs-2024.01.02-000001` index created in kibana. That's kind of a good sign.

I can see in kibana that the Index lifecycle management `logs` was created, but it's not configured to remove files. So I changed it's setup, thanks to backup I made.

If I see index templates, I'm not yet sure that everything is ok because there is a template for `logs-*-*-*, logs-*-*-*-*, logs-*.*.*, logs-*.*.*-*` and one for `logs-current-*`, so I'm not totally sure which one will apply (I think `logs-current-*` would be the good one). Let's see tomorrow.

I also added the index life cycle management definition in the repository, so that next time it's correctly configured. (see [openfoodfacts-monitoring commit 234fd2da](https://github.com/openfoodfacts/openfoodfacts-monitoring/commit/234fd2daf9101a3e7f8fe0b94d4a6bab9fe3d57b).)

