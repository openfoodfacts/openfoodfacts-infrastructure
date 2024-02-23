# Redis

Redis is a very versatile database to act as a synchronization between different services.

We are using redis in a variety of places.

## Production Instance for OFF

We have a production instance of Redis dedicated to OFF.

It is currently use for the event stream function to enable other services like off-queries, robotoff and search-a-licious to update their data.

It is proxied between ovh and free datacenter through [stunnel](./stunnel.md).
To use it from ovh1/ovh2, connect to stunnel client server on standard Redis port: `10.1.0.113:6379`.

### Install

It's on a container on the off proxmox cluster, on container 122.

`/var/lib/redis` is in a specific dataset.

This is a simple debian deployment (specific configurations are in `confs/off-redis`),
we override systemd service to send emails on failure.


## Matomo

[Matomo also uses Redis Queues](./matomo.md) to be able to manage the traffic.


## Related reports

* [Setting up Stunnel](./reports/2024-01-04-setting-up-stunnel.md)
* [Prod Redis install](./reports/2024-02-08-prod-redis-install.md)
