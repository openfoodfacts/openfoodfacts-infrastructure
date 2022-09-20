# Docker architecture

Below is a diagram of how the various OFF apps interact within the Docker
environments:

![Docker architecture](./img/docker_arch.png)


## Docker server for staging

The 200 VM on ovh2 is the serveur hosting the docker for stagging.


## Docker server for prod

The 201 VM on ovh2 is the serveur hosting the docker for production.

## Useful commands

List all mapped ports on a VM:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}'|grep '\->'
```