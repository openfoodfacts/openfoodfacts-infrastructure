# How to deploy a new service

Open Food Facts is made of several components and tools for the community or to manage the innfrastructure.

Each of those service will cost resources and have certain requirements to run.
It's important to keep those things in mind when deploying a new service.

## Decide where to deploy

First you have to decide the way you will deploy your service:

* using [docker-compose](./docker_architecture.md) is the preferred way to deploy a service that have developments.
  It enables an easy updgrade of main components, a good reproducibility of the environment,
  and a good integration in [CI/CD tools](./cicd.md)

  Docker compose are to be deployed in a VM. We are also experimenting deploying them in containers, but there is no official support for that.

* using a [proxmox container](./proxmox.md#how-to-create-a-new-container) is the second best option.
  Use this if you deploy a service that is packaged in debian,
  or that updates easily in such environment (eg. a PHP software).

That decided you have to choose the best server to deploy your service.
This is done in coordination with the infrastructure team.

Factors to consider:
* resources needed by the service
* latency needed to access other services (or the other way around)
* how critical the service is


## Separating data from the system

It's important to try to separate data from the system.

You have different types of data:
* Primary source Data
* Indexes (that can be rebuilt)
* Caches and temporary data
* Logs
* Configurations data

Separating Data has a lot of benefits:
* It enables updating the system without putting data at risk and enabling a roll-back without loosing data
* It's enables putting data on faster disks if needed.

Of course if your service is not very important, does not have much data, and you can afford loosing some data, it might not be worth the effort.

## Watch for performance after deployment

If your service is heavy duty, try to do some performance check in staging.

After deployment you should also check
how the new service impacts the performance of the whole system.

[Munin](./munin.md) offers a good way to check that,
as you can compare performances before and after deployment.

Some key indicators to monitor:
* CPU usage (also look at I/O wait time)
* RAM usage
* disk Usage (utilization per device)
* Pressure stall information, gives you indication on the bottleneck between CPU, disk and RAM