# Kibana down because of Elasticsearch circuit_breaking_exception

## Symptoms

We got a lot of alerts in infrastructure-alerts slack channel for:

> Service probe on URL 'https://kibana.openfoodfacts.org/status' failed for more than 5 minutes.

Going to the status url we got a "server error".

## Trying to diagnose and remedy

### Base problem

On the machine, looking at kibana logs, while doing a request

```
docker-compose logs --tail=0 -f kibana
```
we see
```json
kibana_1                  | {"type":"log","@timestamp":"2022-07-27T12:36:07+00:00","tags":["error","plugins","security","authentication"],"pid":1216,"message":"License is not available, authentication is not possible."}
kibana_1                  | {"type":"log","@timestamp":"2022-07-27T12:36:07+00:00","tags":["warning","plugins","licensing"],"pid":1216,"message":"License information could not be obtained from Elasticsearch due to {\"error\":{\"root_cause\":[{\"type\":\"circuit_breaking_exception\",\"reason\":\"[parent] Data too large, data for [<http_request>] would be [1028220976/980.5mb], which is larger than the limit of [1020054732/972.7mb], real usage: [1028220976/980.5mb], new bytes reserved: [0/0b], usages [request=0/0b, fielddata=0/0b, in_flight_requests=0/0b, model_inference=0/0b, eql_sequence=0/0b, accounting=76757928/73.2mb]\",\"bytes_wanted\":1028220976,\"bytes_limit\":1020054732,\"durability\":\"PERMANENT\"}],\"type\":\"circuit_breaking_exception\",\"reason\":\"[parent] Data too large, data for [<http_request>] would be [1028220976/980.5mb], which is larger than the limit of [1020054732/972.7mb], real usage: [1028220976/980.5mb], new bytes reserved: [0/0b], usages [request=0/0b, fielddata=0/0b, in_flight_requests=0/0b, model_inference=0/0b, eql_sequence=0/0b, accounting=76757928/73.2mb]\",\"bytes_wanted\":1028220976,\"bytes_limit\":1020054732,\"durability\":\"PERMANENT\"},\"status\":429} error"}
```

### More memory

The day before, I gave more memory to ES to see if it was the problem, but it's not (see [openfoodfacts-monitoring:#54](https://github.com/openfoodfacts/openfoodfacts-monitoring/pull/54)).

### Continue diagnosis

If we go on kibana container we can reproduce error:

```
docker-compose exec kibana bash
```

ES is there:
```
curl -XGET http://elasticsearch:9200
```

but we get the circuit_breaking_exception while querying
```json
curl -XGET http://elasticsearch:9200/_license?pretty=true
{
  "error" : {
    "root_cause" : [
      {
        "type" : "circuit_breaking_exception",
        "reason" : "[parent] Data too large, data for [<http_request>] would be [1027528328/979.9mb], which is larger than the limit of [1020054732/972.7mb], real usage: [1027528328/979.9mb], new bytes reserved: [0/0b], usages [request=0/0b, fielddata=0/0b, in_flight_requests=0/0b, model_inference=0/0b, eql_sequence=0/0b, accounting=76607288/73mb]",
        "bytes_wanted" : 1027528328,
        "bytes_limit" : 1020054732,
        "durability" : "PERMANENT"
      }
    ],
    "type" : "circuit_breaking_exception",
    "reason" : "[parent] Data too large, data for [<http_request>] would be [1027528328/979.9mb], which is larger than the limit of [1020054732/972.7mb], real usage: [1027528328/979.9mb], new bytes reserved: [0/0b], usages [request=0/0b, fielddata=0/0b, in_flight_requests=0/0b, model_inference=0/0b, eql_sequence=0/0b, accounting=76607288/73mb]",
    "bytes_wanted" : 1027528328,
    "bytes_limit" : 1020054732,
    "durability" : "PERMANENT"
  },
  "status" : 429
}

```


