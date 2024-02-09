# Redis

Redis is a very versatile database to act as a synchronization between different services.

We are using redis in a variety of places.

## Production Instance for OFF

We have a production instance of Redis dedicated to OFF.

It is currently use for the event stream function to enable other services like off-queries, robotoff and search-a-licious to update their data.

### Install

It's on a container on the off proxmox cluster, on container 113.

`/var/lib/redis` is in a specific dataset.

This is a simple debian deployment (specific configurations are in `confs/off-redis`),
we override systemd service to send emails on failure.

It is proxied between ovh and free datacenter through [stunnel](./stunnel.md)


## Matomo

[Matomo also uses Redis Queues](./matomo.md) to be able to manage the traffic.

