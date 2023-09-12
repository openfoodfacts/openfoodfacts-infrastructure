# ovh2 server logs

Report here the timeline of incidents and interventions on ovh2 server.
Keep things short or write a report.

## 2023-09-04 cleaning docker monitoring VM

In order to enable using off-query on staging (which will consume around 35G of data)
* removed the `monitoring/` docker containers and volumes (docker-compose down -v) and the folder
  as they were moved to their own container (see [2022-11 moving monitoring to its own machine](./reports/2022-11-09-monitoring-move-to-own-vm.md))
* `docker volume prune`  reclaimed space.
* from 76G (out of 294) of free space we are back to 118G.