trying to [get stats](https://www.elastic.co/guide/en/elasticsearch//reference/current/cluster-nodes-stats.html) for breaker:
```
curl -XGET elasticsearch:9200/_nodes/stats/breaker?pretty=true
```
we see:
```json
"parent" : {
          "limit_size_in_bytes" : 1020054732,
          "limit_size" : "972.7mb",
          "estimated_size_in_bytes" : 1030370648,
          "estimated_size" : "982.6mb",
          "overhead" : 1.0,
          "tripped" : 39108
        }
```

Parent is the responsible for all memory according to [amazon help center]() :

>  The parent circuit breaker (a circuit breaker type) is responsible for the overall memory usage of your cluster.

I tried to clear out `fielddata` cache:

```
curl -XPOST http://elasticsearch:9200/*/_cache/clear?fielddata=true
```
but it does not solve the problem.

### Tunning parent circuit breaker

Comparing to [reference documentation](https://www.elastic.co/guide/en/elasticsearch/reference/7.0/circuit-breaker.html#parent-circuit-breaker),
our settings seems a bit low compared to defaults.

I will try to augment the parent size for now, and set it to real memory tracking.

Edited the docker-compose to add configuration (through environment variables):

```yaml
  elasticsearch:
  ...
    environment:
    ...
      - "indices.breaker.total.use_real_memory=true"
      - "indices.breaker.request.limit=95%"
```

and restarted the container
```
docker-compose restart elasticsearch
```

It's not enough.

The issue might be that we have too much  data (17Gb indexes)

### Garbage collection ?

Is that maybe related to Garbage collection ?
Listing `/usr/share/elasticsearch/config/jvm.options` in the container shows that G1GC is in use:

```bash
## GC configuration
8-13:-XX:+UseConcMarkSweepGC
8-13:-XX:CMSInitiatingOccupancyFraction=75
8-13:-XX:+UseCMSInitiatingOccupancyOnly

## G1GC Configuration
# NOTE: G1 GC is only supported on JDK version 10 or later
# to use G1GC, uncomment the next two lines and update the version on the
# following three lines to your version of the JDK
# 10-13:-XX:-UseConcMarkSweepGC
# 10-13:-XX:-UseCMSInitiatingOccupancyOnly
14-:-XX:+UseG1GC
```

line `14-:` applies for we are on version 16 of the jdk:

```
# jdk/bin/java --version
openjdk 16.0.2 2021-07-20
```

### Data size

In elasticsearch container:
```
curl localhost:9200/_cluster/stats?pretty=true
```

We got
```json
 ...
 "segments" : {
      "count" : 2390,
      "memory_in_bytes" : 76423432,
      "terms_memory_in_bytes" : 65353984,
      "stored_fields_memory_in_bytes" : 1225392,
      "term_vectors_memory_in_bytes" : 0,
      "norms_memory_in_bytes" : 9117696,
      "points_memory_in_bytes" : 0,
      "doc_values_memory_in_bytes" : 726360,
      "index_writer_memory_in_bytes" : 35328144,
      "version_map_memory_in_bytes" : 0,
      "fixed_bit_set_memory_in_bytes" : 960,
      "max_unsafe_auto_id_timestamp" : 1658927252002,
      "file_sizes" : { }
    },
 ...
}
```
other memory values (for `querycache` or `fielddata`) ar `0` or near `0`.

This is 188,175,008 bytes in total, which is 180m.

If we look at nodes using [cat nodes API](https://www.elastic.co/guide/en/elasticsearch/reference/7.14/cat-nodes.html):

```
curl -XGET "localhost:9200/_cat/nodes?v=true&h=name,node*,heap*"
name         id   node.role   heap.current heap.percent heap.max
0665175f0369 3vOq cdfhilmrstw      978.5mb           95      1gb
```
we see two potential problems:
* heap size is only 1gb (it should be 2 according to our heap settings)
* our a node use 95% memory

### Too many shards ?

following [Es blog on memory troubleshooting](https://www.elastic.co/blog/managing-and-troubleshooting-elasticsearch-memory)

Over sharding is a usual suspect, let see:

```json
# curl -XGET "localhost:9200/_cluster/health?filter_path=status,*_shards&pretty=true"
{
  "status" : "yellow",
  "active_primary_shards" : 317,
  "active_shards" : 317,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 302,
  "delayed_unassigned_shards" : 0
}
```

while recommanded for our setting (2Gb) is 40 shards !
Also having `unassigned_shards` seems a bad news !

The problems comes from the fact that we have many indices. The ILM (Index Life Cycle Management) should prevent that, but it does not.

## Repairing (backup then remove old indices)

### More memory

First I need to snapshot to eventually clear some indices. But with the exception I can't do it, I can't even check a snapshot repository already exists:

```
$ curl -XGET 127.0.0.1:9200/_snapshot
{"error":{"root_cause":[{"type":"circuit_breaking_exception","reason":"[parent] Data too large, data for [<http_request>] would be [1026619992/979mb], which is larger than the limit of [1020054732/972.7mb], real usage: [1026619992/979mb], new bytes reserved: [0/0b], usages [request=0/0b, fielddata=815/815b, in_flight_request...
```

No choice then, we have to give ES enough memory to be able to handle current indices… we go for a hype of 8G.
I change the `docker-compose.yml`:
```yaml
  elasticsearch:
    ...
    environment:
      ...
      - "ES_JAVA_OPTS=-Xms8048m -Xmx8048m"
    ...
    mem_limit: 9g
```

But then again after a while we are blocked by the exception again :-(
Even stranger, we have a larger than the limit of [1020054732/972.7mb]


circuit breaker limit was for request not total !
changed `indices.breaker.request.limit=95%` to `indices.breaker.total.limit=95%`.
... same result !

### Snapshoting (backup)

Trying to backup:

- modified docker-compose.yml to add

  ```yaml
  elasticsearch
      ...
      environment:
      ...
      - "path.repo=/opt/elasticsearch/backups"
      ...
      volumes:
      - elasticsearch-backup:/opt/elasticsearch

  volumes:
  ...
  elasticsearch-backup:
  ```
- Create directories

  ```bash
  docker-compose run --rm elasticsearch bash
  cd /opt/elasticsearch
  mkdir backups
  chown elasticsearch /opt/elasticsearch/ -R
  ```

- Recreated container

  ```bash
  docker-compose rm -sf elasticsearch
  docker-compose up -d elasticsearch
  ```

- Created the snapshot repository
  ```bash
  curl -X PUT "http://localhost:9200/_snapshot/backups?pretty" -H 'Content-Type: application/json'     -d'
  {
    "type": "fs",
    "settings": {
      "location": "/opt/elasticsearch/backups"
    }
  }
  '
  ```
  **Note:** (we had to retry several times because of circuit breaking exceptions)

- get all indices names

    ```bash
    curl -XGET "http://localhost:9200/*?pretty=true"|grep '^  "logs'
    ```

- make a global snapshot, in a screen !!!

  ```bash
  screen
  ...
  curl -X PUT "localhost:9200/_snapshot/backups/2022-07-31?wait_for_completion=true&pretty" -H   'Content-Type: application/json' -d'
  {
    "indices": [],
    "ignore_unavailable": true,
    "include_global_state": false,
    "metadata": {
      "taken_by": "alex",
      "taken_because": "backup before removing some indices"
    }
  }
  '
  ```
  And it's a success !

  ```json
  {
  "snapshot" : {
    "snapshot" : "2022-07-31",
    "uuid" : "kHQXBTGhQb-4-jH0m5mMfg",
    "repository" : "backups",
    "version_id" : 7140199,
    ...
    "state" : "SUCCESS",
    "start_time" : "2022-07-31T18:06:51.220Z",
    "start_time_in_millis" : 1659290811220,
    "end_time" : "2022-07-31T18:15:08.301Z",
    "end_time_in_millis" : 1659291308301,
    "duration_in_millis" : 497081,
    "failures" : [ ],
    "shards" : {
      "total" : 322,
      "failed" : 0,
      "successful" : 322
    },
    "feature_states" : [ ]
  }
  }
  ```

So we start removing indices !


### Removing indices

Let's remove 2021 logs

```bash
curl -X DELETE "localhost:9200/logs-2021.*?pretty=true"
```

Is hard to pass, so we restart elasticsearch and try again… success.

Lets remove 2022.01… until 04

Finally it works !

## Fixing Snapshot policy and ILM policy

It is a temporary fix… now we have to use kibana to setup a better policy (and maybe take ES memory down a bit again ?)

### Create snapshot policy

In Kibana, go to Management -> Stack Management -> Snapshot and restore

In "Repositories" we see the `backups` repository that was created before, pointing to `/opt/elasticsearch/backups`

Remember that we had to edit the `docker-compose.yml` file to add the `path.repo` environment variable and the `elasticsearch-backup` volume.

In "Policies", we create a policy named `weekly-snapshots` as follow:
- Snapshot name: `<weekly-snap-{now/d}>`
- Repository: backups
- Schedule : weekly
- Data streams and indices: All indices
- Ignore unavailable indices: No
- Allow partial shards: No
- Include global state: Yes
- Retention: delete after 360d
- Min count: 20

### Create Index Lifecycle Management policy

This part is very important. Logs are creating a lot of indices (as logrotate would) and so we have to automatically manage what happens with old indices so that we do not go beyond hardware capabilities (too much indices takes too much memory).
ES has a mechanism for that called Index Lifecycle Management (ILM).

In Kibana, go to Management -> Stack Management -> Index Lifecycle Policy

There is already a log policy. Edit it to have this:

* Hot phase (the phase where the index is the active index for logs)
  * Roll over : use recommended defaults
  * set index priority to 100
* Warm phase (the phase where the index is history of logs, you want to search)
  * Move data into phase when 58 days old
  * replicas: 0
  * Shrink: to 1
  * Force merge to 1 + compress
  * mark read only
  * index priority: 50
* Cold phase (historical data, last phase before removal)
  * Move data into phase when: 119 days old
  * Do not make them searchable
* Delete phase:
  * move data intor phase when 240 days old
  * Wait for snapshot policy: weekly-snapshots


### Attach policy to index template

Attach the logs policy you edited to the logs index template.

In Management -> Stack Management -> Index Lifecycle Policy,

* On the line corresponding to **logs** policy, use *Action* button + *Add policy to index template*
* Set template to **logs**
* Set alias to **logs-current**

We notice that logs template pattern was not coherent, as it was `logs-*-*`, so we also add `logs-*.*.*` that match our indexes names.
To do this goes to Management -> Stack Management -> Index Management -> Index Templates, and edit the logs template.

Now we have to create the active alias. It should correspond to our last index. This was `logs-2022.08.18` at time of writing.

In the Dev Tool -> Console, we run:

```
POST _aliases
{
  "actions": [
    {
      "add": {
        "index": "logs-2022.08.18",
        "alias": "logs-current",
         "is_write_index": true
      }
    }
  ]
}
```

We then go to  Management -> Stack Management -> Index Management

Select *logs-2022.08.18* and use "Manage" apply log policy, with:
* policy: logs
* alias: logs-current

### Attach old index to a policy

This will add it for future indices, but we want to add it to existing indices (we follow [ES doc, section Manage existing indices](https://www.elastic.co/guide/en/elasticsearch/reference/current/ilm-with-existing-indices.html)).

* going to Management -> Stack Management -> Index Lifecycle Policy
  we create a policy that is exactly the same as logs policy but:
  * name is logs-old
  * rollover is disabled
* we apply it to 05 logs, in Dev Tool -> Console, by running (put the unix timestamp value corresponding to the month in `origination_date`[^origination_date]):
  ```
  PUT logs-2022.05.*/_settings
  {
    "index": {
      "lifecycle": {
        "name": "logs-old"
        "origination_date": "xxxxx"
      }
    }
  }
  ```
* we do the  same for every monthes until 08, but beware not to apply it to 2022.08.18 !

[^origination_date]:
    this is the timestamp used to calculate the index age for its phase transitions. If not specified, today date is taken.
    see [documentation](https://www.elastic.co/guide/en/elasticsearch/reference/8.6/ilm-settings.html#index-lifecycle-origination-date).
    You can get timestamp, eg in python with `datetime(year, month, date).timestamp()`.

## Useful resources

About circuit breaker exception:
- https://aws.amazon.com/premiumsupport/knowledge-center/opensearch-circuit-breaker-exception/
- https://www.elastic.co/blog/improving-node-resiliency-with-the-real-memory-circuit-breaker
- https://www.elastic.co/guide/en/elasticsearch/reference/7.0/circuit-breaker.html#parent-circuit-breaker

About index lifecycle management (ILM):
* https://www.elastic.co/guide/en/elasticsearch/reference/current/getting-started-index-lifecycle-management.html
* https://www.elastic.co/guide/en/elasticsearch/reference/current/index-lifecycle-management.html
