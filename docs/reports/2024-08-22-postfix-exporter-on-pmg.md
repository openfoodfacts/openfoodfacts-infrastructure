# 2024-08-22 Adding postfix exporter to Proxmox Mail Gateway

Email is very important either to get alerts or to send email to our users.

We were not following email delivery on a regular basis.

I decided to give it a try to add a postfix exporter to the PMG container.

I installed the postfix exporter:

```bash
apt install prometheus-postfix-exporter
```

Tested it:
```bash
curl 10.1.0.102:9154/metrics
```
It was working.

I then add the scrapping configuration to prometheus in the monitoring project:

```bash
# in prometheus/config.yml
  - job_name: pmg-postfix
    static_configs:
      - targets:
        # PMG
        - "10.1.0.102:9154"
        labels:
          app: Proxmox mail gateway
          service: postfix
          env: prod
```

and I configured a first alert to verify queues don't have too much stall emails:

```bash
# in  prometheus/alerts.yml
  - alert: Postfix mail messages queue is high
    expr: postfix_showq_message_age_seconds_count > 20
    for: 1h
    labels:
      severity: warning
      instance: "{{ $labels.instance }}"
    annotations:
      summary: stalled messages in queue {{ $labels.queue }} of {{ $labels.app }} ({{ $labels.instance }})
      description: Number of messages for queue {{ $labels.queue }} of {{ $labels.app }} ({{ $labels.instance }}) is {{ $value }} for more than 1h.
```

Related commit in openfoodfacts-monitoring [295a8e1](https://github.com/openfoodfacts/openfoodfacts-monitoring/commit/295a8e174470482c759648a39ce53fd50631326f)

As I had deferred email currently in queue
(because of a solved bug on ovh3 where bug were sent to the wrong host)
I was able to test that is was working.

I have a [PR to add an alert if the number of message sent drops significantly](https://github.com/openfoodfacts/openfoodfacts-monitoring/pull/113) but I have to wait that we have enough values in prometheus to activate it.