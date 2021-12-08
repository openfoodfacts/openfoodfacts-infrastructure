# Observability

This document describes the observability stack used at Open Food Facts to monitor applications. 

Having a good observability stack is critical to spend less time when debugging failures, to have a comprehension of how applications behave over time, and to have the ability to compare a software version with the previously deployed one.

The observability stack used in the OFF stack is comprised of the following applications:

* **Filebeat** as a logs collection agent deployed on each QEMU VM with Docker containers.

* **ElasticSearch** for centralized storage and indexing of logs collected from Docker.

* **Kibana** UI to visualize and use logs collected by ElasticSearch.

* **Prometheus** for scraping metrics from Prometheus exporters' `/metrics` endpoint, running as sidecar containers of the applications.

* **AlertManager** to send alerts based on Prometheus metrics, integrated with dedicated Slack channels.

* **Grafana** for visualizing Prometheus metrics, InfluxDB and other metrics; and create dashboards.

* **Prometheus exporters** such as the [Apache Prometheus Exporter](https://github.com/Lusitaniae/apache_exporter), which collect metrics from applications and expose them on a port in the Prometheus metric format. Some applications natively export Prometheus metrics and do not need additional exporters.

The observability stack diagram is as follows:

![Observability stack](./img/obs_stack.png)
