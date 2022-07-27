# Kibana down because of Elasticsearch circuit_breaking_exception

## Symptoms

We got a lot of alerts in infrastructure-alerts slack channel for:

> Service probe on URL 'https://kibana.openfoodfacts.org/status' failed for more than 5 minutes.

Going to the status url we got a "server error".

## Trying to diagnose and remedy

On the machine, looking at kibana logs, while doing a request

```
docker-compose logs --tail=0 -f kibana
```
we see
```json
kibana_1                  | {"type":"log","@timestamp":"2022-07-27T12:36:07+00:00","tags":["error","plugins","security","authentication"],"pid":1216,"message":"License is not available, authentication is not possible."}
kibana_1                  | {"type":"log","@timestamp":"2022-07-27T12:36:07+00:00","tags":["warning","plugins","licensing"],"pid":1216,"message":"License information could not be obtained from Elasticsearch due to {\"error\":{\"root_cause\":[{\"type\":\"circuit_breaking_exception\",\"reason\":\"[parent] Data too large, data for [<http_request>] would be [1028220976/980.5mb], which is larger than the limit of [1020054732/972.7mb], real usage: [1028220976/980.5mb], new bytes reserved: [0/0b], usages [request=0/0b, fielddata=0/0b, in_flight_requests=0/0b, model_inference=0/0b, eql_sequence=0/0b, accounting=76757928/73.2mb]\",\"bytes_wanted\":1028220976,\"bytes_limit\":1020054732,\"durability\":\"PERMANENT\"}],\"type\":\"circuit_breaking_exception\",\"reason\":\"[parent] Data too large, data for [<http_request>] would be [1028220976/980.5mb], which is larger than the limit of [1020054732/972.7mb], real usage: [1028220976/980.5mb], new bytes reserved: [0/0b], usages [request=0/0b, fielddata=0/0b, in_flight_requests=0/0b, model_inference=0/0b, eql_sequence=0/0b, accounting=76757928/73.2mb]\",\"bytes_wanted\":1028220976,\"bytes_limit\":1020054732,\"durability\":\"PERMANENT\"},\"status\":429} error"}
```

The day before, I gave more memory to ES to see if it was the problem, but it's not (see [openfoodfacts-monitoring:#54](https://github.com/openfoodfacts/openfoodfacts-monitoring/pull/54)).

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


# Useful resources

- https://aws.amazon.com/premiumsupport/knowledge-center/opensearch-circuit-breaker-exception/
- https://www.elastic.co/blog/improving-node-resiliency-with-the-real-memory-circuit-breaker
- https://www.elastic.co/guide/en/elasticsearch/reference/7.0/circuit-breaker.html#parent-circuit-breaker